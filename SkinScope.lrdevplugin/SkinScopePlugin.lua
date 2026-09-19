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
local LrPathUtils = import 'LrPathUtils'

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

        local samplerPath = LrPathUtils.child(_PLUGIN.path, 'SkinSampler.lua')
        local SkinSampler = dofile(samplerPath)
        local samples = SkinSampler.samplePhoto(targetPhoto)

        local sampledSkin = samples and samples.sampled_skin
        local faceSample = samples and samples.face_sample
        local bodySample = samples and samples.body_sample

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

        local dialogPath = LrPathUtils.child(_PLUGIN.path, 'SkinScopeDialog.lua')
        local SkinScopeDialog = dofile(dialogPath)
        SkinScopeDialog.show(activeSettings)
    end)

    if not success then
        local errStr = tostring(err)
        pcall(function()
            local logDir = LrPathUtils.getStandardFilePath('appData') or _PLUGIN.path
            local logPath = LrPathUtils.child(logDir, 'skinscope_error.log')
            local f = io.open(logPath, "w")
            if f then
                f:write(errStr)
                f:close()
            end
        end)
        LrDialogs.showError("SkinScope Error:\n" .. errStr)
    end
end)
