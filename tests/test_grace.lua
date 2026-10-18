-- The "wait for Steam" experiment (AntiDisconnect/grace.lua).

local grace = require("AntiDisconnect.grace")
local support = require("support")
local eq = support.eq
local runner = support.runner()
local test = runner.test

local OFF, ON = { steam_grace = false }, { steam_grace = true }
local ACTIVE, FAILED = 2, 4
local WAIT = grace.WAIT_US

local function info(detect, state) return { detect = detect, state = state or ACTIVE } end

test("30 seconds, in microseconds", function()
    eq(WAIT, 30000000, "the engine compares microseconds")
end)

test("on: the wait is set once, and logged when it stayed", function()
    local st = grace.new()
    local out = grace.step(st, info(0), ON, 1)
    eq(out.set, WAIT, "set")
    eq(#out.events, 0, "not logged before it is seen")
    local stayed = grace.step(st, info(WAIT), ON, 1.5)
    eq(stayed.set, nil, "not again")
    eq(stayed.events[1].kind, "grace", "logged")
    eq(stayed.events[1].from, 0, "from the game's value")
    eq(stayed.events[1].to, WAIT, "to the wait")
    local quiet = grace.step(st, info(WAIT), ON, 2)
    eq(quiet.set == nil and #quiet.events == 0, true, "then quiet")
end)

test("only while the context is active (one that is not running ignores it)", function()
    local st = grace.new()
    local out = grace.step(st, info(0, 1), ON, 1)
    eq(out.set, nil, "booting: not set")
    eq(#out.events, 0, "nothing logged")
    eq(grace.step(st, info(nil), ON, 1).set, nil, "not Steam, or not readable: nothing")
    eq(grace.step(st, info(0), ON, 2).set, WAIT, "set once active")
end)

test("a new context starts with the game's value: set again", function()
    local st = grace.new()
    grace.step(st, info(0), ON, 1)
    grace.step(st, info(WAIT), ON, 1.5)
    grace.step(st, info(0, FAILED), ON, 100)   -- Steam was gone too long; the game makes a new context
    local again = grace.step(st, info(0), ON, 120)
    eq(again.set, WAIT, "set again")
    eq(grace.step(st, info(WAIT), ON, 120.5).events[1].kind, "grace", "logged again")
end)

test("if it does not stay: logged once, tried again every 10 s", function()
    local st = grace.new()
    grace.step(st, info(0), ON, 1)
    eq(grace.step(st, info(0), ON, 5).set, nil, "waits before trying again")
    local retry = grace.step(st, info(0), ON, 11)
    eq(retry.set, WAIT, "tried again")
    eq(retry.events[1].kind, "grace_failed", "told")
    local later = grace.step(st, info(0), ON, 21)
    eq(later.set, WAIT, "and again")
    eq(#later.events, 0, "told only once")
    local stayed = grace.step(st, info(WAIT), ON, 21.5)
    eq(stayed.events[1].from, 0, "the value it replaced")
end)

test("off: the value from before is put back once", function()
    local st = grace.new()
    grace.step(st, info(5000), ON, 1)
    grace.step(st, info(WAIT), ON, 1.5)
    local back = grace.step(st, info(WAIT), OFF, 2)
    eq(back.set, 5000, "the game's own value")
    eq(back.events[1].kind, "grace", "logged")
    eq(back.events[1].to, 5000, "to")
    local quiet = grace.step(st, info(5000), OFF, 2.5)
    eq(quiet.set == nil and #quiet.events == 0, true, "nothing more")
    eq(grace.step(st, info(5000), ON, 3).set, WAIT, "on again: set again")
end)

test("off after \"Reset scripts\" (seen in game): our 30 s goes back to the game's own value", function()
    local st = grace.new()   -- the script started again; the context still has our value
    local back = grace.step(st, info(WAIT), OFF, 1)
    eq(back.set, grace.GAME_US, "the game's value")
    eq(back.events[1].to, 0, "logged")
    local again = grace.step(st, info(WAIT), OFF, 1.5)
    eq(again.set == nil and #again.events == 0, true, "tried once, not every tick")
    eq(grace.step(st, info(WAIT), ON, 2).set, nil, "on: already set, nothing to do")
end)

test("off by default: nothing is changed", function()
    local st = grace.new()
    local out = grace.step(st, info(0), OFF, 1)
    eq(out.set == nil and #out.events == 0, true, "untouched")
    grace.step(st, info(0), ON, 2)
    local back = grace.step(st, info(0), OFF, 2.5)
    eq(back.set == nil and #back.events == 0, true, "turned off before it stayed: nothing to put back")
end)

runner.run()
