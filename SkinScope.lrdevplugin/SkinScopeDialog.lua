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
local SkinMath = dofile(_PLUGIN.path .. '/SkinMath.lua')

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
    if SkinScopeDialog.isOpen then
        LrDialogs.showBezel("SkinScope is already open.")
        return
    end

    LrFunctionContext.callWithContext('SkinScopeDialog', function(context)
        SkinScopeDialog.isOpen = true
        local f = LrView.osFactory()

        -- Property table for reactive UI bindings
        local propertyTable = LrBinding.makePropertyTable(context)
        propertyTable.complexion = 'auto_detect'
        propertyTable.gender = 'female'
        propertyTable.sample_zone = 'face'
        propertyTable.face_sample = nil
        propertyTable.body_sample = nil
        propertyTable.tan = 'winter'
        propertyTable.mood = 'neutral'
        propertyTable.prior_r = nil
        propertyTable.prior_g = nil
        propertyTable.prior_b = nil
        propertyTable.has_prior_diff = false
        propertyTable.swatch_left_label = "◀ Current (Photo)"
        propertyTable.detected_complexion_str = ""
        propertyTable.look_info_str = "0.0° Neutral Baseline (Rec.709 I-Line)"
        
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

        propertyTable.exp_low_text = "Low EV"
        propertyTable.exp_mid_text = "Mid EV"
        propertyTable.exp_high_text = "High EV"
        propertyTable.live_mode = true

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
                
                local mood_key = propertyTable.mood or 'neutral'
                if mood_key == 'filmic' then
                    propertyTable.look_info_str = "-2.0° Rose Shift • Soft Muted Film"
                elseif mood_key == 'fashion' then
                    propertyTable.look_info_str = "0.0° Clean • High-Contrast Editorial"
                elseif mood_key == 'golden' then
                    propertyTable.look_info_str = "+2.5° Golden Finish • Rich Warm Glow"
                else
                    propertyTable.look_info_str = "0.0° Neutral Baseline (Rec.709 I-Line)"
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
                local errFile = io.open("C:\\Users\\me\\AppData\\Roaming\\Adobe\\Lightroom\\skinscope_diag_error.log", "a")
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
            if value == true then
                applyLiveCorrection("live_mode_toggle")
                LrDialogs.showBezel("Live Auto-Apply: ON\n(Immediate Photo Push)")
            else
                LrDialogs.showBezel("On Press: ON\n(Manual Trigger)")
            end
        end)

        -- Helper to read settings from a photo
        local function refreshFromActivePhoto(photo)
            if not photo then return end
            propertyTable.prior_r = nil
            propertyTable.prior_g = nil
            propertyTable.prior_b = nil
            propertyTable.has_prior_diff = false
            propertyTable.face_sample = nil
            propertyTable.body_sample = nil
            LrTasks.pcall(function()
                local name = photo:getFormattedMetadata('fileName') or "Active Photo"
                propertyTable.photo_name = name

                local curTemp = nil
                local curTint = nil
                local curOrange = nil
                local curExposure = nil
                local curOrangeSat = nil

                if LrApplicationView.getCurrentModuleName() == 'develop' then
                    curTemp = LrDevelopController.getValue('Temperature')
                    curTint = LrDevelopController.getValue('Tint')
                    curOrange = LrDevelopController.getValue('HueAdjustmentOrange')
                    curExposure = LrDevelopController.getValue('Exposure2012') or LrDevelopController.getValue('Exposure')
                    curOrangeSat = LrDevelopController.getValue('SaturationAdjustmentOrange')
                end

                if not curTemp or not curTint then
                    local dev = photo:getDevelopSettings() or {}
                    curTemp = curTemp or dev.Temperature or 5500
                    curTint = curTint or dev.Tint or 10
                    curOrange = curOrange or dev.HueAdjustmentOrange or 0
                    curExposure = curExposure or dev.Exposure2012 or dev.Exposure or 0
                    curOrangeSat = curOrangeSat or dev.SaturationAdjustmentOrange or 0
                end

                local flashFired = 0
                LrTasks.pcall(function() flashFired = photo:getRawMetadata('flashFired') or 0 end)

                propertyTable.photo_baseline_temp = curTemp or 5500
                propertyTable.photo_baseline_tint = curTint or 8
                propertyTable.current_temp = curTemp or 5500
                propertyTable.current_tint = curTint or 8
                propertyTable.current_orange_hue = curOrange or 0
                propertyTable.current_exposure = curExposure or 0
                propertyTable.current_orange_sat = curOrangeSat or 0

                local profileName = "Adobe Color"
                LrTasks.pcall(function()
                    local d = photo:getDevelopSettings() or {}
                    profileName = d.Profile or d.CameraProfile or "Adobe Color"
                end)
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
                local photoPath = nil
                LrTasks.pcall(function() photoPath = photo:getRawMetadata('path') end)
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
                                    propertyTable.sampled_skin = { r = r, g = g, b = b, angle = angle, sat = sat, luma = luma }
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
                                        propertyTable.face_sample = { r = fr, g = fg, b = fb, angle = fa, sat = fs, luma = fl }
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
                                        propertyTable.body_sample = { r = br, g = bg, b = bb, angle = ba, sat = bs, luma = bl }
                                    end
                                end
                            end
                        end
                    end)
                end

                updateDiagnostics()
            end)
        end

        -- Filmstrip navigation helper
        local function selectAdjacentPhoto(delta)
            LrTasks.startAsyncTask(function()
                local success, err = LrTasks.pcall(function()
                    local catalog = LrApplication.activeCatalog()
                    local targetPhoto = catalog:getTargetPhoto()
                    if not targetPhoto then return end

                    local photos = nil
                    local sources = catalog:getActiveSources()
                    if sources and #sources > 0 and sources[1].getPhotos then
                        photos = sources[1]:getPhotos()
                    end
                    if not photos or #photos == 0 then
                        photos = catalog:getTargetPhotos()
                    end
                    if not photos or #photos == 0 then return end

                    local currentIndex = nil
                    local targetId = targetPhoto.localIdentifier
                    for i, p in ipairs(photos) do
                        if p.localIdentifier == targetId then
                            currentIndex = i
                            break
                        end
                    end

                    if currentIndex then
                        local nextIndex = currentIndex + delta
                        if nextIndex >= 1 and nextIndex <= #photos then
                            local nextPhoto = photos[nextIndex]
                            catalog:setSelectedPhotos(nextPhoto, {})
                            refreshFromActivePhoto(nextPhoto)
                        else
                            LrDialogs.showBezel(delta > 0 and "At end of photo list." or "At start of photo list.")
                        end
                    end
                end)
            end)
        end

        -- Background tracking task: auto-updates when you click or scroll in Lightroom, or adjust controls
        local isRunning = true
        LrTasks.startAsyncTask(function()
            local catalog = LrApplication.activeCatalog()
            local lastPhotoId = nil
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

            local initP = catalog:getTargetPhoto()
            if initP then lastPhotoId = initP.localIdentifier end

            while isRunning do
                LrTasks.pcall(function()
                    local currentTarget = catalog:getTargetPhoto()
                    if currentTarget then
                        local currentId = currentTarget.localIdentifier
                        local curTemp = nil
                        local curTint = nil
                        local curOrange = nil
                        local curExp = nil
                        local curSat = nil

                        if LrApplicationView.getCurrentModuleName() == 'develop' then
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

                        if isApplyingLive then
                            -- Live sync is currently pushing values to Lightroom; skip overwriting
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
                    action = function() selectAdjacentPhoto(-1) end,
                },
                f:static_text {
                    title = LrView.bind('photo_name'),
                    font = "<system/bold>",
                    alignment = "center",
                    fill_horizontal = 1,
                },
                f:push_button {
                    title = "Next ▶",
                    action = function() selectAdjacentPhoto(1) end,
                },
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

            -- Live vs On-Press Mode Toggle (Checkbox)
            f:row {
                fill_horizontal = 1,
                spacing = 6,
                f:static_text { title = "Sync:", width = 72, font = "<system/bold>" },
                f:checkbox {
                    title = "Live Auto-Sync",
                    value = LrView.bind('live_mode'),
                    font = "<system/bold>",
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
                        { title = "1. Porcelain (Ginger / Pink)", value = 'pale' },
                        { title = "2. Fair European (Neutral Peach)", value = 'fair' },
                        { title = "3. East Asian (Warm Ivory)", value = 'east_asian' },
                        { title = "4. Olive / Tan (Mediterranean)", value = 'olive' },
                        { title = "5. Brown - Light (Wheatish)", value = 'brown_light' },
                        { title = "6. Brown - Medium (Bronze)", value = 'brown_medium' },
                        { title = "7. Brown - Deep (Dark Bronze)", value = 'brown_deep' },
                        { title = "8. Deep Melanin (Ebony)", value = 'deep_melanin' },
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
                    text_color = LrColor(0.20, 0.65, 1.0),
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
                        { title = "Commercial Clean (0.0°)", value = 'neutral' },
                        { title = "Soft Filmic Rose (-2.0°)", value = 'filmic' },
                        { title = "Fashion Contrast (0.0°)", value = 'fashion' },
                        { title = "Golden Finish (+2.5°)", value = 'golden' },
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
                    title = "Snap Exposure (Luma Target):",
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
            save_frame = "skinscope_floating_hud_v29",
            contents = contents,
            windowWillClose = function()
                isRunning = false
                SkinScopeDialog.isOpen = false
            end,
        })
    end)
end

return SkinScopeDialog
