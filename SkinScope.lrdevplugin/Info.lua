return {
    LrSdkVersion = 11.0,
    LrSdkMinimumVersion = 8.0,

    LrToolkitIdentifier = 'com.jason.skinscope',
    LrPluginName = 'SkinScope (Vectorscope Skin Tone Assistant)',
    LrPluginInfoUrl = 'https://github.com/jasonpatel/Lightroom-SkinScope',

    LrPluginExtrasMenuItems = {
        {
            title = "SkinScope: Vectorscope Skin Tone Assistant...",
            file = "SkinScopePlugin.lua",
        },
        {
            title = "SkinScope: Batch Align Selected to I-Line...",
            file = "SkinScopeBatch.lua",
        },
    },

    LrExportMenuItems = {
        {
            title = "SkinScope: Vectorscope Skin Tone Assistant...",
            file = "SkinScopePlugin.lua",
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
    },

    VERSION = { major = 1, minor = 1, revision = 0, build = 1 },
}
