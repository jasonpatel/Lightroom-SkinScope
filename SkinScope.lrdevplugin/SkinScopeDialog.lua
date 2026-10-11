--[[
  SkinScopeDialog.lua
  Live Floating HUD for SkinScope in Lightroom Classic.
  Engineered to match Lightroom's standard side panel footprint (~340px)
  with live vectorscope tracking, calibrated Before/After skin tone swatches,
  and 1-click single-step HSL correction.
]]

local LrView = import 'LrView'
local LrDialogs = import 'LrDialogs'
local LrDevelopController = import 'LrDevelopController'
local LrApplicationView = import 'LrApplicationView'
local LrApplication = import 'LrApplication'
local LrBinding = import 'LrBinding'
local LrColor = import 'LrColor'
local LrTasks = import 'LrTasks'
local LrFunctionContext = import 'LrFunctionContext'
local LrHttp = import 'LrHttp'
local LrPathUtils = import 'LrPathUtils'
local LrPrefs = import 'LrPrefs'
local SkinMath = dofile(LrPathUtils.child(_PLUGIN.path, 'SkinMath.lua'))

local SkinScopeDialog = {}
SkinScopeDialog.isOpen = false

--- Construct a live ASCII vectorscope gauge showing deviation from I-Line target (0.0 deg delta)
local function make_vectorscope_gauge(delta_angle, status)
    local delta = delta_angle or 0.0
    if status == "EXTREME_COLD" or delta < -30 then
        return "◄ [EXTREME BLUE] ───|───"
    elseif status == "EXTREME_WARM" or delta > 30 then
        return "───|─── [EXTREME WARM] ►"
    end

    local center = 6
    local steps = 11
    local pos = math.floor(center + (delta / 5.0) * 5 + 0.5)

    if pos < 1 then
        return "◄● [Mag] ────|────"
    elseif pos > steps then
        return "────|──── [Grn] ●►"
    else
        local chars = {}
        for i = 1, steps do
            if i == center then
                chars[i] = "|"
            else
                chars[i] = "─"
            end
        end
        chars[pos] = "●"
        return "◄ Mag [ " .. table.concat(chars) .. " ] Grn ►"
    end
end

