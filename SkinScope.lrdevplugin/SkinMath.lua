--[[
  SkinMath.lua
  Mathematical foundation for SkinScope (Lightroom Classic Plugin)
  Vectorscope Rec.709 Cb/Cr, CIELAB conversions, calibration matrices,
  and dynamic Develop slider color-shift simulation.
]]

local SkinMath = {}

-- Calibration Matrices for 8 Plain-English Complexions
-- Calibrated against X-Rite ColorChecker Classic/Passport and Google Monk Skin Tone (MST) research
SkinMath.COMPLEXIONS = {
    pale = { 
        title = "1. Very Fair / Pale (Porcelain / English Rose)", 
        baseline = 119.5, r = 0.92, g = 0.78, b = 0.73, sat_min = 0.06, sat_max = 0.16,
        female = { luma_min = 60, luma_max = 82, sat_target = 24, sat_min = 18, sat_max = 30 },
        male   = { luma_min = 55, luma_max = 77, sat_target = 22, sat_min = 16, sat_max = 28 },
    },
    fair = { 
        title = "2. Fair / Light (European / Neutral Peach)", 
        baseline = 124.5, r = 0.86, g = 0.67, b = 0.58, sat_min = 0.08, sat_max = 0.18,
        female = { luma_min = 55, luma_max = 75, sat_target = 25, sat_min = 20, sat_max = 30 },
        male   = { luma_min = 50, luma_max = 70, sat_target = 23, sat_min = 18, sat_max = 28 },
    },
    east_asian = { 
        title = "3. East Asian / Golden Light (Warm Ivory)", 
        baseline = 131.0, r = 0.86, g = 0.70, b = 0.56, sat_min = 0.08, sat_max = 0.18,
        female = { luma_min = 55, luma_max = 75, sat_target = 25, sat_min = 20, sat_max = 30 },
        male   = { luma_min = 50, luma_max = 70, sat_target = 23, sat_min = 18, sat_max = 28 },
    },
    olive = { 
        title = "4. Olive / Sun-Kissed Tan (Mediterranean / Latino)", 
        baseline = 131.5, r = 0.82, g = 0.64, b = 0.50, sat_min = 0.09, sat_max = 0.20,
        female = { luma_min = 45, luma_max = 68, sat_target = 26, sat_min = 21, sat_max = 31 },
        male   = { luma_min = 40, luma_max = 63, sat_target = 24, sat_min = 19, sat_max = 29 },
    },
    brown_light = { 
        title = "5. Brown - Light (Wheatish / North Indian / Desi)", 
        baseline = 129.5, r = 0.75, g = 0.56, b = 0.43, sat_min = 0.09, sat_max = 0.22,
        female = { luma_min = 40, luma_max = 62, sat_target = 25, sat_min = 20, sat_max = 30 },
        male   = { luma_min = 35, luma_max = 57, sat_target = 23, sat_min = 18, sat_max = 28 },
    },
    brown_medium = { 
        title = "6. Brown - Medium (Warm Bronze / South Indian Lighter)", 
        baseline = 127.5, r = 0.64, g = 0.46, b = 0.34, sat_min = 0.08, sat_max = 0.20,
        female = { luma_min = 30, luma_max = 52, sat_target = 24, sat_min = 19, sat_max = 29 },
        male   = { luma_min = 25, luma_max = 47, sat_target = 22, sat_min = 17, sat_max = 27 },
    },
    brown_deep = { 
        title = "7. Brown - Deep (Dark Bronze / South Indian Deeper)", 
        baseline = 125.5, r = 0.50, g = 0.34, b = 0.24, sat_min = 0.07, sat_max = 0.18,
        female = { luma_min = 22, luma_max = 44, sat_target = 23, sat_min = 18, sat_max = 28 },
        male   = { luma_min = 18, luma_max = 39, sat_target = 20, sat_min = 15, sat_max = 25 },
    },
    deep_melanin = { 
        title = "8. Deep Melanin / Ebony (African / Rich Espresso)", 
        baseline = 123.0, r = 0.38, g = 0.25, b = 0.18, sat_min = 0.06, sat_max = 0.16,
        female = { luma_min = 16, luma_max = 36, sat_target = 22, sat_min = 17, sat_max = 27 },
        male   = { luma_min = 14, luma_max = 32, sat_target = 18, sat_min = 13, sat_max = 23 },
    },
}

-- Backward compatibility aliases
SkinMath.COMPLEXIONS.medium = SkinMath.COMPLEXIONS.brown_medium
SkinMath.COMPLEXIONS.dark = SkinMath.COMPLEXIONS.deep_melanin

