-- Every text Anti Disconnect shows, by key. English is built in; other languages are Lua
-- modules in AntiDisconnect/lang/ that return { key = text }. T(key, ...) formats the text
-- with string.format; an unknown key is shown as the key itself rather than failing.
--
-- A translated text is only used when it takes the same values in the same order as the
-- English one (the same %d / %s / %.1f / %% in order); otherwise the English text is shown,
-- so a broken translation can never break a message. (The same machinery as in Bulk Sell.)

local lang = {}

local EN = {
    title = "Anti Disconnect",
    version = "Version %s",
    language = "Language / Bahasa",

    -- AFK guard
    afk_guard = "Stop the AFK kick (the game moves you to Online Single Player after 30 minutes without input)",
    afk_public_quests = "Also during quests with players outside my Link Party",
    afk_welcome = "Tell me when I come back after the AFK guard kept me online",
    afk_help = "Only the kick is stopped: after 3 minutes without input other players still see you as Idle, "
        .. "like in the normal game.",
    status_off = "AFK guard: off.",
    status_starting = "AFK guard: waiting for the game...",
    status_unavailable = "AFK guard: not available on this game version (the game's idle timer was not found).",
    status_not_needed = "AFK guard: nothing to do right now (you are not online with other players).",
    status_lobby = "AFK guard: protecting you in the lobby.",
    status_link = "AFK guard: protecting you in your Link Party.",
    status_quest = "AFK guard: protecting you in this quest (only you and your Link Party).",
    status_quest_all = "AFK guard: protecting you in this quest.",
    status_strangers = "AFK guard: not protecting you in this quest, because it has players outside your Link Party. "
        .. "The game's 30-minute kick applies here.",
    status_unknown = "AFK guard: not protecting you in this quest (its members could not be read).",
    idle_line = "No input for %s · Idle status after %s · kick after %s",
    idle_held = "No input for %s · the game's timer is held at %s, below the kick",
    limits_assumed = "(The game's limits could not be read; 3:00 and 30:00 are assumed.)",

    -- Steady link (experiment)
    steady_link = "Experiment: send \"I'm still here\" signals more often in quests and the Link Party",
    steady_help = "For unstable connections such as mobile data: the other players hear from you more often, so a short "
        .. "pause is less likely to drop you. Uses a little more data. Turn it off if anything feels wrong.",
    link_line = "%s: %s · direct connections %d of %d · \"still here\" signals: %s",
    context_line = "Platform connection: %s · DisconnectionDetectionTime %s (changed %d times)",
    health_0 = "normal",
    health_1 = "more often",
    health_nil = "unknown",
    report_button = "Copy report",
    report_done = "Report copied. Paste it in a report on GitHub (github.com/zamcoder/anti-disconnected-mhwilds/issues) "
        .. "or in the Bugs tab of the mod's Nexus page. It is also saved in reframework/data/AntiDisconnect/report.txt "
        .. "and holds no names or IDs.",

    -- Disconnect log
    log_title = "Disconnect log",
    log_empty = "Nothing recorded yet.",
    log_more = "... %d older entries in the file",
    log_clear = "Clear log",
    log_file = "Full log: reframework/data/AntiDisconnect/events.json",
    log_hooks_missing = "Not watched on this game version: %s",
    log_repeat = " (x%d)",
    ev_start = "Anti Disconnect %s started",
    ev_session = "%s: %s -> %s",
    session_lobby = "Lobby",
    session_quest = "Quest session",
    session_link = "Link Party",
    session_memories = "Memories session",
    session_local = "Local session",
    ev_session_event = "%s: engine notice %s",
    ev_about_you = " (about you)",
    ev_about_host = " (about the host)",
    ev_leave_call = "%s: your game leaves this session",
    ev_party_leave = "Link Party: your game leaves the party (%s)",
    ev_lobby_leave = "Lobby connection ended: %s",
    ev_lobby_leave_clean = "Lobby connection ended (no error reported)",
    ev_health_failed = "%s: the faster \"still here\" signals did not stay (the game set them back)",
    ev_lobby_connect = "Lobby connection failed: %s",
    ev_p2p = "%s: %s, direct connections %d of %d",
    ev_health = "%s: \"still here\" signals %s -> %s",
    state_off = "not connected",
    state_solo = "online, alone",
    state_multi = "online with others",
    ev_context = "Network: %s -> %s",
    ev_local_on = "Local network mode on",
    ev_local_off = "Local network mode off",
    ev_login = "Your online status: %s -> %s",
    ev_app_error = "Game error %s (%d), area %s",
    ev_app_error_raw = "Server error %d, area %s",
    ev_app_error_engine = "Game error from the network layer (%s), area %s",
    ev_engine_error = "Network error: %s",
    ev_lobby_closed = "Lobby connection closed",
    ev_lobby_error = "Lobby connection error (code %d)",
    ev_afk_saved = "AFK guard kept you online (%d minutes without input)",
    ev_unknown = "Unknown entry",

    -- Messages while the REFramework menu is closed
    toast_title = "Anti Disconnect",
    toast_welcome = "Welcome back! You had no input for %d minutes. Anti Disconnect kept you online "
        .. "(the game kicks after %d).",
    toast_test_button = "Show a test message",
    toast_test = "This is how Anti Disconnect tells you something while you play.",
    toast_test_hint = "Close the REFramework menu (Insert) to see it.",

    error = "Error: %s",
    ui_error = "UI error: %s",
}

