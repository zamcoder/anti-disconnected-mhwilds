-- Game access (AntiDisconnect/game.lua) against the fake game.

local mock = require("mock_reframework")
local fake = require("fake_game")
local support = require("support")
local eq = support.eq
local runner = support.runner()
local test = runner.test

local env = mock.install()
local world = fake.build(env)
local game = require("AntiDisconnect.game")

test("reads and writes the idle timer", function()
    world.set_timer(12.5)
    eq(game.idle_timer(), 12.5, "read")
    eq(game.set_idle_timer(1740), true, "write")
    eq(world.timer(), 1740, "written")
end)

test("the input manager falls back to the static get_Instance", function()
    env.singletons["app.GameInputManager"] = nil
    eq(game.idle_timer(), nil, "no singleton, no fallback type")
    game._cache.methods.input_instance = nil
    local base = mock.new_type("ace.GAElement`1<app.GameInputManager>")
    mock.add_method(base, "get_Instance", "app.GameInputManager", {}, function() return world.input end, true)
    world.set_timer(7)
    eq(game.idle_timer(), 7, "read through get_Instance")
    env.singletons["app.GameInputManager"] = world.input
end)

test("reads the limits from the game, again after a while", function()
    game._cache.limits = nil
    local limits = game.limits(0)
    eq(limits.idle, 180.0, "idle")
    eq(limits.kick, 1800.0, "kick")
    eq(limits.read, true, "read from the game")
    mock.types["app.GameInputManager"].field_by_name.TO_NO_INPUT_DISCONNECT_TIME.static_value = 3600.0
    eq(game.limits(5).kick, 1800.0, "cached for a while")
    eq(game.limits(11).kick, 3600.0, "read again")
    mock.types["app.GameInputManager"].field_by_name.TO_NO_INPUT_DISCONNECT_TIME.static_value = 1800.0
end)

test("limits that cannot be read or make no sense give the known ones", function()
    local field = mock.types["app.GameInputManager"].field_by_name.TO_NO_INPUT_DISCONNECT_TIME
    for _, bad in ipairs({ "x", 0, 5, 100000 }) do
        field.static_value = bad
        game._cache.limits = nil
        local limits = game.limits(0)
        eq(limits.kick, 1800, "known kick for " .. tostring(bad))
        eq(limits.read, false, "marked as assumed")
    end
    field.static_value = 120.0   -- not above the idle limit
    game._cache.limits = nil
    eq(game.limits(0).read, false, "kick below idle")
    field.static_value = 1800.0
    game._cache.limits = nil
end)

test("session states", function()
    world.set("multi", "off", "solo")
    local s = game.sessions()
    eq(s.lobby, "multi", "lobby")
    eq(s.quest, "off", "quest")
    eq(s.link, "solo", "link")
    world.set()
end)

test("lobby kind", function()
    world.lobby_type = 1
    eq(game.lobby_kind(), "private", "private")
    world.lobby_type = 2
    eq(game.lobby_kind(), "squad", "squad")
    world.lobby_type = 7
    eq(game.lobby_kind(), nil, "unknown")
    world.lobby_type = 0
end)

test("quest members outside the Link Party", function()
    world.members[2] = { { id = "ME", self = true }, { id = "FRIEND" } }
    world.members[3] = { { id = "ME", self = true }, { id = "FRIEND" } }
    eq(game.quest_has_strangers(), false, "only the Link Party")
    world.members[2][3] = { id = "RANDOM" }
    eq(game.quest_has_strangers(), true, "a player outside the party")
    world.members[2] = { { id = "ME", self = true }, { id = "RANDOM" } }
    world.members[3] = {}
    eq(game.quest_has_strangers(), true, "no Link Party at all")
    world.members[2] = { { id = "ME", self = true } }
    eq(game.quest_has_strangers(), false, "alone in the quest")
    world.members[2] = { { id = "ME", self = true }, { id = nil } }
    eq(game.quest_has_strangers(), nil, "an id that cannot be read")
    world.members[2] = { { id = "ME", self = true }, { id = "GONE", valid = false } }
    eq(game.quest_has_strangers(), false, "invalid slots are ignored")
    world.members = { {}, {}, {} }
end)

test("connection context", function()
    world.context.values._ContextState = 3
    world.context.values._LoginStatus = 1
    world.local_network = true
    local c = game.context()
    eq(c.state, 3, "state")
    eq(c.login, 1, "login")
    eq(c.local_network, true, "local network")
    world.context.values._ContextState = 2
    world.context.values._LoginStatus = 2
    world.local_network = false
end)