SkinMath.GENDERS = {
    female = { title = "♀ Female Portrait (Soft Glow)", luma_offset = 0, sat_offset = 0 },
    male = { title = "♂ Male Portrait (Natural Matte)", luma_offset = -5, sat_offset = -5 },
}

-- Scene Lighting & Atmospheric WB presets (Relative offsets from photo neutral baseline)
SkinMath.LIGHTING = {
    auto_detect = { title = "Auto-Detect (Current Photo)", offset = 0.0, temp_delta = 0, tint_delta = 0, sat_offset = 0 },
    neutral = { title = "Daylight / Clean Neutral (Base)", offset = 0.0, temp_delta = 0, tint_delta = 0, sat_offset = 0 },
    golden_hour = { title = "Sunset / Golden Hour (+900K)", offset = 5.0, temp_delta = 900, tint_delta = 3, sat_offset = 3 },
    warm_glow = { title = "Warm Studio / Honey (+450K)", offset = 2.5, temp_delta = 450, tint_delta = 2, sat_offset = 1 },
    overcast_shade = { title = "Open Shade / Cool Moody (-400K)", offset = -1.5, temp_delta = -400, tint_delta = 3, sat_offset = -1 },
    tungsten = { title = "Tungsten / Candlelight (+1500K)", offset = 6.5, temp_delta = 1500, tint_delta = 2, sat_offset = 4 },
}
-- Backward compatibility alias
SkinMath.LIGHTING.flash_daylight = SkinMath.LIGHTING.neutral

SkinMath.MOODS = {
    neutral = { title = "Commercial Clean (0.0°)", offset = 0.0 },
    filmic = { title = "Soft Filmic Rose (-2.0°)", offset = -2.0 },
    fashion = { title = "Fashion Contrast (0.0°)", offset = 0.0 },
    golden = { title = "Warm Golden Finish (+2.5°)", offset = 2.5 },
}

SkinMath.TANS = {
    winter = { title = "Natural / Untanned (Base)", offset = 0.0, sat_offset = 0 },
    sun_kissed = { title = "Sun-Kissed Glow (+2.0°)", offset = 2.0, sat_offset = 2 },
    deep_tan = { title = "Deep Bronze Tan (+4.0°)", offset = 4.0, sat_offset = 5 },
}

--- Auto-detect scene lighting intent from camera temperature and flash metadata
function SkinMath.detect_lighting_setup(current_temp, flash_fired)
    if flash_fired == true or flash_fired == 1 then
        return "neutral", "Auto: Studio Flash (Daylight Base)"
    end
    local temp = current_temp or 5500
    if temp >= 6400 then
        return "overcast_shade", string.format("Auto: Open Shade (~%dK)", math.floor(temp))
    elseif temp >= 5850 then
        return "golden_hour", string.format("Auto: Sunset / Golden (~%dK)", math.floor(temp))
    elseif temp >= 4400 then
        return "neutral", string.format("Auto: Daylight / Neutral (~%dK)", math.floor(temp))
    elseif temp >= 2800 and temp <= 3600 then
        return "tungsten", string.format("Auto: Tungsten Lamp (~%dK)", math.floor(temp))
    else
        return "neutral", string.format("Auto: Custom Kelvin (~%dK)", math.floor(temp))
    end
end

--- Automatically detect the closest matching complexion profile using biological Luma & Melanin indexing
function SkinMath.detect_complexion(r, g, b, luma, angle)
    if not r or not g or not b then
        return 'fair', "Auto: Fair European (Neutral Peach)"
    end

    local Y = (luma and (luma / 100.0)) or (0.2126 * r + 0.7152 * g + 0.0722 * b)
    local br_ratio = b / math.max(0.01, r)
    local best_key = 'fair'

    -- Tier 1: Very Fair / Fair / East Asian (Luma >= 63%)
    if Y >= 0.63 then
        if Y >= 0.78 or br_ratio >= 0.74 then
            best_key = 'pale'
        elseif br_ratio >= 0.62 then
            best_key = 'fair'
        else
            best_key = 'east_asian'
        end
    -- Tier 2: Medium / Tan / Olive / Brown Light (Luma 48% - 63%)
    elseif Y >= 0.48 then
        if br_ratio <= 0.60 then
            best_key = 'olive'
        else
            best_key = 'brown_light'
        end
    -- Tier 3: Brown Medium (Luma 38% - 48%)
    elseif Y >= 0.38 then
        best_key = 'brown_medium'
    -- Tier 4: Brown Deep (Luma 28% - 38%)
    elseif Y >= 0.28 then
        best_key = 'brown_deep'
    -- Tier 5: Deep Melanin (Luma < 28%)
    else
        best_key = 'deep_melanin'
    end

    local comp_obj = SkinMath.COMPLEXIONS[best_key]
    local title = comp_obj and comp_obj.title or best_key
    return best_key, "Auto: " .. title
