--[[
  SkinScopeBatch.lua
  Batch I-Line Skin Tone Alignment for Adobe Lightroom Classic.
  Processes all selected photos in the Library grid or filmstrip:
  1. Detects skin complexion using rendered thumbnail sampling
  2. Solves exact Orange HSL Hue & Saturation to align to the Rec.709 I-Line
  3. Applies settings with named history states and a progress bar
]]

local LrApplication = import 'LrApplication'
local LrApplicationView = import 'LrApplicationView'
local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrPathUtils = import 'LrPathUtils'
local LrProgressScope = import 'LrProgressScope'
local LrTasks = import 'LrTasks'

local SkinMath = dofile(LrPathUtils.child(_PLUGIN.path, 'SkinMath.lua'))
local SkinSampler = dofile(LrPathUtils.child(_PLUGIN.path, 'SkinSampler.lua'))

LrTasks.startAsyncTask(function()
    local catalog = LrApplication.activeCatalog()
    local curModule = LrApplicationView.getCurrentModuleName()

    -- Lightroom Develop module quirk: getTargetPhotos() only returns the active photo unless in Library
    local wasInDevelop = (curModule == 'develop')
    if wasInDevelop then
        LrApplicationView.switchToModule('library')
        LrTasks.sleep(0.15)
    end

    local photos = catalog:getTargetPhotos()

    if not photos or #photos == 0 then
        if wasInDevelop then
            LrApplicationView.switchToModule('develop')
        end
        LrDialogs.message(
            "SkinScope: Batch Alignment",
            "No photos selected.\n\nPlease select one or more photos in the Library grid or filmstrip and try again.",
            "info"
        )
        return
    end

    local photoCount = #photos
    local confirmMsg = string.format(
        "Align skin tones for %d photo%s to the Vectorscope I-Line?\n\n" ..
        "• Automatically samples skin and detects complexion per photo\n" ..
        "• Aligns Orange Hue & Saturation to the Rec.709 I-Line\n" ..
        "• White Balance, Exposure, and creative presets remain untouched\n" ..
        "• Fully undoable via Edit \226\150\184 Undo or Develop History",
        photoCount,
        photoCount == 1 and "" or "s"
    )

    local confirm = LrDialogs.confirm(
        "SkinScope: Batch I-Line Alignment",
        confirmMsg,
        "Batch Align",
        "Cancel"
    )
    if confirm ~= 'ok' then
        if wasInDevelop then
            LrApplicationView.switchToModule('develop')
        end
        return
    end

    LrFunctionContext.callWithContext('skinScopeBatchProgress', function(context)
        local progress = LrProgressScope({
            title = "SkinScope: Aligning skin tones",
            functionContext = context,
        })

        local successCount = 0
        local skippedCount = 0
        local errors = {}
        local summaries = {}

        for i, photo in ipairs(photos) do
            if progress:isCanceled() then break end

            local fileName = photo:getFormattedMetadata('fileName') or ("photo " .. i)
            progress:setPortionComplete(i - 1, photoCount)
            progress:setCaption(string.format("%s  (%d / %d)", fileName, i, photoCount))
            LrTasks.yield()

            local itemOk, itemErr = LrTasks.pcall(function()
                -- Step 1: Read current develop settings
                local ds = photo:getDevelopSettings() or {}
                local curTemp = ds.Temperature or 5500
                local curTint = ds.Tint or 8
                local curOrangeHue = ds.HueAdjustmentOrange or 0
                local curOrangeSat = ds.SaturationAdjustmentOrange or 0
                local curExp = ds.Exposure2012 or ds.Exposure or 0

                local flashFired = 0
                LrTasks.pcall(function()
                    flashFired = photo:getRawMetadata('flashFired') or 0
                end)

                -- Step 2: Sample skin pixels
                local samples = SkinSampler.samplePhoto(photo)
                local sk = samples and samples.sampled_skin

                if not sk then
                    skippedCount = skippedCount + 1
                    summaries[#summaries + 1] = {
                        fileName = fileName,
                        status = "Skipped (No skin detected)",
                    }
                else
                    -- Step 3: Evaluate skin state and solve target Orange HSL
                    local res = SkinMath.evaluate_active_photo(
                        curTemp, curTint, curOrangeHue,
                        'auto_detect', 'auto_detect', 'neutral', 'winter',
                        flashFired, nil, 'female', curExp, curOrangeSat,
                        sk.r, sk.g, sk.b, curTemp, curTint
                    )

                    if res and res.suggested_hsl_orange_target and res.suggested_orange_sat_target then
                        local targetHue = res.suggested_hsl_orange_target
                        local targetSat = res.suggested_orange_sat_target
                        local newSettings = {
                            HueAdjustmentOrange = targetHue,
                            SaturationAdjustmentOrange = targetSat,
                        }

                        -- Step 4: Apply settings with named history transaction
                        local writeOk = false
                        catalog:withWriteAccessDo('SkinScope: Batch I-Line Alignment', function()
                            photo:applyDevelopSettings(newSettings)
                            writeOk = true
                        end)

                        if writeOk then
                            successCount = successCount + 1
                            local compName = res.detected_complexion_title or "Detected"
                            local infoStr = ""
                            if samples and samples.sample_info and samples.sample_info.width then
                                infoStr = string.format(" (%d×%d px • %d skin px)",
                                    samples.sample_info.width, samples.sample_info.height,
                                    samples.sample_info.count or 0)
                            end
                            summaries[#summaries + 1] = {
                                fileName = fileName,
                                status = string.format("Hue %+d (Δ%+d), Sat %+d (Δ%+d) [%s]%s",
                                    targetHue, targetHue - curOrangeHue,
                                    targetSat, targetSat - curOrangeSat,
                                    compName, infoStr),
                            }
                        else
                            errors[#errors + 1] = fileName .. ": Write transaction failed"
                        end
                    else
                        skippedCount = skippedCount + 1
                        summaries[#summaries + 1] = {
                            fileName = fileName,
                            status = "Skipped (Could not solve targets)",
                        }
                    end
                end
            end)

            if not itemOk then
                errors[#errors + 1] = fileName .. ": " .. tostring(itemErr)
            end

            if i < photoCount and not progress:isCanceled() then
                LrTasks.sleep(0.05)
            end
        end

        progress:done()

        if wasInDevelop then
            LrApplicationView.switchToModule('develop')
        end

        -- Results dialog
        local resultTitle = "SkinScope: Batch Alignment Done"
        local msgParts = {}

        if skippedCount == 0 and #errors == 0 then
            msgParts[#msgParts + 1] = string.format(
                "All %d photo%s aligned successfully to the I-Line.",
                successCount,
                successCount == 1 and "" or "s"
            )
        else
            msgParts[#msgParts + 1] = string.format(
                "%d aligned, %d skipped, %d error%s.",
                successCount,
                skippedCount,
                #errors,
                #errors == 1 and "" or "s"
            )
        end

        if #summaries > 0 then
            msgParts[#msgParts + 1] = ""
            for _, s in ipairs(summaries) do
                msgParts[#msgParts + 1] = string.format("• %s: %s", s.fileName, s.status)
            end
        end

        if #errors > 0 then
            msgParts[#msgParts + 1] = "\nErrors:"
            for _, e in ipairs(errors) do
                msgParts[#msgParts + 1] = "  " .. e
            end
        end

        local msgType = (#errors > 0) and "warning" or "info"
        LrDialogs.message(resultTitle, table.concat(msgParts, "\n"), msgType)
    end)
end)
