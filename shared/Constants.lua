--[[
    Constants.lua
    Shared constants for Priz's Islands Hub
]]--

return {
    MAX_SELECTIONS = 100,
    MAX_HISTORY = 50,
    MAX_VENDING_BALANCE = 5000000000,
    VENDING_LIMIT = 5000000000,
    DEFAULT_HOTKEYS = {
        withdrawAll = Enum.KeyCode.F1,
        depositAll = Enum.KeyCode.F2,
        selectRandom = Enum.KeyCode.F3,
        scanVendings = Enum.KeyCode.F4,
        emptyAll = Enum.KeyCode.F5
    },
    DEFAULT_SETTINGS = {
        theme = "Amethyst",
        radius = 100,
        useRadius = false,
        processMode = true
    },
    NOTIFICATION_DURATION = {
        SHORT = 2,
        NORMAL = 3,
        LONG = 4,
        EXTRA_LONG = 5
    }
}
