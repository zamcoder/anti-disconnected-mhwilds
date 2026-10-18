# Changelog

## 0.1.0 (not released yet)

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
