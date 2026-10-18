-- The whole script (AntiDisconnect.lua) against the fake game: ticks, the AFK guard, the log,
-- the menu and the message. The menu must never call the game while it draws.

local mock = require("mock_reframework")
local fake = require("fake_game")
local support = require("support")
local eq = support.eq
local runner = support.runner()
local test = runner.test

local env = mock.install()
env.use_fake_clock()
env.guard_draw = true
local world = fake.build(env)
ANTIDISCONNECT_TEST = {}
dofile(PROJECT_ROOT .. "/src/reframework/autorun/AntiDisconnect.lua")
local state = ANTIDISCONNECT_TEST.state
local frame = env.entries["UpdateBehavior"]

local function tick(seconds)
    env.advance(seconds or 0.5)
    frame()
end

local function timer_writes()
    local n = 0
    for _, w in ipairs(mock.writes) do
        if w.name == "_NoInputTimer" then n = n + 1 end
    end
    return n
end

local function last_event() return state.log.events[#state.log.events] end

test("starts with the guard on, the log hooks on and a start entry", function()
    eq(state.settings.afk_guard, true, "guard on")
    eq(#state.hooks.on, 16, "hooks")
    eq(state.settings.steady_link, false, "the experiment is off by default")
    eq(state.log.events[1].kind, "start", "start entry")
    tick()
    eq(state.guard.status, "status_not_needed", "offline at first")
end)

test("idle in an online lobby: the timer is held below the kick", function()
    world.set("multi", "off", "off")
    world.set_timer(1000)
    tick()
    eq(timer_writes(), 0, "below the ceiling nothing is written")
    eq(state.guard.status, "status_lobby", "protecting")
    world.set_timer(1790)
    tick()
    eq(world.timer(), 1740, "held")
    eq(state.guard.held, true, "held flag")
    env.draw()
    eq(env.has("AFK guard: protecting you in the lobby."), true, "status shown")
    eq(env.has_text("^No input for 29:5"), true, "real idle time shown")
end)

test("the session change was logged", function()
    local found = false
    for _, e in ipairs(state.log.events) do
        if e.kind == "session" and e.session == "lobby" and e.to == "multi" then found = true end
    end
    eq(found, true, "lobby: off -> multi")
end)

test("coming back after 34 minutes shows the welcome message once", function()
    env.advance(250)            -- 1790 s + 250 s + a few ticks without input
    tick()
    world.set_timer(0.1)        -- input
    tick()
    eq(last_event().kind, "afk_saved", "logged")
    eq(state.toast ~= nil, true, "message")
    eq(state.toast.text:find("Welcome back! You had no input for 34 minutes", 1, true) ~= nil, true, state.toast.text)
    eq(state.guard.saves, 1, "counted")
    env.drawing_ui = false
    env.callbacks.frame()       -- drawn while the menu is closed (window fallback without the draw API)
    env.drawing_ui = true
    tick()
    eq(state.guard.saves, 1, "only once")
end)

test("a quest with a player outside the Link Party keeps the game's kick", function()
    world.set("multi", "multi", "off")
    world.members[2] = { { id = "ME", self = true }, { id = "RANDOM" } }
    world.set_timer(1795)
    local before = timer_writes()
    tick()
    eq(timer_writes(), before, "not held")
    eq(state.guard.status, "status_strangers", "status")
    env.draw()
    eq(env.has_text("^AFK guard: not protecting you in this quest"), true, "explained")
end)

test("turning on public quests protects that quest and saves the setting", function()
    local saves = #env.written
    env.draw({}, { ["Also during quests with players outside my Link Party##AntiDisconnect_afk_public_quests"] = true })
    eq(state.settings.afk_public_quests, true, "set")
    tick()
    eq(world.timer(), 1740, "held now")
    eq(state.guard.status, "status_quest_all", "status")
    local saved = false
    for i = saves + 1, #env.written do
        if env.written[i].path == "AntiDisconnect/config.json" then saved = env.written[i].data.afk_public_quests end
    end
    eq(saved, true, "config written")
    env.draw({}, { ["Also during quests with players outside my Link Party##AntiDisconnect_afk_public_quests"] = false })
    world.members[2] = {}
    world.set("multi", "off", "off")
    world.set_timer(0)
    tick()
end)

test("turning the guard off stops holding", function()
    env.draw({}, { ["Stop the AFK kick (the game moves you to Online Single Player after 30 minutes without input)##AntiDisconnect_afk_guard"] = false })
    world.set_timer(1795)
    local before = timer_writes()
    tick()
    eq(timer_writes(), before, "not held")
    eq(state.guard.status, "status_off", "status")
    env.draw()
    eq(env.has("AFK guard: off."), true, "shown")
    env.draw({}, { ["Stop the AFK kick (the game moves you to Online Single Player after 30 minutes without input)##AntiDisconnect_afk_guard"] = true })
    world.set_timer(0)
    tick()
end)

test("errors from the game are logged and shown", function()
    world.hook("requestAppError(app.NETWORK_ERROR_TYPE, app.NETWORK_ERROR_CODE, " .. fake.ACTION .. ")").pre({ 0, {}, 0, 106005, 0 })
    eq(last_event().name, "COMMON_BE_OFFLINE", "named")
    world.set("off", "off", "off")
    world.context.values._LoginStatus = 1
    tick()
    env.draw()
    eq(env.has_text("Game error COMMON_BE_OFFLINE %(106005%), area CONTEXT"), true, "error line")
    eq(env.has_text("Lobby: online with others %-> not connected"), true, "lobby line")
    eq(env.has_text("Your online status: ONLINE %-> OFFLINE"), true, "offline line")
end)

test("the log file is written within a few seconds", function()
    local before = #env.written
    tick(6)
    local wrote = false
    for i = before + 1, #env.written do
        if env.written[i].path == "AntiDisconnect/events.json" then wrote = true end
    end
    eq(wrote, true, "events.json")
end)

test("steady link: the health check rate goes up in the quest and Link Party, and back when turned off", function()
    world.engines.link.values.tried, world.engines.link.values.ok = 3, 1
    tick()
    eq(world.engines.link.values.health, 0, "untouched while off")
    env.draw()
    eq(env.has_text("^Link Party: via.network.SessionPlayFab · direct connections 1 of 3"), true, "connection shown")
    local label = "Experiment: send \"I'm still here\" signals more often in quests and the Link Party##AntiDisconnect_steady_link"
    env.draw({}, { [label] = true })
    tick()
    eq(world.engines.quest.values.health, 0, "sessions that are not running are left alone")
    world.set("multi", "solo", "multi")
    tick()
    eq(world.engines.quest.values.health, 1, "quest highest")
    eq(world.engines.link.values.health, 1, "link highest")
    eq(world.engines.lobby.values.health, 0, "the lobby is left alone")
    local logged = false
    for _, e in ipairs(state.log.events) do
        if e.kind == "health" and e.session == "link" and e.to == 1 then logged = true end
    end
    eq(logged, true, "the change is logged")
    env.draw({}, { [label] = false })
    tick()
    eq(world.engines.link.values.health, 0, "back to what it was")
    world.set("off", "off", "off")
    tick()
end)

test("a message waits while the REFramework menu is open (seen in game: the wake-up key opened it)", function()
    state.toast = { text = "Welcome back!", shown_at = os.clock(), until_at = os.clock() + 12 }
    env.drawing_ui = true
    env.callbacks.frame()
    env.advance(30)
    env.callbacks.frame()
    eq(state.toast ~= nil, true, "still waiting after 30 s with the menu open")
    env.drawing_ui = false
    env.callbacks.frame()
    eq(state.toast ~= nil and state.toast.until_at > os.clock() + 11, true, "shown for its full time once the menu closes")
    env.advance(13)
    env.callbacks.frame()
    eq(state.toast, nil, "then gone")
    env.drawing_ui = true
end)

test("Copy report puts the log on the clipboard and in a file", function()
    env.enable_fs()
    world.hook("<registDelegate>b__179_9(via.network.Error)").pre({ 0, world.sessions.link,
        world.engine_error({ get_Service = 3, get_Cause = 131, valid = true }) })
    env.draw({ "Copy report##AntiDisconnectReport" })
    tick()
    env.draw()
    local text = env.clipboard or ""
    eq(text:find("Anti Disconnect 0.1.0 report", 1, true) ~= nil, true, "header")
    eq(text:find("Link Party: engine notice b__179_9: Session / PeerNorecvTimeout", 1, true) ~= nil, true, text)
    eq(env.text_files["AntiDisconnect/report.txt"], text, "the same text in the file")
    eq(env.has_text("^Report copied"), true, "told")
    eq(state.clipboard, nil, "handed to ImGui once")
end)

test("Clear log empties the log", function()
    env.draw({ "Clear log##AntiDisconnectClearLog" })
    eq(#state.log.events, 0, "empty")
    env.draw()
    eq(env.has("Nothing recorded yet."), true, "empty text")
end)

test("the test message waits for the menu to close", function()
    env.draw({ "Show a test message##AntiDisconnectToastTest" })
    eq(state.toast_on_close ~= nil, true, "waiting")
    env.drawing_ui = false
    tick()
    eq(state.toast ~= nil and state.toast.text:find("This is how", 1, true) ~= nil, true, "shown after closing")
    env.drawing_ui = true
end)

test("Indonesian", function()
    env.draw({}, { ["Language / Bahasa##AntiDisconnectLanguage"] = 2 })
    eq(state.settings.language, "id", "setting")
    tick()
    env.draw()
    eq(env.has("Versi 0.1.0"), true, "translated")
    env.draw({}, { ["Language / Bahasa##AntiDisconnectLanguage"] = 1 })
    eq(state.settings.language, "en", "back")
end)

test("no idle timer after a game update: the guard says so and nothing breaks", function()
    env.singletons["app.GameInputManager"] = nil
    world.set("multi", "off", "off")
    tick()
    eq(state.guard.status, "status_unavailable", "status")
    env.draw()
    eq(env.has_text("^AFK guard: not available"), true, "shown")
    env.singletons["app.GameInputManager"] = world.input
end)

test("a game call that fails is caught inside game.lua", function()
    local sessions = mock.types["app.Net_SessionService"]
    local original = sessions.methods[1].impl
    sessions.methods[1].impl = function() error("game changed") end
    local logs = #env.logs
    tick()
    tick()
    eq(state.error, nil, "a failing game call is caught inside game.lua")
    sessions.methods[1].impl = original
    eq(#env.logs >= logs, true, "no crash")
end)

runner.run()