test("platform contexts and DisconnectionDetectionTime", function()
    local info = game.context_info()
    eq(info.main, "via.network.ContextSteam", "Steam context")
    eq(info.rebe, "via.network.ContextRebe", "the other context")
    eq(info.detect, 10000, "value")
    eq(game.set_detection_time(30000000), true, "set")
    eq(game.context_info().detect, 30000000, "read back")
    eq(game.set_detection_time(10000), true, "put back")
    world.context.values._Context = nil
    eq(game.context_info().detect, nil, "no context, no value")
    eq(game.set_detection_time(30000000), false, "no context, nothing set")
    world.context.values._Context = world.steam
end)

test("enum names", function()
    game.load_names()
    eq(game.name_of("error_code", 106003), "COMMON_AFK", "error code")
    eq(game.name_of("context", 4), "FAILRE", "context state")
    eq(game.name_of("login", 1), "OFFLINE", "login status")
    eq(game.name_of("error_code", 1), nil, "unknown value")
    eq(game.name_of("nonsense", 1), nil, "unknown kind")
end)

test("int32 of hook arguments", function()
    eq(game._int32(106003), 106003, "plain")
    eq(game._int32(0xFFFFFFFF), -1, "negative")
    eq(game._int32(0x1FFFFFFFF), -1, "upper bits dropped")
    eq(game._int32(nil), nil, "nil")
end)

