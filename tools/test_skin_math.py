#!/usr/bin/env python3
"""
test_skin_math.py
Unit tests and simulation harness for SkinScope vectorscope math.
Validates Rec.709 YCbCr transforms, hue angle math, and dynamic slider color simulation.
"""

import math

def rgb_to_ycbcr(r: float, g: float, b: float):
    """Convert normalized RGB [0.0 - 1.0] to Rec.709 YCbCr."""
    Y  =  0.2126 * r + 0.7152 * g + 0.0722 * b
    Cb = -0.1146 * r - 0.3854 * g + 0.5000 * b
    Cr =  0.5000 * r - 0.4542 * g - 0.0458 * b
    return Y, Cb, Cr

def ycbcr_to_hue_angle(Cb: float, Cr: float) -> float:
    """Calculate vectorscope hue angle in degrees (0 - 360)."""
    rad = math.atan2(Cr, Cb)
    deg = math.degrees(rad)
    if deg < 0:
        deg += 360.0
    return deg

def simulate_effective_rgb(cur_temp, cur_tint, cur_orange_hue, target_temp, target_tint, base_r=0.72, base_g=0.49, base_b=0.465):
    r, g, b = base_r, base_g, base_b
    m_cur = 1e6 / cur_temp
    m_tgt = 1e6 / target_temp
    delta_m = m_cur - m_tgt
    r *= (1.0 - delta_m * 0.0032)
    b *= (1.0 + delta_m * 0.0042)
    delta_tint = cur_tint - target_tint
    g *= (1.0 - delta_tint * 0.0045)
    r *= (1.0 + delta_tint * 0.0018)
    b *= (1.0 + delta_tint * 0.0018)
    orange_factor = (cur_orange_hue or 0) * 0.0035
    r *= (1.0 - orange_factor * 0.5)
    g *= (1.0 + orange_factor * 0.5)
    max_val = max(r, g, b)
    if max_val > 1.0:
        r, g, b = r/max_val, g/max_val, b/max_val
    return r, g, b

COMPLEXIONS = {
    'pale': {'title': '1. Very Fair / Pale (Porcelain / English Rose)', 'baseline': 107.0, 'r': 0.86, 'g': 0.61, 'b': 0.590, 'temp_offset': -100, 'tint_offset': 3},
    'fair': {'title': '2. Fair / Light (European / Neutral Light)', 'baseline': 108.0, 'r': 0.86, 'g': 0.59, 'b': 0.563, 'temp_offset': -50, 'tint_offset': 1},
    'east_asian': {'title': '3. East Asian / Golden Light (Warm Ivory)', 'baseline': 110.0, 'r': 0.84, 'g': 0.58, 'b': 0.544, 'temp_offset': 0, 'tint_offset': -2},
    'olive': {'title': '4. Olive / Sun-Kissed Tan (Mediterranean / Latino)', 'baseline': 111.5, 'r': 0.82, 'g': 0.55, 'b': 0.504, 'temp_offset': 50, 'tint_offset': -4},
    'brown_light': {'title': '5. Brown - Light (Wheatish / North Indian / Desi)', 'baseline': 109.5, 'r': 0.80, 'g': 0.55, 'b': 0.518, 'temp_offset': 50, 'tint_offset': 0},
    'brown_medium': {'title': '6. Brown - Medium (Warm Bronze / South Indian Lighter)', 'baseline': 108.5, 'r': 0.72, 'g': 0.49, 'b': 0.465, 'temp_offset': 100, 'tint_offset': 2},
    'brown_deep': {'title': '7. Brown - Deep (Dark Bronze / South Indian Deeper)', 'baseline': 107.5, 'r': 0.62, 'g': 0.42, 'b': 0.402, 'temp_offset': 120, 'tint_offset': 4},
    'deep_melanin': {'title': '8. Deep Melanin / Ebony (African / Rich Espresso)', 'baseline': 108.0, 'r': 0.56, 'g': 0.39, 'b': 0.373, 'temp_offset': 150, 'tint_offset': 3},
}

LIGHTING = {
    'flash_daylight': {'title': 'Direct Sun / Studio Flash (5500K)', 'offset': 0.0, 'base_temp': 5500, 'base_tint': 10},
    'overcast_shade': {'title': 'Open Shade / Tree Canopy (7200K)', 'offset': -1.5, 'base_temp': 7200, 'base_tint': 12},
    'golden_hour': {'title': 'Golden Hour / Sunset (6200K)', 'offset': 3.0, 'base_temp': 6200, 'base_tint': 8},
    'tungsten': {'title': 'Tungsten / Indoor Lamp (3200K)', 'offset': 2.0, 'base_temp': 3200, 'base_tint': 5},
}