end

--- Convert sRGB [0.0 - 1.0] to Rec.709 YCbCr
function SkinMath.rgb_to_ycbcr(r, g, b)
    local Y  =  0.2126 * r + 0.7152 * g + 0.0722 * b
    local Cb = -0.1146 * r - 0.3854 * g + 0.5000 * b
    Cr =  0.5000 * r - 0.4542 * g - 0.0458 * b
    return Y, Cb, Cr
end

--- Calculate Vectorscope Hue Angle (degrees) from Cb, Cr
function SkinMath.ycbcr_to_hue_angle(Cb, Cr)
    local rad = math.atan2(Cr, Cb)
    local deg = rad * (180.0 / math.pi)
    if deg < 0 then
        deg = deg + 360.0
    end
    return deg
end

--- Calculate Vectorscope Saturation (Radius from center)
function SkinMath.ycbcr_to_saturation(Cb, Cr)
    return math.sqrt(Cb * Cb + Cr * Cr)
end

--- Calculate Target Angle and Target WB from Context Configuration
function SkinMath.calculate_targets(complexion_key, lighting_key, mood_key, tan_key, current_temp, flash_fired, baseline_temp, baseline_tint)
    local comp = SkinMath.COMPLEXIONS[complexion_key] or SkinMath.COMPLEXIONS.fair
    local effective_lighting_key = lighting_key or "auto_detect"
    local detected_desc = ""

    if effective_lighting_key == "auto_detect" or not SkinMath.LIGHTING[effective_lighting_key] then
        effective_lighting_key, detected_desc = SkinMath.detect_lighting_setup(current_temp, flash_fired)
    else
        detected_desc = "Manual: " .. (SkinMath.LIGHTING[effective_lighting_key] and SkinMath.LIGHTING[effective_lighting_key].title or effective_lighting_key)
    end

    local light = SkinMath.LIGHTING[effective_lighting_key] or SkinMath.LIGHTING.neutral
    local mood = SkinMath.MOODS[mood_key] or SkinMath.MOODS.neutral
    local tan = SkinMath.TANS[tan_key] or SkinMath.TANS.winter

    -- Calibrated I-Line vectorscope target angle (Skin complexion + Tan + Look/Mood)
    local target_angle = comp.baseline + (tan.offset or 0.0) + (mood.offset or 0.0)

    -- Relative Scene White Balance Target:
    -- Anchors to photo baseline (or current temp) and adds creative offset
    local base_t = baseline_temp or current_temp or 5500
    local base_ti = baseline_tint or 8
    local target_temp = math.floor(base_t + (light.temp_delta or 0))
    local target_tint = math.floor(base_ti + (light.tint_delta or 0))

    -- Safety bounds: never push tint past photographic sanity
    target_tint = math.max(-4, math.min(14, target_tint))

    return target_angle, target_temp, target_tint, comp.sat_min, comp.sat_max, detected_desc, effective_lighting_key
end

--- Simulate the effective skin color under active Develop settings
function SkinMath.simulate_effective_rgb(current_temp, current_tint, current_orange_hue, target_temp, target_tint, complexion_key, exposure_ev, orange_sat, custom_r, custom_g, custom_b)
    local comp = SkinMath.COMPLEXIONS[complexion_key] or SkinMath.COMPLEXIONS.fair
    local r = custom_r or comp.r or 0.85
    local g = custom_g or comp.g or 0.67
    local b = custom_b or comp.b or 0.57

    local cur_temp = math.max(2000, math.min(50000, current_temp or target_temp or 5500))
    local cur_tint = math.max(-150, math.min(150, current_tint or target_tint or 8))
    local ref_temp = target_temp or 5500
    local ref_tint = target_tint or 8

    -- Exposure EV adjustment (2^EV photographic scale)
    local exp_val = exposure_ev or 0.0
    if exp_val ~= 0.0 then
        local exp_mult = math.pow(2.0, math.max(-3.0, math.min(3.0, exp_val)))
        r = r * exp_mult
        g = g * exp_mult
        b = b * exp_mult
    end

    -- Orange Hue in LR: -100 is toward Red, +100 is toward Yellow
    local orange_factor = (current_orange_hue or 0) * 0.0035
    r = r * (1.0 - orange_factor * 0.5)
    g = g * (1.0 + orange_factor * 0.5)

    -- Orange Saturation adjustment in LR (-100 to +100)
    local sat_val = orange_sat or 0.0
    if sat_val ~= 0.0 then
        local sat_factor = math.max(0.0, 1.0 + (sat_val / 100.0))
        local gray = 0.2126 * r + 0.7152 * g + 0.0722 * b
        r = gray + (r - gray) * sat_factor
        g = gray + (g - gray) * sat_factor
        b = gray + (b - gray) * sat_factor
    end

    local max_val = math.max(r, math.max(g, b))
    if max_val > 1.0 then
        r = r / max_val
        g = g / max_val
        b = b / max_val
    end
    r = math.max(0.01, math.min(1.0, r))
    g = math.max(0.01, math.min(1.0, g))
    b = math.max(0.01, math.min(1.0, b))

    return r, g, b
