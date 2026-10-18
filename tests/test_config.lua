-- Settings (AntiDisconnect/config.lua).

local mock = require("mock_reframework")
local support = require("support")
local eq = support.eq
local runner = support.runner()
local test = runner.test

local env = mock.install()
local config = require("AntiDisconnect.config")

test("defaults: the guard is on, quests with other players keep the kick", function()
    local s = config.load()
    eq(s.afk_guard, true, "guard")
    eq(s.afk_public_quests, false, "public quests")
    eq(s.afk_welcome, true, "welcome message")
    eq(s.steady_link, false, "the steady link experiment is off")
    eq(s.steam_grace, true, "waiting for Steam is on")
    eq(s.language, "en", "language")
    eq(s.toast_seconds, 12, "toast seconds")
end)

test("wrong values fall back to the defaults, unknown keys are dropped", function()
    local s = config.validate({ afk_guard = "yes", afk_public_quests = true, language = "fr", toast_seconds = 999, extra = 1 })
    eq(s.afk_guard, true, "bad type")
    eq(s.afk_public_quests, true, "good value kept")
    eq(s.language, "en", "unknown language")
    eq(s.toast_seconds, 12, "out of range")
    eq(s.extra, nil, "unknown key")
    eq(config.validate({ language = "id", toast_seconds = 30 }).toast_seconds, 30, "in range")
end)

test("save and load", function()
    local s = config.load()
    s.afk_guard = false
    s.language = "id"
    eq(config.save(s), true, "saved")
    eq(env.written[#env.written].path, config.PATH, "path")
    eq(env.written[#env.written].data.version, 1, "version written")
    local back = config.load()
    eq(back.afk_guard, false, "guard read back")
    eq(back.language, "id", "language read back")
end)

runner.run()
