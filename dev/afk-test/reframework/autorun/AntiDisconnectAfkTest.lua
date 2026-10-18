-- Anti Disconnect, development test set (deploy.ps1 -Dev afk-test). Never part of a release.
--
-- Shows the game's AFK state live and offers the tests of the first in-game session
-- (design/riset-anti-disconnect.md, section 8):
--   T1  watch: the idle timer grows while you are idle in an online lobby and drops to 0 on
--       input; the limits read 180 and 1800.
--   T2  "idle timer = 175": about 5 s later your online status turns AFK (Idle).
--   T3  with the mod's AFK guard OFF, "idle timer = 1780": about 20 s later the game kicks you
--       to Online Single Player, and the mod's log shows COMMON_AFK (106003).
--   T4  with the guard ON, the same button: no kick; the timer stays at 1740.
-- The test buttons wait 5 s first, so the click that pressed them does not reset the timer.
-- Close the REFramework menu and keep your hands off the keyboard, mouse and pad afterwards.
--
-- Game calls only happen on the game thread (UpdateBehavior); the panel reads Lua state.

local P = "[AntiDisconnect test] "
local DELAY = 5
local LOGIN = { [1] = "OFFLINE", [2] = "ONLINE", [3] = "AFK", [4] = "BUSY" }
local CONTEXT = { [0] = "INACTIVE", [1] = "BOOTUP", [2] = "ACTIVE", [3] = "SHUTDOWN", [4] = "FAILRE" }
local SESSIONS = { { "LOBBY", 1 }, { "QUEST", 2 }, { "LINK", 3 } }

local live = {}            -- what the last tick read, for the panel
local pending = nil        -- { at, timer } a test write waiting for its time
local dump_requested = false
local last = {}            -- values of the previous tick, to log changes
local next_tick = 0

local function safe(fn, ...)
    local ok, value = pcall(fn, ...)
    if ok then return value end
    return nil
end

local function field(obj, name)
    if obj == nil then return nil end
    return safe(function() return obj:get_field(name) end)
end

local function call(obj, name, ...)
    if obj == nil then return nil end
    local args = { ... }
    return safe(function() return obj:call(name, table.unpack(args)) end)
end

local function static(type_name, name)
    local td = sdk.find_type_definition(type_name)
    local f = td and td:get_field(name)
    return f and safe(f.get_data, f, nil)
end

local function member_count(manager, session)
    local list = call(manager, "getUserInfoList", session)
    local infos = field(list, "_ListInfo")
    if not infos then return nil end
    local valid = 0
    for i = 0, (safe(function() return infos:get_size() end) or 0) - 1 do
        local info = safe(function() return infos:get_element(i) end)
        if info and call(info, "get_IsValid") == true then valid = valid + 1 end
    end
    return valid
end

local function read_live()
    local r = {}
    local gim = sdk.get_managed_singleton("app.GameInputManager")
    r.NoInputTimer = field(gim, "_NoInputTimer")
    r.TO_NO_INPUT_TIME = static("app.GameInputManager", "TO_NO_INPUT_TIME")
    r.TO_NO_INPUT_DISCONNECT_TIME = static("app.GameInputManager", "TO_NO_INPUT_DISCONNECT_TIME")
    local nm = sdk.get_managed_singleton("app.NetworkManager")
    local cm = field(nm, "_ContextManager")
    r.LoginStatus = field(cm, "_LoginStatus")
    r.ContextState = field(cm, "_ContextState")
    r.IsDisconnectErrorShow = field(cm, "_IsDisconnectErrorShow")
    r.IsLocalNetwork = call(nm, "get_IsLocalNetwork")
    local ss = field(nm, "_SessionService")
    local uim = field(nm, "_UserInfoManager")
    for _, s in ipairs(SESSIONS) do
        r["isOnline_" .. s[1]] = call(ss, "isOnline", s[2])
        r["isMultiplay_" .. s[1]] = call(ss, "isMultiplay", s[2])
        r["members_" .. s[1]] = member_count(uim, s[2])
    end
    return r
end

