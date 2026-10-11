# SkinScope for Lightroom Classic

> A Lightroom Classic plugin by **Jason Patel** that brings vectorscope skin tone grading and fast filmstrip culling into a simple floating HUD.

---

<p align="center">
  <img src="assets/skinscope-hud-v2.png" alt="SkinScope Floating HUD" width="380" />
  <br>
  <em>SkinScope HUD: Vectorscope I-Line indicator, skin complexion presets, and Before/After split swatch.</em>
</p>

---

## 📸 Why I Built This

Judging skin tones by eye gets tiring fast. After an hour of editing, your eyes adapt to whatever tint is on the screen, and what looked right at 9 PM often looks greenish or overly magenta the next morning. If you have any color vision deficiency (like red-green weakness), it's even harder.

Video editors don't rely on their eyes for skin tones—they use the **Vectorscope I-Line** in DaVinci Resolve. 

SkinScope brings that same reference line into Lightroom Classic. It samples the skin in your photo, tells you if it's leaning too magenta or too yellow, and lets you snap it into place with one click. When working through a set, you can grade one photo and move to the next while keeping the same look automatically.

---

## 🚀 What It Does

* **Vectorscope Skin Line (I-Line)**: Shows exactly where skin tones land and flags magenta or yellow/green casts.
* **8 Complexion Profiles**: From porcelain to deep melanin, based on Alexis Van Hurkman's reference standards.
* **Quick Tone Snapping**: Click to align Orange HSL directly to the skin line without affecting the rest of the image.
* **3 Exposure Options**: Pick Low, Mid, or High luminance depending on the mood of the shot.
* **Apply & Next (`⚡ Apply Next ▶`)**: Locks in your target look and adjusts each photo in a sequence to match as you click through.
* **Fast Navigation**: Works directly with Lightroom's develop cache and debounced sampling so cycling photos doesn't stall.
* **Complexion Lock (`🔒`)**: Locks your selected profile so accidental mouse scrolls don't change it.
* **Before / After Swatch**: Live split swatch showing the original photo next to your current adjustment and target.

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

