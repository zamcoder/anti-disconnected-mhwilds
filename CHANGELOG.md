# Changelog

## 0.1.2 beta (2026-10-18)

- New, on by default: **wait for Steam**. It is for drops with the code `C1081-AAA-AAA2` or `C1082-AAA-AAA2` (`Context / LinkStateInactive` or `LostAuth` in the log).
  - Tested in game by cutting only Steam's connection for 8–9 seconds. With the experiment off, the game went offline in the same second (`C1082-AAA-AAA2`). With it on, the game stayed online.
  - Why these drops happen: the player's Steam log showed that their PC's network went away for about 6 seconds and Steam lost its connection to its servers for about a second. The game went to Offline Mode in that same second and left the lobby, quest and Link Party.
  - The game's network engine only goes offline once Steam has been disconnected for longer than the Steam context's `DisconnectionDetectionTime` (in microseconds). The game never sets that value.
  - With the experiment on, the value is set to 30 seconds while you are connected, so the game waits for Steam to log back on. In the player's Steam log nearly every short Steam drop was over within that time.
  - The value from before comes back when the setting is turned off.
- The menu shows how long the game waits for Steam, now and its own value. The report shows the setting.
- After REFramework's "Reset scripts", turning wait for Steam off puts back the game's own value (0). Engine errors from HttpClient now show the cause name.

## 0.1.1 beta (2026-10-18)

- The first real drop report showed a different kind of drop:
  - the game's platform connection (Steam) reported `Context / LinkStateInactive` (on-screen code `C1081-AAA-AAA2`);
  - the game went to Offline Mode at once and left the lobby, quest and Link Party;
  - the connections to the other players were fine and direct.
- The menu and the report now show the platform connections and the Steam context's `DisconnectionDetectionTime`. This is read only, to learn what it is before an experiment changes it.
- The report form asks for the lines of Steam's `logs\connection_log.txt` around the drop.

## 0.1.0 beta (2026-10-18)

First release, for testing with many players.

- AFK guard: stops the game's 30-minute kick to Online Single Player while you are online with others. The game's idle counter is held one minute below the kick limit; the 3-minute Idle status still works.
- In quests with players outside your Link Party the kick still applies, unless "Also during quests with players outside my Link Party" is on.
- "Welcome back" message when the guard kept you online.
- Disconnect log:
  - records the game's network errors, lobby connection errors and closes, and changes of the lobby, quest and Link Party sessions and of the server connection;
  - shows the entries in the menu;
  - keeps up to 300 entries in `reframework/data/AntiDisconnect/events.json`.
  - also records what the game engine tells the quest, Link Party and lobby sessions (a member left, the session ended and why), when your game leaves a session or the Link Party, and direct versus relayed player connections.
- "Copy report": the settings, the connections and the newest log entries in English, on the clipboard and in `report.txt`, without names or IDs.
- Steady link (experiment, off by default): the engine's highest "still here" health check rate in quests and the Link Party.
- English and Bahasa Indonesia.