def detect_lighting_setup(current_temp: float, flash_fired: bool = False):
    if flash_fired:
        return 'flash_daylight', 'Auto: Studio Flash (~5500K)'
    temp = current_temp or 5500
    if temp >= 6400:
        return 'overcast_shade', f'Auto: Open Shade / Tree Canopy (~{int(temp)}K)'
    elif temp >= 5850:
        return 'golden_hour', f'Auto: Golden Hour / Sunset (~{int(temp)}K)'
    elif temp >= 4600:
        return 'flash_daylight', f'Auto: Direct Sun / Daylight (~{int(temp)}K)'
    else:
        return 'tungsten', f'Auto: Tungsten / Warm Indoor (~{int(temp)}K)'

def test_skin_samples():
    print("==========================================================")
    print("    SkinScope Vectorscope Math Verification Test Bench    ")
    print("==========================================================")

    print("\n--- 1. Testing All 8 Plain-English Complexions ---")
    for key, c in COMPLEXIONS.items():
        Y, Cb, Cr = rgb_to_ycbcr(c['r'], c['g'], c['b'])
        ang = ycbcr_to_hue_angle(Cb, Cr)
        print(f"[{key:12s}] {c['title']:50s} -> Baseline: {c['baseline']:.1f}° | Measured Rec.709: {ang:.1f}°")
        # Baselines must all lie within the human skin tone corridor (104° - 114°)
        assert 104.0 <= ang <= 114.0, f"{key} out of human skin tone range: {ang}"

    print("\n--- 2. Testing Lighting Auto-Detection (Sun vs. Shade vs. Flash) ---")
    test_cases = [
        (5400, False, 'flash_daylight', 'Direct Sun on a clear day'),
        (7100, False, 'overcast_shade', 'Open Shade under blue sky / canopy'),
        (6100, False, 'golden_hour', 'Golden Hour sunset warmth'),
        (3100, False, 'tungsten', 'Warm incandescent indoor bulb'),
        (6800, True, 'flash_daylight', 'Speedlight fired (flash overrides shade)'),
    ]
    for temp, flash, expected_key, scenario in test_cases:
        det_key, desc = detect_lighting_setup(temp, flash)
        print(f"Scenario: {scenario:42s} (Temp={temp}K, Flash={flash}) => {det_key:15s} [{desc}]")
        assert det_key == expected_key, f"Failed for {scenario}: expected {expected_key}, got {det_key}"

    print("\n--- 3. Extreme Bad Edit Verification ---")
    tgt_temp = 5350
    tgt_tint = 16
    r, g, b = simulate_effective_rgb(39473, -137, 0, tgt_temp, tgt_tint)
    Y, Cb, Cr = rgb_to_ycbcr(r, g, b)
    ang = ycbcr_to_hue_angle(Cb, Cr)
    print(f"Deliberate Bad Edit (Temp=39473, Tint=-137) -> Angle: {ang:.1f}° (Delta: {ang - 108.5:+.1f}°)")
    assert ang > 150.0

    print("\n--- 4. Single-Click Exact Orange HSL Solver Verification ---")
    def solve_target_orange_hue(cur_temp, cur_tint, target_temp, target_tint, r0, g0, b0, target_angle):
        low, high = -100.0, 100.0
        for _ in range(25):
            mid = (low + high) * 0.5
            r, g, b = simulate_effective_rgb(cur_temp, cur_tint, mid, target_temp, target_tint, r0, g0, b0)
            Y, Cb, Cr = rgb_to_ycbcr(r, g, b)
            ang = ycbcr_to_hue_angle(Cb, Cr)
            if ang < target_angle:
                low = mid
            else:
                high = mid
        return int(round((low + high) * 0.5))

    for key, c in COMPLEXIONS.items():
        tgt_ang = c['baseline']
        # Solve exact hue in 1 click
        exact_hue = solve_target_orange_hue(5500, 10, 5500, 10, c['r'], c['g'], c['b'], tgt_ang)
        r_snap, g_snap, b_snap = simulate_effective_rgb(5500, 10, exact_hue, 5500, 10, c['r'], c['g'], c['b'])
        final_ang = ycbcr_to_hue_angle(*rgb_to_ycbcr(r_snap, g_snap, b_snap)[1:])
        rem_delta = abs(final_ang - tgt_ang)
        print(f"[{key:12s}] 1-Click Snap -> Target {tgt_ang:.1f}°, Solved Orange Hue={exact_hue:+d}, Residual Delta={rem_delta:.2f}°")
        assert rem_delta <= 0.3, f"Failed 1-click snap for {key}: remaining delta {rem_delta}"

    print("\n[SUCCESS] All 8 complexions, lighting auto-detection, and 1-click HSL snap passed!")

if __name__ == "__main__":
    test_skin_samples()

