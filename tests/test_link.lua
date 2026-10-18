-- The quest and Link Party connections and the steady link experiment (AntiDisconnect/link.lua).

local link = require("AntiDisconnect.link")
local support = require("support")
local eq = support.eq
local runner = support.runner()
local test = runner.test

local OFF, ON = { steady_link = false }, { steady_link = true }

local function info(health, online, tried, ok)
    return { class = "via.network.SessionPlayFab", health = health, online = online ~= false, p2p_tried = tried or 0, p2p_ok = ok or 0 }
end

local function count(events, kind)
    local n = 0
    for _, e in ipairs(events) do if e.kind == kind then n = n + 1 end end
    return n
end

test("steady link raises the health check rate of the online quest and Link Party", function()
    local st = link.new()
    local out = link.step(st, { lobby = info(0), quest = info(0), link = info(0) }, ON)
    eq(#out.sets, 2, "quest and link, not the lobby")
    eq(out.sets[1][1], "quest", "quest first")
    eq(out.sets[1][2], link.HIGHEST, "highest")
    eq(count(out.events, "health"), 2, "logged")
    eq(#link.step(st, { quest = info(1), link = info(1) }, ON).sets, 0, "nothing when it stuck")
end)

test("a session that is not running is left alone (in game it ignores the setting)", function()
    local st = link.new()
    local out = link.step(st, { quest = info(0, false), link = info(0, false) }, ON)
    eq(#out.sets, 0, "not set")
    eq(#out.events, 0, "nothing logged")
end)

test("set once per time online; if the game sets it back, that is logged once", function()
    local st = link.new()
    eq(#link.step(st, { quest = info(0) }, ON).sets, 1, "first try")
    local back = link.step(st, { quest = info(0) }, ON)
    eq(#back.sets, 0, "no second try")
    eq(count(back.events, "health_failed"), 1, "told once")
    local again = link.step(st, { quest = info(0) }, ON)
    eq(#again.sets + #again.events, 0, "then quiet")
    link.step(st, { quest = info(0, false) }, ON)   -- the quest ended
    eq(#link.step(st, { quest = info(0) }, ON).sets, 1, "a new quest gets a new try")
end)

test("turning it off puts the old value back", function()
    local st = link.new()
    link.step(st, { quest = info(0) }, ON)
    local back = link.step(st, { quest = info(1) }, OFF)
    eq(back.sets[1][2], 0, "the value from before")
    eq(back.events[1].to, 0, "logged")
    eq(#link.step(st, { quest = info(0) }, OFF).sets, 0, "nothing more")
    eq(#link.step(st, { quest = info(0) }, ON).sets, 1, "on again: a new try")
end)

test("off by default: nothing is changed", function()
    local st = link.new()
    eq(#link.step(st, { quest = info(0), link = info(0) }, OFF).sets, 0, "untouched")
    eq(#link.step(st, { quest = info(nil) }, ON).sets, 0, "a rate that cannot be read is left alone")
end)

test("direct and relayed connections are logged when they change", function()
    local st = link.new()
    eq(#link.step(st, { quest = info(0, true, 0, 0) }, OFF).events, 0, "nothing tried yet")
    local out = link.step(st, { quest = info(0, true, 3, 1) }, OFF)
    eq(out.events[1].kind, "p2p", "logged")
    eq(out.events[1].tried, 3, "tried")
    eq(out.events[1].ok, 1, "made")
    eq(#link.step(st, { quest = info(0, true, 3, 1) }, OFF).events, 0, "only changes")
    eq(#link.step(st, {}, OFF).events, 0, "no session")
end)

runner.run()
