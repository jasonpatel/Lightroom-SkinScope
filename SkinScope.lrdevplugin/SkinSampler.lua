--[[
  SkinSampler.lua
  Skin pixel sampling engine for SkinScope.
  Coordinates native Lightroom rendered thumbnail extraction,
  fallback to raw file preview, and Python sampling execution.
]]

local LrTasks = import 'LrTasks'
local LrPathUtils = import 'LrPathUtils'
local LrPrefs = import 'LrPrefs'

local SkinSampler = {}

--- Request a rendered JPEG thumbnail from Lightroom's preview cache.
-- Returns jpegData (binary string) or nil, errorMsg
function SkinSampler.getRenderedThumbnail(photo, size, timeoutSec)
    size = size or 1024
    timeoutSec = timeoutSec or 6

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

--- Sample skin pixels from a photo.
-- Tries rendered JPEG thumbnail first (reflects active edits & works with Smart Previews),
-- then falls back to the original raw file path if needed.
function SkinSampler.samplePhoto(photo)
    if not photo then return nil end

    local pluginPrefs = LrPrefs.prefsForPlugin()
    local thumbSize = tonumber(pluginPrefs.thumbnailSize) or 1024

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

    -- Helper to execute python and parse results
    local function executeAndParse(sourceFile)
        local cmd = string.format('python "%s" "%s" "%s"', pyScript, sourceFile, sampleJson)
        local code = LrTasks.execute(cmd)
        if code ~= 0 then
            local cmd3 = string.format('python3 "%s" "%s" "%s"', pyScript, sourceFile, sampleJson)
            code = LrTasks.execute(cmd3)
        end

        local f = io.open(sampleJson, "r")
        if not f then return nil end
        local content = f:read("*all")
        f:close()

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

        return {
            sampled_skin = sampledSkin,
            face_sample = faceSample,
            body_sample = bodySample,
        }
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
