# SkinScope for Lightroom Classic

> Get natural, consistent skin tones across your portrait sessions in seconds—without second-guessing by eye.

---

<p align="center">
  <img src="assets/skinscope-hud-v2.png" alt="SkinScope Floating HUD" width="380" />
  <br>
  <em>SkinScope HUD: Real-time skin tone meter, complexion presets, and instant 1-click correction.</em>
</p>

---

## 📸 The Problem

* **Eye fatigue:** After 30 minutes of editing, your eyes adapt to screen tints, making color balance a guessing game.
* **Inconsistent light:** Changing clouds, flash power, or bounce light make skin tones shift from shot to shot.
* **Copy-paste fails:** Pasting develop settings rarely produces consistent skin across a sequence.
* **Color vision:** Any degree of red-green deficiency makes judging subtle skin undertones stressful.

---

## 💡 How It Works

SkinScope is a compact floating panel in Lightroom Classic that acts as a **dedicated color meter for skin**:

1. **Auto-Reads Skin**: Samples skin pixels from your active photo in real time.
2. **Shows Casts Instantly**: Flags immediately if skin is leaning too pink/magenta or too yellow/green.
3. **1-Click Correction**: Snaps Orange HSL to neutral skin targets without changing white balance or background colors.
4. **Cull & Match (`⚡ Apply Next ▶`)**: Advances to the next shot and automatically recalculates the exact fix to match.

---

## 🚀 Key Features

* **Real-Time Skin Meter**: Visual vectorscope readout showing color cast and luminance.
* **1-Click Snap**: Aligns skin tone without affecting background or clothing.
* **8 Skin Profiles**: Baselines from pale/porcelain to deep melanin.
* **3 Exposure Targets**: 1-click Low, Mid, or Bright skin luminance.
* **Sequence Matching (`Apply Next`)**: Move shot-by-shot with consistent skin applied automatically.
* **Native Speed**: Zero lag when cycling photos; memory-cached analysis.
* **Before / After Swatch**: Live split swatch comparing your photo to the target.

---

## 📥 Download & Installation

### 1. Download the Plugin
* 👉 [**Download Latest Release (SkinScope-v2.0.0.zip)**](https://github.com/jasonpatel/Lightroom-SkinScope/releases/latest)
* Extract the `.zip` archive on your computer. You will find a folder named **`SkinScope.lrplugin`**.  
  *(Recommended: Keep this folder in a permanent location like `Documents/Lightroom Plugins/`)*.

---

### 2. Add to Adobe Lightroom Classic
1. Open **Adobe Lightroom Classic**.
2. Go to the top menu bar: **File** → **Plug-in Manager...**
3. In the bottom-left corner of the dialog, click the **Add** button.
4. Browse to the folder where you extracted the plugin, select the **`SkinScope.lrplugin`** folder, and click **Select Folder** (Windows) or **Add Plug-in** (Mac).
5. The status indicator next to **SkinScope** will show a green circle (`Installed and running`). Click **Done**.

---

### 🎯 How to Use

1. Switch to Lightroom's **Develop** module (press `D`) and select any portrait.
2. Open the SkinScope floating HUD:
   * **Windows shortcut**: <kbd>Ctrl</kbd> + <kbd>Alt</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd>
   * **Mac shortcut**: <kbd>Cmd</kbd> + <kbd>Opt</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd>
   * *(Or via menu: **Help** → **Plug-in Extras** → **SkinScope**)*
3. The real-time 344px floating HUD opens alongside your photo:
   * **Complexion Profile**: Auto-Detect reads the skin tone, or select from 8 Van Hurkman calibrated profiles.
   * **Live Auto-Sync**: Check `Live Auto-Sync` to automatically sync Develop sliders in real time as you browse profiles.
   * **1-Click Orange HSL Snap**: Click the prominent **`Orange HSL: [Δ] (Align)`** button to immediately align skin tones to the Rec.709 Vectorscope I-Line.
   * **Exposure Snapping**: Click **Low**, **Mid**, or **High** to snap exposure to exact Van Hurkman luminance targets.

---

## 📁 Repository Structure

* [**`SPECIFICATION.md`**](file:///U:/%5BObsidian%5D/Home/IT/GitHub%20Projects/Lightroom-SkinScope/SPECIFICATION.md): Complete mathematical foundations, color science, solver algorithms, and decision log.
* [**`WINDOWS_SETUP.md`**](file:///U:/%5BObsidian%5D/Home/IT/GitHub%20Projects/Lightroom-SkinScope/WINDOWS_SETUP.md): Windows installation and development setup guide.
* [**`SkinScope.lrdevplugin/`**](file:///U:/%5BObsidian%5D/Home/IT/GitHub%20Projects/Lightroom-SkinScope/SkinScope.lrdevplugin): The active Lightroom Classic plugin bundle:
  * `SkinMath.lua`: ITU-R BT.709 color science, complexion matrix, binary search solvers, BMP generator.
  * `SkinScopeDialog.lua`: Floating HUD UI, live sync engine, event loop, property bindings.
  * `SkinScopePlugin.lua`: Lightroom Classic plugin entry point.
  * `sample_photo.py`: RAW preview skin pixel extractor.
  * `comparison.html`: Visual Split Viewer.
  * `Info.lua`: Plugin manifest.
* [**`tools/test_skin_math.py`**](file:///U:/%5BObsidian%5D/Home/IT/GitHub%20Projects/Lightroom-SkinScope/tools/test_skin_math.py): Mathematical test suite.

---

## ☕ Support the Project
If SkinScope helps your photography workflow, you can support development via [Buy Me a Coffee](https://buymeacoffee.com/jasonpatel).

---

## 👥 Authors & Contributors
* **Jason Patel** ([@jasonpatel](https://github.com/jasonpatel)) — Creator & Lead Architect
* **Gemini (Google DeepMind)** — Co-developer & Color Science / SDK Engineering

