# SkinScope for Lightroom Classic — Architecture, Color Science & Design Specification

> **SkinScope** by Jason Patel  
> An objective, vectorscope-driven skin tone calibration instrument for Adobe Lightroom Classic.  
> Built for portrait photographers and color vision deficient (CVD) retouchers seeking mathematical certainty in skin color grading.

---

## 1. Project Mission & Philosophical Foundation

Judging skin tone purity by eye is inherently subjective and easily compromised by:
1. **Color Vision Deficiencies (CVD)**: Protanopia, deuteranopia, and tritanopia distort perceptions of subtle red-versus-green and amber-versus-magenta undertones.
2. **Visual Metamerism & Eye Fatigue**: Retinal chromatic adaptation quickly normalizes severe color casts during extended retouching sessions.
3. **Ambient Light Inconsistencies**: Uncalibrated room lighting shifts screen perception.

In high-end film and television post-production (e.g., DaVinci Resolve), colorists never grade skin tones solely by eye; they rely on the **Vectorscope I-Line (Skin Tone Indicator)**. 

SkinScope brings this cinema-standard calibration methodology into Adobe Lightroom Classic as a real-time, 344px floating HUD with single-click mathematical auto-snapping.

---

## 2. Color Science & Mathematical Foundations

### A. Coordinate Space: ITU-R BT.709 $Y C_b C_r$
SkinScope transforms linear sRGB $[0.0, 1.0]$ into Rec.709 chrominance and luminance:

$$
\begin{aligned}
Y   &= 0.2126 R + 0.7152 G + 0.0722 B \\
C_b &= 0.5389 (B - Y) \\
C_r &= 0.6350 (R - Y)
\end{aligned}
$$

### B. Vectorscope Hue Angle ($	heta$)
Hue angle measures the rotational angle on the vectorscope chrominance wheel ($C_b$ on horizontal axis, $C_r$ on vertical axis):

$$\theta = \left(\text{atan2}(C_r, C_b) \times \frac{180^\circ}{\pi} + 360^\circ\right) \pmod{360^\circ}$$

* **$\theta \approx 124.5^\circ$**: The calibrated universal Fair European Human Skin Line (Neutral Peach).
* **$\theta < 122^\circ$**: Drift toward Red / Magenta (sunburn, flush, excessive tint).
* **$\theta > 126^\circ$**: Drift toward Yellow / Green (sallow, jaundiced, fluorescent/tree-canopy cast).

### C. Luma-Normalized Saturation Formula (Exposure Invariance)
Because luminance $Y$ also scales uniformly by $2^{\Delta\text{EV}}$, the ratio $\frac{\text{Chroma}}{Y}$ is completely exposure-invariant:

$$\frac{\text{Chroma} \cdot 2^{\Delta\text{EV}}}{Y \cdot 2^{\Delta\text{EV}}} = \frac{\text{Chroma}}{Y} = \text{Constant}$$

SkinScope implements calibrated luma-normalized saturation:

$$\text{Sat}_{\%} = \left\lfloor \left( \frac{\text{Chroma}}{\max(0.01, Y)} \right) \times \frac{\text{Base}_Y}{0.5} \times 100 + 0.5 \right\rfloor$$

### D. Dead-Band Orange Saturation Controller
Alexis Van Hurkman’s $28\%$ saturation target was formulated for flat video LOG feeds. Modern still raw files in Lightroom (under Adobe Color) are already richly saturated. Forcing saturation to $28\%$ pushed Orange Saturation to $+15$, causing unnatural spray-tan artifacts.

SkinScope implements a photographic dead-band:
* If natural skin saturation is within **$19\% - 28\%$**, Orange Saturation is locked at **`0`** (natural).
* Desaturated/lifeless skin ($<19\%$) is gently lifted by $+1$ to $+3$ max.
* Oversaturated skin ($>28\%$) is gently pulled back by $-1$ to $-5$ max.

---

## 3. Calibration Standards Matrix

### A. The 8 Plain-English Biological Complexions
Anchored to Rec.709 empirical ground truth:

