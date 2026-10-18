-- Anti Disconnect for Monster Hunter Wilds (REFramework script).
--
-- 1. AFK guard: after 30 minutes without input the game moves you to Online Single Player,
--    which also takes you out of your lobby, quest session and Link Party. The guard holds the
--    game's idle timer a minute below that limit while you are online with others; in a quest
--    with players outside your Link Party it does not, unless the player turns that on. The
--    Idle status after 3 minutes still works.
-- 2. Disconnect log: what the game reports about the network (errors, a closed lobby
--    connection, session changes, what the engine tells the quest and Link Party sessions,
--    leaving them), with the time, in reframework/data/AntiDisconnect/. "Copy report" puts
--    it on the clipboard to send.
-- 3. Steady link (experiment, off by default): the engine's highest health check rate in
--    quests and the Link Party, for connections that pause for a moment (mobile data).
-- 4. Wait for Steam (on by default): when Steam loses its connection for a
--    moment, the game waits up to 30 seconds for it to come back instead of going to
--    Offline Mode at once.
--
-- All game access runs on the game thread (UpdateBehavior), twice a second. The hooks only
-- watch: nothing the game does is skipped or changed, except that the idle timer is held and,
-- with the experiments on, the health check rate and the wait for Steam are raised.

local afk = require("AntiDisconnect.afk")
local config = require("AntiDisconnect.config")
local game = require("AntiDisconnect.game")
local grace = require("AntiDisconnect.grace")
local lang = require("AntiDisconnect.lang")
local link = require("AntiDisconnect.link")
local netlog = require("AntiDisconnect.netlog")
local ui = require("AntiDisconnect.ui")

local T = lang.T

local VERSION = "0.1.2"
local TICK_SECONDS = 0.5
local REPORT_PATH = "AntiDisconnect/report.txt"
local REPORT_ENTRIES = 80

local settings = config.load()
local _, lang_error = lang.set(settings.language)

local state = {
    version = VERSION,
    settings = settings,
    settings_dirty = false,   -- saved at the next tick
    guard = afk.new(),
    log = netlog.new(),
    reading = nil,            -- what the last tick read from the game, for the UI
    link = link.new(),        -- steady link: what was seen and changed per session
    links = {},               -- { lobby, quest, link } = game.link_info of the last tick, for the UI
    contexts = { changes = 0 }, -- the platform contexts and DisconnectionDetectionTime: first, now, changes
    grace = grace.new(),      -- wait for Steam: the value before the change, and the last try
    report_requested = false, -- "Copy report" was pressed; made at the next tick
    report_done = false,
    clipboard = nil,          -- text the UI puts on the clipboard in its next frame
    hooks = nil,              -- { on, missing } of the log hooks
    next_tick = 0,
    names_loaded = false,
    error = nil,              -- the last tick error, shown in the menu
    drawing = false,
    toast = nil,              -- { text, shown_at, until_at }: a message shown while the REFramework menu is closed
    toast_on_close = nil,     -- a message to show as soon as the REFramework menu closes (test button)
}

local function log_error(message)
    log.error("[AntiDisconnect] " .. message)
end

if lang_error then log_error("translation could not be loaded: " .. lang_error) end
if #lang.rejected > 0 then log_error("translation texts not used (unknown key or other values): " .. table.concat(lang.rejected, ", ")) end

netlog.load(state.log)
netlog.add(state.log, { kind = "start", version = VERSION })

local function show_toast(text)
    state.toast = { text = text, shown_at = os.clock(), until_at = os.clock() + state.settings.toast_seconds }
end

local function enum_name(kind, value)
    if value == nil then return nil end
    return game.name_of(kind, value) or tostring(value)
end

local function tick(now)
    local reading = { timer = game.idle_timer(), limits = game.limits(now), sessions = game.sessions() }
    if reading.sessions and reading.sessions.quest == "multi" then reading.strangers = game.quest_has_strangers() end
    local result = afk.step(state.guard, reading, state.settings, now)
    if result.set_timer then game.set_idle_timer(result.set_timer) end
    if result.saved_minutes then
        netlog.add(state.log, { kind = "afk_saved", minutes = result.saved_minutes })
        if state.settings.afk_welcome then
            show_toast(T("toast_welcome", result.saved_minutes, math.floor(reading.limits.kick / 60)))
        end
    end
    state.reading = reading
    local connection = game.context()
    netlog.observe(state.log, { sessions = reading.sessions, context = connection }, enum_name, game.lobby_kind)

    local infos = { lobby = game.link_info("lobby"), quest = game.link_info("quest"), link = game.link_info("link") }
    for _, name in ipairs(link.SESSIONS) do
        if infos[name] then infos[name].online = reading.sessions ~= nil and reading.sessions[name] ~= "off" end
    end
    local changes = link.step(state.link, infos, state.settings)
    for _, set in ipairs(changes.sets) do game.set_health_check(set[1], set[2]) end
    for _, event in ipairs(changes.events) do netlog.add(state.log, event) end
    state.links = infos

    -- DisconnectionDetectionTime: the game's own value (first), and how often it changed.
    local ctx = game.context_info()
    local seen = state.contexts
    if ctx.detect ~= nil then
        if seen.first == nil then seen.first = ctx.detect end
        if seen.now ~= nil and seen.now ~= ctx.detect then seen.changes = seen.changes + 1 end
        seen.now = ctx.detect
    end
    seen.main, seen.rebe = ctx.main, ctx.rebe
    local wait = grace.step(state.grace, { detect = ctx.detect, state = connection.state }, state.settings, now)
    if wait.set then game.set_detection_time(wait.set) end
    for _, event in ipairs(wait.events) do netlog.add(state.log, event) end
