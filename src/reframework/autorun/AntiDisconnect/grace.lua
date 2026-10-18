-- The Steam connection and the "wait for Steam" experiment.
--
-- On Steam the game's platform connection (via.network.ContextSteam) follows Steam's own
-- connection to its servers. When Steam reports that it lost it (SteamServersDisconnected_t),
-- the engine checks at every update how long ago that was. Once that is at least the
-- context's DisconnectionDetectionTime (microseconds), it ends the context with
-- Context / LinkStateInactive or LostAuth: the game goes to Offline Mode and leaves the
-- lobby, the quest and the Link Party (on screen C1081-AAA-AAA2 or C1082-AAA-AAA2). When
-- Steam is logged on again before then, nothing happens. Seen in game on 2026-10-18 by
-- cutting only Steam off: with 0 the game went offline in the same second (C1082); with
-- 30 s it stayed online while Steam was gone for 8 s. (Machine code of game build 24705561. The game itself never sets the
-- value; in a player's report of 2026-10-18 the game went offline in the same second as
-- Steam dropped, so it is 0 or close to it.)
--
-- Steam usually logs back on within seconds: in that player's Steam log nearly all short
-- drops were over within 2 minutes, most within 30 seconds. With steam_grace on, the value
-- is set to WAIT_US, so a drop that short no longer ends the connection. The value before
-- the change is put back when the setting is turned off. After REFramework's "Reset
-- scripts" that value is not known any more, so the game's own value GAME_US is put back
-- instead (0, read in game on 2026-10-18).
--
-- A context that is not running ignores the value, and a new context starts with the
-- game's own value, so it is set while the context is active and again after the game
-- started a new one. If it does not stay, that is logged once and tried again every
-- RETRY_SECONDS.
--
-- grace.step makes no game calls, so all of this is tested offline.

local grace = {}

grace.SECONDS = 30
grace.WAIT_US = grace.SECONDS * 1000000
grace.GAME_US = 0
grace.ACTIVE = 2   -- app.net_context_manager.cContextManager.CONTEXT_STATE
local RETRY_SECONDS = 10

function grace.new()
    return { original = nil, from = nil, sent_at = nil, told = false, put_back = false }
end

-- info = { detect = DisconnectionDetectionTime or nil (not Steam, or unreadable),
--          state = cContextManager._ContextState or nil }; now = seconds (os.clock).
-- Returns what to do: { set = value or nil, events = { log entries } }.
function grace.step(st, info, settings, now)
    local out = { events = {} }
    local value = info.detect
    if value == nil then return out end
    if settings.steam_grace then
        st.put_back = false
        if info.state ~= grace.ACTIVE then
            st.sent_at = nil
        elseif value == grace.WAIT_US then
            if st.sent_at then
                out.events[#out.events + 1] = { kind = "grace", from = st.from, to = value }
                st.sent_at, st.told = nil, false
            end
        elseif st.sent_at == nil or now - st.sent_at >= RETRY_SECONDS then
            if st.sent_at and not st.told then
                st.told = true
                out.events[#out.events + 1] = { kind = "grace_failed" }
            end
            if st.original == nil then st.original = value end
            if st.sent_at == nil then st.from = value end
            out.set, st.sent_at = grace.WAIT_US, now
        end
    elseif st.original ~= nil then
        if value ~= st.original then
            out.set = st.original
            out.events[#out.events + 1] = { kind = "grace", from = value, to = st.original }
        end
        st.original, st.from, st.sent_at, st.told = nil, nil, nil, false
    elseif value == grace.WAIT_US and not st.put_back then
        st.put_back = true
        out.set = grace.GAME_US
        out.events[#out.events + 1] = { kind = "grace", from = value, to = grace.GAME_US }
    end
    return out
end

return grace
