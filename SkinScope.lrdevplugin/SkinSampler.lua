--[[
  SkinSampler.lua
  Skin pixel sampling engine for SkinScope.
  Coordinates native Lightroom rendered thumbnail extraction,
  fallback to raw file preview, and persistent Python daemon sampling execution.
]]

local LrTasks = import 'LrTasks'
local LrPathUtils = import 'LrPathUtils'
local LrPrefs = import 'LrPrefs'

local WIN_ENV = (LrPathUtils.directorySeparator() == '\\')

local SkinSampler = {}

--- Request a rendered JPEG thumbnail from Lightroom's preview cache.
-- Returns jpegData (binary string) or nil, errorMsg
function SkinSampler.getRenderedThumbnail(photo, size, timeoutSec)
    size = size or 512
    timeoutSec = timeoutSec or 5

    local jpegData, thumbErr, done = nil, nil, false

    photo:requestJpegThumbnail(size, size, function(data, err)
        if data and #data > 0 then
            jpegData = data
        else
            thumbErr = err or "Preview unavailable"
        end
        done = true
    end)

    local deadline = os.time() + timeoutSec
    while not done do
        LrTasks.yield()
        if os.time() > deadline then
            return nil, "Timed out waiting for rendered preview"
        end
    end

    return jpegData, thumbErr
end

--- Internal: Parse skin statistics JSON string into Lua table.
local function parseJsonResult(content, sourceFile, thumbPath)
    if not content or not content:find('"success":%s*true') then
        return nil
    end

    local r = tonumber(content:match('"r":%s*([%d%.]+)'))
    local g = tonumber(content:match('"g":%s*([%d%.]+)'))
    local b = tonumber(content:match('"b":%s*([%d%.]+)'))
    local angle = tonumber(content:match('"angle":%s*([%d%.]+)'))
    local sat = tonumber(content:match('"sat":%s*([%d%.]+)'))
    local luma = tonumber(content:match('"luma":%s*([%d%.]+)'))

    local sampledSkin = nil
    if r and g and b then
        sampledSkin = { r = r, g = g, b = b, angle = angle, sat = sat, luma = luma }
    end

    local faceSample = nil
    local face_str = content:match('"face":%s*({[^}]+})')
    if face_str then
        local fr = tonumber(face_str:match('"r":%s*([%d%.]+)'))
        local fg = tonumber(face_str:match('"g":%s*([%d%.]+)'))
        local fb = tonumber(face_str:match('"b":%s*([%d%.]+)'))
        local fa = tonumber(face_str:match('"angle":%s*([%d%.]+)'))
        local fs = tonumber(face_str:match('"sat":%s*([%d%.]+)'))
        local fl = tonumber(face_str:match('"luma":%s*([%d%.]+)'))
        if fr and fg and fb then
            faceSample = { r = fr, g = fg, b = fb, angle = fa, sat = fs, luma = fl }
        end
    end

    local bodySample = nil
    local body_str = content:match('"body":%s*({[^}]+})')
    if body_str then
        local br = tonumber(body_str:match('"r":%s*([%d%.]+)'))
        local bg = tonumber(body_str:match('"g":%s*([%d%.]+)'))
        local bb = tonumber(body_str:match('"b":%s*([%d%.]+)'))
        local ba = tonumber(body_str:match('"angle":%s*([%d%.]+)'))
        local bs = tonumber(body_str:match('"sat":%s*([%d%.]+)'))
        local bl = tonumber(body_str:match('"luma":%s*([%d%.]+)'))
        if br and bg and bb then
            bodySample = { r = br, g = bg, b = bb, angle = ba, sat = bs, luma = bl }
        end
    end

    local width = tonumber(content:match('"width":%s*(%d+)'))
    local height = tonumber(content:match('"height":%s*(%d+)'))
    local count = tonumber(content:match('"count":%s*(%d+)'))

    return {
        sampled_skin = sampledSkin,
        face_sample = faceSample,
        body_sample = bodySample,
        sample_info = {
            width = width,
            height = height,
            count = count,
            source = (sourceFile == thumbPath and "Preview" or "Raw"),
        },
    }
end

--- Get or launch persistent Python sampling daemon.
local daemonPort = nil

local function getPortFilePath()
    local logDir = LrPathUtils.getStandardFilePath('appData') or _PLUGIN.path
    return LrPathUtils.child(logDir, 'skinscope_daemon.port')
end

local function readDaemonPort()
    local portFile = getPortFilePath()
    local f = io.open(portFile, "r")
    if f then
        local p = tonumber(f:read("*line"))
        f:close()
        if p and p > 1024 then
            return p
        end
    end
    return nil
end

local function startDaemon()
    local portFile = getPortFilePath()
    pcall(function() os.remove(portFile) end)
    local pyScript = LrPathUtils.child(_PLUGIN.path, 'sample_photo.py')

    -- Launch detached Python daemon process
    local cmd = string.format('python "%s" --daemon "%s"', pyScript, portFile)
    if WIN_ENV then
        -- Windows: launch detached via cmd start /b
        LrTasks.execute(string.format('cmd /c start "" /b python "%s" --daemon "%s"', pyScript, portFile))
    else
        LrTasks.execute(string.format('python3 "%s" --daemon "%s" &', pyScript, portFile))
    end

    -- Wait up to 1.5 seconds for port file to appear
    for _ = 1, 15 do
        LrTasks.sleep(0.10)
        local p = readDaemonPort()
        if p then
            daemonPort = p
            return daemonPort
        end
    end
    return nil
