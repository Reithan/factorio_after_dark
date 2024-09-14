data:extend({

    -- Map settings
    -- ============

    {
        type = "int-setting",
        name = "fad-lamp-search-radius",
        setting_type = "runtime-global",
        order = "aa",
        default_value = 30,
        minimum_value = 10,
        maximum_value = 100
    },

    {
        type = "bool-setting",
        name = "fad-display-misses",
        order = "ab",
        setting_type = "runtime-per-user",
        default_value = true
    }
})