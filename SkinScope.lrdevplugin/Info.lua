return {
    LrSdkVersion = 11.0,
    LrSdkMinimumVersion = 8.0,

    LrToolkitIdentifier = 'com.jason.skinscope',
    LrPluginName = 'SkinScope (Vectorscope Skin Tone Assistant)',
    LrPluginInfoUrl = 'https://github.com/jasonpatel/Lightroom-SkinScope',

    LrExportMenuItems = {
        {
            title = "SkinScope: Vectorscope Skin Tone Assistant...",
            file = "SkinScopePlugin.lua",
        },
        {
            title = "SkinScope: Batch Align Selected to I-Line...",
            file = "SkinScopeBatch.lua",
        },
        {
            title = "SkinScope: Settings & Defaults...",
            file = "SettingsDialog.lua",
        },
    },

    LrLibraryMenuItems = {
        {
            title = "SkinScope: Vectorscope Skin Tone Assistant...",
            file = "SkinScopePlugin.lua",
        },
        {
            title = "SkinScope: Batch Align Selected to I-Line...",
            file = "SkinScopeBatch.lua",
        },
        {
            title = "SkinScope: Settings & Defaults...",
            file = "SettingsDialog.lua",
        },
    },

    VERSION = { major = 2, minor = 0, revision = 0, build = 1 },
}