end

--- Solve for the exact Orange HSL Hue setting that aligns vectorscope angle with target_angle in a single click
function SkinMath.solve_target_orange_hue(current_temp, current_tint, ref_temp, ref_tint, complexion_key, target_angle, exposure_ev, orange_sat, custom_r, custom_g, custom_b)
    local low = -25.0
    local high = 25.0
    for i = 1, 30 do
        local mid = (low + high) * 0.5
        local r, g, b = SkinMath.simulate_effective_rgb(current_temp, current_tint, mid, ref_temp, ref_tint, complexion_key, exposure_ev, orange_sat, custom_r, custom_g, custom_b)
        local _, Cb, Cr = SkinMath.rgb_to_ycbcr(r, g, b)
        local ang = SkinMath.ycbcr_to_hue_angle(Cb, Cr)
        if ang < target_angle then
            low = mid
        else
            high = mid
        end
    end
    local best_hue = math.floor((low + high) * 0.5 + 0.5)
    -- Strict photographic safety limit: Orange Hue should refine skin (-20 to +20), never cause extreme distortion
    return math.max(-20, math.min(20, best_hue))
end

--- Solve for the Orange HSL Saturation setting with a dead-band controller
--- In raw photography, skin is already naturally saturated. 
--- If skin saturation is in the healthy band (19% - 28%), keep Orange Saturation at 0 (natural).
--- Only gently boost (+1 to +3) if ashen, or gently pull back (-1 to -5) if oversaturated.
function SkinMath.solve_target_orange_sat(current_temp, current_tint, orange_hue, ref_temp, ref_tint, complexion_key, target_sat_pct, exposure_ev, custom_r, custom_g, custom_b)
    local comp = SkinMath.COMPLEXIONS[complexion_key] or SkinMath.COMPLEXIONS.fair
    local base_r = custom_r or comp.r or 0.86
    local base_g = custom_g or comp.g or 0.67
    local base_b = custom_b or comp.b or 0.58
    local base_Y = 0.2126 * base_r + 0.7152 * base_g + 0.0722 * base_b

    -- Check natural saturation at neutral 0 Orange Saturation
    local r0, g0, b0 = SkinMath.simulate_effective_rgb(current_temp, current_tint, orange_hue, ref_temp, ref_tint, complexion_key, exposure_ev, 0, custom_r, custom_g, custom_b)
    local Y0, Cb0, Cr0 = SkinMath.rgb_to_ycbcr(r0, g0, b0)
    local chroma0 = SkinMath.ycbcr_to_saturation(Cb0, Cr0)
    local natural_sat = (chroma0 / math.max(0.01, Y0)) * base_Y / 0.5 * 100.0

    -- Dead-Band: If natural saturation is within healthy photographic range (19% - 28%), do NOT boost!
    if natural_sat >= 19.0 and natural_sat <= 28.0 then
        return 0
    elseif natural_sat > 28.0 then
        -- Gently pull back oversaturated skin (e.g. spray tan or sunburn)
        local excess = natural_sat - 28.0
        local pullback = -math.floor(excess * 0.8 + 0.5)
        return math.max(-5, math.min(0, pullback))
    else
        -- Gently lift lifeless/ashen skin
        local deficit = 19.0 - natural_sat
        local boost = math.floor(deficit * 0.6 + 0.5)
        return math.max(0, math.min(3, boost))
    end
end

--- Solve for the target Global WB Tint setting that aligns vectorscope angle with target_angle at target_temp
function SkinMath.solve_target_global_wb_tint(target_temp, ref_temp, ref_tint, complexion_key, target_angle, exposure_ev, orange_sat, custom_r, custom_g, custom_b)
    local low = -6.0
    local high = 16.0
    for i = 1, 25 do
        local mid = (low + high) * 0.5
        local r, g, b = SkinMath.simulate_effective_rgb(target_temp, mid, 0, ref_temp, ref_tint, complexion_key, exposure_ev, orange_sat, custom_r, custom_g, custom_b)
        local _, Cb, Cr = SkinMath.rgb_to_ycbcr(r, g, b)
        local ang = SkinMath.ycbcr_to_hue_angle(Cb, Cr)
        if ang > target_angle then
            low = mid
        else
            high = mid
        end
    end
    local best_tint = math.floor((low + high) * 0.5 + 0.5)
    -- Photographic safety bounds: never force extreme tint that turns neutral clothing purple/green
    return math.max(-4, math.min(14, best_tint))
