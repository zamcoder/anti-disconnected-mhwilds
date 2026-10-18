-- The Anti Disconnect section of the REFramework menu (Insert by default), and the message
-- shown while that menu is closed. Both only read and edit Lua state; every game call
-- happens in the tick of AntiDisconnect.lua.

local afk = require("AntiDisconnect.afk")
local lang = require("AntiDisconnect.lang")
local netlog = require("AntiDisconnect.netlog")
local T = lang.T

local ui = {}

local LOG_LINES = 12   -- newest entries shown; the file keeps more
local WRAP = 100       -- characters per line for long messages (ImGui does not wrap plain text)
local RED = 0xFF4040FF
local YELLOW = 0xFF40FFFF
local GREEN = 0xFF60FF60
local GREY = 0xFFA0A0A0
local TOAST_FLAGS = 201583   -- NoDecoration | NoMove | AlwaysAutoResize | NoSavedSettings | NoFocusOnAppearing | NoInputs

local STATUS_COLORS = {
    status_lobby = GREEN, status_link = GREEN, status_quest = GREEN, status_quest_all = GREEN,
    status_strangers = YELLOW, status_unknown = YELLOW, status_unavailable = RED,
    status_off = GREY, status_not_needed = GREY, status_starting = GREY,
}
local ERROR_KINDS = { app_error = true, engine_error = true, lobby_closed = true, lobby_error = true }

local function has(name) return type(imgui[name]) == "function" end

