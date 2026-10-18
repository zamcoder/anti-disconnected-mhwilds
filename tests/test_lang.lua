-- Languages (AntiDisconnect/lang.lua and AntiDisconnect/lang/*.lua).

local lang = require("AntiDisconnect.lang")
local support = require("support")
local eq = support.eq
local runner = support.runner()
local test = runner.test

test("Indonesian has every text, with the same values in the same order", function()
    local id = require("AntiDisconnect.lang.id")
    local missing, extra, other = {}, {}, {}
    for key, text in pairs(lang.EN) do
        if id[key] == nil then missing[#missing + 1] = key end
        if id[key] and lang._placeholders(id[key]) ~= lang._placeholders(text) then other[#other + 1] = key end
    end
    for key in pairs(id) do
        if lang.EN[key] == nil then extra[#extra + 1] = key end
    end
    table.sort(missing)
    table.sort(extra)
    table.sort(other)
    eq(#missing, 0, "missing: " .. table.concat(missing, ", "))
    eq(#extra, 0, "not in English: " .. table.concat(extra, ", "))
    eq(#other, 0, "other values: " .. table.concat(other, ", "))
    eq(lang.set("id"), "id", "loaded")
    eq(#lang.rejected, 0, "nothing rejected")
    lang.set("en")
end)

test("texts are ASCII except the middle dot", function()
    for _, texts in ipairs({ lang.EN, require("AntiDisconnect.lang.id") }) do
        for key, text in pairs(texts) do
            local rest = text:gsub("\194\183", "")
            eq(rest:find("[\128-\255]") == nil, true, "key " .. key)
        end
    end
end)

test("switching languages, and the English log text", function()
    eq(lang.code(), "en", "English first")
    local before = lang.revision()
    eq(lang.set("id"), "id", "Indonesian")
    eq(lang.revision() > before, true, "revision goes up")
    eq(lang.T("log_title"), "Catatan disconnect", "translated")
    eq(lang.english("log_title"), "Disconnect log", "the log stays English")
    eq(lang.T("ev_lobby_error", 7), "Error koneksi lobby (kode 7)", "with a value")
    eq(lang.T("no such key"), "no such key", "unknown key shows the key")
    eq(lang.set("xx"), "en", "unknown language is English")
    eq(lang.T("log_title"), "Disconnect log", "back to English")
end)

test("a broken translation text is shown in English", function()
    lang.use("id", { log_title = "Catatan", ev_lobby_error = "kode %s %s", nonsense = "x" })
    eq(lang.T("log_title"), "Catatan", "good text used")
    eq(lang.T("ev_lobby_error", 7), "Lobby connection error (code 7)", "other values: English")
    eq(#lang.rejected, 2, "two rejected")
    lang.set("en")
end)

runner.run()