end

--- Query the daemon using a fast temporary Python bridge or direct socket
local function queryDaemon(port, photoPath, outJsonPath)
    -- Fast client command that executes socket call without importing heavyweight packages
    local clientCode = string.format(
        "import socket, json, sys; s = socket.socket(socket.AF_INET, socket.SOCK_STREAM); s.connect(('127.0.0.1', %d)); s.sendall(json.dumps({'cmd': 'sample', 'path': sys.argv[1]}).encode() + b'\\n'); data = b'';\nwhile b'\\n' not in data:\n    chunk = s.recv(4096)\n    if not chunk: break\n    data += chunk\ns.close()\nwith open(sys.argv[2], 'wb') as f: f.write(data.strip())",
        port
    )
    local cmd = string.format('python -c "%s" "%s" "%s"', clientCode, photoPath, outJsonPath)
    local code = LrTasks.execute(cmd)
    if code ~= 0 then
        local cmd3 = string.format('python3 -c "%s" "%s" "%s"', clientCode, photoPath, outJsonPath)
        code = LrTasks.execute(cmd3)
    end
    return (code == 0)
end

--- Terminate the daemon gracefully
function SkinSampler.stopDaemon()
    local p = daemonPort or readDaemonPort()
    if p then
        local exitCode = string.format(
            "import socket, json; s = socket.socket(socket.AF_INET, socket.SOCK_STREAM); s.connect(('127.0.0.1', %d)); s.sendall(json.dumps({'cmd': 'exit'}).encode() + b'\\n'); s.close()",
            p
        )
        pcall(function() LrTasks.execute(string.format('python -c "%s"', exitCode)) end)
    end
    daemonPort = nil
    pcall(function() os.remove(getPortFilePath()) end)
end

--- Sample skin pixels from a photo.
function SkinSampler.samplePhoto(photo)
    if not photo then return nil end

    local pluginPrefs = LrPrefs.prefsForPlugin()
    local thumbSize = tonumber(pluginPrefs.thumbnailSize) or 512

    local logDir = LrPathUtils.getStandardFilePath('appData') or _PLUGIN.path
    local thumbPath = LrPathUtils.child(logDir, 'skinscope_thumb.jpg')
    local sampleJson = LrPathUtils.child(_PLUGIN.path, 'skin_sample.json')
    local pyScript = LrPathUtils.child(_PLUGIN.path, 'sample_photo.py')

    -- Get RAW path as potential fallback
    local rawPath = nil
    LrTasks.pcall(function()
        rawPath = photo:getRawMetadata('path')
    end)

    -- 1. Try native rendered thumbnail first
    local sampleSource = nil
    local jpegData, thumbErr = SkinSampler.getRenderedThumbnail(photo, thumbSize, 5)
    if jpegData then
        local tf = io.open(thumbPath, "wb")
        if tf then
            tf:write(jpegData)
            tf:close()
            sampleSource = thumbPath
        end
    end

    -- 2. Fallback to rawPath if thumbnail was unavailable
    if not sampleSource and rawPath and rawPath ~= "" then
        sampleSource = rawPath
    end

    if not sampleSource then
        return nil
    end

    -- 3. Execute sampling via persistent daemon (or one-shot fallback)
    local function executeAndParse(sourceFile)
        pcall(function() os.remove(sampleJson) end)

        local port = daemonPort or readDaemonPort()
        if not port then
            port = startDaemon()
        end

        local success = false
        if port then
            success = queryDaemon(port, sourceFile, sampleJson)
            if not success then
                -- Daemon might have died or timed out; try restarting once
                port = startDaemon()
                if port then
                    success = queryDaemon(port, sourceFile, sampleJson)
                end
            end
        end

        -- Fallback to standard one-shot execution if daemon could not be reached
        if not success then
            local cmd = string.format('python "%s" "%s" "%s"', pyScript, sourceFile, sampleJson)
            local code = LrTasks.execute(cmd)
            if code ~= 0 then
                local cmd3 = string.format('python3 "%s" "%s" "%s"', pyScript, sourceFile, sampleJson)
                code = LrTasks.execute(cmd3)
            end
        end

        local f = io.open(sampleJson, "r")
        if not f then return nil end
        local content = f:read("*all")
        f:close()

        return parseJsonResult(content, sourceFile, thumbPath)
    end

    local result = nil
    LrTasks.pcall(function()
        result = executeAndParse(sampleSource)
        -- If thumbnail failed to produce skin samples, try rawPath as last resort
        if not result and sampleSource == thumbPath and rawPath and rawPath ~= "" then
            result = executeAndParse(rawPath)
        end
    end)

    return result
end

return SkinSampler