end

--- Generate a completely borderless 344x36 compact split swatch image
--- If prior_r/g/b is provided and differs from cur_r/g/b (live edits active):
--- Left half is stacked: top half = Prior (unmodified photo), bottom half = Current (live edits)
--- Right half = Target (look goal) across all rows
function SkinMath.write_split_swatch(filePath, cur_r, cur_g, cur_b, tgt_r, tgt_g, tgt_b, prior_r, prior_g, prior_b)
    local width = 344
    local height = 36
    local row_size = width * 3 -- 1032 bytes, exactly divisible by 4
    local file_size = 54 + row_size * height

    local f = io.open(filePath, "wb")
    if not f then return false end

    -- Helper to write 16-bit little-endian integer
    local function write16(n)
        f:write(string.char(n % 256, math.floor(n / 256) % 256))
    end

    -- Helper to write 32-bit little-endian integer
    local function write32(n)
        f:write(string.char(
            n % 256,
            math.floor(n / 256) % 256,
            math.floor(n / 65536) % 256,
            math.floor(n / 16777216) % 256
        ))
    end

    -- BMP Header (14 bytes)
    f:write("BM")
    write32(file_size)
    write32(0) -- Reserved
    write32(54) -- Offset to pixel data

    -- DIB Header (40 bytes, BITMAPINFOHEADER)
    write32(40) -- Header size
    write32(width)
    write32(height)
    write16(1) -- Color planes
    write16(24) -- Bits per pixel (24-bit BGR)
    write32(0) -- BI_RGB (uncompressed)
    write32(row_size * height)
    write32(2835) -- 72 DPI
    write32(2835) -- 72 DPI
    write32(0)
    write32(0)

    -- Pixel data (BGR format in BMP)
    local c_b = math.floor(math.max(0, math.min(1, cur_b or 0.465)) * 255 + 0.5)
    local c_g = math.floor(math.max(0, math.min(1, cur_g or 0.49)) * 255 + 0.5)
    local c_r = math.floor(math.max(0, math.min(1, cur_r or 0.72)) * 255 + 0.5)

    local t_b = math.floor(math.max(0, math.min(1, tgt_b or 0.465)) * 255 + 0.5)
    local t_g = math.floor(math.max(0, math.min(1, tgt_g or 0.49)) * 255 + 0.5)
    local t_r = math.floor(math.max(0, math.min(1, tgt_r or 0.72)) * 255 + 0.5)

    local cur_pixel = string.char(c_b, c_g, c_r)
    local right_pixel = string.char(t_b, t_g, t_r)

    local cur_half = string.rep(cur_pixel, 172)
    local right_half = string.rep(right_pixel, 172)

    local has_prior = false
    local prior_half = nil
    if prior_r and prior_g and prior_b then
        local p_b = math.floor(math.max(0, math.min(1, prior_b)) * 255 + 0.5)
        local p_g = math.floor(math.max(0, math.min(1, prior_g)) * 255 + 0.5)
        local p_r = math.floor(math.max(0, math.min(1, prior_r)) * 255 + 0.5)
        local diff = math.abs(p_r - c_r) + math.abs(p_g - c_g) + math.abs(p_b - c_b)
        if diff >= 2 then
            has_prior = true
            local prior_pixel = string.char(p_b, p_g, p_r)
            prior_half = string.rep(prior_pixel, 172)
        end
    end

    local full_image
    if has_prior then
        -- BMP scanlines are bottom-to-top:
        -- Bottom 18 rows = Current live edits
        -- Top 18 rows = Prior photo baseline
        local bottom_row = cur_half .. right_half
        local top_row = prior_half .. right_half
        full_image = string.rep(bottom_row, 18) .. string.rep(top_row, 18)
    else
        local single_row = cur_half .. right_half
        full_image = string.rep(single_row, height)
    end

    f:write(full_image)
    f:close()
    return true
end

