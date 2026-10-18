-- The disconnect log (AntiDisconnect/netlog.lua).

local mock = require("mock_reframework")
local support = require("support")
local eq = support.eq
local runner = support.runner()
local test = runner.test

local env = mock.install()
local lang = require("AntiDisconnect.lang")
local netlog = require("AntiDisconnect.netlog")

local function names(kind, value) return kind .. ":" .. tostring(value) end
local function lobby_kind() return "private" end

test("an entry gets the time and goes to the REFramework log in English", function()
    local l = netlog.new()
    lang.set("id")
    netlog.add(l, { kind = "lobby_closed" }, 1000)
    lang.set("en")
    eq(l.events[1].t, 1000, "time")
    eq(l.dirty, true, "to be saved")
    eq(env.logs[#env.logs], "info: [AntiDisconnect] Lobby connection closed", "English in the log")
end)

test("the same entry again within 10 s only counts", function()
    local l = netlog.new()
    netlog.add(l, { kind = "lobby_error", code = 216009 }, 1000)
    netlog.add(l, { kind = "lobby_error", code = 216009 }, 1005)
    netlog.add(l, { kind = "lobby_error", code = 216009 }, 1010)
    eq(#l.events, 1, "one entry")
    eq(l.events[1].n, 3, "counted")
    eq(netlog.describe(l.events[1]), "Lobby connection error (code 216009) (x3)", "shown with the count")
    netlog.add(l, { kind = "lobby_error", code = 216009 }, 1021)
    eq(#l.events, 2, "a new entry after 10 s")
    netlog.add(l, { kind = "lobby_error", code = 1 }, 1022)
    eq(#l.events, 3, "a different entry is new")
    netlog.add(l, { kind = "app_error", engine = { service = 13, cause = 65 } }, 1023)
    netlog.add(l, { kind = "app_error", engine = { service = 13, cause = 141 } }, 1024)
    eq(#l.events, 5, "nested details make entries different")
end)

test("an alternating flood is counted, not listed (seen in a 100-player lobby)", function()
    local l = netlog.new()
    for i = 1, 100 do
        netlog.add(l, { kind = "session_event", session = "quest", fn = "b__179_1" }, 1000)
        netlog.add(l, { kind = "session_event", session = "quest", fn = "b__179_10" }, 1000)
    end
    eq(#l.events, 2, "two entries")
    eq(l.events[1].n, 100, "counted")
    eq(l.events[2].n, 100, "counted")
end)

test("only the newest entries are kept", function()
    local l = netlog.new()
    for i = 1, netlog.MAX_EVENTS + 25 do netlog.add(l, { kind = "lobby_error", code = i }, i * 100) end
    eq(#l.events, netlog.MAX_EVENTS, "capped")
    eq(l.events[1].code, 26, "oldest dropped")
end)

test("changes of the sessions and the connection", function()
    local l = netlog.new()
    local s = { lobby = "multi", quest = "off", link = "multi" }
    local c = { state = 2, login = 2, local_network = false }
    netlog.observe(l, { sessions = s, context = c }, names, lobby_kind)
    eq(#l.events, 0, "the first look only remembers")
    netlog.observe(l, { sessions = { lobby = "off", quest = "off", link = "multi" }, context = c }, names, lobby_kind)
    eq(l.events[1].kind, "session", "session change")
    eq(netlog.describe(l.events[1]), "Lobby: online with others -> not connected", "text")
    netlog.observe(l, { sessions = { lobby = "multi", quest = "off", link = "multi" }, context = c }, names, lobby_kind)
    eq(l.events[2].lobby_kind, "private", "lobby kind when it comes back")
    eq(netlog.describe(l.events[2]), "Lobby: not connected -> online with others (private)", "text with the kind")
    netlog.observe(l, { sessions = nil, context = { state = 4, login = 3, local_network = true } }, names, lobby_kind)
    eq(#l.events, 4, "context and local network; sessions unknown are skipped; AFK presence is not logged")
    eq(netlog.describe(l.events[3]), "Network: context:2 -> context:4", "context text")
    eq(netlog.describe(l.events[4]), "Local network mode on", "local network text")
    netlog.observe(l, { sessions = nil, context = { state = 4, login = 1, local_network = true } }, names, lobby_kind)
    eq(netlog.describe(l.events[5]), "Your online status: login:3 -> login:1", "going offline is logged")
end)

test("texts of every kind", function()
    local d = netlog.describe
    eq(d({ kind = "start", version = "0.1.0" }), "Anti Disconnect 0.1.0 started", "start")
    eq(d({ kind = "app_error", code = 106003, name = "COMMON_AFK", area = "CONTEXT" }),
        "Game error COMMON_AFK (106003), area CONTEXT", "app error")
    eq(d({ kind = "app_error", raw = -2, area = "LOBBY" }), "Server error -2, area LOBBY", "raw")
    eq(d({ kind = "app_error", engine = { service = 13, cause = 65, service_name = "WebSocketClient", cause_name = "Timeout", text = "t" } }),
        "Game error from the network layer (WebSocketClient / Timeout: t), area ?", "engine app error")
    eq(d({ kind = "engine_error", engine = { service = 3, cause = 131 } }), "Network error: service 3 / cause 131", "names unknown")
    eq(d({ kind = "engine_error" }), "Network error: ?", "no details")
    eq(d({ kind = "afk_saved", minutes = 42 }), "AFK guard kept you online (42 minutes without input)", "afk saved")
    eq(d({ kind = "something new" }), "Unknown entry", "unknown kind")
    eq(d({ kind = "session_event", session = "link", fn = "b__179_9", engine = { service = 3, cause = 131,
        service_name = "Session", cause_name = "PeerNorecvTimeout" } }),
        "Link Party: engine notice b__179_9: Session / PeerNorecvTimeout", "engine notice with a reason")
    eq(d({ kind = "session_event", session = "quest", fn = "b__179_2", self = true }),
        "Quest session: engine notice b__179_2 (about you)", "about this player")
    eq(d({ kind = "session_event", session = "app.cSomethingNew", fn = "b__1_0", host = true }),
        "app.cSomethingNew: engine notice b__1_0 (about the host)", "unknown session type shown as it is")
    eq(d({ kind = "leave_call", session = "link" }), "Link Party: your game leaves this session", "leave")
    eq(d({ kind = "party_leave", via = "reqLeaveLinkParty" }), "Link Party: your game leaves the party (reqLeaveLinkParty)", "party")
    eq(d({ kind = "lobby_leave", engine = { service = 13, cause = 141 } }), "Lobby connection ended: service 13 / cause 141", "lobby leave")
    eq(d({ kind = "lobby_leave" }), "Lobby connection ended (no error reported)", "a normal leave")
    eq(d({ kind = "grace", from = 0, to = 30000000 }),
        "Steam drop: the game now goes offline after 30 s without Steam (was 0 s)", "wait for Steam")
    eq(d({ kind = "grace", from = 30000000, to = 10000 }),
        "Steam drop: the game now goes offline after 0.01 s without Steam (was 30 s)", "put back")
    eq(d({ kind = "grace" }), "Steam drop: the game now goes offline after ? without Steam (was ?)", "values unknown")
    eq(d({ kind = "grace_failed" }), "Steam drop: the longer wait did not stay (the game set it back)", "did not stay")
    eq(d({ kind = "health_failed", session = "link" }),
        "Link Party: the faster \"still here\" signals did not stay (the game set them back)", "did not stay")
    eq(d({ kind = "p2p", session = "quest", class = "via.network.SessionPlayFab", tried = 3, ok = 1 }),
        "Quest session: via.network.SessionPlayFab, direct connections 1 of 3", "p2p")
    eq(d({ kind = "health", session = "link", from = 0, to = 1 }), "Link Party: \"still here\" signals normal -> more often", "health")
    eq(d({ kind = "app_error", code = 106003.0, name = "COMMON_AFK", area = "CONTEXT" }),
        "Game error COMMON_AFK (106003), area CONTEXT", "a code read back from JSON as a float")
    lang.set("id")
    eq(d({ kind = "lobby_closed" }), "Koneksi lobby ditutup", "Indonesian")
    lang.set("en")
end)

test("saved at most every 5 s, read back, and a broken file starts empty", function()
    local l = netlog.new()
    netlog.add(l, { kind = "lobby_closed" }, 1000)
    netlog.save(l, 10)
    eq(#env.written, 1, "written")
    eq(env.written[1].path, netlog.PATH, "path")
    eq(l.dirty, false, "clean")
    netlog.add(l, { kind = "lobby_error", code = 5 }, 1001)
    netlog.save(l, 12)
    eq(#env.written, 1, "not again within 5 s")
    netlog.save(l, 15)
    eq(#env.written, 2, "after 5 s")
    netlog.save(l, 30)
    eq(#env.written, 2, "nothing new, nothing written")
    netlog.add(l, { kind = "lobby_closed" }, 1100)
    netlog.save(l, 31, true)
    eq(#env.written, 3, "forced")

    local back = netlog.new()
    netlog.load(back)
    eq(#back.events, 3, "read back")
    eq(back.events[2].code, 5, "content")

    env.files[netlog.PATH] = { version = 1, events = { { kind = "x" }, "junk", { kind = "lobby_closed", t = 5 } } }
    local partly = netlog.new()
    netlog.load(partly)
    eq(#partly.events, 1, "only valid entries")
    env.files[netlog.PATH] = { version = 1 }   -- an empty list is written as null
    local empty = netlog.new()
    netlog.load(empty)
    eq(#empty.events, 0, "empty")
end)

test("the report holds the header and the newest entries in English", function()
    local l = netlog.new()
    for i = 1, 5 do netlog.add(l, { kind = "lobby_error", code = i }, 1000 + i * 20) end
    lang.set("id")
    local text = netlog.report(l, { "Header line" }, 3)
    lang.set("en")
    eq(text:find("^Header line\n") ~= nil, true, "header first")
    eq(text:find("Log: 5 entries, the newest 3 below", 1, true) ~= nil, true, "counts")
    eq(text:find("(code 2)", 1, true), nil, "older entries left out")
    eq(text:find("Lobby connection error (code 5)", 1, true) ~= nil, true, "newest in, in English")
end)

test("clear", function()
    local l = netlog.new()
    netlog.add(l, { kind = "lobby_closed" }, 1)
    l.dirty = false
    netlog.clear(l)
    eq(#l.events, 0, "cleared")
    eq(l.dirty, true, "to be saved")
end)

runner.run()
