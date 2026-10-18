-- The AFK guard's decisions (AntiDisconnect/afk.lua); no game needed.

local afk = require("AntiDisconnect.afk")
local support = require("support")
local eq = support.eq
local runner = support.runner()
local test = runner.test

local LIMITS = { idle = 180, kick = 1800, read = true }
local ON = { afk_guard = true, afk_public_quests = false }

local function reading(timer, lobby, quest, link, strangers)
    return { timer = timer, limits = LIMITS, strangers = strangers,
        sessions = { lobby = lobby or "off", quest = quest or "off", link = link or "off" } }
end

test("in an online lobby the timer is held a minute below the kick", function()
    local g = afk.new()
    eq(afk.step(g, reading(1000, "multi"), ON, 0).set_timer, nil, "below the limit nothing is written")
    eq(g.status, "status_lobby", "status")
    eq(g.held, false, "not held yet")
    local r = afk.step(g, reading(1741, "multi"), ON, 10)
    eq(r.set_timer, 1740, "held at kick - 60")
    eq(g.held, true, "held")
    eq(g.idle_start, 10 - 1741, "input stopped when the timer started")
    eq(afk.step(g, reading(1740.4, "multi"), ON, 10.5).set_timer, 1740, "held again on the next look")
end)

test("the Idle status is left alone: nothing is written below the ceiling", function()
    local g = afk.new()
    for _, t in ipairs({ 0, 179, 181, 600, 1739.9 }) do
        eq(afk.step(g, reading(t, "multi"), ON, t).set_timer, nil, "timer " .. t)
    end
end)

test("a Link Party without a lobby is protected", function()
    local g = afk.new()
    eq(afk.step(g, reading(1790, "off", "off", "multi"), ON, 0).set_timer, 1740, "held")
    eq(g.status, "status_link", "status")
end)

test("alone or offline there is nothing to do", function()
    for _, scene in ipairs({ { "off" }, { "solo" }, { "solo", "solo", "solo" } }) do
        local g = afk.new()
        eq(afk.step(g, reading(1790, scene[1], scene[2], scene[3]), ON, 0).set_timer, nil, "not held")
        eq(g.status, "status_not_needed", "status")
    end
end)

test("a quest with players outside the Link Party keeps the game's kick", function()
    local g = afk.new()
    eq(afk.step(g, reading(1790, "multi", "multi", "multi", true), ON, 0).set_timer, nil, "not held, even with a lobby")
    eq(g.status, "status_strangers", "status")
end)

test("a quest with only the Link Party is protected", function()
    local g = afk.new()
    eq(afk.step(g, reading(1790, "multi", "multi", "multi", false), ON, 0).set_timer, 1740, "held")
    eq(g.status, "status_quest", "status")
end)

test("a quest whose members cannot be read keeps the game's kick", function()
    local g = afk.new()
    eq(afk.step(g, reading(1790, "multi", "multi", "off", nil), ON, 0).set_timer, nil, "not held")
    eq(g.status, "status_unknown", "status")
end)

test("afk_public_quests protects every quest", function()
    local g = afk.new()
    local all = { afk_guard = true, afk_public_quests = true }
    eq(afk.step(g, reading(1790, "multi", "multi", "off", true), all, 0).set_timer, 1740, "with strangers")
    eq(g.status, "status_quest_all", "status")
    eq(afk.step(afk.new(), reading(1790, "off", "multi", "off", nil), all, 0).set_timer, 1740, "members unknown")
end)

test("guard off, timer missing, game not ready", function()
    local g = afk.new()
    eq(afk.step(g, reading(1790, "multi"), { afk_guard = false }, 0).set_timer, nil, "off")
    eq(g.status, "status_off", "off status")
    eq(afk.step(g, reading(nil, "multi"), ON, 0).set_timer, nil, "no timer")
    eq(g.status, "status_unavailable", "unavailable status")
    local r = { timer = 1790, limits = LIMITS, sessions = nil }
    eq(afk.step(g, r, ON, 0).set_timer, nil, "no sessions")
    eq(g.status, "status_starting", "starting status")
end)

test("coming back after more than the kick time counts as saved", function()
    local g = afk.new()
    afk.step(g, reading(1745, "multi"), ON, 100)   -- input stopped at 100 - 1745 = -1645
    afk.step(g, reading(1740, "multi"), ON, 160)
    local r = afk.step(g, reading(0.2, "multi"), ON, 400)   -- 2045 s without input
    eq(r.saved_minutes, 34, "minutes")
    eq(r.set_timer, nil, "nothing written")
    eq(g.saves, 1, "count")
    eq(g.held, false, "released")
end)

test("coming back before the kick time is not counted", function()
    local g = afk.new()
    afk.step(g, reading(1745, "multi"), ON, 0)
    local r = afk.step(g, reading(0, "multi"), ON, 30)   -- 1775 s: the game would not have kicked yet
    eq(r.saved_minutes, nil, "not saved")
    eq(g.saves, 0, "count")
    eq(g.held, false, "released")
end)

test("losing the protection while held hands the timer back to the game", function()
    local g = afk.new()
    afk.step(g, reading(1745, "multi"), ON, 0)
    local r = afk.step(g, reading(1740, "multi", "multi", "off", true), ON, 1)
    eq(r.set_timer, nil, "not held in a quest with other players")
    eq(g.held, false, "released")
    local back = afk.step(g, reading(0, "multi"), ON, 5000)
    eq(back.saved_minutes, nil, "the kick may have happened: nothing is claimed")
end)

test("other limits", function()
    eq(afk.ceiling({ kick = 3600 }), 3540, "one minute below")
    eq(afk.ceiling({ kick = 120 }), 90, "a quarter below for short limits")
    local g = afk.new()
    local r = afk.step(g, { timer = 3550, limits = { idle = 180, kick = 3600 }, sessions = { lobby = "multi" } }, ON, 0)
    eq(r.set_timer, 3540, "held below 3600")
end)

test("idle seconds are real time while the timer is held", function()
    local g = afk.new()
    local r = reading(1745, "multi")
    afk.step(g, r, ON, 100)
    eq(afk.idle_seconds(g, r, 400), 2045, "real idle time")
    eq(afk.idle_seconds(afk.new(), reading(42, "multi"), 0), 42, "the game's timer otherwise")
end)

runner.run()
