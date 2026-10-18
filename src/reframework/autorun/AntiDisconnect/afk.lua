-- The AFK guard. The game moves you to Online Single Player when its idle timer reaches its
-- kick limit (30 minutes; game.lua explains where). The guard holds that timer a minute below
-- the limit while you are online with others, so the game's own check never fires. The Idle
-- status after 3 minutes keeps working as usual.
--
-- In a quest with players outside your Link Party the kick stays on, unless the player turns
-- on afk_public_quests: an AFK player in other people's quest gets rewards for nothing.
--
-- afk.step makes no game calls, so all of this is tested offline.

local afk = {}

local MARGIN = 60          -- the timer is held this many seconds below the kick
local RELEASE_DROP = 5     -- a held timer that falls by this much means input came back

function afk.new()
    return { status = "status_starting", held = false, idle_start = nil, ceiling = nil, saves = 0 }
end

-- Where the timer is held for these limits.
function afk.ceiling(limits)
    return limits.kick - math.min(MARGIN, limits.kick / 4)
end

-- The status text key for this situation, and whether the timer is held.
-- reading = { timer, limits, sessions = { lobby, quest, link }, strangers }.
function afk.decide(reading, settings)
    if not settings.afk_guard then return "status_off", false end
    if reading.timer == nil then return "status_unavailable", false end
    local s = reading.sessions
    if s == nil then return "status_starting", false end
    if s.quest == "multi" then
        if settings.afk_public_quests then return "status_quest_all", true end
        if reading.strangers == false then return "status_quest", true end
        if reading.strangers == true then return "status_strangers", false end
        return "status_unknown", false
    end
    if s.lobby == "multi" then return "status_lobby", true end
    if s.link == "multi" then return "status_link", true end
    return "status_not_needed", false
end

-- One look at the game's timer. Returns what to do: { set_timer = seconds } to hold it, and
-- { saved_minutes = n } once the player is back after an idle time that would have ended in
-- the kick.
function afk.step(guard, reading, settings, now)
    local status, protect = afk.decide(reading, settings)
    guard.status = status
    local result = {}
    local timer = reading.timer
    if timer == nil then
        guard.held = false
        return result
    end
    local ceiling = afk.ceiling(reading.limits)
    guard.ceiling = ceiling
    if guard.held then
        if not protect then
            -- Turned off, or a quest with other players: the game's own rules apply again.
            guard.held = false
        elseif timer < ceiling - RELEASE_DROP then
            guard.held = false
            local idle = now - guard.idle_start
            if idle >= reading.limits.kick then
                guard.saves = guard.saves + 1
                result.saved_minutes = math.floor(idle / 60)
            end
        end
    end
    if protect and timer > ceiling then
        result.set_timer = ceiling
        if not guard.held then
            guard.held = true
            guard.idle_start = now - timer
        end
    end
    return result
end

-- Seconds without input: the game's timer, or the real time since the last input while the
-- timer is held.
function afk.idle_seconds(guard, reading, now)
    if guard.held and guard.idle_start then return now - guard.idle_start end
    return reading and reading.timer
end

return afk
