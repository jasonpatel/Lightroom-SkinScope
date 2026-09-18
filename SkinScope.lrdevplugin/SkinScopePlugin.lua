--[[
  SkinScopePlugin.lua
  Main entry point for SkinScope in Lightroom Classic.
  Samples the active photo or active people mask and launches the SkinScope diagnostic dialog.
]]

local LrApplication = import 'LrApplication'
local LrTasks = import 'LrTasks'
local LrDialogs = import 'LrDialogs'
local LrDevelopController = import 'LrDevelopController'
local LrApplicationView = import 'LrApplicationView'

LrTasks.startAsyncTask(function()
    local success, err = LrTasks.pcall(function()
        local catalog = LrApplication.activeCatalog()
        local targetPhoto = catalog:getTargetPhoto()

        if not targetPhoto then
            LrDialogs.showError("Please select a photo in the Library or Develop module before opening SkinScope.")
            return
        end

        -- Ensure we can access Develop controller values
        if LrApplicationView.getCurrentModuleName() ~= 'develop' then
            LrApplicationView.switchToModule('develop')
        end

        local curTemp = LrDevelopController.getValue('Temperature')
        local curTint = LrDevelopController.getValue('Tint')
        local curOrangeHue = LrDevelopController.getValue('HueAdjustmentOrange') or 0
        local curExposure = LrDevelopController.getValue('Exposure2012') or LrDevelopController.getValue('Exposure') or 0
        local curOrangeSat = LrDevelopController.getValue('SaturationAdjustmentOrange') or 0

        -- Fallback to photo develop settings if controller returned nil
        if not curTemp or not curTint then
            local devSettings = targetPhoto:getDevelopSettings()
            if devSettings then
                curTemp = curTemp or devSettings.Temperature
                curTint = curTint or devSettings.Tint
                curOrangeHue = curOrangeHue or devSettings.HueAdjustmentOrange or 0
                curExposure = curExposure or devSettings.Exposure2012 or devSettings.Exposure or 0
                curOrangeSat = curOrangeSat or devSettings.SaturationAdjustmentOrange or 0
            end
        end

        -- Read camera flash metadata if available
        local flashFired = 0
        LrTasks.pcall(function()
            flashFired = targetPhoto:getRawMetadata('flashFired') or 0
        end)

        -- Read file name safely
        local fileName = "Active Photo"
        LrTasks.pcall(function()
            fileName = targetPhoto:getFormattedMetadata('fileName') or "Active Photo"
        end)

        local photoPath = nil
        LrTasks.pcall(function()
            photoPath = targetPhoto:getRawMetadata('path')
        end)

        local sampledSkin = nil
        local faceSample = nil
        local bodySample = nil
        if photoPath and photoPath ~= "" then
            local sampleJson = _PLUGIN.path .. "/skin_sample.json"
            local pyScript = _PLUGIN.path .. "/sample_photo.py"
            local cmd = string.format('python "%s" "%s" "%s"', pyScript, photoPath, sampleJson)
            LrTasks.pcall(function()
                LrTasks.execute(cmd)
                local f = io.open(sampleJson, "r")
                if f then
                    local content = f:read("*all")
                    f:close()
                    if content and content:find('"success":%s*true') then
                        local r = tonumber(content:match('"r":%s*([%d%.]+)'))
                        local g = tonumber(content:match('"g":%s*([%d%.]+)'))
                        local b = tonumber(content:match('"b":%s*([%d%.]+)'))
                        local angle = tonumber(content:match('"angle":%s*([%d%.]+)'))
                        local sat = tonumber(content:match('"sat":%s*([%d%.]+)'))
                        local luma = tonumber(content:match('"luma":%s*([%d%.]+)'))
                        if r and g and b then
                            sampledSkin = { r = r, g = g, b = b, angle = angle, sat = sat, luma = luma }
                        end

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
                    end
                end
            end)
        end

        local profileName = "Adobe Color"
        LrTasks.pcall(function()
            local d = targetPhoto:getDevelopSettings() or {}
            profileName = d.Profile or d.CameraProfile or "Adobe Color"
        end)

        local activeSettings = {
            temp = curTemp or 5500,
            tint = curTint or 8,
            baseline_temp = curTemp or 5500,
            baseline_tint = curTint or 8,
            orange_hue = curOrangeHue or 0,
            exposure = curExposure or 0,
            orange_sat = curOrangeSat or 0,
            flash_fired = flashFired or 0,
            file_name = fileName,
            photo_path = photoPath,
            camera_profile = profileName,
            sampled_skin = sampledSkin,
            face_sample = faceSample,
            body_sample = bodySample,
        }

        local SkinScopeDialog = dofile(_PLUGIN.path .. '/SkinScopeDialog.lua')
        SkinScopeDialog.show(activeSettings)
    end)

    if not success then
        local errStr = tostring(err)
        pcall(function()
            local f = io.open("C:\\Users\\me\\AppData\\Roaming\\Adobe\\Lightroom\\skinscope_error.log", "w")
            if f then
                f:write(errStr)
                f:close()
            end
        end)
        LrDialogs.showError("SkinScope Error:\n" .. errStr)
    end
end)
