-- The connections of the quest session and the Link Party, and the "steady link" experiment.
--
-- The engine sends health checks ("I am still here") to the other players. When they have
-- heard nothing from a player for too long, that player is dropped (PeerNorecvTimeout), even
-- when the connection only paused for a moment. Mobile data in particular (shared IP
-- addresses, CGNAT) can forget a quiet game connection within seconds. With steady_link on,
-- the quest session and the Link Party send their health checks at the engine's highest
-- rate (via.network.session.HealthCheckSendFrequency.Highest), so the connection is never
-- quiet and the others hear from this player more often. The value before the change is
-- put back when the setting is turned off.
--
-- The rate is only set while the session is online, once each time it comes online: a
-- session that is not running ignores it (seen in game on 2026-10-18). If the game puts the
-- old rate back anyway, that is logged once instead of fighting it.
--
-- link.step makes no game calls, so all of this is tested offline.

local link = {}

link.DEFAULT, link.HIGHEST = 0, 1   -- via.network.session.HealthCheckSendFrequency
link.SESSIONS = { "quest", "link" }   -- the player-to-player sessions (PlayFab)

function link.new()
    return { seen = {}, original = {}, tried = {}, told = {} }
end

-- infos = { quest = info, link = info } from game.link_info, each with `online` added.
-- Returns what to do: { sets = { { session, value } }, events = { log entries } }.
function link.step(st, infos, settings)
    local out = { sets = {}, events = {} }
    for _, name in ipairs(link.SESSIONS) do
        local info = infos[name]
        if info then
            local seen = st.seen[name]
            -- Direct connections tried and made: fewer made than tried means the rest go
            -- through a relay, which is slower and one more thing that can fail.
            if (info.p2p_tried or 0) > 0 and (not seen or seen.p2p_tried ~= info.p2p_tried or seen.p2p_ok ~= info.p2p_ok) then
                out.events[#out.events + 1] = { kind = "p2p", session = name, class = info.class,
                    tried = info.p2p_tried, ok = info.p2p_ok }
            end
            st.seen[name] = info
            if not info.online then st.tried[name], st.told[name] = nil, nil end
            local want
            if settings.steady_link then
                if info.online and info.health ~= nil and info.health ~= link.HIGHEST then
                    if not st.tried[name] then
                        if st.original[name] == nil then st.original[name] = info.health end
                        st.tried[name] = true
                        want = link.HIGHEST
                    elseif not st.told[name] then
                        st.told[name] = true
                        out.events[#out.events + 1] = { kind = "health_failed", session = name }
                    end
                end
            elseif st.original[name] ~= nil then
                if info.health ~= st.original[name] then want = st.original[name] end
                st.original[name], st.tried[name], st.told[name] = nil, nil, nil
            end
            if want then
                out.sets[#out.sets + 1] = { name, want }
                out.events[#out.events + 1] = { kind = "health", session = name, from = info.health, to = want }
            end
        end
    end
    return out
end

return link