-- Draws a long message on several lines, broken at spaces.
local function wrap_at(text, width)
    local lines, rest = {}, tostring(text)
    while #rest > width do
        local cut = rest:sub(1, width + 1):match("^.*() ")   -- the last space that keeps the line short enough
        if not cut or cut <= 1 then break end
        lines[#lines + 1] = rest:sub(1, cut - 1)
        rest = rest:sub(cut + 1)
    end
    lines[#lines + 1] = rest
    return lines
end

local function say(text, color)
    for _, l in ipairs(wrap_at(text, WRAP)) do
        if color then imgui.text_colored(l, color) else imgui.text(l) end
    end
end

-- 95 -> "1:35", 4000 -> "1:06:40".
local function clock(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    local h, m, s = seconds // 3600, (seconds % 3600) // 60, seconds % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
    return string.format("%d:%02d", m, s)
end

-- The time of a log entry: only the clock for today, with the date otherwise.
local function when(t)
    if type(t) ~= "number" then return "--:--:--" end
    if os.date("%Y-%m-%d", t) == os.date("%Y-%m-%d") then return os.date("%H:%M:%S", t) end
    return os.date("%Y-%m-%d %H:%M", t)
end

local function event_color(event)
    if event.kind == "afk_saved" then return GREEN end
    if ERROR_KINDS[event.kind] then return YELLOW end
    if event.kind == "session" and event.to == "off" then return YELLOW end
    return nil
end

local function checkbox(state, key)
    local changed, value = imgui.checkbox(T(key) .. "##AntiDisconnect_" .. key, state.settings[key])
    if changed then
        state.settings[key] = value
        state.settings_dirty = true
    end
end

local function draw_guard(state, actions)
    checkbox(state, "afk_guard")
    if state.settings.afk_guard then
        if has("indent") then imgui.indent(20) end
        checkbox(state, "afk_public_quests")
        checkbox(state, "afk_welcome")
        if has("unindent") then imgui.unindent(20) end
    end
    say(T("afk_help"), GREY)
    say(T(state.guard.status), STATUS_COLORS[state.guard.status])
    local reading = state.reading
    if reading and reading.timer and reading.limits then
        local idle = afk.idle_seconds(state.guard, reading, os.clock())
        if idle and idle >= 1 then
            if state.guard.held then
                imgui.text(T("idle_held", clock(idle), clock(state.guard.ceiling)))
            else
                imgui.text(T("idle_line", clock(idle), clock(reading.limits.idle), clock(reading.limits.kick)))
            end
        end
        if not reading.limits.read then imgui.text_colored(T("limits_assumed"), YELLOW) end
    end
    if imgui.button(T("toast_test_button") .. "##AntiDisconnectToastTest") then actions.test_toast() end
    if state.toast_on_close then imgui.text(T("toast_test_hint")) end
end

local SESSION_LINES = { "quest", "link" }

local function draw_steady(state)
    checkbox(state, "steady_link")
    say(T("steady_help"), GREY)
    for _, name in ipairs(SESSION_LINES) do
        local info = state.links and state.links[name]
        if info then
            imgui.text(T("link_line", T("session_" .. name), tostring(info.class), info.p2p_ok or 0, info.p2p_tried or 0,
                T("health_" .. tostring(info.health))))
        end
    end
end

local function draw_grace(state)
    checkbox(state, "steam_grace")
    say(T("grace_help"), GREY)
    local ctx = state.contexts
    if ctx and ctx.main then
        imgui.text(T("grace_line", tostring(ctx.main), netlog.duration(T, ctx.now), netlog.duration(T, ctx.first)))
    end
end

local function draw_log(state, actions)
    imgui.text(T("log_title"))
    local events = state.log.events
    if #events == 0 then imgui.text_colored(T("log_empty"), GREY) end
    for i = #events, math.max(1, #events - LOG_LINES + 1), -1 do
        local event = events[i]
        say(when(event.t) .. "  " .. netlog.describe(event), event_color(event))
    end
    if #events > LOG_LINES then imgui.text_colored(T("log_more", #events - LOG_LINES), GREY) end
    if imgui.button(T("report_button") .. "##AntiDisconnectReport") then actions.copy_report() end
    if #events > 0 then
        imgui.same_line()
        if imgui.button(T("log_clear") .. "##AntiDisconnectClearLog") then actions.clear_log() end
    end
    if state.report_done then say(T("report_done"), GREEN) end
    imgui.text_colored(T("log_file"), GREY)
    if state.hooks and #state.hooks.missing > 0 then
        say(T("log_hooks_missing", table.concat(state.hooks.missing, ", ")), YELLOW)
    end
end

local function draw_menu(state, actions)
    imgui.text(T("version", state.version))
    local names, current = {}, 1
    for i, language in ipairs(lang.LANGUAGES) do
        names[i] = language.name
        if language.code == lang.code() then current = i end
    end
    local changed, choice = imgui.combo(T("language") .. "##AntiDisconnectLanguage", current, names)
    if changed and lang.LANGUAGES[choice] and choice ~= current then actions.set_language(lang.LANGUAGES[choice].code) end
    if state.error then say(T("error", state.error), RED) end
    imgui.separator()
    draw_guard(state, actions)
    imgui.separator()
    draw_steady(state)
    imgui.separator()
    draw_grace(state)
    imgui.separator()
    draw_log(state, actions)
end

function ui.menu(state, actions)
    -- The report was made in the last tick; ImGui can only set the clipboard while it draws.
    if state.clipboard then
        if has("set_clipboard") then pcall(imgui.set_clipboard, state.clipboard) end
        actions.clipboard_done()
    end
    if imgui.tree_node("Anti Disconnect") then
        local ok, err = pcall(draw_menu, state, actions)
        if not ok then imgui.text_colored(T("ui_error", tostring(err)), RED) end
        imgui.tree_pop()
    end
end

-- A short message on the right of the screen while the REFramework menu is closed. It takes
-- no input and only reads Lua state (it is drawn from re.on_frame). The same look as the
-- Bulk Sell messages:
--
-- With REFramework's draw API it looks like the game's own notices: thin lines above and below
-- with small diamonds, a bold white title and the text with a shadow, fading in and out.
-- Without it, a small window with a gold edge is shown instead.
local TOAST_WRAP = 60
local TOAST_STYLE = {   -- ImGuiCol index, RGBA: a dark panel with a gold edge
    { 2, 0.06, 0.05, 0.04, 0.88 },   -- WindowBg
    { 5, 0.84, 0.69, 0.35, 0.90 },   -- Border
}
local TOAST_GOLD = 0xFF6CC8E8

-- Colours of the game-style message, 0xAABBGGRR as ImGui takes them.
local NOTICE = {
    width = 470, right = 34, top = 0.30, pad = 9, indent = 30, wrap = 44,   -- pixels at 1080p, top as a share of the height
    text = 0xFFFFFFFF, shadow = 0xD0000000, line = 0xFFC8D0D0, band = 0x60000000, icon = 0xFF6CC8E8,
    fade_in = 0.25, fade_out = 0.6,
}

-- The default font at a bigger size, like the game's notice text (falls back to the normal font).
local notice_font
if has("load_font") then
    local ok, font = pcall(imgui.load_font, nil, 22)
    if ok and font then notice_font = font end
end

local function with_alpha(color, alpha)
    local a = math.floor(((color >> 24) & 0xFF) * alpha)
    return (color & 0x00FFFFFF) | (a << 24)
end

local function diamond(x, y, r, color)
    draw.filled_quad(x, y - r, x + r, y, x, y + r, x - r, y, color)
end

local function shadowed(text, x, y, color, alpha, bold)
    draw.text(text, x + 1, y + 1, with_alpha(NOTICE.shadow, alpha))
    draw.text(text, x, y, with_alpha(color, alpha))
    if bold then draw.text(text, x + 1, y, with_alpha(color, alpha)) end
end

local function draw_notice(toast, now)
    local size = imgui.get_display_size()
    if not size or not size.x or size.x <= 0 then return false end
    local scale = size.y / 1080
    local alpha = math.min(1, (now - (toast.shown_at or now)) / NOTICE.fade_in, (toast.until_at - now) / NOTICE.fade_out)
    alpha = math.max(0, alpha)
    local pushed = notice_font ~= nil and pcall(imgui.push_font, notice_font)
    local ok = pcall(function()
        local line_h = (has("calc_text_size") and imgui.calc_text_size("Ag").y or 18) + 2 * scale
        local body = wrap_at(toast.text, NOTICE.wrap)
        local x1 = size.x - NOTICE.right * scale
        local x0 = x1 - NOTICE.width * scale
        local y0 = size.y * NOTICE.top
        local h = NOTICE.pad * scale * 2 + line_h * (1 + #body)
        local y1 = y0 + h
        draw.filled_rect(x0, y0, x1 - x0, h, with_alpha(NOTICE.band, alpha))
        for _, y in ipairs({ y0, y1 }) do
            draw.line(x0 + 6 * scale, y, x1, y, with_alpha(NOTICE.line, alpha))
            diamond(x0, y, 3.5 * scale, with_alpha(NOTICE.line, alpha))
        end
        local tx = x0 + NOTICE.indent * scale
        local ty = y0 + NOTICE.pad * scale
        diamond(x0 + 14 * scale, ty + line_h / 2, 5 * scale, with_alpha(NOTICE.icon, alpha))
        shadowed(T("toast_title"), tx, ty, NOTICE.text, alpha, true)
        for i, line in ipairs(body) do shadowed(line, tx, ty + line_h * i, NOTICE.text, alpha, false) end
    end)
    if pushed then imgui.pop_font() end
    return ok
end

local function place_toast()
    local size = has("get_display_size") and imgui.get_display_size()
    if size and size.x and size.x > 0 then
        imgui.set_next_window_pos(Vector2f.new(size.x - 24, size.y * 0.30), 1, Vector2f.new(1, 0))   -- top right corner there
    else
        imgui.set_next_window_pos(Vector2f.new(40, 140), 1)
    end
end

local function draw_window_toast(toast)
    pcall(place_toast)
    -- Colours are pushed one by one and popped exactly as often, or ImGui would break.
    local pushed = 0
    if has("push_style_color") and has("pop_style_color") and Vector4f then
        for _, c in ipairs(TOAST_STYLE) do
            if pcall(imgui.push_style_color, c[1], Vector4f.new(c[2], c[3], c[4], c[5])) then pushed = pushed + 1 end
        end
    end
    imgui.begin_window("Anti Disconnect###AntiDisconnectToast", nil, TOAST_FLAGS)
    pcall(function()
        imgui.text_colored(T("toast_title"), TOAST_GOLD)
        for _, line in ipairs(wrap_at(toast.text, TOAST_WRAP)) do imgui.text(line) end
    end)
    imgui.end_window()
    if pushed > 0 then imgui.pop_style_color(pushed) end
end

function ui.toast(state)
    local toast = state.toast
    if not toast then return end
    local now = os.clock()
    -- The REFramework menu hides the message, and its time only runs while it can be seen:
    -- the input that wakes the player up is often the key that opens the menu.
    if reframework:is_drawing_ui() then
        toast.left = toast.left or math.max(0, toast.until_at - now)
        return
    end
    if toast.left then
        toast.until_at, toast.shown_at, toast.left = now + toast.left, now, nil
    end
    if now > toast.until_at then
        state.toast = nil
        return
    end
    local game_style = type(draw) == "table" and type(draw.text) == "function" and type(draw.line) == "function"
        and type(draw.filled_quad) == "function" and type(draw.filled_rect) == "function" and has("get_display_size")
    if not (game_style and draw_notice(toast, now)) then draw_window_toast(toast) end
end

-- Exposed for tests.
ui._clock = clock
ui._wrap = wrap_at

return ui