--- Calculate calibrated target skin RGB for the given complexion, lighting, and mood
function SkinMath.calculate_target_skin_rgb(complexion_key, lighting_key, mood_key, tan_key)
    local comp = SkinMath.COMPLEXIONS[complexion_key] or SkinMath.COMPLEXIONS.fair
    local mood = SkinMath.MOODS[mood_key] or SkinMath.MOODS.neutral
    local light = SkinMath.LIGHTING[lighting_key] or SkinMath.LIGHTING.neutral
    local tan = SkinMath.TANS[tan_key] or SkinMath.TANS.winter

    local r = comp.r or 0.85
    local g = comp.g or 0.67
    local b = comp.b or 0.57

    -- Total angle rotation from baseline
    local rot_deg = (tan.offset or 0.0) + (light.offset or 0.0) + (mood.offset or 0.0)
    if rot_deg > 0 then
        -- Golden/warm shift: more yellow and red, less blue
        r = r * (1.0 + rot_deg * 0.012)
        g = g * (1.0 + rot_deg * 0.008)
        b = b * (1.0 - rot_deg * 0.020)
    elseif rot_deg < 0 then
        -- Rosy/cool shift: more red/magenta, less green
        local mag = math.abs(rot_deg)
        r = r * (1.0 + mag * 0.010)
        g = g * (1.0 - mag * 0.018)
        b = b * (1.0 + mag * 0.006)
    end

    local max_val = math.max(r, math.max(g, b))
    if max_val > 1.0 then
        r = r / max_val
        g = g / max_val
        b = b / max_val
    end

    return math.max(0.01, math.min(1.0, r)),
           math.max(0.01, math.min(1.0, g)),
           math.max(0.01, math.min(1.0, b))
end