| Profile Key | Baseline ($	heta_0$) | Nominal Rec.709 RGB | Female Luma | Male Luma | Target Sat | Typical Undertones |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **`pale`** | $119.5^\circ$ | $(0.92, 0.78, 0.73)$ | $60–82\%$ | $55–77\%$ | $24\%$ | Porcelain, English Rose, Ginger |
| **`fair`** | $124.5^\circ$ | $(0.86, 0.67, 0.58)$ | $55–75\%$ | $50–70\%$ | $25\%$ | European Neutral Peach |
| **`east_asian`** | $131.0^\circ$ | $(0.86, 0.70, 0.56)$ | $55–75\%$ | $50–70\%$ | $25\%$ | Golden Light, Warm Ivory |
| **`olive`** | $131.5^\circ$ | $(0.82, 0.64, 0.50)$ | $45–68\%$ | $40–63\%$ | $26\%$ | Sun-Kissed Tan, Mediterranean, Latino |
| **`brown_light`**| $129.5^\circ$ | $(0.75, 0.56, 0.43)$ | $40–62\%$ | $35–57\%$ | $25\%$ | Wheatish, Desi / North Indian |
| **`brown_medium`**| $127.5^\circ$| $(0.64, 0.46, 0.34)$ | $30–52\%$ | $25–47\%$ | $24\%$ | Warm Bronze, South Indian |
| **`brown_deep`** | $125.5^\circ$ | $(0.50, 0.34, 0.24)$ | $22–44\%$ | $18–39\%$ | $23\%$ | Dark Bronze |
| **`deep_melanin`**| $123.0^\circ$| $(0.38, 0.25, 0.18)$ | $16–36\%$ | $14–32\%$ | $22\%$ | Rich Espresso, Ebony |

### B. Separation of Global White Balance vs. Skin Tone
* **Scene White Balance (`Temp` and `Tint`)**: Belongs entirely to Lightroom Classic (via the eyedropper or strobe Kelvin).
* **Skin Calibration (`Orange HSL`)**: Belongs to SkinScope. Modifying Orange HSL isolates skin without altering white clothing, walls, or background.

### C. Sun Tan Modifiers
* **`winter` (Natural / Untanned Base)**: $\Delta\theta = 0.0^\circ$
* **`sun_kissed`**: $\Delta\theta = +2.0^\circ$
* **`deep_tan` (Bronze)**: $\Delta\theta = +4.0^\circ$

### D. Aesthetic Look (Mood) Offsets
* **`neutral` (Commercial Clean)**: $\Delta\theta = 0.0^\circ$
* **`filmic` (Soft Filmic Rose)**: $\Delta\theta = -2.0^\circ$
* **`fashion` (Fashion Contrast)**: $\Delta\theta = 0.0^\circ$
* **`golden` (Warm Golden Finish)**: $\Delta\theta = +2.5^\circ$

$$\theta_{\text{target}} = \theta_0 + \Delta\theta_{\text{tan}} + \Delta\theta_{\text{mood}}$$

---

## 4. Algorithmic Solvers (Binary Search Engine)

### 1. Orange HSL Hue Solver (`solve_target_orange_hue`)
Solves for the exact Lightroom `HueAdjustmentOrange` slider value that aligns vectorscope angle with $\theta_{\text{target}}$:
* Search space: $[-25, +25]$.
* **Strict Photographic Safety Clamp**: $[-20, +20]$ to prevent unnatural skin distortion.

### 2. Orange HSL Saturation Solver (`solve_target_orange_sat`)
Applies the photographic dead-band controller ($19\% - 28\%$) to keep skin natural and eliminate spray-tan artifacts.

### 3. 3-Way Exposure Calculator (`calc_ev_target`)
Calculates photographic EV adjustments using logarithmic scaling:

$$\Delta\text{EV} = \log_2\left(\frac{\text{Luma}_{\text{target}}}{\max(1, \text{Luma}_{\text{current}})}\right)$$

* **Low**: Low-Key Luma Target
* **Mid**: Commercial Balanced Luma Target ($70\% - 73\%$)
* **High**: High-Key / Bright & Airy Luma Target

---

## 5. Subsystem Architecture & Implementation

### A. Live Auto-Sync Engine
* Default enabled (`live_mode = true`).
* Strictly adjusts `HueAdjustmentOrange` and `SaturationAdjustmentOrange`. `Exposure2012` is isolated to prevent unintended exposure changes.
* Re-evaluates in $<0.2\text{ms}$ during background polling loop.

### B. Seamless Split Swatch Generator
* Generates a 24-bit uncompressed $344 \times 36$ BMP dynamically (`write_split_swatch`).
* Zero black separator line.
* Left: live simulated skin. Right: target goal post.

---

## 6. File Map & Verification Protocol

* `SkinScopeDialog.lua`: Floating HUD UI (344px), property bindings, live sync loop.
* `SkinMath.lua`: ITU-R BT.709 color science, complexion matrix, binary search solvers.
* `SkinScopePlugin.lua`: Main entry point and initial photo loader.
* `sample_photo.py`: Raw preview pixel extractor.
* `Info.lua`: Lightroom Classic plugin manifest.
* `SPECIFICATION.md`: This design specification.

**Verification Standard**:  
All code modifications in `C:\Users\me\AppData\Roaming\Adobe\Lightroom\Modules\SkinScope.lrdevplugin\` are mirrored to `U:\[Obsidian]\Home\IT\GitHub Projects\Lightroom-SkinScope\SkinScope.lrdevplugin\` with **100% matching SHA256 checksums**.
