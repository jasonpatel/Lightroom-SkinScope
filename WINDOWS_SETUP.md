# Installing SkinScope in Lightroom Classic (Windows)

## 1. Plugin Location
The plugin folder is:
```text
SkinScope.lrdevplugin/
  ├── Info.lua
  ├── SkinScopePlugin.lua
  ├── SkinMath.lua
  └── SkinScopeDialog.lua
```

---

## 2. Step-by-Step Installation on Windows

1. **Copy or Sync the Plugin Folder:**
   * Copy the folder `SkinScope.lrdevplugin` to your Windows machine (e.g. `C:\Users\<YourUser>\AppData\Roaming\Adobe\Lightroom\Modules\SkinScope.lrdevplugin` or any project folder on your drive).

2. **Open Lightroom Classic:**
   * In the top menu bar, click **File** $\rightarrow$ **Plug-in Manager** (or press `Ctrl + Alt + Shift + ,`).

3. **Add the Plugin:**
   * Click the **Add** button in the bottom-left corner of the Plug-in Manager window.
   * Navigate to the folder containing `SkinScope.lrdevplugin` and click **Select Folder**.
   * You will see **SkinScope (Vectorscope Skin Tone Assistant)** appear with a green "Installed and Running" status dot.
   * Click **Done**.

4. **Using SkinScope:**
   * Select a portrait photo in the **Develop** module.
   * Go to **File** $\rightarrow$ **Plug-in Extras** $\rightarrow$ **SkinScope: Check Active Photo** (or use the menu command).
   * Select the subject's **Complexion**, **Lighting**, and **Target Mood**.
   * Observe the objective angle readout and click **Auto-Snap** to let the plugin adjust Temp/Tint or HSL Orange.
