# SkinScope for Lightroom Classic

> Get natural, consistent skin tones across your portrait sessions in seconds—without second-guessing by eye.

---

<p align="center">
  <img src="assets/skinscope-hud-v2.png" alt="SkinScope Floating HUD" width="380" />
  <br>
  <em>SkinScope HUD: Real-time skin tone meter, complexion presets, and instant 1-click correction.</em>
</p>

---

## The Problem

* **Eye fatigue:** After 30 minutes of editing, eyes adapt to screen tints, making color balance a guessing game.
* **Inconsistent light:** Changing clouds, flash power, or ambient bounce cause skin tones to drift between shots.
* **Batch copy-paste fails:** Applying static develop settings rarely produces consistent skin across a sequence.
* **Color vision challenges:** Any degree of red-green deficiency makes evaluating subtle skin undertones difficult.

---

## How It Works

SkinScope is a compact floating panel in Lightroom Classic that acts as a dedicated reference meter for skin tones:

1. **Auto-Reads Skin**: Samples skin pixels from the active photo in real time.
2. **Identifies Casts**: Shows immediately if skin tones lean toward magenta/pink or yellow/green.
3. **One-Click Correction**: Adjusts Orange HSL directly to neutral skin targets without altering overall white balance or background colors.
4. **Sequence Matching (Apply Next)**: Advances to the next photo and recalculates the correction to maintain a matching look.

---

## Key Features

* **Real-Time Skin Meter**: Vectorscope indicator showing color cast and luminance status.
* **One-Click Snap**: Aligns skin tone without shifting background or clothing colors.
* **8 Complexion Profiles**: Calibrated baselines ranging from pale/porcelain to deep melanin.
* **3 Exposure Targets**: Low, Mid, and High skin luminance targets.
* **Sequence Matching (Apply Next)**: Step through shoots photo-by-photo with consistent skin tones applied automatically.
* **Native Responsiveness**: Low-latency photo cycling with cached develop settings and debounced sampling.
* **Before / After Swatch**: Live split swatch comparing the unadjusted photo against the target.

---

## Download & Installation

### 1. Download the Plugin
* [Download Latest Release (SkinScope-v2.0.0.zip)](https://github.com/jasonpatel/Lightroom-SkinScope/releases/latest)
* Extract the `.zip` archive to obtain the **`SkinScope.lrplugin`** folder.  
  *(Recommended location: a permanent directory such as `Documents/Lightroom Plugins/`)*.

---

### 2. Add to Adobe Lightroom Classic
1. Open **Adobe Lightroom Classic**.
2. Go to: **File** → **Plug-in Manager...**
3. Click the **Add** button in the lower-left corner.
4. Select the **`SkinScope.lrplugin`** folder and click **Select Folder** (Windows) or **Add Plug-in** (macOS).
5. The status indicator next to **SkinScope** will show `Installed and running`. Click **Done**.

---

### How to Use

1. Switch to Lightroom's **Develop** module (`D`) and select a portrait.
2. Open the SkinScope floating HUD:
   * **Windows shortcut**: <kbd>Ctrl</kbd> + <kbd>Alt</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd>
   * **macOS shortcut**: <kbd>Cmd</kbd> + <kbd>Opt</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd>
   * *(Or via menu: **Help** → **Plug-in Extras** → **SkinScope**)*
3. Use the floating HUD controls:
   * **Complexion Profile**: Auto-detects skin tone or choose from 8 calibrated profiles. Lock the profile with the lock icon to prevent accidental changes.
   * **Orange HSL Snap**: Click the orange target button to align skin tones to the reference line.
   * **Exposure Snapping**: Click **Low**, **Mid**, or **High** to adjust skin luminance.
   * **Apply Next**: Lock in your preferred look and cycle through sequential shots.

---

## Repository Structure

* [**`SPECIFICATION.md`**](file:///U:/%5BObsidian%5D/Home/IT/GitHub%20Projects/Lightroom-SkinScope/SPECIFICATION.md): Mathematical foundations, color science, and solver algorithms.
* [**`WINDOWS_SETUP.md`**](file:///U:/%5BObsidian%5D/Home/IT/GitHub%20Projects/Lightroom-SkinScope/WINDOWS_SETUP.md): Windows installation and development guide.
* [**`SkinScope.lrdevplugin/`**](file:///U:/%5BObsidian%5D/Home/IT/GitHub%20Projects/Lightroom-SkinScope/SkinScope.lrdevplugin): Active Lightroom Classic plugin bundle.
* [**`tools/test_skin_math.py`**](file:///U:/%5BObsidian%5D/Home/IT/GitHub%20Projects/Lightroom-SkinScope/tools/test_skin_math.py): Test suite.

---

## Support the Project
If SkinScope is helpful to your workflow, you can support development via [Buy Me a Coffee](https://buymeacoffee.com/jasonpatel).

---

## Authors & Contributors
* **Jason Patel** ([@jasonpatel](https://github.com/jasonpatel)) — Creator & Lead Architect
* **Gemini (Google DeepMind)** — Co-developer & Color Science / SDK Engineering