function SkinScopeDialog.show(activeSettings)
    if _G.SkinScope_isOpen or SkinScopeDialog.isOpen then
        LrDialogs.showBezel("SkinScope is already open.")
        return
    end

    LrFunctionContext.callWithContext('SkinScopeDialog', function(context)
        _G.SkinScope_isOpen = true
        SkinScopeDialog.isOpen = true
        local f = LrView.osFactory()

        local pluginPrefs = LrPrefs.prefsForPlugin()

        -- Property table for reactive UI bindings
        local propertyTable = LrBinding.makePropertyTable(context)
        local savedComp = pluginPrefs.savedComplexion or pluginPrefs.defaultComplexion or 'auto_detect'
        local savedGender = pluginPrefs.savedGender or pluginPrefs.defaultGender or 'female'
        local savedZone = pluginPrefs.savedZone or 'face'
        local savedTan = pluginPrefs.savedTan or 'winter'
        local savedMood = pluginPrefs.savedMood or 'neutral'
        local savedLive = true
        if pluginPrefs.savedLiveMode ~= nil then
            savedLive = pluginPrefs.savedLiveMode
        elseif pluginPrefs.defaultLiveMode ~= nil then
            savedLive = pluginPrefs.defaultLiveMode
        end

        propertyTable.complexion = savedComp
        propertyTable.gender = savedGender
        propertyTable.sample_zone = savedZone
        propertyTable.face_sample = nil
        propertyTable.body_sample = nil
        propertyTable.tan = savedTan
        propertyTable.mood = savedMood
        propertyTable.prior_r = nil
        propertyTable.prior_g = nil
        propertyTable.prior_b = nil
        propertyTable.has_prior_diff = false
        propertyTable.swatch_left_label = "◀ Current (Photo)"
        propertyTable.detected_complexion_str = ""
        propertyTable.detected_complexion_color = (savedComp ~= 'auto_detect') and LrColor(0.20, 0.78, 0.30) or LrColor(0.20, 0.65, 1.0)
        propertyTable.look_info_str = "0.0° Rec.709 Baseline"
        propertyTable.live_mode = savedLive
        
        -- Initialize photo name and settings immediately from caller
        propertyTable.photo_name = (activeSettings and activeSettings.file_name) or "Active Photo"
        propertyTable.current_temp = (activeSettings and activeSettings.temp) or 5500
        propertyTable.current_tint = (activeSettings and activeSettings.tint) or 10
        propertyTable.current_orange_hue = (activeSettings and activeSettings.orange_hue) or 0
        propertyTable.current_exposure = (activeSettings and activeSettings.exposure) or 0
        propertyTable.current_orange_sat = (activeSettings and activeSettings.orange_sat) or 0
        propertyTable.flash_fired = (activeSettings and activeSettings.flash_fired) or 0
        propertyTable.sampled_skin = (activeSettings and activeSettings.sampled_skin) or nil
        propertyTable.profile_status_str = "Adobe Color (Optimal ✔)"
        propertyTable.profile_status_color = LrColor(0.20, 0.78, 0.30)

        local function format_sample_info_str(width, height, count)
            if not width or not height then
                return "Preview: Standard"
            end
            count = count or 0
            local status = ""
            if count >= 1000 then
                status = " (Optimal ✔)"
            elseif count >= 200 then
                status = " (Sufficient ✔)"
            elseif count > 0 then
                status = " (Low count ⚠)"
            else
                status = " (No skin found)"
            end
            return string.format("%d×%d px • %d skin px%s", width, height, count, status)
        end

        local initInfo = activeSettings and activeSettings.sample_info
        if initInfo and initInfo.width then
            propertyTable.sample_info_str = format_sample_info_str(initInfo.width, initInfo.height, initInfo.count)
        else
            propertyTable.sample_info_str = "Preview: Standard"
        end

        propertyTable.exp_low_text = "Low EV"
        propertyTable.exp_mid_text = "Mid EV"
        propertyTable.exp_high_text = "High EV"

        local swatch_toggle = false

        local function updateDiagnostics()
            local active_sample = propertyTable.sampled_skin
            if propertyTable.sample_zone == 'body' and propertyTable.body_sample then
                active_sample = propertyTable.body_sample
            elseif propertyTable.face_sample then
                active_sample = propertyTable.face_sample
            end

            local custom_r, custom_g, custom_b = nil, nil, nil
            if active_sample then
                custom_r = active_sample.r
                custom_g = active_sample.g
                custom_b = active_sample.b
            end

            local success, res = pcall(function()
                return SkinMath.evaluate_active_photo(
                    propertyTable.current_temp or 5500,
                    propertyTable.current_tint or 8,
                    propertyTable.current_orange_hue or 0,
                    propertyTable.complexion or 'auto_detect',
                    'neutral',
                    propertyTable.mood or 'neutral',
                    propertyTable.tan or 'winter',
                    propertyTable.flash_fired or 0,
                    propertyTable.complexion or 'auto_detect',
                    propertyTable.gender or 'female',
                    propertyTable.current_exposure or 0,
                    propertyTable.current_orange_sat or 0,
                    custom_r, custom_g, custom_b,
                    propertyTable.photo_baseline_temp,
                    propertyTable.photo_baseline_tint
                )
            end)

            if success and res then
                propertyTable.current_angle_str = string.format("%.1f°", res.current_angle)
                propertyTable.target_angle_str = string.format("%.1f°", res.target_angle)
                propertyTable.delta_str = string.format("%+.1f°", res.delta_angle)
                propertyTable.gauge_str = make_vectorscope_gauge(res.delta_angle, res.status)
                propertyTable.metrics_str = string.format("Skin: %.1f°  •  Target: %.1f°  •  Δ: %+.1f°", 
                    res.current_angle, res.target_angle, res.delta_angle)
                
                -- Alexis Van Hurkman Exposure & Saturation Readout
                propertyTable.luma_readout_str = res.luma_readout_str or ""
                propertyTable.sat_readout_str = res.sat_readout_str or ""
                propertyTable.luma_color = (res.luma_status == "OPTIMAL") and LrColor(0.20, 0.78, 0.30) or LrColor(0.95, 0.68, 0.10)
                propertyTable.sat_color = (res.sat_status == "OPTIMAL") and LrColor(0.20, 0.78, 0.30) or LrColor(0.95, 0.68, 0.10)
                
                propertyTable.detected_complexion_str = res.detected_complexion_title or ""
                if propertyTable.complexion and propertyTable.complexion ~= 'auto_detect' then
                    propertyTable.detected_complexion_color = LrColor(0.20, 0.78, 0.30)
                else
                    propertyTable.detected_complexion_color = LrColor(0.20, 0.65, 1.00)
                end
                
                local mood_key = propertyTable.mood or 'neutral'
                if mood_key == 'filmic' then
                    propertyTable.look_info_str = "-2.0° Soft Filmic Rose"
                elseif mood_key == 'fashion' then
                    propertyTable.look_info_str = "0.0° Contrast Editorial"
                elseif mood_key == 'golden' then
                    propertyTable.look_info_str = "+2.5° Golden Warmth"
                else
                    propertyTable.look_info_str = "0.0° Rec.709 Baseline"
                end
                
                -- Track photo baseline (prior) prior to plugin edits
                if propertyTable.prior_r == nil and res.current_r then
                    propertyTable.prior_r = res.current_r
                    propertyTable.prior_g = res.current_g
                    propertyTable.prior_b = res.current_b
                end

                local p_r = math.floor((propertyTable.prior_r or res.current_r or 0.72) * 255 + 0.5)
                local p_g = math.floor((propertyTable.prior_g or res.current_g or 0.49) * 255 + 0.5)
                local p_b = math.floor((propertyTable.prior_b or res.current_b or 0.465) * 255 + 0.5)
                local c_r = math.floor((res.current_r or 0.72) * 255 + 0.5)
                local c_g = math.floor((res.current_g or 0.49) * 255 + 0.5)
                local c_b = math.floor((res.current_b or 0.465) * 255 + 0.5)
                local diff = math.abs(p_r - c_r) + math.abs(p_g - c_g) + math.abs(p_b - c_b)
                local has_diff = (diff >= 2)
                propertyTable.has_prior_diff = has_diff

                if has_diff then
                    propertyTable.swatch_left_label = string.format("◀ Prior rgb %d, %d, %d", p_r, p_g, p_b)
                else
                    propertyTable.swatch_left_label = "◀ Current (Photo)"
                end

                propertyTable.cur_color_label = string.format("Live rgb %d, %d, %d", c_r, c_g, c_b)
                propertyTable.target_color_label = string.format("Target rgb %d, %d, %d", 
                    math.floor((res.target_r or 0.72) * 255 + 0.5), 
                    math.floor((res.target_g or 0.49) * 255 + 0.5), 
                    math.floor((res.target_b or 0.465) * 255 + 0.5))

                -- Generate seamless borderless split swatch image (Zero black bar)
                swatch_toggle = not swatch_toggle
                local swatch_name = swatch_toggle and "skinscope_swatch_1.bmp" or "skinscope_swatch_2.bmp"
                local swatch_path = _PLUGIN.path .. "/" .. swatch_name
                pcall(function()
                    SkinMath.write_split_swatch(
                        swatch_path,
                        res.current_r, res.current_g, res.current_b,
                        res.target_r, res.target_g, res.target_b,
                        propertyTable.prior_r, propertyTable.prior_g, propertyTable.prior_b
                    )
                end)
                propertyTable.swatch_image_path = swatch_path

                local hueDiff = math.abs((propertyTable.current_orange_hue or 0) - (res.suggested_hsl_orange_target or 0))
                local satDiff = math.abs((propertyTable.current_orange_sat or 0) - (res.suggested_orange_sat_target or 0))
                local isAligned = (math.abs(res.delta_angle) <= 0.6) or (hueDiff <= 1 and satDiff <= 2)

                if res.status == "EXTREME_COLD" or res.status == "EXTREME_WARM" then
                    propertyTable.suggested_orange_text = "Fix WB First (Extreme Cast)"
                elseif isAligned then
                    propertyTable.suggested_orange_text = string.format("Orange HSL: %+dH, %+dS (Aligned)", 
                        math.floor(propertyTable.current_orange_hue or res.suggested_hsl_orange_target),
                        math.floor(propertyTable.current_orange_sat or res.suggested_orange_sat_target or 0))
                else
                    propertyTable.suggested_orange_text = string.format("Snap Orange HSL: %+dH, %+dS", 
                        res.suggested_hsl_orange_target,
                        res.suggested_orange_sat_target or 0)
                end

                local expLow = res.exp_target_low or (propertyTable.current_exposure or 0)
                local expMid = res.exp_target_mid or (propertyTable.current_exposure or 0)
                local expHigh = res.exp_target_high or (propertyTable.current_exposure or 0)

                propertyTable.exp_low_text = string.format("Low: %+.2f", expLow)
                propertyTable.exp_mid_text = string.format("Mid: %+.2f", expMid)
                propertyTable.exp_high_text = string.format("High: %+.2f", expHigh)

                -- Visual badges and cohesive broadcast status colors
                if res.status == "ON_TARGET" then
                    propertyTable.status_badge_str = string.format("PERFECT I-LINE (%+.1f°)", res.delta_angle)
                    propertyTable.status_color = LrColor(0.20, 0.78, 0.30) -- Phosphor Green
                    propertyTable.action_hint = "Skin tone is in optimal grading band."
                elseif res.status == "EXTREME_COLD" then
                    propertyTable.status_badge_str = string.format("FREEZING BLUE (%+.1f°)", res.delta_angle)
                    propertyTable.status_color = LrColor(0.20, 0.65, 1.00) -- Ice Cyan/Blue
                    propertyTable.action_hint = "WB too cold. Adjust WB in Lightroom."
                elseif res.status == "EXTREME_WARM" then
                    propertyTable.status_badge_str = string.format("EXTREME AMBER (%+.1f°)", res.delta_angle)
                    propertyTable.status_color = LrColor(1.00, 0.45, 0.10) -- Flame Orange
                    propertyTable.action_hint = "WB too warm. Adjust WB in Lightroom."
                elseif res.status == "TOO_MAGENTA" then
                    propertyTable.status_badge_str = string.format("TOO MAGENTA (%+.1f°)", res.delta_angle)
                    propertyTable.status_color = LrColor(0.95, 0.20, 0.35) -- Rose Crimson
                    propertyTable.action_hint = string.format("Needs +%.1f° toward yellow.", math.abs(res.delta_angle))
                else
                    propertyTable.status_badge_str = string.format("TOO GREEN/SALLOW (%+.1f°)", res.delta_angle)
                    propertyTable.status_color = LrColor(0.95, 0.68, 0.10) -- Amber Gold
                    propertyTable.action_hint = string.format("Needs -%.1f° toward rose.", math.abs(res.delta_angle))
                end
                
                propertyTable.res = res
            else
                local logDir = LrPathUtils.getStandardFilePath('appData') or _PLUGIN.path
                local logPath = LrPathUtils.child(logDir, 'skinscope_diag_error.log')
                local errFile = io.open(logPath, "a")
                if errFile then
                    errFile:write("updateDiagnostics error: " .. tostring(res) .. "\n")
                    errFile:close()
                end
            end
        end

        -- Initialize immediately so values are never blank
        local isApplyingLive = false
        local function applyLiveCorrection(trigger)
            if not propertyTable.live_mode then return end
            if isApplyingLive then return end

            isApplyingLive = true
            LrTasks.startAsyncTask(function()
                -- Allow popup menu to close and release Lightroom UI focus
                LrTasks.sleep(0.15)

                if LrApplicationView.getCurrentModuleName() ~= 'develop' then
                    LrApplicationView.switchToModule('develop')
                    LrTasks.sleep(0.15)
                end

                updateDiagnostics()
                if not propertyTable.res then
                    isApplyingLive = false
                    return
                end

                local targetHue = propertyTable.res.suggested_hsl_orange_target or 0
                local targetSat = propertyTable.res.suggested_orange_sat_target or 0

                pcall(function()
                    LrDevelopController.setValue('HueAdjustmentOrange', targetHue)
                end)
                LrTasks.sleep(0.04)
                pcall(function()
                    LrDevelopController.setValue('SaturationAdjustmentOrange', targetSat)
                end)

                propertyTable.current_orange_hue = targetHue
                propertyTable.current_orange_sat = targetSat
                updateDiagnostics()

                local compTitle = (propertyTable.res and propertyTable.res.detected_complexion_title) or "Auto-Detected"
                if propertyTable.complexion ~= 'auto_detect' and SkinMath.COMPLEXIONS[propertyTable.complexion] then
                    compTitle = SkinMath.COMPLEXIONS[propertyTable.complexion].title
                end
                LrDialogs.showBezel(string.format("Live Auto-Sync: %s\nOrange Hue %+d • Sat %+d", compTitle:sub(1, 24), targetHue, targetSat))
                
                LrTasks.sleep(0.10)
                isApplyingLive = false
            end)
        end

        local function onContextChanged(props, key, value)
            if key == 'complexion' then pluginPrefs.savedComplexion = value
            elseif key == 'gender' then pluginPrefs.savedGender = value
            elseif key == 'sample_zone' then pluginPrefs.savedZone = value
            elseif key == 'tan' then pluginPrefs.savedTan = value
            elseif key == 'mood' then pluginPrefs.savedMood = value
            end

            updateDiagnostics()
            if propertyTable.live_mode then
                applyLiveCorrection("observer_" .. tostring(key))
            end
        end

        propertyTable:addObserver('complexion', onContextChanged)
        propertyTable:addObserver('gender', onContextChanged)
        propertyTable:addObserver('sample_zone', onContextChanged)
        propertyTable:addObserver('tan', onContextChanged)
        propertyTable:addObserver('mood', onContextChanged)

        propertyTable:addObserver('live_mode', function(props, key, value)
            pluginPrefs.savedLiveMode = value
            if value == true then
                applyLiveCorrection("live_mode_toggle")
                LrDialogs.showBezel("HUD Mode: Live Push ON\n(Immediate Photo Push)")
            else
                LrDialogs.showBezel("HUD Mode: Live Push OFF\n(Manual Trigger)")
            end
        end)

        -- Track sampling requests so that rapid navigation doesn't let stale background samples overwrite the active photo
        local currentSamplingSeq = 0

        -- Helper to read settings from a photo
        -- Helper to read settings from a photo instantaneously without blocking on Develop side panel loading
        local function refreshFromActivePhoto(photo, appliedSettings)
            if not photo then return end
            propertyTable.prior_r = nil
            propertyTable.prior_g = nil
            propertyTable.prior_b = nil
            propertyTable.has_prior_diff = false
            propertyTable.face_sample = nil
            propertyTable.body_sample = nil

            currentSamplingSeq = currentSamplingSeq + 1
            local thisSamplingSeq = currentSamplingSeq

            -- Phase 1: INSTANT Metadata & Settings from Database (0ms delay, no side panel lock)
            LrTasks.pcall(function()
                local name = photo:getFormattedMetadata('fileName') or "Active Photo"
                propertyTable.photo_name = name

                -- Read cached settings directly from database; instantaneous and does not wait for UI panels
                local dev = photo:getDevelopSettings() or {}
                local curTemp = dev.Temperature or 5500
                local curTint = dev.Tint or 10
                local curOrange = dev.HueAdjustmentOrange or 0
                local curExposure = dev.Exposure2012 or dev.Exposure or 0
                local curOrangeSat = dev.SaturationAdjustmentOrange or 0

                if appliedSettings then
                    curOrange = appliedSettings.hue or curOrange
                    curOrangeSat = appliedSettings.sat or curOrangeSat
                    curExposure = appliedSettings.exp or curExposure
                end

                propertyTable.photo_baseline_temp = curTemp
                propertyTable.photo_baseline_tint = curTint
                propertyTable.current_temp = curTemp
                propertyTable.current_tint = curTint
                propertyTable.current_orange_hue = curOrange
                propertyTable.current_exposure = curExposure
                propertyTable.current_orange_sat = curOrangeSat

                local profileName = dev.Profile or dev.CameraProfile or "Adobe Color"
                propertyTable.camera_profile = profileName
                local prof_lower = profileName:lower()
                if prof_lower:find("b&w") or prof_lower:find("monochrome") or prof_lower:find("black") then
                    propertyTable.profile_status_str = string.format("%s (B&W - Skin N/A)", profileName:sub(1, 18))
                    propertyTable.profile_status_color = LrColor(0.95, 0.20, 0.35)
                elseif prof_lower:find("adobe color") or prof_lower:find("adobe portrait") or prof_lower:find("camera standard") or prof_lower:find("camera faithful") or prof_lower:find("camera neutral") or prof_lower:find("adobe standard") or prof_lower:find("adobe neutral") then
                    propertyTable.profile_status_str = string.format("%s (Optimal ✔)", profileName:sub(1, 22))
                    propertyTable.profile_status_color = LrColor(0.20, 0.78, 0.30)
                else
                    propertyTable.profile_status_str = string.format("%s (Creative LUT)", profileName:sub(1, 18))
                    propertyTable.profile_status_color = LrColor(0.95, 0.68, 0.10)
                end

                -- Compute immediate baseline diagnostics before pixels arrive
                updateDiagnostics()
            end)

            -- Phase 2: ASYNC Background Pixel Sampling (Doesn't block UI / Next / Prev)
            propertyTable.sample_info_str = "Analyzing skin pixels..."
            LrTasks.startAsyncTask(function()
                local samplerPath = LrPathUtils.child(_PLUGIN.path, 'SkinSampler.lua')
                local SkinSampler = dofile(samplerPath)
                local samples = SkinSampler.samplePhoto(photo)

                -- Only apply sampled pixels if the user hasn't already switched to another photo
                if thisSamplingSeq == currentSamplingSeq then
                    if samples then
                        propertyTable.sampled_skin = samples.sampled_skin
                        propertyTable.face_sample = samples.face_sample
                        propertyTable.body_sample = samples.body_sample
                        if samples.sample_info and samples.sample_info.width then
                            propertyTable.sample_info_str = format_sample_info_str(
                                samples.sample_info.width,
                                samples.sample_info.height,
                                samples.sample_info.count
                            )
                        end
                    end
                    updateDiagnostics()
                end
            end)
        end

        -- Shared photo tracking identifier across navigation and background monitor
        local lastPhotoId = nil
        local initCatalog = LrApplication.activeCatalog()
        local initP = initCatalog and initCatalog:getTargetPhoto()
        if initP then lastPhotoId = initP.localIdentifier end

        -- Helper to apply skin tone & luma settings directly to photo and Develop module
        local function applySettingsToPhoto(photo, targetHue, targetSat, targetExp)
            if not photo then return end

            -- 1. Direct catalog database transaction: permanently saves to this photo
            local catalog = LrApplication.activeCatalog()
            pcall(function()
                catalog:withWriteAccessDo("SkinScope: Apply Settings", function()
                    photo:applyDevelopSettings({
                        HueAdjustmentOrange = targetHue,
                        SaturationAdjustmentOrange = targetSat,
                        Exposure2012 = targetExp,
                    })
                end)
            end)

            -- 2. If in Develop module, also push to LrDevelopController if photo matches
            if LrApplicationView.getCurrentModuleName() == 'develop' then
                local cur = catalog:getTargetPhoto()
                if cur and cur.localIdentifier == photo.localIdentifier then
                    pcall(function()
                        LrDevelopController.setValue('HueAdjustmentOrange', targetHue)
                    end)
                    LrTasks.sleep(0.01)
                    pcall(function()
                        LrDevelopController.setValue('SaturationAdjustmentOrange', targetSat)
                    end)
                    LrTasks.sleep(0.01)
                    pcall(function()
                        if LrDevelopController.getValue('Exposure2012') ~= nil then
                            LrDevelopController.setValue('Exposure2012', targetExp)
                        else
                            LrDevelopController.setValue('Exposure', targetExp)
                        end
                    end)
                end
            end

            propertyTable.current_orange_hue = targetHue
            propertyTable.current_orange_sat = targetSat
            propertyTable.current_exposure = targetExp
        end

        -- Filmstrip navigation helper
        local isNavigating = false
        local cachedFilmstripPhotos = nil
        local cachedFilmstripTime = 0
        local cachedCurrentIndex = nil

        local function getFilmstripPhotos(catalog)
            local targetPhotos = catalog:getTargetPhotos()
            if targetPhotos and #targetPhotos > 1 then
                -- Explicit multi-selection active
                return targetPhotos
            end

            local now = os.time()
            if cachedFilmstripPhotos and (now - cachedFilmstripTime) < 3 then
                return cachedFilmstripPhotos
            end

            -- Query active filmstrip respecting filter bar
            local filteredFilmstrip = nil
            pcall(function()
                if catalog.getMultipleSelectedOrAllPhotos then
                    filteredFilmstrip = catalog:getMultipleSelectedOrAllPhotos()
                end
            end)
            if filteredFilmstrip and #filteredFilmstrip > 0 then
                cachedFilmstripPhotos = filteredFilmstrip
                cachedFilmstripTime = now
                return cachedFilmstripPhotos
            end

            local sources = catalog:getActiveSources()
            if sources and #sources > 0 then
                for _, src in ipairs(sources) do
                    if src and src.getPhotos then
                        local srcPhotos = src:getPhotos()
                        if srcPhotos and #srcPhotos > 0 then
                            cachedFilmstripPhotos = srcPhotos
                            cachedFilmstripTime = now
                            return cachedFilmstripPhotos
                        end
                    end
                end
            end

            return nil
        end

        local function selectAdjacentPhoto(delta, forceApply)
            if isNavigating then return end
            isNavigating = true

            local shouldApply = (forceApply == true)

            LrTasks.startAsyncTask(function()
                local success, err = LrTasks.pcall(function()
                    local catalog = LrApplication.activeCatalog()
                    local targetPhoto = catalog:getTargetPhoto()
                    if not targetPhoto then
                        isNavigating = false
                        return
                    end

                    local oldId = targetPhoto.localIdentifier

                    -- If applying, ensure current photo is snapped before advancing
                    if shouldApply and propertyTable.res then
                        local curHueDiff = math.abs((propertyTable.current_orange_hue or 0) - (propertyTable.res.suggested_hsl_orange_target or 0))
                        if curHueDiff > 1 or not propertyTable.current_orange_hue or propertyTable.current_orange_hue == 0 then
                            local tHue = propertyTable.res.suggested_hsl_orange_target or 0
                            local tSat = propertyTable.res.suggested_orange_sat_target or 0
                            local tExp = propertyTable.res.exp_target_mid or (propertyTable.current_exposure or 0)
                            applySettingsToPhoto(targetPhoto, tHue, tSat, tExp)
                        end
                    end

                    -- Discover adjacent photo across active filmstrip
                    local allPhotos = getFilmstripPhotos(catalog)
                    local nextPhoto = nil

                    if allPhotos and #allPhotos > 1 then
                        local currentIndex = nil
                        -- Fast check cached index first
                        if cachedCurrentIndex and allPhotos[cachedCurrentIndex] and allPhotos[cachedCurrentIndex].localIdentifier == oldId then
                            currentIndex = cachedCurrentIndex
                        else
                            for i, p in ipairs(allPhotos) do
                                if p.localIdentifier == oldId then
                                    currentIndex = i
                                    break
                                end
                            end
                        end

                        if currentIndex then
                            local nextIndex = currentIndex + delta
                            if nextIndex >= 1 and nextIndex <= #allPhotos then
                                nextPhoto = allPhotos[nextIndex]
                                cachedCurrentIndex = nextIndex
                            else
                                LrDialogs.showBezel(delta > 0 and "At end of photo list." or "At start of photo list.")
                                isNavigating = false
                                return
                            end
                        else
                            -- Fallback: refresh cache once
                            cachedFilmstripPhotos = nil
                            allPhotos = getFilmstripPhotos(catalog)
                            if allPhotos then
                                for i, p in ipairs(allPhotos) do
                                    if p.localIdentifier == oldId then
                                        local nextIndex = i + delta
                                        if nextIndex >= 1 and nextIndex <= #allPhotos then
                                            nextPhoto = allPhotos[nextIndex]
                                            cachedCurrentIndex = nextIndex
                                        end
                                        break
                                    end
                                end
                            end
                        end
                    end

                    if not nextPhoto then
                        LrDialogs.showBezel("No adjacent photo found.")
                        isNavigating = false
                        return
                    end

                    -- 1. Switch active selection to nextPhoto immediately
                    lastPhotoId = nextPhoto.localIdentifier
                    local targetPhotos = catalog:getTargetPhotos()
                    if targetPhotos and #targetPhotos > 1 then
                        catalog:setSelectedPhotos(nextPhoto, targetPhotos)
                    else
                        catalog:setSelectedPhotos(nextPhoto, { nextPhoto })
                    end

                    -- 2. Release navigation lock IMMEDIATELY so the user can hit Next/Prev again instantly
                    isNavigating = false

                    -- 3. Update HUD immediately from database develop settings & metadata
                    refreshFromActivePhoto(nextPhoto)

                    -- 4. If applying, solve & apply tailored settings for this specific photo
                    if shouldApply and propertyTable.res then
                        local targetHue = propertyTable.res.suggested_hsl_orange_target or 0
                        local targetSat = propertyTable.res.suggested_orange_sat_target or 0
                        local targetExp = propertyTable.res.exp_target_mid or (propertyTable.current_exposure or 0)

                        applySettingsToPhoto(nextPhoto, targetHue, targetSat, targetExp)
                        updateDiagnostics()

                        LrDialogs.showBezel(string.format("Auto-Aligned Next Photo:\nOrange %+dH %+dS • Luma %+.2f EV", targetHue, targetSat, targetExp))
                    end
                end)

                isNavigating = false
                if not success and err then
                    LrDialogs.showError("Navigation error: " .. tostring(err))
                end
            end)
        end

        -- Background tracking task: auto-updates when you click or scroll in Lightroom, or adjust controls
        local isRunning = true
        LrTasks.startAsyncTask(function()
            local catalog = LrApplication.activeCatalog()
            local lastTemp = nil
            local lastTint = nil
            local lastOrange = nil
            local lastExp = nil
            local lastSat = nil
            local lastComplexion = propertyTable.complexion
            local lastGender = propertyTable.gender
            local lastSampleZone = propertyTable.sample_zone
            local lastTan = propertyTable.tan
            local lastMood = propertyTable.mood

            while isRunning do
                LrTasks.pcall(function()
                    local currentTarget = catalog:getTargetPhoto()
                    if currentTarget then
                        local currentId = currentTarget.localIdentifier
                        local isNewPhoto = (currentId ~= lastPhotoId)
                        local curTemp = nil
                        local curTint = nil
                        local curOrange = nil
                        local curExp = nil
                        local curSat = nil

                        if not isNewPhoto and LrApplicationView.getCurrentModuleName() == 'develop' then
                            -- Only query UI controllers when settled on the current photo (to detect live user slider moves)
                            curTemp = LrDevelopController.getValue('Temperature')
                            curTint = LrDevelopController.getValue('Tint')
                            curOrange = LrDevelopController.getValue('HueAdjustmentOrange')
                            curExp = LrDevelopController.getValue('Exposure2012') or LrDevelopController.getValue('Exposure')
                            curSat = LrDevelopController.getValue('SaturationAdjustmentOrange')
                        end

                        if not curTemp or not curTint then
                            local dev = currentTarget:getDevelopSettings() or {}
                            curTemp = curTemp or dev.Temperature or 5500
                            curTint = curTint or dev.Tint or 10
                            curOrange = curOrange or dev.HueAdjustmentOrange or 0
                            curExp = curExp or dev.Exposure2012 or dev.Exposure or 0
                            curSat = curSat or dev.SaturationAdjustmentOrange or 0
                        end

                        local contextChanged = (propertyTable.complexion ~= lastComplexion) or
                                               (propertyTable.gender ~= lastGender) or
                                               (propertyTable.sample_zone ~= lastSampleZone) or
                                               (propertyTable.tan ~= lastTan) or
                                               (propertyTable.mood ~= lastMood)

                        local isNewPhoto = (currentId ~= lastPhotoId)
                        local slidersChanged = (curTemp ~= lastTemp) or
                                               (curTint ~= lastTint) or
                                               (curOrange ~= lastOrange) or
                                               (curExp ~= lastExp) or
                                               (curSat ~= lastSat)

                        if isApplyingLive or isNavigating then
                            -- Live sync or photo navigation is active; skip overwriting
                        elseif isNewPhoto or slidersChanged or contextChanged then
                            lastPhotoId = currentId
                            lastTemp = curTemp
                            lastTint = curTint
                            lastOrange = curOrange
                            lastExp = curExp
                            lastSat = curSat
                            lastComplexion = propertyTable.complexion
                            lastGender = propertyTable.gender
                            lastSampleZone = propertyTable.sample_zone
                            lastTan = propertyTable.tan
                            lastMood = propertyTable.mood

                            if isNewPhoto then
                                refreshFromActivePhoto(currentTarget)
                            else
                                propertyTable.current_temp = curTemp
                                propertyTable.current_tint = curTint
                                propertyTable.current_orange_hue = curOrange
                                propertyTable.current_exposure = curExp
                                propertyTable.current_orange_sat = curSat
                                updateDiagnostics()
                                if contextChanged and propertyTable.live_mode then
                                    applyLiveCorrection("bg_loop")
                                end
                            end
                        end
                    end
                end)
                LrTasks.sleep(0.20)
            end
        end)

        -- Compact, elegant layout scaled to slim panel width (344px)
        local contents = f:column {
            bind_to_object = propertyTable,
            width = 344,
            spacing = 5,
            margin = 2,

            -- Top Photo Navigation Bar
            f:row {
                fill_horizontal = 1,
                spacing = 4,
                f:push_button {
                    title = "◀ Prev",
                    tooltip = "Go to previous photo (Ctrl+Left)",
                    action = function() selectAdjacentPhoto(-1, false) end,
                },
                f:static_text {
                    title = LrView.bind('photo_name'),
                    font = "<system/bold>",
                    alignment = "center",
                    fill_horizontal = 1,
                    width = 180,
                    truncation = 'middle',
                },
                f:push_button {
                    title = "Next ▶",
                    tooltip = "Advance to next photo without altering settings (Ctrl+Right)",
                    action = function() selectAdjacentPhoto(1, false) end,
                },
            },

            -- Filmstrip Apply & Advance Action
            f:row {
                fill_horizontal = 1,
                f:push_button {
                    title = "⚡ Apply & Next ▶",
                    fill_horizontal = 1,
                    font = "<system/bold>",
                    tooltip = "Copy current skin tone (Orange HSL) and Luma exposure to the next photo and advance",
                    action = function() selectAdjacentPhoto(1, true) end,
                },
            },

            f:static_text {
                title = LrView.bind('sample_info_str'),
                font = "<system/small>",
                alignment = "center",
                text_color = LrColor(0.45, 0.50, 0.55),
                fill_horizontal = 1,
                tooltip = "SkinScope requires at least 200 skin pixels for statistical accuracy. 1,000+ pixels provides cinema-grade vectorscope calibration certainty.",
            },

            f:separator { fill_horizontal = 1 },

            -- Hero Vectorscope Gauge Card
            f:column {
                fill_horizontal = 1,
                spacing = 2,
                
                f:static_text {
                    title = LrView.bind('gauge_str'),
                    font = "<system/bold>",
                    alignment = "center",
                    fill_horizontal = 1,
                    text_color = LrView.bind('status_color'),
                },
                f:static_text {
                    title = LrView.bind('status_badge_str'),
                    font = "<system/bold>",
                    alignment = "center",
                    fill_horizontal = 1,
                    text_color = LrView.bind('status_color'),
                },
                f:static_text {
                    title = LrView.bind('metrics_str'),
                    font = "<system/small>",
                    alignment = "center",
                    fill_horizontal = 1,
                    text_color = LrColor(0.35, 0.38, 0.42),
                },
                f:row {
                    fill_horizontal = 1,
                    f:static_text {
                        title = LrView.bind('luma_readout_str'),
                        font = "<system/small/bold>",
                        alignment = "left",
                        fill_horizontal = 0.5,
                        text_color = LrView.bind('luma_color'),
                    },
                    f:static_text {
                        title = LrView.bind('sat_readout_str'),
                        font = "<system/small/bold>",
                        alignment = "right",
                        fill_horizontal = 0.5,
                        text_color = LrView.bind('sat_color'),
                    },
                },
                f:static_text {
                    title = LrView.bind('action_hint'),
                    font = "<system/small>",
                    alignment = "center",
                    fill_horizontal = 1,
                    text_color = LrColor(0.30, 0.35, 0.40),
                },
            },

            f:separator { fill_horizontal = 1 },

            -- Continuous Split-Screen Swatch Bar (Butted Edge-to-Edge)
            f:column {
                fill_horizontal = 1,
                spacing = 2,

                -- Labels above split bar
                f:row {
                    fill_horizontal = 1,
                    f:static_text {
                        title = LrView.bind('swatch_left_label'),
                        font = "<system/small/bold>",
                        alignment = "left",
                        fill_horizontal = 0.5,
                    },
                    f:static_text {
                        title = "Target (Look) ▶",
                        font = "<system/small/bold>",
                        alignment = "right",
                        fill_horizontal = 0.5,
                    },
                },

                -- Borderless split image (completely seamless, 0 gap, ZERO black line)
                f:picture {
                    value = LrView.bind('swatch_image_path'),
                    width = 344,
                    height = 36,
                },

                -- RGB readouts below split bar
                f:row {
                    fill_horizontal = 1,
                    f:static_text {
                        title = LrView.bind('cur_color_label'),
                        font = "<system/small>",
                        alignment = "left",
                        fill_horizontal = 0.5,
                        text_color = LrColor(0.35, 0.38, 0.42),
                    },
                    f:static_text {
                        title = LrView.bind('target_color_label'),
                        font = "<system/small>",
                        alignment = "right",
                        fill_horizontal = 0.5,
                        text_color = LrColor(0.35, 0.38, 0.42),
                    },
                },
            },

            f:separator { fill_horizontal = 1 },

            -- Live vs On-Press Mode Toggle (Controls whether HUD profile changes push to sliders live)
            f:row {
                fill_horizontal = 1,
                spacing = 6,
                f:static_text { title = "HUD Mode:", width = 72, font = "<system/bold>" },
                f:checkbox {
                    title = "Live Push",
                    value = LrView.bind('live_mode'),
                    font = "<system/bold>",
                    tooltip = "When checked, changing Complexion, Tan, or Mood immediately adjusts Lightroom sliders. When unchecked, values only change when clicking the Snap button.",
                },
            },

            -- Context & Calibration Profile Controls
            f:row {
                fill_horizontal = 1,
                spacing = 6,
                f:static_text { title = "Complexion:", width = 72, font = "<system/bold>" },
                f:popup_menu {
                    value = LrView.bind('complexion'),
                    fill_horizontal = 1,
                    items = {
                        { title = "Auto-Detect", value = 'auto_detect' },
                        { title = "1. Porcelain", value = 'pale' },
                        { title = "2. Fair European", value = 'fair' },
                        { title = "3. East Asian", value = 'east_asian' },
                        { title = "4. Olive / Tan", value = 'olive' },
                        { title = "5. Brown - Light", value = 'brown_light' },
                        { title = "6. Brown - Medium", value = 'brown_medium' },
                        { title = "7. Brown - Deep", value = 'brown_deep' },
                        { title = "8. Deep Melanin", value = 'deep_melanin' },
                    },
                },
            },

            f:row {
                fill_horizontal = 1,
                spacing = 6,
                f:static_text { title = "Tone Info:", width = 72 },
                f:static_text {
                    title = LrView.bind('detected_complexion_str'),
                    fill_horizontal = 1,
                    font = "<system/small>",
                    text_color = LrView.bind('detected_complexion_color'),
                },
            },

            f:row {
                fill_horizontal = 1,
                spacing = 6,
                f:static_text { title = "Profile:", width = 72 },
                f:static_text {
                    title = LrView.bind('profile_status_str'),
                    fill_horizontal = 1,
                    font = "<system/small>",
                    text_color = LrView.bind('profile_status_color'),
                },
            },

            -- 1-Click Subject Segmented Pair (Female / Male)
            f:row {
                fill_horizontal = 1,
                spacing = 6,
                f:static_text { title = "Subject:", width = 72, font = "<system/bold>" },
                f:radio_button {
                    title = "Female",
                    value = LrView.bind('gender'),
                    checked_value = 'female',
                },
                f:radio_button {
                    title = "Male",
                    value = LrView.bind('gender'),
                    checked_value = 'male',
                },
            },

            -- 1-Click Sampling Zone Segmented Pair (Face / Body)
            f:row {
                fill_horizontal = 1,
                spacing = 6,
                f:static_text { title = "Zone:", width = 72, font = "<system/bold>" },
                f:radio_button {
                    title = "Face",
                    value = LrView.bind('sample_zone'),
                    checked_value = 'face',
                },
                f:radio_button {
                    title = "Body",
                    value = LrView.bind('sample_zone'),
                    checked_value = 'body',
                },
            },

            -- 1-Click Sun Tan Segmented Strip (Natural / Sun-Kissed / Bronze)
            f:row {
                fill_horizontal = 1,
                spacing = 6,
                f:static_text { title = "Sun Tan:", width = 72, font = "<system/bold>" },
                f:radio_button {
                    title = "Natural",
                    value = LrView.bind('tan'),
                    checked_value = 'winter',
                },
                f:radio_button {
                    title = "Sun-Kissed",
                    value = LrView.bind('tan'),
                    checked_value = 'sun_kissed',
                },
                f:radio_button {
                    title = "Bronze",
                    value = LrView.bind('tan'),
                    checked_value = 'deep_tan',
                },
            },


            -- Look / Mood Dropdown
            f:row {
                fill_horizontal = 1,
                spacing = 6,
                f:static_text { title = "Look:", width = 72, font = "<system/bold>" },
                f:popup_menu {
                    value = LrView.bind('mood'),
                    fill_horizontal = 1,
                    items = {
                        { title = "Clean (0.0°)", value = 'neutral' },
                        { title = "Filmic (-2.0°)", value = 'filmic' },
                        { title = "Editorial (0.0°)", value = 'fashion' },
                        { title = "Golden (+2.5°)", value = 'golden' },
                    },
                },
            },

            f:row {
                fill_horizontal = 1,
                spacing = 6,
                f:static_text { title = "Grading:", width = 72 },
                f:static_text {
                    title = LrView.bind('look_info_str'),
                    fill_horizontal = 1,
                    font = "<system/small>",
                    text_color = LrColor(0.20, 0.65, 1.0),
                },
            },

            f:separator { fill_horizontal = 1 },

            -- 1-Click Correction Actions (Vertical Stack for Ergonomics)
            f:column {
                fill_horizontal = 1,
                spacing = 5,

                -- Primary Action: Orange HSL (Skin Tone Target)
                f:push_button {
                    title = LrView.bind('suggested_orange_text'),
                    fill_horizontal = 1,
                    font = "<system/bold>",
                    action = function()
                        if propertyTable.res and (propertyTable.res.status == "EXTREME_COLD" or propertyTable.res.status == "EXTREME_WARM") then
                            LrDialogs.showBezel("White Balance has an extreme cast. Adjust WB in Lightroom first.")
                            return
                        end
                        if LrApplicationView.getCurrentModuleName() ~= 'develop' then
                            LrApplicationView.switchToModule('develop')
                        end
                        local targetHue = propertyTable.res and propertyTable.res.suggested_hsl_orange_target or 0
                        local targetSat = propertyTable.res and propertyTable.res.suggested_orange_sat_target or 0
                        LrDevelopController.setValue('HueAdjustmentOrange', targetHue)
                        LrDevelopController.setValue('SaturationAdjustmentOrange', targetSat)
                        propertyTable.current_orange_hue = targetHue
                        propertyTable.current_orange_sat = targetSat
                        updateDiagnostics()
                        LrDialogs.showBezel(string.format("Orange Snapped: Hue %+d, Sat %+d (Skin Perfected)", targetHue, targetSat))
                    end,
                },

                -- Exposure / Luma Trio (Low, Mid, High)
                f:static_text {
                    title = "Snap Exposure (Luma):",
                    font = "<system/small>",
                    text_color = LrColor(0.30, 0.35, 0.40),
                    fill_horizontal = 1,
                },
                f:row {
                    fill_horizontal = 1,
                    spacing = 3,
                    f:push_button {
                        title = LrView.bind('exp_low_text'),
                        fill_horizontal = 0.33,
                        action = function()
                            if LrApplicationView.getCurrentModuleName() ~= 'develop' then
                                LrApplicationView.switchToModule('develop')
                            end
                            local targetExp = propertyTable.res and propertyTable.res.exp_target_low or (propertyTable.current_exposure or 0)
                            LrDevelopController.setValue('Exposure2012', targetExp)
                            propertyTable.current_exposure = targetExp
                            updateDiagnostics()
                            LrDialogs.showBezel(string.format("Exposure Snapped: %+.2f EV (Low-Key Luma)", targetExp))
                        end,
                    },
                    f:push_button {
                        title = LrView.bind('exp_mid_text'),
                        fill_horizontal = 0.34,
                        font = "<system/bold>",
                        action = function()
                            if LrApplicationView.getCurrentModuleName() ~= 'develop' then
                                LrApplicationView.switchToModule('develop')
                            end
                            local targetExp = propertyTable.res and propertyTable.res.exp_target_mid or (propertyTable.current_exposure or 0)
                            LrDevelopController.setValue('Exposure2012', targetExp)
                            propertyTable.current_exposure = targetExp
                            updateDiagnostics()
                            LrDialogs.showBezel(string.format("Exposure Snapped: %+.2f EV (Balanced Mid Luma)", targetExp))
                        end,
                    },
                    f:push_button {
                        title = LrView.bind('exp_high_text'),
                        fill_horizontal = 0.33,
                        action = function()
                            if LrApplicationView.getCurrentModuleName() ~= 'develop' then
                                LrApplicationView.switchToModule('develop')
                            end
                            local targetExp = propertyTable.res and propertyTable.res.exp_target_high or (propertyTable.current_exposure or 0)
                            LrDevelopController.setValue('Exposure2012', targetExp)
                            propertyTable.current_exposure = targetExp
                            updateDiagnostics()
                            LrDialogs.showBezel(string.format("Exposure Snapped: %+.2f EV (High-Key Luma)", targetExp))
                        end,
                    },
                },

                -- Utility Bar: Re-measure Photo
                f:push_button {
                    title = "Re-measure Photo",
                    fill_horizontal = 1,
                    action = function()
                        local catalog = LrApplication.activeCatalog()
                        local curPhoto = catalog:getTargetPhoto()
                        if curPhoto then
                            refreshFromActivePhoto(curPhoto)
                        end
                    end,
                },

                -- Footer Bar: Buy Me a Coffee (Full width, Visual Split removed per user request)
                f:push_button {
                    title = "Buy Me a Coffee",
                    fill_horizontal = 1,
                    action = function()
                        LrTasks.startAsyncTask(function()
                            LrHttp.openUrlInBrowser("https://buymeacoffee.com/jasonpatel")
                        end)
                    end,
                },

                -- Author credit
                f:static_text {
                    title = "SkinScope by Jason Patel",
                    font = "<system/small>",
                    alignment = "center",
                    fill_horizontal = 1,
                    text_color = LrColor(0.45, 0.48, 0.52),
                },
            },
        }

        LrDialogs.presentFloatingDialog(_PLUGIN, {
            title = "SkinScope",
            save_frame = "skinscope_floating_hud_v30",
            contents = contents,
            windowWillClose = function()
                isRunning = false
                SkinScopeDialog.isOpen = false
                _G.SkinScope_isOpen = false

                -- Shut down persistent sampling daemon cleanly
                LrTasks.startAsyncTask(function()
                    local samplerPath = LrPathUtils.child(_PLUGIN.path, 'SkinSampler.lua')
                    local SkinSampler = dofile(samplerPath)
                    if SkinSampler and SkinSampler.stopDaemon then
                        SkinSampler.stopDaemon()
                    end
                end)
            end,
        })
    end)
end

return SkinScopeDialog
