-- The disconnect log: what the game reported about the network, in order, with the time.
-- Entries come from the watching hooks (game.install_hooks) and from changes of the session
-- and connection state seen at every tick (netlog.observe). The newest MAX_EVENTS entries are
-- kept in reframework/data/AntiDisconnect/events.json, and every new entry also goes to the
-- REFramework log in English.
--
-- No entry identifies another player: no names, no hunter ids, no lobby ids.

local files = require("AntiDisconnect.files")
local lang = require("AntiDisconnect.lang")

local netlog = {}

local PATH = "AntiDisconnect/events.json"
local VERSION = 1
local MAX_EVENTS = 300
local SAVE_SECONDS = 5        -- at most one write of the file per this many seconds
local REPEAT_SECONDS = 10     -- the same entry again within this time only raises its count...
local REPEAT_LOOKBACK = 10    -- ...when it is among this many newest entries (floods alternate)
local OFFLINE = 1             -- ace_network.EnumHunterLoginStatus.OFFLINE
local SESSIONS = { "lobby", "quest", "link" }

function netlog.new()
    return { events = {}, dirty = false, saved_at = -math.huge, snapshot = nil }
end

-- Everything that makes an entry what it is (not its time or count), as one string.
local function signature(event)
    local parts = {}
    for k, v in pairs(event) do
        if k ~= "t" and k ~= "n" then
            if type(v) == "table" then
                for k2, v2 in pairs(v) do parts[#parts + 1] = k .. "." .. tostring(k2) .. "=" .. tostring(v2) end
            else
                parts[#parts + 1] = k .. "=" .. tostring(v)
            end
        end
    end
    table.sort(parts)
    return table.concat(parts, ";")
end

local function engine_text(e)
    if type(e) ~= "table" then return "?" end
    local result = (e.service_name or ("service " .. tostring(e.service))) .. " / "
        .. (e.cause_name or ("cause " .. tostring(e.cause)))
    if e.text then result = result .. ": " .. e.text end
    return result
end

-- "Quest session" for "quest"; an unknown session type is shown as it is.
local function session_label(tr, session)
    local key = "session_" .. tostring(session)
    local label = tr(key)
    if label == key then return tostring(session) end
    return label
end

-- 30000000 microseconds -> "30 s" ("?" when unknown).
function netlog.duration(tr, microseconds)
    if type(microseconds) ~= "number" then return "?" end
    return tr("seconds", string.format("%g", microseconds / 1000000))
end

-- One line for an entry. `tr` is lang.T (the chosen language) or lang.english (the log).
function netlog.describe(event, tr)
    tr = tr or lang.T
    local kind = event.kind
    local line
    if kind == "start" then
        line = tr("ev_start", tostring(event.version))
    elseif kind == "session" then
        line = tr("ev_session", session_label(tr, event.session), tr("state_" .. tostring(event.from)),
            tr("state_" .. tostring(event.to)))
        if event.lobby_kind then line = line .. " (" .. event.lobby_kind .. ")" end
    elseif kind == "session_event" then
        line = tr("ev_session_event", session_label(tr, event.session), tostring(event.fn))
        if event.self then line = line .. tr("ev_about_you") elseif event.host then line = line .. tr("ev_about_host") end
        if event.engine then line = line .. ": " .. engine_text(event.engine) end
    elseif kind == "leave_call" then
        line = tr("ev_leave_call", session_label(tr, event.session))
    elseif kind == "party_leave" then
        line = tr("ev_party_leave", tostring(event.via))
    elseif kind == "lobby_leave" then
        line = event.engine and tr("ev_lobby_leave", engine_text(event.engine)) or tr("ev_lobby_leave_clean")
    elseif kind == "health_failed" then
        line = tr("ev_health_failed", session_label(tr, event.session))
    elseif kind == "lobby_connect" then
        line = tr("ev_lobby_connect", engine_text(event.engine))
    elseif kind == "p2p" then
        line = tr("ev_p2p", session_label(tr, event.session), tostring(event.class or "?"),
            math.tointeger(event.ok) or 0, math.tointeger(event.tried) or 0)
    elseif kind == "health" then
        line = tr("ev_health", session_label(tr, event.session), tr("health_" .. tostring(math.tointeger(event.from))),
            tr("health_" .. tostring(math.tointeger(event.to))))
    elseif kind == "grace" then
        line = tr("ev_grace", netlog.duration(tr, event.to), netlog.duration(tr, event.from))
    elseif kind == "grace_failed" then
        line = tr("ev_grace_failed")
    elseif kind == "context" then
        line = tr("ev_context", tostring(event.from), tostring(event.to))
    elseif kind == "local_network" then
        line = event.on and tr("ev_local_on") or tr("ev_local_off")
    elseif kind == "login" then
        line = tr("ev_login", tostring(event.from), tostring(event.to))
    elseif kind == "app_error" then
        local area = tostring(event.area or "?")
        if event.code then
            line = tr("ev_app_error", tostring(event.name or "?"), math.tointeger(event.code) or 0, area)
        elseif event.raw then
            line = tr("ev_app_error_raw", math.tointeger(event.raw) or 0, area)
        else
            line = tr("ev_app_error_engine", engine_text(event.engine), area)
        end
    elseif kind == "engine_error" then
        line = tr("ev_engine_error", engine_text(event.engine))
    elseif kind == "lobby_closed" then
        line = tr("ev_lobby_closed")
    elseif kind == "lobby_error" then
        line = tr("ev_lobby_error", math.tointeger(event.code) or -1)
    elseif kind == "afk_saved" then
        line = tr("ev_afk_saved", math.tointeger(event.minutes) or 0)
    else
        line = tr("ev_unknown")
    end
    if (event.n or 1) > 1 then line = line .. tr("log_repeat", math.tointeger(event.n) or 0) end
    return line
end

-- Adds an entry with the current time (or `wall`, seconds since 1970).
function netlog.add(log_state, event, wall)
    wall = wall or os.time()
    local events = log_state.events
    local sig = signature(event)
    for i = #events, math.max(1, #events - REPEAT_LOOKBACK + 1), -1 do
        local recent = events[i]
        if type(recent.t) ~= "number" or wall - recent.t > REPEAT_SECONDS then break end
        if signature(recent) == sig then
            recent.n = (recent.n or 1) + 1
            log_state.dirty = true
            return
        end
    end
    event.t = wall
    events[#events + 1] = event
    while #events > MAX_EVENTS do table.remove(events, 1) end
    log.info("[AntiDisconnect] " .. netlog.describe(event, lang.english))
    log_state.dirty = true
end

-- Adds entries for what changed since the last tick.
-- snapshot = { sessions = { lobby, quest, link } or nil, context = { state, login, local_network } }
-- name(kind, value) gives an enum name for the log; lobby_kind() says what kind of lobby you
-- are in. Both are only called for a change.
function netlog.observe(log_state, snapshot, name, lobby_kind)
    local before = log_state.snapshot
    log_state.snapshot = snapshot
    if not before then return end
    local was, now = before.sessions, snapshot.sessions
    if was and now then
        for _, session in ipairs(SESSIONS) do
            if was[session] ~= now[session] then
                local event = { kind = "session", session = session, from = was[session], to = now[session] }
                if session == "lobby" and now[session] ~= "off" then event.lobby_kind = lobby_kind() end
                netlog.add(log_state, event)
            end
        end
    end
    local a, b = before.context or {}, snapshot.context or {}
    if a.state and b.state and a.state ~= b.state then
        netlog.add(log_state, { kind = "context", from = name("context", a.state), to = name("context", b.state) })
    end
    if a.local_network ~= nil and b.local_network ~= nil and a.local_network ~= b.local_network then
        netlog.add(log_state, { kind = "local_network", on = b.local_network })
    end
    -- Online and Idle come and go with every pause; only going offline or coming back is kept.
    if a.login and b.login and a.login ~= b.login and (a.login == OFFLINE or b.login == OFFLINE) then
        netlog.add(log_state, { kind = "login", from = name("login", a.login), to = name("login", b.login) })
    end
end

-- Reads the entries of earlier sessions. A missing or corrupt file starts an empty log.
function netlog.load(log_state)
    local status, loaded = files.read_json(PATH)
    if status ~= "ok" or type(loaded) ~= "table" or type(loaded.events) ~= "table" then return end
    for _, event in ipairs(loaded.events) do
        if type(event) == "table" and type(event.kind) == "string" and type(event.t) == "number" then
            log_state.events[#log_state.events + 1] = event
        end
    end
    while #log_state.events > MAX_EVENTS do table.remove(log_state.events, 1) end
end

-- Writes the file when something changed, at most every SAVE_SECONDS unless `force`.
function netlog.save(log_state, now, force)
    if not log_state.dirty then return end
    if not force and now - log_state.saved_at < SAVE_SECONDS then return end
    log_state.saved_at = now
    -- REFramework writes an empty list as null, which netlog.load reads as an empty log.
    if files.write_json(PATH, { version = VERSION, events = log_state.events }) then log_state.dirty = false end
end

-- The text of "Copy report": the header lines, then the newest `count` entries (oldest
-- first) in English with date and time.
function netlog.report(log_state, header, count)
    local lines = {}
    for _, line in ipairs(header) do lines[#lines + 1] = line end
    local events = log_state.events
    local first = math.max(1, #events - count + 1)
    lines[#lines + 1] = string.format("Log: %d entries, the newest %d below (oldest first)", #events, #events - first + 1)
    for i = first, #events do
        local event = events[i]
        local t = type(event.t) == "number" and os.date("%Y-%m-%d %H:%M:%S", event.t) or "?"
        lines[#lines + 1] = t .. "  " .. netlog.describe(event, lang.english)
    end
    return table.concat(lines, "\n") .. "\n"
end

function netlog.clear(log_state)
    log_state.events = {}
    log_state.dirty = true
end

netlog.PATH = PATH
netlog.MAX_EVENTS = MAX_EVENTS

return netlog