local function log_changes(r)
    for _, key in ipairs({ "LoginStatus", "ContextState", "IsDisconnectErrorShow", "isMultiplay_LOBBY",
        "isMultiplay_QUEST", "isMultiplay_LINK", "isOnline_LOBBY", "IsLocalNetwork" }) do
        if r[key] ~= last[key] then
            log.info(string.format("%s%s %s -> %s (NoInputTimer %.1f)", P, key, tostring(last[key]), tostring(r[key]),
                tonumber(r.NoInputTimer) or -1))
            last[key] = r[key]
        end
    end
end

-- P1: the names the mod uses, as REFramework sees them in this game version.
local function dump_types()
    local function dump(type_name, filter)
        local td = sdk.find_type_definition(type_name)
        if not td then
            log.info(P .. "MISSING type " .. type_name)
            return
        end
        log.info(P .. "== " .. type_name)
        for _, f in ipairs(td:get_fields() or {}) do
            local name = f:get_name()
            if not filter or name:lower():find(filter) then
                log.info(string.format("%sF %s static=%s", P, name, tostring(f:is_static())))
            end
        end
        for _, m in ipairs(td:get_methods() or {}) do
            local name = m:get_name()
            if not filter or name:lower():find(filter) then
                local params = {}
                for _, p in ipairs(m:get_param_types() or {}) do params[#params + 1] = p:get_full_name() end
                log.info(string.format("%sM %s(%s)", P, name, table.concat(params, ", ")))
            end
        end
    end
    dump("app.GameInputManager", "input")
    dump("app.net_context_manager.cContextManager", "input")
    dump("app.net_context_manager.cContextManager", "login")
    dump("app.net_context_manager.cContextManager", "disconnect")
    dump("app.Net_SessionService", "multiplay")
    dump("app.Net_SessionService", "online")
    dump("app.Net_UserInfoManager", "userinfo")
    dump("app.Net_UserInfo", "id")
    dump("app.Net_UserInfo", "self")
    dump("app.Net_UserInfo", "valid")
    dump("app.NetworkErrorManager", "requestapperror")
    dump("app.NetworkRequestManager", "onerror")
    dump("app.net_lobby_session.cLobbySession", "websocket")
    log.info(P .. "type dump done")
end

re.on_pre_application_entry("UpdateBehavior", function()
    if dump_requested then
        dump_requested = false
        pcall(dump_types)
    end
    local now = os.clock()
    if pending and now >= pending.at then
        local value = pending.timer
        pending = nil
        local gim = sdk.get_managed_singleton("app.GameInputManager")
        local ok = gim and pcall(function() gim:set_field("_NoInputTimer", value) end)
        log.info(string.format("%sTEST set _NoInputTimer = %.0f (%s)", P, value, ok and "done" or "FAILED"))
    end
    if now < next_tick then return end
    next_tick = now + 0.25
    local ok, r = pcall(read_live)
    if ok and r then
        live = r
        log_changes(r)
    end
end)

re.on_draw_ui(function()
    if not imgui.tree_node("Anti Disconnect: AFK test (dev)") then return end
    local keys = {}
    for k in pairs(live) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local v = live[k]
        if k == "LoginStatus" then v = tostring(v) .. " " .. tostring(LOGIN[v]) end
        if k == "ContextState" then v = tostring(v) .. " " .. tostring(CONTEXT[v]) end
        if type(v) == "number" then v = string.format("%.2f", v) end
        imgui.text(k .. " = " .. tostring(v))
    end
    if pending then
        imgui.text(string.format("Waiting: _NoInputTimer = %.0f in %.0f s. Hands off!", pending.timer, pending.at - os.clock()))
    end
    if imgui.button("T2: in 5 s set the idle timer to 175 s (Idle status about 5 s later)") then
        pending = { at = os.clock() + DELAY, timer = 175.0 }
    end
    if imgui.button("T3/T4: in 5 s set the idle timer to 1780 s (kick about 20 s later unless the guard is on)") then
        pending = { at = os.clock() + DELAY, timer = 1780.0 }
    end
    if imgui.button("P1: write the names the mod uses to the log") then dump_requested = true end
    imgui.tree_pop()
end)

log.info(P .. "loaded")
