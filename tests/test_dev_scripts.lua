-- The development test set (dev/afk-test) loads, shows the live values and runs its tests.

local mock = require("mock_reframework")
local fake = require("fake_game")
local support = require("support")
local eq = support.eq
local runner = support.runner()
local test = runner.test

local env = mock.install()
env.use_fake_clock()
env.guard_draw = true   -- the panel only reads Lua state
local world = fake.build(env)
dofile(PROJECT_ROOT .. "/dev/afk-test/reframework/autorun/AntiDisconnectAfkTest.lua")
local frame = env.entries["UpdateBehavior"]

local function tick(seconds)
    env.advance(seconds or 0.25)
    frame()
end

test("shows the live values", function()
    world.set("multi", "off", "off")
    world.members[1] = { { id = "ME", self = true }, { id = "OTHER" } }
    world.set_timer(42)
    tick()
    env.draw()
    eq(env.has("NoInputTimer = 42.00"), true, "timer")
    eq(env.has("TO_NO_INPUT_DISCONNECT_TIME = 1800.00"), true, "kick limit")
    eq(env.has("isMultiplay_LOBBY = true"), true, "lobby flag")
    eq(env.has("members_LOBBY = 2.00"), true, "members")
    eq(env.has("LoginStatus = 2 ONLINE"), true, "login status")
end)

test("a test write waits 5 s", function()
    env.draw({ "T3/T4: in 5 s set the idle timer to 1780 s (kick about 20 s later unless the guard is on)" })
    tick(1)
    eq(world.timer(), 42, "not yet")
    env.draw()
    eq(env.has_text("^Waiting: _NoInputTimer = 1780"), true, "waiting shown")
    tick(5)
    eq(world.timer(), 1780.0, "written")
    eq(env.logs[#env.logs]:find("TEST set _NoInputTimer = 1780 (done)", 1, true) ~= nil, true, "logged")
end)

test("changes are logged", function()
    world.context.values._LoginStatus = 3
    tick()
    local found = false
    for _, line in ipairs(env.logs) do
        if line:find("LoginStatus 2 -> 3", 1, true) then found = true end
    end
    eq(found, true, "login status change")
end)

test("the name dump runs", function()
    env.draw({ "P1: write the names the mod uses to the log" })
    tick()
    eq(env.logs[#env.logs]:find("type dump done", 1, true) ~= nil, true, "done")
end)

runner.run()
