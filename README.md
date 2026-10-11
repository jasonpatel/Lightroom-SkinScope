# SkinScope for Lightroom Classic

> Get natural, consistent skin tones across your portrait sessions in seconds—without second-guessing by eye.

---

<p align="center">
  <img src="assets/skinscope-hud-v2.png" alt="SkinScope Floating HUD" width="380" />
  <br>
  <em>SkinScope HUD: Real-time skin tone meter, complexion presets, and instant 1-click correction.</em>
</p>

---

## 📸 The Problem Every Portrait Photographer Faces

Getting skin tones right across an entire shoot is one of the most frustrating parts of editing:
- **Eye fatigue lies to you:** After staring at a screen for an hour, your eyes adjust to whatever color cast is in front of you. What looked warm and flattering at midnight often looks sickly yellow or bright magenta the next morning.
- **Inconsistent lighting:** Even in the same location, slight changes in bounce light, flash power, or cloudy skies cause skin tones to shift from one shot to the next.
- **Copying and pasting develop settings rarely works:** A slider adjustment that looked great on one photo often makes the next one look sunburned or washed out.
- **Color vision challenges:** If you have even subtle red-green color deficiency, judging skin undertones by eye is stressful guesswork.

---

## 💡 How SkinScope Helps

SkinScope is a small floating panel that sits alongside your Lightroom develop module. Instead of guessing, it acts as an **objective color meter for skin**:

1. **It reads the skin in your photo:** SkinScope automatically samples skin pixels from your active photo.
2. **It shows you if the color is off:** A simple meter tells you immediately whether the skin is leaning too magenta (red/pink) or too green/yellow, and whether it's too dark or bright.
3. **Fix it in 1 click:** Click the orange snap button, and SkinScope adjusts only the skin sliders (Orange Hue & Saturation) to bring it directly onto a natural baseline—without changing the background, clothing, or overall white balance.
4. **Move through your shoot fast (`⚡ Apply Next ▶`):** As you click through your photos, SkinScope automatically recalculates and applies the right adjustment for each individual photo so the entire sequence matches.

---

## 🚀 Key Features at a Glance

* **Visual Skin Meter**: Instantly see if your skin tones are neutral, too pink, or too yellow.
* **1-Click Tone Correction**: Fixes skin color instantly without touching white balance or background colors.
* **8 Skin Profiles**: Tailored baselines for fair, olive, East Asian, and deep melanin skin tones.
* **3 Skin Brightness Targets**: Snap skin exposure to Low, Mid, or Bright with one click.
* **Batch Consistency (`Apply Next`)**: Move through a sequence photo-by-photo with the same look applied to each one automatically.
* **Fast & Responsive**: Built to flip between photos instantly without slowing down your editing workflow.
* **Before / After Color Swatch**: See your original photo's skin tone right next to your edited result.

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