test("every log hook is installed and only watches", function()
    local events = {}
    local result = game.install_hooks(function(event) events[#events + 1] = event end)
    eq(#result.on, 16, "5 requestAppError, onError, 2 lobby, 2 session callbacks, leaveSession, 3 cloud, 2 party")
    eq(#result.missing, 0, "nothing missing")
    local A = fake.ACTION
    world.hook("requestAppError(app.NETWORK_ERROR_TYPE, app.NETWORK_ERROR_CODE, " .. A .. ")").pre({ 0, {}, 0, 106003, 0 })
    eq(events[1].kind, "app_error", "kind")
    eq(events[1].code, 106003, "code")
    eq(events[1].name, "COMMON_AFK", "code name")
    eq(events[1].area, "CONTEXT", "area")
    world.hook("requestAppError(app.NETWORK_ERROR_TYPE, System.Int32, System.Byte[], " .. A .. ")").pre({ 0, {}, 3, 0xFFFFFFFE, 0 })
    eq(events[2].raw, -2, "raw server code")
    eq(events[2].area, "LOBBY", "area")
    local err = world.engine_error({ get_Service = 13, get_Cause = 65, get_Method = 0, get_Level = 2, get_No = 7, text = "ws timeout" })
    world.hook("requestAppError(app.NETWORK_ERROR_TYPE, via.network.Error, via.Component, " .. A .. ")").pre({ 0, {}, 3, err, 0, 0 })
    eq(events[3].engine.service_name, "WebSocketClient", "engine service")
    eq(events[3].engine.cause_name, "Timeout", "engine cause")
    eq(events[3].engine.text, "ws timeout", "engine text")
    world.hook("onError(System.Int32, via.network.Error, via.Component, System.Boolean)").pre({ 0, {}, 5, err, 0, 1 })
    eq(events[4].kind, "engine_error", "onError")
    eq(events[4].engine.service, 13, "onError service")
    world.hook("websocketOnCloseDetect()").pre({ 0, {} })
    eq(events[5].kind, "lobby_closed", "lobby closed")
    world.hook("websocketErrorCallback(System.Boolean, System.Int32, System.Byte[])").pre({ 0, {}, 0, 216009, 0 })
    eq(events[6].code, 216009, "lobby error code")
    eq(#events, 6, "one event per call")
end)

test("what the engine tells the quest and Link Party sessions is logged, packets are not", function()
    local events = {}
    env.hooks = {}
    game.install_hooks(function(event) events[#events + 1] = event end)
    local drop = world.engine_error({ get_Service = 3, get_Cause = 131, valid = true, text = "S9052-TAD-W79J" })
    world.hook("<registDelegate>b__179_9(via.network.Error)").pre({ 0, world.sessions.link, drop })
    eq(events[1].kind, "session_event", "kind")
    eq(events[1].session, "link", "which session")
    eq(events[1].fn, "b__179_9", "which callback")
    eq(events[1].engine.cause_name, "PeerNorecvTimeout", "engine reason")
    eq(events[1].engine.text, "S9052-TAD-W79J", "the code the game shows")
    world.hook("<registDelegate>b__179_1(System.Int32, via.network.session.MemberInfo)").pre({ 0, world.sessions.quest, 2,
        world.member({ self = true, host = false }) })
    eq(events[2].session, "quest", "quest session")
    eq(events[2].self, true, "about this player")
    eq(events[2].host, false, "not the host")
    for _, h in ipairs(env.hooks) do
        eq(h.method.name == "<registDelegate>b__179_14" or h.method.name == "<registDelegate>b__179_15", false,
            "packet receivers and empty callbacks are not hooked")
    end
    world.hook("leaveSession()").pre({ 0, world.sessions.link })
    eq(events[3].kind, "leave_call", "leaving")
    eq(events[3].session, "link", "the Link Party session")
    -- In a public lobby 100 players come and go: only errors are kept there.
    world.hook("<registDelegate>b__179_1(System.Int32, via.network.session.MemberInfo)").pre({ 0, world.sessions.lobby, 5,
        world.member({ self = false }) })
    eq(#events, 3, "a lobby member joining is not logged")
    world.hook("<registDelegate>b__179_9(via.network.Error)").pre({ 0, world.sessions.lobby, drop })
    eq(events[4].session, "lobby", "a lobby error is")
end)

test("the lobby connection and the ways out of the Link Party are logged", function()
    local events = {}
    env.hooks = {}
    game.install_hooks(function(event) events[#events + 1] = event end)
    local closed = world.engine_error({ get_Service = 13, get_Cause = 141, valid = true })
    world.hook("onLeaveSession(via.network.Error)").pre({ 0, {}, closed })
    eq(events[1].kind, "lobby_leave", "lobby left")
    eq(events[1].engine.cause_name, "ClosedByServer", "reason")
    world.hook("onConnect(via.network.Error)").pre({ 0, {}, world.engine_error({ valid = false }) })
    eq(#events, 1, "a connect without an error is not logged")
    world.hook("onConnect(via.network.Error)").pre({ 0, {}, world.engine_error({ get_Service = 13, get_Cause = 65, valid = true }) })
    eq(events[2].kind, "lobby_connect", "a failed connect is")
    world.hook("reqLeaveLinkParty()").pre({ 0, {} })
    world.hook("onLeaveLinkPartySync()").pre({ 0, {} })
    world.hook("app.NetworkRequestManager.INet_LinkParty.leaveLinkPartySync(System.Boolean, app.Net_Party.PARTY_SYNC_OPTION)").pre({ 0, {}, 1, 2 })
    eq(events[3].via, "reqLeaveLinkParty", "request")
    eq(events[4].via, "onLeaveLinkPartySync", "sync leave")
    eq(events[5].option, 2, "sync option")
end)

test("connection info per session and the health check setting", function()
    world.engines.quest.values.tried, world.engines.quest.values.ok = 3, 1
    local info = game.link_info("quest")
    eq(info.class, "via.network.SessionPlayFab", "engine class")
    eq(info.health, 0, "default rate")
    eq(info.p2p_tried, 3, "tried")
    eq(info.p2p_ok, 1, "made")
    eq(game.set_health_check("quest", 1), true, "set")
    eq(world.engines.quest.values.health, 1, "highest now")
    eq(world.engines.link.values.health, 0, "the Link Party is separate")
    world.network.values._SessionService.values._QuestSession = nil
    eq(game.link_info("quest"), nil, "no quest session")
    eq(game.set_health_check("quest", 1), false, "nothing to set")
    world.network.values._SessionService.values._QuestSession = world.sessions.quest
    world.engines.quest.values.health = 0
end)

test("a hook that fails is logged once and the game call goes on", function()
    -- A record function that fails stands for any bug behind a hook.
    env.hooks = {}
    local calls = 0
    game.install_hooks(function() calls = calls + 1 error("boom") end)
    local logs_before = #env.logs
    local h = world.hook("websocketOnCloseDetect()")
    eq(h.pre({ 0, {} }), nil, "the original method still runs")
    eq(h.pre({ 0, {} }), nil, "again")
    eq(h.post("ret"), "ret", "the return value is kept")
    eq(calls, 2, "tried every time")
    eq(#env.logs, logs_before + 1, "logged once")
    eq(env.logs[#env.logs]:find("a log hook failed", 1, true) ~= nil, true, "the log line")
end)

test("a game without the hooked methods reports them missing", function()
    local env2 = mock.install()
    for _, name in ipairs({ "app.NetworkErrorManager", "app.NetworkRequestManager", "app.net_lobby_session.cLobbySession",
        "app.net_session_manager.SessionManager", "app.Net_CloudSessionRequest", "app.Net_Party" }) do
        mock.types[name] = nil
    end
    local result = game.install_hooks(function() end)
    eq(#result.on, 0, "nothing on")
    eq(#result.missing, 11, "every hook is listed as missing")
    eq(#env2.hooks, 0, "no hook installed")
end)

runner.run()