lang.EN = EN

-- The languages of the Language combo, each named in its own language.
lang.LANGUAGES = { { code = "en", name = "English" }, { code = "id", name = "Bahasa Indonesia" } }
local MODULES = { id = "AntiDisconnect.lang.id" }

local active = {}     -- checked texts of the chosen language; empty for English
local code = "en"
local revision = 0    -- goes up on every change, so cached texts can be made again
lang.rejected = {}    -- keys of the chosen language that were not used (unknown key or other values)

-- "%d ... %s ... %%" -> "%d %s %%": the values a text takes, in order.
local function placeholders(text)
    local list = {}
    for spec in text:gmatch("%%[-#0 +]*%d*%.?%d*[%a%%]") do list[#list + 1] = spec end
    return table.concat(list, " ")
end
lang._placeholders = placeholders

-- Uses `texts` ({ key = text }) for language `name`; "en" or no table means English.
function lang.use(name, texts)
    active, code, revision = {}, "en", revision + 1
    lang.rejected = {}
    if name == "en" or type(texts) ~= "table" then return end
    for key, text in pairs(texts) do
        if type(text) == "string" and EN[key] and placeholders(text) == placeholders(EN[key]) then
            active[key] = text
        else
            lang.rejected[#lang.rejected + 1] = tostring(key)
        end
    end
    table.sort(lang.rejected)
    code = name
end

-- Switches to a language of lang.LANGUAGES. Returns the code in use and, when the
-- translation could not be loaded, the error.
function lang.set(name)
    local module = MODULES[name]
    if not module then
        lang.use("en")
        return "en"
    end
    local ok, texts = pcall(require, module)
    if not ok or type(texts) ~= "table" then
        lang.use("en")
        return "en", tostring(texts)
    end
    lang.use(name, texts)
    return name
end

function lang.code() return code end
function lang.revision() return revision end

function lang.T(key, ...)
    local text = active[key] or EN[key]
    if not text then return key end
    if select("#", ...) == 0 then return text end
    local ok, result = pcall(string.format, text, ...)
    return ok and result or text
end

-- The English text, for the REFramework log (which is read when people report bugs).
function lang.english(key, ...)
    local text = EN[key]
    if not text then return key end
    if select("#", ...) == 0 then return text end
    local ok, result = pcall(string.format, text, ...)
    return ok and result or text
end

return lang
