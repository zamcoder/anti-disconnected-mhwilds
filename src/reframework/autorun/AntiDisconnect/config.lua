-- Persistent settings for Anti Disconnect, stored in reframework/data/AntiDisconnect/config.json.

local files = require("AntiDisconnect.files")

local config = {}

local PATH = "AntiDisconnect/config.json"
local VERSION = 1
local LANGUAGES = { en = true, id = true }

local DEFAULTS = {
    version = VERSION,
    language = "en",              -- "en" or "id" (lang.LANGUAGES)
    afk_guard = true,             -- hold the game's idle timer below its 30-minute kick
    afk_public_quests = false,    -- ...also in quests with players outside your Link Party
    afk_welcome = true,           -- a message when you come back after the guard kept you online
    steady_link = false,          -- experiment: the engine's highest health check rate in quests and the Link Party
    steam_grace = true,           -- wait up to 30 s for Steam to come back before the game goes offline (tested in game)
    toast_seconds = 12,           -- how long such a message stays
}

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = copy(v) end
    return result
end

local function integer_in(value, low, high)
    local n = type(value) == "number" and math.tointeger(value)
    return n and n >= low and n <= high and n or nil
end

-- Values of the wrong type or range are replaced by defaults, so a hand-edited file cannot
-- break the mod. Unknown keys are dropped.
function config.validate(loaded)
    local result = copy(DEFAULTS)
    if type(loaded) ~= "table" then return result end
    if LANGUAGES[loaded.language] then result.language = loaded.language end
    for _, key in ipairs({ "afk_guard", "afk_public_quests", "afk_welcome", "steady_link", "steam_grace" }) do
        if type(loaded[key]) == "boolean" then result[key] = loaded[key] end
    end
    result.toast_seconds = integer_in(loaded.toast_seconds, 3, 60) or DEFAULTS.toast_seconds
    return result
end

-- A missing or corrupt file gives the defaults.
function config.load()
    local status, loaded = files.read_json(PATH)
    if status ~= "ok" then return config.validate(nil) end
    return config.validate(loaded)
end

function config.save(values)
    local out = copy(values)
    out.version = VERSION
    return files.write_json(PATH, out)
end

config.DEFAULTS = DEFAULTS
config.PATH = PATH

return config
