-- A fake of the game parts Anti Disconnect uses, on top of mock_reframework: the idle timer and
-- its limits, the session flags, member lists, the connection context, the enums the log
-- names, and the methods the log hooks. Tests change `world` to set the scene.

local mock = require("mock_reframework")

local F = {}

local SESSION = "app.net_session_manager.SESSION_TYPE"
local ACTION = "System.Action`1<app.NETWORK_ERROR_CODE>"

local function noop() end

local function enum(name, values)
    local td = mock.new_type(name, { parent = "System.Enum" })
    for key, value in pairs(values) do mock.add_field(td, key, name, true, value) end
    return td
end

-- opts: { idle_limit, kick_limit, no_input_manager, no_hooks }
function F.build(env, opts)
    opts = opts or {}
    local world = {
        online = { false, false, false },   -- by SESSION_TYPE 1 lobby, 2 quest, 3 link
        multi = { false, false, false },
        members = { {}, {}, {} },           -- { id, self, valid } per session
        lobby_type = 0,
        local_network = false,
    }

    enum("app.NETWORK_ERROR_TYPE", { CONTEXT = 0, AUTH = 1, LOBBY = 3, QUEST = 4 })
    enum("app.NETWORK_ERROR_CODE", { NONE = 0, COMMON_AFK = 106003, COMMON_BE_OFFLINE = 106005,
        SERVER_LOBBYSESSION_USER_READ_LOOP_TIME_OUT = 216009 })
    enum("app.net_context_manager.cContextManager.CONTEXT_STATE", { INACTIVE = 0, BOOTUP = 1, ACTIVE = 2, SHUTDOWN = 3, FAILRE = 4 })
    enum("ace_network.EnumHunterLoginStatus", { OFFLINE = 1, ONLINE = 2, AFK = 3, BUSY = 4 })
    enum("via.network.error.Service", { None = 0, Context = 1, P2p = 2, Session = 3, WebSocketClient = 13 })
    enum("via.network.error.CauseWebSocketClient", { Timeout = 65, ClosedByServer = 141 })
    enum("via.network.error.CauseSession", { Timeout = 65, PeerNorecvTimeout = 131 })

    local input = mock.new_type("app.GameInputManager")
    mock.add_field(input, "TO_NO_INPUT_TIME", "System.Single", true, opts.idle_limit or 180.0)
    mock.add_field(input, "TO_NO_INPUT_DISCONNECT_TIME", "System.Single", true, opts.kick_limit or 1800.0)
    mock.add_field(input, "_NoInputTimer", "System.Single")
    world.input = mock.new_object("app.GameInputManager", { _NoInputTimer = 0.0 })

    local service = mock.new_type("app.Net_SessionService")
    mock.add_method(service, "isOnline", "System.Boolean", { SESSION }, function(_, s) return world.online[s] end)
    mock.add_method(service, "isMultiplay", "System.Boolean", { SESSION }, function(_, s) return world.multi[s] end)
    local settings_type = mock.new_type("app.net_lobby_session.cLobbySettings")
    mock.add_method(settings_type, "get_LobbyType", "System.Int32", {}, function() return world.lobby_type end)
    local lobby_settings = mock.new_object("app.net_lobby_session.cLobbySettings")
    mock.add_method(service, "getLobbySettings", "app.net_lobby_session.cLobbySettings", {}, function() return lobby_settings end)

    local info = mock.new_type("app.Net_UserInfo")
    mock.add_method(info, "get_IsValid", "System.Boolean", {}, function(self) return self.values.valid end)
    mock.add_method(info, "get_IsSelf", "System.Boolean", {}, function(self) return self.values.self end)
    mock.add_method(info, "get_ShortHunterId", "System.String", {}, function(self) return self.values.id end)
    mock.new_type("app.Net_UserInfoList")
    local users = mock.new_type("app.Net_UserInfoManager")
    mock.add_method(users, "getUserInfoList", "app.Net_UserInfoList", { SESSION }, function(_, s)
        local items = {}
        for i, m in ipairs(world.members[s] or {}) do
            items[i] = mock.new_object("app.Net_UserInfo", { valid = m.valid ~= false, self = m.self == true, id = m.id })
        end
        while #items < 4 do items[#items + 1] = mock.new_object("app.Net_UserInfo", { valid = false }) end
        return mock.new_object("app.Net_UserInfoList", { _ListInfo = mock.new_array("app.Net_UserInfo", items) })
    end)

    mock.new_type("app.net_context_manager.cContextManager")
    mock.new_type("via.network.ContextBase")
    local steam = mock.new_type("via.network.ContextSteam", { parent = "via.network.ContextBase" })
    mock.add_method(steam, "get_DisconnectionDetectionTime", "System.Int64", {}, function(self) return self.values.detect end)
    mock.new_type("via.network.ContextRebe", { parent = "via.network.ContextBase" })
    world.steam = mock.new_object("via.network.ContextSteam", { detect = 10000 })
    world.context = mock.new_object("app.net_context_manager.cContextManager", { _ContextState = 2, _LoginStatus = 2,
        _Context = world.steam, _RebeContext = mock.new_object("via.network.ContextRebe") })

    -- Session managers, each with its engine connection (PlayFab for quest and Link Party).
    mock.new_type("via.network.SessionBase")
    local engine = mock.new_type("via.network.SessionPlayFab", { parent = "via.network.SessionBase" })
    mock.add_method(engine, "get_HealthCheckSendFrequency", "via.network.session.HealthCheckSendFrequency", {},
        function(self) return self.values.health end)
    mock.add_method(engine, "set_HealthCheckSendFrequency", "System.Void", { "via.network.session.HealthCheckSendFrequency" },
        function(self, value) self.values.health = value end)
    mock.add_method(engine, "get_P2pConnectNum", "System.UInt32", {}, function(self) return self.values.tried end)
    mock.add_method(engine, "get_P2pSuccessNum", "System.UInt32", {}, function(self) return self.values.ok end)
    local manager = mock.new_type("app.net_session_manager.SessionManager")
    for _, name in ipairs({ "app.net_lobby_session.cLobbySession", "app.net_quest_session.cQuestSession", "app.cLinkSession" }) do
        mock.new_type(name, { parent = "app.net_session_manager.SessionManager" })
    end
    world.engines = {}
    local function session(type_name, key)
        world.engines[key] = mock.new_object("via.network.SessionPlayFab", { health = 0, tried = 0, ok = 0 })
        return mock.new_object(type_name, { _Session = world.engines[key] })
    end
    world.sessions = {
        lobby = session("app.net_lobby_session.cLobbySession", "lobby"),
        quest = session("app.net_quest_session.cQuestSession", "quest"),
        link = session("app.cLinkSession", "link"),
    }

    local network = mock.new_type("app.NetworkManager")
    mock.add_method(network, "get_IsLocalNetwork", "System.Boolean", {}, function() return world.local_network end)
    world.network = mock.new_object("app.NetworkManager", {
        _SessionService = mock.new_object("app.Net_SessionService", {
            _LobbySession = world.sessions.lobby, _QuestSession = world.sessions.quest, _LinkSession = world.sessions.link,
        }),
        _UserInfoManager = mock.new_object("app.Net_UserInfoManager"),
        _ContextManager = world.context,
    })

    local member = mock.new_type("via.network.session.MemberInfo")
    mock.add_method(member, "get_IsSelf", "System.Boolean", {}, function(self) return self.values.self end)
    mock.add_method(member, "get_IsHost", "System.Boolean", {}, function(self) return self.values.host end)
    function world.member(values) return mock.new_object("via.network.session.MemberInfo", values) end

    if not opts.no_hooks then
        local errors = mock.new_type("app.NetworkErrorManager")
        local T, CODE = "app.NETWORK_ERROR_TYPE", "app.NETWORK_ERROR_CODE"
        mock.add_method(errors, "requestAppError", "System.Void", { T, "System.Int32", "System.Byte[]", ACTION }, noop)
        mock.add_method(errors, "requestAppError", "System.Void", { T, "System.Int32", "System.Byte[]", "System.String[]", ACTION }, noop)
        mock.add_method(errors, "requestAppError", "System.Void", { T, "via.network.Error", "via.Component", ACTION }, noop)
        mock.add_method(errors, "requestAppError", "System.Void", { T, CODE, ACTION }, noop)
        mock.add_method(errors, "requestAppError", "System.Void", { T, CODE, "System.String[]", ACTION }, noop)
        mock.add_method(errors, "showError", "System.Void", {}, noop)
        local requests = mock.new_type("app.NetworkRequestManager")
        mock.add_method(requests, "onError", "System.Void", { "System.Int32", "via.network.Error", "via.Component", "System.Boolean" }, noop)
        local lobby = mock.types["app.net_lobby_session.cLobbySession"]
        mock.add_method(lobby, "websocketOnCloseDetect", "System.Void", {}, noop)
        mock.add_method(lobby, "websocketErrorCallback", "System.Void", { "System.Boolean", "System.Int32", "System.Byte[]" }, noop)
        -- What the engine tells a session (two of this build's callbacks), plus ones the log skips.
        mock.add_method(manager, "<registDelegate>b__179_1", "System.Void", { "System.Int32", "via.network.session.MemberInfo" }, noop)
        mock.add_method(manager, "<registDelegate>b__179_9", "System.Void", { "via.network.Error" }, noop)
        mock.add_method(manager, "<registDelegate>b__179_14", "System.Void", { "System.Int32", "System.Object" }, noop)
        mock.add_method(manager, "<registDelegate>b__179_15", "System.Void", {}, noop)
        mock.add_method(manager, "leaveSession", "System.Void", {}, noop)
        local cloud = mock.new_type("app.Net_CloudSessionRequest")
        mock.add_method(cloud, "onLeaveSession", "System.Void", { "via.network.Error" }, noop)
        mock.add_method(cloud, "onConnect", "System.Void", { "via.network.Error" }, noop)
        mock.add_method(cloud, "reqLeaveLinkParty", "System.Void", {}, noop)
        local party = mock.new_type("app.Net_Party")
        mock.add_method(party, "onLeaveLinkPartySync", "System.Void", {}, noop)
        mock.add_method(party, "app.NetworkRequestManager.INet_LinkParty.leaveLinkPartySync", "System.Void",
            { "System.Boolean", "app.Net_Party.PARTY_SYNC_OPTION" }, noop)
    end
    local err = mock.new_type("via.network.Error")
    for _, getter in ipairs({ "get_Service", "get_Cause", "get_Method", "get_Level", "get_No" }) do
        mock.add_method(err, getter, "System.Int32", {}, function(self) return self.values[getter] end)
    end
    mock.add_method(err, "get_Valid", "System.Boolean", {}, function(self) return self.values.valid end)
    mock.add_method(err, "get_ShortString", "System.String", {}, function(self) return self.values.text end)

    if not opts.no_input_manager then env.singletons["app.GameInputManager"] = world.input end
    env.singletons["app.NetworkManager"] = world.network

    -- The scene: lobby/quest/link are "off", "solo" or "multi".
    function world.set(lobby, quest, link)
        for i, s in ipairs({ lobby or "off", quest or "off", link or "off" }) do
            world.online[i] = s ~= "off"
            world.multi[i] = s == "multi"
        end
    end

    function world.timer() return world.input.values._NoInputTimer end
    function world.set_timer(seconds) world.input.values._NoInputTimer = seconds end

    function world.engine_error(values) return mock.new_object("via.network.Error", values) end

    -- The hook installed on a method, by its signature.
    function world.hook(sig)
        for _, h in ipairs(env.hooks) do
            if h.method.sig == sig then return h end
        end
        error("no hook on " .. sig, 2)
    end

    return world
end

F.ACTION = ACTION

return F