end

local function info_line(name, info)
    if not info then return lang.english("session_" .. name) .. ": -" end
    return lang.english("link_line", lang.english("session_" .. name), tostring(info.class), info.p2p_ok or 0,
        info.p2p_tried or 0, lang.english("health_" .. tostring(info.health)))
end

-- The report for "Copy report": settings, the connections now and the newest log entries,
-- in English. It holds no names or IDs.
local function make_report()
    local s = state.settings
    local sessions = state.reading and state.reading.sessions
    local header = {
        string.format("Anti Disconnect %s report, %s", VERSION, os.date("%Y-%m-%d %H:%M:%S")),
        string.format("Settings: AFK guard %s, public quests %s, steady link %s, wait for Steam %s", tostring(s.afk_guard),
            tostring(s.afk_public_quests), tostring(s.steady_link), tostring(s.steam_grace)),
        sessions and string.format("Sessions now: lobby %s, quest %s, link %s", sessions.lobby, sessions.quest, sessions.link)
            or "Sessions now: unknown",
        info_line("lobby", state.links.lobby),
        info_line("quest", state.links.quest),
        info_line("link", state.links.link),
        string.format("Contexts: main %s, rebe %s, DisconnectionDetectionTime first %s now %s, changed %d times",
            tostring(state.contexts.main), tostring(state.contexts.rebe), tostring(state.contexts.first),
            tostring(state.contexts.now), state.contexts.changes),
        "Log hooks on: " .. tostring(state.hooks and #state.hooks.on or 0)
            .. ((state.hooks and #state.hooks.missing > 0) and (", missing: " .. table.concat(state.hooks.missing, ", ")) or ""),
    }
    local text = netlog.report(state.log, header, REPORT_ENTRIES)
    if type(fs) == "table" and type(fs.write) == "function" then pcall(fs.write, REPORT_PATH, text) end
    state.clipboard = text
    state.report_done = true
end

local actions = {
    set_language = function(code)
        local used, err = lang.set(code)
        state.settings.language = used
        state.settings_dirty = true
        if err then log_error("translation could not be loaded: " .. err) end
    end,
    clear_log = function() netlog.clear(state.log) end,
    test_toast = function() state.toast_on_close = T("toast_test") end,
    copy_report = function() state.report_requested = true end,
    clipboard_done = function() state.clipboard = nil end,
}

state.hooks = game.install_hooks(function(event) netlog.add(state.log, event) end)
if #state.hooks.missing > 0 then log_error("log hooks not found on this game version: " .. table.concat(state.hooks.missing, ", ")) end

re.on_pre_application_entry("UpdateBehavior", function()
    local drawing = reframework:is_drawing_ui()
    if state.drawing and not drawing and state.toast_on_close then
        show_toast(state.toast_on_close)
        state.toast_on_close = nil
    end
    state.drawing = drawing

    local now = os.clock()
    if now < state.next_tick then return end
    state.next_tick = now + TICK_SECONDS
    if not state.names_loaded then
        state.names_loaded = true
        pcall(game.load_names)
    end
    local ok, err = pcall(tick, now)
    if ok then
        state.error = nil
    else
        if state.error ~= tostring(err) then log_error("tick failed: " .. tostring(err)) end
        state.error = tostring(err)
    end
    if state.settings_dirty then
        state.settings_dirty = false
        config.save(state.settings)
    end
    if state.report_requested then
        state.report_requested = false
        local made, report_err = pcall(make_report)
        if not made then log_error("report failed: " .. tostring(report_err)) end
    end
    netlog.save(state.log, now)
end)

re.on_draw_ui(function()
    ui.menu(state, actions)
end)

-- Messages while the REFramework menu is closed; only reads Lua state.
re.on_frame(function()
    ui.toast(state)
end)

re.on_config_save(function()
    config.save(state.settings)
    netlog.save(state.log, os.clock(), true)
end)

-- Offline tests set ANTIDISCONNECT_TEST before loading the script to reach its state.
if type(ANTIDISCONNECT_TEST) == "table" then
    ANTIDISCONNECT_TEST.state = state
    ANTIDISCONNECT_TEST.actions = actions
end