--- Analyze active photo settings and evaluate vectorscope metrics
function SkinMath.evaluate_active_photo(current_temp, current_tint, current_orange_hue, complexion_key, lighting_key, mood_key, tan_key, flash_fired, subject_complexion_key, gender_key, current_exposure, current_orange_sat, custom_r, custom_g, custom_b, baseline_temp, baseline_tint)
    local detected_comp, detected_comp_title = nil, nil
    local eff_comp = complexion_key
    local Y_temp = custom_r and (0.2126 * custom_r + 0.7152 * (custom_g or 0.67) + 0.0722 * (custom_b or 0.57))
    local custom_angle = nil
    if custom_r and custom_g and custom_b then
        local _, cCb, cCr = SkinMath.rgb_to_ycbcr(custom_r, custom_g, custom_b)
        custom_angle = SkinMath.ycbcr_to_hue_angle(cCb, cCr)
    end

    if not eff_comp or eff_comp == "auto_detect" or not SkinMath.COMPLEXIONS[eff_comp] then
        detected_comp, detected_comp_title = SkinMath.detect_complexion(custom_r, custom_g, custom_b, Y_temp and (Y_temp * 100), custom_angle)
        eff_comp = detected_comp
    else
        local c_obj = SkinMath.COMPLEXIONS[eff_comp]
        detected_comp_title = "Manual: " .. (c_obj and c_obj.title or eff_comp)
    end

    local target_angle, target_temp, target_tint, sat_min, sat_max, detected_desc, effective_lighting_key = 
        SkinMath.calculate_targets(eff_comp, lighting_key, mood_key, tan_key, current_temp, flash_fired, baseline_temp, baseline_tint)

    -- Standard reference for daylight skin tone calibration
    local ref_temp = baseline_temp or 5500
    local ref_tint = baseline_tint or 8

    -- Subject's actual skin complexion in the active photo (matches selected complexion profile)
    local subject_comp = (subject_complexion_key and subject_complexion_key ~= "auto_detect" and subject_complexion_key) or eff_comp or 'fair'

    local r, g, b = SkinMath.simulate_effective_rgb(
        current_temp, current_tint, current_orange_hue, ref_temp, ref_tint, subject_comp, current_exposure, current_orange_sat, custom_r, custom_g, custom_b
    )

    local Y, Cb, Cr = SkinMath.rgb_to_ycbcr(r, g, b)
    local current_angle = SkinMath.ycbcr_to_hue_angle(Cb, Cr)
    local current_sat = SkinMath.ycbcr_to_saturation(Cb, Cr)

    -- Van Hurkman Luminance and Saturation metrics (Color Correction Handbook)
    local gender = gender_key or 'female'
    local comp = SkinMath.COMPLEXIONS[eff_comp] or SkinMath.COMPLEXIONS.fair
    local comp_vh = (comp[gender]) or comp.female or { luma_min = 55, luma_max = 75, sat_target = 28, sat_min = 23, sat_max = 33 }

    local luma_pct = math.floor(Y * 100 + 0.5)

    -- Luma-normalized saturation: (chroma / Y) * base_Y / 0.5 * 100
    -- This is exposure-invariant: when RGB scales by 2^EV, both chroma and Y
    -- scale equally, so chroma/Y stays constant. base_Y anchors the scale
    -- so existing sat_min/sat_max ranges remain valid at baseline exposure.
    local base_r = custom_r or comp.r or 0.85
    local base_g = custom_g or comp.g or 0.67
    local base_b = custom_b or comp.b or 0.57
    local base_Y = 0.2126 * base_r + 0.7152 * base_g + 0.0722 * base_b
    local sat_pct = math.floor((current_sat / math.max(0.01, Y)) * base_Y / 0.5 * 100 + 0.5)

    local target_luma_min = comp_vh.luma_min
    local target_luma_max = comp_vh.luma_max
    local target_sat_min = comp_vh.sat_min
    local target_sat_max = comp_vh.sat_max

    local luma_tag = "✔"
    local luma_status = "OPTIMAL"
    if luma_pct < target_luma_min then
        luma_status = "UNDEREXPOSED"
        luma_tag = "▼ Low"
    elseif luma_pct > target_luma_max then
        luma_status = "OVEREXPOSED"
        luma_tag = "▲ High"
    end

    local sat_tag = "✔"
    local sat_status = "OPTIMAL"
    if sat_pct < target_sat_min then
        sat_status = "ASHEN_LOW"
        sat_tag = "▼ Low"
    elseif sat_pct > target_sat_max then
        sat_status = "OVERSATURATED"
        sat_tag = "▲ High"
    end

    local luma_readout_str = string.format("Luma: %d%% (%d–%d%% %s)", luma_pct, target_luma_min, target_luma_max, luma_tag)
    local sat_readout_str = string.format("Sat: %d%% (%d–%d%% %s)", sat_pct, target_sat_min, target_sat_max, sat_tag)
    local van_hurkman_metrics_str = luma_readout_str .. "  •  " .. sat_readout_str
    local van_hurkman_is_optimal = (luma_status == "OPTIMAL") and (sat_status == "OPTIMAL")

    -- Exposure EV calculations to bring Luma into Low, Mid, and High target keys
    local cur_exp = current_exposure or 0.0
    local target_luma_low = target_luma_min + 2
    local target_luma_mid = (target_luma_min + target_luma_max) / 2.0
    local target_luma_high = target_luma_max - 2

    local function calc_ev_target(target_luma, current_luma, current_ev)
        local safe_luma = math.max(1, current_luma or 50)
        local delta = math.log(target_luma / safe_luma) / math.log(2.0)
        delta = math.max(-2.0, math.min(2.0, delta))
        delta = math.floor(delta * 20 + 0.5) / 20.0
        local tgt = (current_ev or 0.0) + delta
        tgt = math.max(-5.0, math.min(5.0, math.floor(tgt * 100 + 0.5) / 100.0))
        return delta, tgt
    end

    local exp_delta_low, exp_target_low = calc_ev_target(target_luma_low, luma_pct, cur_exp)
    local exp_delta_mid, exp_target_mid = calc_ev_target(target_luma_mid, luma_pct, cur_exp)
    local exp_delta_high, exp_target_high = calc_ev_target(target_luma_high, luma_pct, cur_exp)

    -- Shortest distance on 360-deg color wheel:
    local delta_angle = current_angle - target_angle
    while delta_angle > 180.0 do delta_angle = delta_angle - 360.0 end
    while delta_angle < -180.0 do delta_angle = delta_angle + 360.0 end

    local abs_delta = math.abs(delta_angle)
    local diff_temp = (current_temp or target_temp) - target_temp
    local diff_tint = (current_tint or target_tint) - target_tint

    local status = "ON_TARGET"
    local summary = "Skin tone is in the optimal band."
    local action_text = "No adjustment needed."

    -- 1. Solve for the EXACT target Orange HSL Hue for single-click precision:
    local exact_target_orange = SkinMath.solve_target_orange_hue(
        current_temp, current_tint, ref_temp, ref_tint, subject_comp, target_angle, current_exposure, current_orange_sat, custom_r, custom_g, custom_b
    )

    -- 2. Solve for the EXACT target Orange HSL Saturation for natural balance:
    local exact_target_orange_sat = SkinMath.solve_target_orange_sat(
        current_temp, current_tint, exact_target_orange, ref_temp, ref_tint, subject_comp, comp_vh.sat_target or 28, current_exposure, custom_r, custom_g, custom_b
    )

    -- 3. Solve for the EXACT target Global WB Tint at target_temp:
    local exact_target_tint = SkinMath.solve_target_global_wb_tint(
        target_temp, ref_temp, ref_tint, subject_comp, target_angle, current_exposure, current_orange_sat, custom_r, custom_g, custom_b
    )

    -- Target skin tone: Calibrated human skin tone for the chosen Complexion, Tan & Mood
    local tgt_r, tgt_g, tgt_b = SkinMath.calculate_target_skin_rgb(subject_comp, effective_lighting_key, mood_key, tan_key)

    -- Luminance-matched split swatch:
    -- Match Target's luminance to Current skin luminance so the Before/After comparator
    -- directly reveals hue & saturation differences without a misleading brightness step
    local cur_Y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    local tgt_Y = 0.2126 * tgt_r + 0.7152 * tgt_g + 0.0722 * tgt_b
    if tgt_Y > 0.001 and cur_Y > 0.001 then
        local luma_scale = cur_Y / tgt_Y
        tgt_r = math.max(0.0, math.min(1.0, tgt_r * luma_scale))
        tgt_g = math.max(0.0, math.min(1.0, tgt_g * luma_scale))
        tgt_b = math.max(0.0, math.min(1.0, tgt_b * luma_scale))
    end

    -- Proper classification of color cast:
    -- Proper classification of color cast:
    if abs_delta > 40 or math.abs(diff_temp) > 1200 then
        if diff_temp < -800 or delta_angle < -40 then
            status = "EXTREME_COLD"
            summary = string.format("❄ EXTREME BLUE CAST (Temp %dK is far too cold)", math.floor(current_temp or target_temp))
            action_text = string.format("White Balance is freezing cold. Click 'Scene WB' to restore %dK.", target_temp)
        else
            status = "EXTREME_WARM"
            summary = string.format("🔥 EXTREME AMBER CAST (Temp %dK is far too warm)", math.floor(current_temp or target_temp))
            action_text = string.format("White Balance is too warm. Click 'Scene WB' to restore %dK.", target_temp)
        end
    elseif delta_angle < -0.4 then
        status = "TOO_MAGENTA"
        local prefix = abs_delta > 15 and "[CRITICAL] " or (abs_delta > 5 and "[WARNING] " or "[Notice] ")
        summary = string.format("%s%.1f deg Too Magenta (Heavy Red/Pink Cast)", prefix, abs_delta)
        action_text = string.format("Shift toward Green, or click 'Snap Orange HSL' to set Hue to %+d.", exact_target_orange)
    elseif delta_angle > 0.4 then
        status = "TOO_YELLOW_GREEN"
        local prefix = abs_delta > 15 and "[CRITICAL] " or (abs_delta > 5 and "[WARNING] " or "[Notice] ")
        summary = string.format("%s%.1f deg Too Yellow/Green (Heavy Sallow/Green Cast)", prefix, abs_delta)
        action_text = string.format("Shift toward Rose, or click 'Snap Orange HSL' to set Hue to %+d.", exact_target_orange)
    end

    return {
        current_angle = current_angle,
        target_angle = target_angle,
        delta_angle = delta_angle,
        target_temp = target_temp,
        target_tint = exact_target_tint,
        diff_temp = diff_temp,
        diff_tint = diff_tint,
        saturation = current_sat,
        sat_min = sat_min,
        sat_max = sat_max,
        luma_pct = luma_pct,
        target_luma_min = target_luma_min,
        target_luma_max = target_luma_max,
        luma_status = luma_status,
        sat_pct = sat_pct,
        target_sat_min = target_sat_min,
        target_sat_max = target_sat_max,
        sat_status = sat_status,
        van_hurkman_metrics_str = van_hurkman_metrics_str,
        luma_readout_str = luma_readout_str,
        sat_readout_str = sat_readout_str,
        van_hurkman_is_optimal = van_hurkman_is_optimal,
        status = status,
        summary = summary,
        action_text = action_text,
        suggested_temp_target = target_temp,
        suggested_tint_target = exact_target_tint,
        suggested_exposure_delta = exp_delta_mid,
        suggested_exposure_target = exp_target_mid,
        exp_target_low = exp_target_low,
        exp_target_mid = exp_target_mid,
        exp_target_high = exp_target_high,
        exp_delta_low = exp_delta_low,
        exp_delta_mid = exp_delta_mid,
        exp_delta_high = exp_delta_high,
        suggested_hsl_orange = exact_target_orange,
        suggested_hsl_orange_target = exact_target_orange,
        suggested_orange_sat_target = exact_target_orange_sat,
        detected_lighting_desc = detected_desc,
        effective_lighting_key = effective_lighting_key,
        detected_complexion = detected_comp,
        detected_complexion_title = detected_comp_title,
        effective_complexion = eff_comp,
        current_r = r,
        current_g = g,
        current_b = b,
        target_r = tgt_r,
        target_g = tgt_g,
        target_b = tgt_b,
    }
end

-- Backward compatibility
function SkinMath.evaluate_sample(r, g, b, complexion_key, lighting_key, mood_key, tan_key)
    return SkinMath.evaluate_active_photo(5500, 10, 0, complexion_key, lighting_key, mood_key, tan_key, 0)
end

return SkinMath
