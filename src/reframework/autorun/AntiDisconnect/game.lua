-- Game access for Anti Disconnect. Every name below was checked against the il2cpp dump and
-- the machine code of game build 24705561 (the research notes are kept locally, not in this
-- repository). After a game update a name that is gone makes its feature
-- report itself unavailable instead of failing.
--
-- The inactivity kick lives in two classes:
--   app.GameInputManager._NoInputTimer       seconds without keyboard, mouse or pad input. It only
--                                            grows while you are online with others
--                                            (Net_SessionService.isMultiplay of the lobby, quest or
--                                            Link Party session); any input sets it to 0.
--   app.GameInputManager.TO_NO_INPUT_TIME    180: your status becomes Idle for other players.
--   app.GameInputManager.TO_NO_INPUT_DISCONNECT_TIME
--                                            1800: app.net_context_manager.cContextManager
--                                            .move_check_input_state() then shows COMMON_AFK
--                                            ("Switched to Online Single Player due to
--                                            inactivity") and leaves every session.
-- move_check_input_state is the only reader of the timer, so holding the timer below the
-- limit stops the kick and changes nothing else.
--
-- One player dropping out of a Link Party or quest: each session manager (Net_SessionService
-- _LobbySession / _QuestSession / _LinkSession, all app.net_session_manager.SessionManager)
-- has an engine connection in _Session (via.network.SessionBase; PlayFab for quest and Link
-- Party). The engine decides when a member is gone (via.network.error.CauseSession:
-- PeerNorecvTimeout, PeerUnstableOne, ...) and tells the session manager through the
-- callbacks SessionManager.registDelegate installs (<registDelegate>b__179_N on this build).
-- The log hooks those callbacks and the ways out of a session and the Link Party.

local game = {}

game.SESSIONS = { { "lobby", 1 }, { "quest", 2 }, { "link", 3 } }   -- app.net_session_manager.SESSION_TYPE

local METHODS = {
    is_online = { "app.Net_SessionService", "isOnline(app.net_session_manager.SESSION_TYPE)" },
    is_multiplay = { "app.Net_SessionService", "isMultiplay(app.net_session_manager.SESSION_TYPE)" },
    lobby_settings = { "app.Net_SessionService", "getLobbySettings()" },
    user_list = { "app.Net_UserInfoManager", "getUserInfoList(app.net_session_manager.SESSION_TYPE)" },
    local_network = { "app.NetworkManager", "get_IsLocalNetwork()" },
}

local INPUT_TYPE = "app.GameInputManager"
local LIMIT_FIELDS = { idle = "TO_NO_INPUT_TIME", kick = "TO_NO_INPUT_DISCONNECT_TIME" }
local KNOWN_LIMITS = { idle = 180, kick = 1800 }   -- game version 1.42.0.2
local LIMITS_SECONDS = 10                          -- the limits are read again after this long
local LOBBY_KINDS = { [0] = "public", [1] = "private", [2] = "squad" }   -- cSearchLobbySessionInfo.LOBBY_TYPE
local SESSION_FIELDS = { lobby = "_LobbySession", quest = "_QuestSession", link = "_LinkSession" }   -- on Net_SessionService
local SESSION_NAMES = {   -- session manager classes, for the log
    ["app.net_lobby_session.cLobbySession"] = "lobby", ["app.net_quest_session.cQuestSession"] = "quest",
    ["app.cLinkSession"] = "link", ["app.cMemoriesSession"] = "memories", ["app.net_local_session.cLocalSession"] = "local",
}

-- Enum names for the log. An engine error's cause has a different enum per service.
local ENUMS = {
    error_type = "app.NETWORK_ERROR_TYPE",
    error_code = "app.NETWORK_ERROR_CODE",
    context = "app.net_context_manager.cContextManager.CONTEXT_STATE",
    login = "ace_network.EnumHunterLoginStatus",
    service = "via.network.error.Service",
}
local CAUSE_ENUMS = {
    [1] = "via.network.error.CauseContext", [2] = "via.network.error.CauseP2p",
    [3] = "via.network.error.CauseSession", [7] = "via.network.error.CauseProtocol",
    [13] = "via.network.error.CauseWebSocketClient", [15] = "via.network.error.CauseMatchmaking",
}

local cache = { methods = {}, enums = {}, limits = nil, limits_until = nil }

local function type_def(name)
    local ok, td = pcall(sdk.find_type_definition, name)
    return ok and td or nil
end

local function method(key)
    local m = cache.methods[key]
    if m == nil then
        local spec = METHODS[key]
        local td = type_def(spec[1])
        m = td and td:get_method(spec[2]) or false
        cache.methods[key] = m
    end
    return m or nil
end

-- Array elements and some fields come back as boxed System.Int32 objects.
local function number(value)
    if type(value) == "userdata" then
        local ok, inner = pcall(function() return value:get_field("m_value") end)
        value = ok and inner or nil
    end
    if type(value) ~= "number" then return nil end
    return math.tointeger(value) or value
end

local function field(obj, name)
    if obj == nil then return nil end
    local ok, value = pcall(function() return obj:get_field(name) end)
    if ok then return value end
    return nil
end

-- A getter without arguments, called by name.
local function call(obj, name)
    if obj == nil then return nil end
    local ok, value = pcall(function() return obj:call(name) end)
    if ok then return value end
    return nil
end

local function invoke(key, obj, ...)
    local m = method(key)
    if not m or obj == nil then return nil end
    local ok, value = pcall(m.call, m, obj, ...)
    if ok then return value end
    return nil
end

local function size(array)
    if array == nil then return 0 end
    local ok, value = pcall(function() return array:get_size() end)
    return ok and number(value) or 0
end

local function element(array, index)
    local ok, value = pcall(function() return array:get_element(index) end)
    if ok then return value end
    return nil
end

-- System.String results are Lua strings in REFramework; a managed string object is converted.
local function text(value)
    if type(value) == "userdata" then value = call(value, "ToString") end
    if type(value) == "string" and value ~= "" then return value end
    return nil
end

function game.network_manager()
    return sdk.get_managed_singleton("app.NetworkManager")
end

-- The input manager is an ace.GAElement singleton; its static get_Instance is the fallback in
-- case REFramework's singleton list does not have it.
local function input_manager()
    local manager = sdk.get_managed_singleton(INPUT_TYPE)
    if manager then return manager end
    local m = cache.methods.input_instance
    if m == nil then
        local td = type_def("ace.GAElement`1<" .. INPUT_TYPE .. ">")
        m = td and td:get_method("get_Instance()") or false
        cache.methods.input_instance = m
    end
    if not m then return nil end
    local ok, value = pcall(m.call, m, nil)
    if ok then return value end
    return nil
end

-- Seconds without input as the game counts them, or nil when it cannot be read.
function game.idle_timer()
    local value = field(input_manager(), "_NoInputTimer")
    return type(value) == "number" and value or nil
end

function game.set_idle_timer(seconds)
    local manager = input_manager()
    if not manager then return false end
    local ok = pcall(function() manager:set_field("_NoInputTimer", seconds) end)
    return ok
end

-- The game's two limits in seconds, { idle, kick, read }. read = false when the static fields
-- could not be read and the known values are used instead.
function game.limits(now)
    if cache.limits and now < cache.limits_until then return cache.limits end
    local td = type_def(INPUT_TYPE)
    local result = { idle = KNOWN_LIMITS.idle, kick = KNOWN_LIMITS.kick, read = true }
    for key, name in pairs(LIMIT_FIELDS) do
        local f = td and td:get_field(name)
        local ok, value = false, nil
        if f then ok, value = pcall(f.get_data, f, nil) end
        if ok and type(value) == "number" and value >= 10 and value <= 86400 then
            result[key] = value
        else
            result.read = false
        end
    end
    if result.kick <= result.idle then
        result.idle, result.kick, result.read = KNOWN_LIMITS.idle, KNOWN_LIMITS.kick, false
    end
    cache.limits, cache.limits_until = result, now + LIMITS_SECONDS
    return result
end

-- "off", "solo" (online but alone) or "multi" (online with others) for the lobby, the quest
-- session and the Link Party; nil when the game cannot tell (title screen, game update).
function game.sessions()
    local service = field(game.network_manager(), "_SessionService")
    if not service or not method("is_online") or not method("is_multiplay") then return nil end
    local result = {}
    for _, session in ipairs(game.SESSIONS) do
        local online = invoke("is_online", service, session[2])
        local multi = invoke("is_multiplay", service, session[2])
        if type(online) ~= "boolean" or type(multi) ~= "boolean" then return nil end
        result[session[1]] = multi and "multi" or (online and "solo" or "off")
    end
    return result
end

-- "public", "private" or "squad" for the lobby you are in, or nil.
function game.lobby_kind()
    local settings = invoke("lobby_settings", field(game.network_manager(), "_SessionService"))
    return LOBBY_KINDS[number(call(settings, "get_LobbyType"))]
end

-- Valid members of one session: { id = short hunter id, self = true/false }, or nil.
local function members(manager, session)
    local list = invoke("user_list", manager, session)
    local infos = field(list, "_ListInfo")
    if not infos then return nil end
    local result = {}
    for i = 0, size(infos) - 1 do
        local info = element(infos, i)
        if info and call(info, "get_IsValid") == true then
            result[#result + 1] = { id = text(call(info, "get_ShortHunterId")), self = call(info, "get_IsSelf") == true }
        end
    end
    return result
end

-- true when the quest session has a player who is neither you nor in your Link Party, false
-- when it has none, nil when the member lists cannot be read. Only used for this decision:
-- the ids are never stored or logged.
function game.quest_has_strangers()
    local manager = field(game.network_manager(), "_UserInfoManager")
    local quest = manager and members(manager, 2)
    if not quest then return nil end
    local party = {}
    for _, m in ipairs(members(manager, 3) or {}) do
        if m.id then party[m.id] = true end
    end
    for _, m in ipairs(quest) do
        if not m.self then
            if not m.id then return nil end
            if not party[m.id] then return true end
        end
    end
    return false
end

local function type_name(obj)
    if obj == nil then return nil end
    local ok, name = pcall(function() return obj:get_type_definition():get_full_name() end)
    return ok and name or nil
end

local function session_name(manager)
    local name = type_name(manager)
    return name and (SESSION_NAMES[name] or name) or nil
end

local function engine_session(name)
    return field(field(field(game.network_manager(), "_SessionService"), SESSION_FIELDS[name]), "_Session")
end

-- The engine connection behind the "lobby", "quest" or "link" session:
-- { class, health (HealthCheckSendFrequency: 0 Default, 1 Highest), p2p_tried, p2p_ok }, or nil.
function game.link_info(name)
    local engine = engine_session(name)
    if not engine then return nil end
    return {
        class = type_name(engine),
        health = number(call(engine, "get_HealthCheckSendFrequency")),
        p2p_tried = number(call(engine, "get_P2pConnectNum")),
        p2p_ok = number(call(engine, "get_P2pSuccessNum")),
    }
end

-- How often this game sends the engine's "still here" health checks on one session.
function game.set_health_check(name, value)
    local engine = engine_session(name)
    if not engine then return false end
    local ok = pcall(function() engine:call("set_HealthCheckSendFrequency", value) end)
    return ok
end

-- The engine's platform contexts behind the connection: cContextManager._Context (the
-- platform, via.network.ContextSteam on Steam) and _RebeContext. A Context error
-- "LinkStateInactive" sends the game to Offline Mode and out of every session at once
-- (seen in a player's report on 2026-10-18). ContextSteam has a settable
-- DisconnectionDetectionTime whose meaning and unit are not known yet, so it is only read:
-- { main, rebe, detect } (class names, and the value or nil).
function game.context_info()
    local context = field(game.network_manager(), "_ContextManager")
    local main = field(context, "_Context")
    local info = { main = type_name(main), rebe = type_name(field(context, "_RebeContext")) }
    if info.main == "via.network.ContextSteam" then info.detect = number(call(main, "get_DisconnectionDetectionTime")) end
    return info
end

-- The connection to Capcom's servers: { state, login, local_network }; each value is nil when
-- it cannot be read.
function game.context()
    local manager = game.network_manager()
    local context = field(manager, "_ContextManager")
    local local_network = invoke("local_network", manager)
    return {
        state = number(field(context, "_ContextState")),
        login = number(field(context, "_LoginStatus")),
        local_network = type(local_network) == "boolean" and local_network or nil,
    }
end

-- { [value] = name } of an enum type, read once from its static fields.
function game.enum_names(type_name)
    local names = cache.enums[type_name]
    if names == nil then
        names = false
        local td = type_def(type_name)
        if td then
            local map = {}
            pcall(function()
                for _, f in ipairs(td:get_fields() or {}) do
                    if f:is_static() then
                        local value = number(f:get_data(nil))
                        if math.type(value) == "integer" and map[value] == nil then map[value] = f:get_name() end
                    end
                end
            end)
            if next(map) then names = map end
        end
        cache.enums[type_name] = names
    end
    return names or nil
end

-- The name of an enum value for the log ("error_code", "context", ...), or nil.
function game.name_of(kind, value)
    local names = ENUMS[kind] and game.enum_names(ENUMS[kind])
    return names and value ~= nil and names[value] or nil
end

-- Reads every enum the log uses, once, on the game thread; hooks then only look names up.
function game.load_names()
    for _, type_name in pairs(ENUMS) do game.enum_names(type_name) end
    for _, type_name in pairs(CAUSE_ENUMS) do game.enum_names(type_name) end
end

-- Hook arguments.
local function int32(raw)
    local ok, value = pcall(sdk.to_int64, raw)
    if not ok or type(value) ~= "number" then return nil end
    value = math.tointeger(value)
    if not value then return nil end
    value = value & 0xFFFFFFFF
    if value >= 0x80000000 then value = value - 0x100000000 end
    return value
end

local function object(raw)
    local ok, value = pcall(sdk.to_managed_object, raw)
    if ok then return value end
    return nil
end

-- What a via.network.Error says: the engine service that failed and why.
local function error_details(err)
    if err == nil then return nil end
    local d = {
        service = number(call(err, "get_Service")),
        cause = number(call(err, "get_Cause")),
        method = number(call(err, "get_Method")),
        level = number(call(err, "get_Level")),
        no = number(call(err, "get_No")),
    }
    local short = text(call(err, "get_ShortString"))
    if short then d.text = short:sub(1, 120) end
    d.valid = call(err, "get_Valid") == true
    d.service_name = game.name_of("service", d.service)
    local causes = d.service and CAUSE_ENUMS[d.service]
    local names = causes and game.enum_names(causes)
    d.cause_name = names and d.cause and names[d.cause] or nil
    return d
end

local function param_names(m)
    local names = {}
    pcall(function()
        for i, p in ipairs(m:get_param_types() or {}) do names[i] = p:get_full_name() end
    end)
    return names
end

-- The requestAppError overloads, by the type of their second parameter.
local APP_ERROR_READERS = {
    ["app.NETWORK_ERROR_CODE"] = function(args)
        local code = int32(args[4])
        return { kind = "app_error", area = game.name_of("error_type", int32(args[3])), code = code,
            name = game.name_of("error_code", code) }
    end,
    ["System.Int32"] = function(args)
        return { kind = "app_error", area = game.name_of("error_type", int32(args[3])), raw = int32(args[4]) }
    end,
    ["via.network.Error"] = function(args)
        return { kind = "app_error", area = game.name_of("error_type", int32(args[3])), engine = error_details(object(args[4])) }
    end,
}

-- Hooks that only watch what the game reports about the network and always let it run.
-- `record` gets one event table per call. Returns the hooks that are on and the ones not
-- found on this game version: { on = { name... }, missing = { name... } }.
function game.install_hooks(record)
    local result = { on = {}, missing = {} }
    local reported = false
    local function watch(name, target, read)
        if not target then
            result.missing[#result.missing + 1] = name
            return
        end
        local ok = pcall(sdk.hook, target, function(args)
            local fine, err = pcall(function()
                local event = read(args)
                if event then record(event) end
            end)
            if not fine and not reported then
                reported = true
                log.error("[AntiDisconnect] a log hook failed: " .. tostring(err))
            end
        end, function(retval) return retval end)
        if ok then result.on[#result.on + 1] = name else result.missing[#result.missing + 1] = name end
    end

    local errors = type_def("app.NetworkErrorManager")
    local found = 0
    for _, m in ipairs(errors and errors:get_methods() or {}) do
        if m:get_name() == "requestAppError" then
            local params = param_names(m)
            local read = APP_ERROR_READERS[params[2]]
            if read then
                found = found + 1
                watch("requestAppError(" .. table.concat(params, ", ") .. ")", m, read)
            end
        end
    end
    if found == 0 then result.missing[#result.missing + 1] = "NetworkErrorManager.requestAppError" end

    local requests = type_def("app.NetworkRequestManager")
    watch("NetworkRequestManager.onError",
        requests and requests:get_method("onError(System.Int32, via.network.Error, via.Component, System.Boolean)"),
        function(args) return { kind = "engine_error", engine = error_details(object(args[4])) } end)
    local lobby = type_def("app.net_lobby_session.cLobbySession")
    watch("cLobbySession.websocketOnCloseDetect", lobby and lobby:get_method("websocketOnCloseDetect()"),
        function() return { kind = "lobby_closed" } end)
    watch("cLobbySession.websocketErrorCallback",
        lobby and lobby:get_method("websocketErrorCallback(System.Boolean, System.Int32, System.Byte[])"),
        function(args) return { kind = "lobby_error", code = int32(args[4]) } end)

    -- What the engine tells each session (member joined or left, host changed, the session
    -- ended with an error). Receivers of game data (a System.Object parameter) are left out:
    -- they run for every packet.
    local sessions = type_def("app.net_session_manager.SessionManager")
    local found_callbacks = 0
    for _, m in ipairs(sessions and sessions:get_methods() or {}) do
        local name = m:get_name()
        local params = param_names(m)
        local packets, has_error = false, false
        for _, p in ipairs(params) do
            if p == "System.Object" then packets = true end
            if p == "via.network.Error" then has_error = true end
        end
        if name:find("<registDelegate>", 1, true) == 1 and #params > 0 and not packets then
            found_callbacks = found_callbacks + 1
            local short = name:match("b__[%d_]+") or name
            watch("SessionManager." .. short, m, function(args)
                local event = { kind = "session_event", session = session_name(object(args[2])), fn = short }
                -- Up to 100 players come and go in a lobby: only its errors are kept.
                if event.session == "lobby" and not has_error then return nil end
                for i, p in ipairs(params) do
                    if p == "via.network.Error" then
                        event.engine = error_details(object(args[2 + i]))
                    elseif p == "via.network.session.MemberInfo" then
                        local member = object(args[2 + i])
                        event.self = call(member, "get_IsSelf") == true
                        event.host = call(member, "get_IsHost") == true
                    end
                end
                return event
            end)
        end
    end
    if found_callbacks == 0 then result.missing[#result.missing + 1] = "SessionManager callbacks" end
    watch("SessionManager.leaveSession", sessions and sessions:get_method("leaveSession()"),
        function(args) return { kind = "leave_call", session = session_name(object(args[2])) } end)

    -- The lobby connection, and the ways out of the Link Party.
    local cloud = type_def("app.Net_CloudSessionRequest")
    watch("Net_CloudSessionRequest.onLeaveSession", cloud and cloud:get_method("onLeaveSession(via.network.Error)"),
        function(args) return { kind = "lobby_leave", engine = error_details(object(args[3])) } end)
    watch("Net_CloudSessionRequest.onConnect", cloud and cloud:get_method("onConnect(via.network.Error)"),
        function(args)
            local engine = error_details(object(args[3]))
            if engine and engine.valid then return { kind = "lobby_connect", engine = engine } end
        end)
    watch("Net_CloudSessionRequest.reqLeaveLinkParty", cloud and cloud:get_method("reqLeaveLinkParty()"),
        function() return { kind = "party_leave", via = "reqLeaveLinkParty" } end)
    local party = type_def("app.Net_Party")
    watch("Net_Party.onLeaveLinkPartySync", party and party:get_method("onLeaveLinkPartySync()"),
        function() return { kind = "party_leave", via = "onLeaveLinkPartySync" } end)
    local sync_leave
    for _, m in ipairs(party and party:get_methods() or {}) do
        if m:get_name():find("leaveLinkPartySync", 1, true) and #param_names(m) == 2 then sync_leave = m end
    end
    watch("Net_Party.leaveLinkPartySync", sync_leave,
        function(args) return { kind = "party_leave", via = "leaveLinkPartySync", option = int32(args[4]) } end)
    return result
end

-- Exposed for tests.
game.SESSION_FIELDS = SESSION_FIELDS
game._int32 = int32
game._cache = cache

return game
