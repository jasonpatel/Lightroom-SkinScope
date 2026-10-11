--[[
  SkinScope for Lightroom Classic
  SettingsDialog.lua — Preferences UI

  Stores settings in Lightroom's per-plugin prefs (LrPrefs),
  persisting user defaults across sessions.
]]

local LrBinding = import 'LrBinding'
local LrColor = import 'LrColor'
local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrPathUtils = import 'LrPathUtils'
local LrPrefs = import 'LrPrefs'
local LrTasks = import 'LrTasks'
local LrView = import 'LrView'

local pluginPrefs = LrPrefs.prefsForPlugin()

local COMPLEXIONS = {
    { title = "Auto-Detect Complexion", value = "auto_detect" },
    { title = "1. Very Fair / Pale (Porcelain / English Rose)", value = "pale" },
    { title = "2. Fair / Light (European / Neutral Light)", value = "fair" },
    { title = "3. East Asian / Golden Light (Warm Ivory)", value = "east_asian" },
    { title = "4. Olive / Sun-Kissed Tan (Mediterranean)", value = "olive" },
    { title = "5. Brown - Light (Wheatish / North Indian)", value = "brown_light" },
    { title = "6. Brown - Medium (Warm Bronze / South Indian)", value = "brown_medium" },
    { title = "7. Brown - Deep (Dark Bronze / South Indian)", value = "brown_deep" },
    { title = "8. Deep Melanin / Ebony (Rich Espresso)", value = "deep_melanin" },
}

local GENDERS = {
    { title = "Female (Target 55–75% Luma)", value = "female" },
    { title = "Male (Target 50–70% Luma)", value = "male" },
}

local THUMB_SIZES = {
    { title = "512 px (Fastest sampling - Recommended)", value = "512" },
    { title = "1024 px (Balanced)", value = "1024" },
    { title = "2048 px (High precision)", value = "2048" },
}

LrTasks.startAsyncTask(function()
    local success, err = LrTasks.pcall(function()
        LrFunctionContext.callWithContext('skinScopeSettingsDialog', function(context)
            local f = LrView.osFactory()
            local props = LrBinding.makePropertyTable(context)

            -- Load existing prefs or set defaults
            props.defaultComplexion = pluginPrefs.defaultComplexion or "auto_detect"
            props.defaultGender = pluginPrefs.defaultGender or "female"
            props.thumbnailSize = tostring(pluginPrefs.thumbnailSize or 1024)
            props.defaultLiveMode = (pluginPrefs.defaultLiveMode ~= nil) and pluginPrefs.defaultLiveMode or true

            local contents = f:column {
                bind_to_object = props,
                spacing = f:dialog_spacing(),

                f:static_text {
                    title = "SkinScope Preferences & Defaults",
                    font = "<system/bold>",
                },
                f:static_text {
                    title = "Configure default behaviors for the SkinScope HUD and batch alignment.",
                    font = "<system/small>",
                    text_color = LrColor(0.4, 0.4, 0.4),
                },
                f:separator { fill_horizontal = 1 },

                f:row {
                    f:static_text {
                        title = "Default Complexion:",
                        alignment = "right",
                        width = LrView.share 'pref_lbl',
                    },
                    f:popup_menu {
                        items = COMPLEXIONS,
                        value = LrView.bind('defaultComplexion'),
                        fill_horizontal = 1,
                    },
                },

                f:row {
                    f:static_text {
                        title = "Default Gender Target:",
                        alignment = "right",
                        width = LrView.share 'pref_lbl',
                    },
                    f:popup_menu {
                        items = GENDERS,
                        value = LrView.bind('defaultGender'),
                        fill_horizontal = 1,
                    },
                },

                f:row {
                    f:static_text {
                        title = "Preview Sampling Size:",
                        alignment = "right",
                        width = LrView.share 'pref_lbl',
                    },
                    f:popup_menu {
                        items = THUMB_SIZES,
                        value = LrView.bind('thumbnailSize'),
                        fill_horizontal = 1,
                    },
                },

                f:row {
                    f:static_text {
                        title = "Live Push on Launch:",
                        alignment = "right",
                        width = LrView.share 'pref_lbl',
                    },
                    f:checkbox {
                        title = "Automatically adjust Develop sliders when changing profiles",
                        value = LrView.bind('defaultLiveMode'),
                    },
                },

                f:separator { fill_horizontal = 1 },
                f:static_text {
                    title = "Preferences persist across Lightroom sessions in your catalog preferences.",
                    font = "<system/small>",
                    text_color = LrColor(0.5, 0.5, 0.5),
                },
            }

            local result = LrDialogs.presentModalDialog({
                title = "SkinScope Settings",
                contents = contents,
                actionVerb = "Save",
                cancelVerb = "Cancel",
            })

            if result == 'ok' then
                pluginPrefs.defaultComplexion = props.defaultComplexion
                pluginPrefs.defaultGender = props.defaultGender
                pluginPrefs.thumbnailSize = tonumber(props.thumbnailSize) or 1024
                pluginPrefs.defaultLiveMode = props.defaultLiveMode
                LrDialogs.showBezel("SkinScope Settings Saved")
            end
        end)
    end)

    if not success then
        local errStr = tostring(err)
        pcall(function()
            local logDir = LrPathUtils.getStandardFilePath('appData') or _PLUGIN.path
            local logPath = LrPathUtils.child(logDir, 'skinscope_error.log')
            local f = io.open(logPath, "w")
            if f then
                f:write("SettingsDialog Error:\n" .. errStr)
                f:close()
            end
        end)
        LrDialogs.showError("SkinScope Settings Error:\n" .. errStr)
    end
end)
