# Anti Disconnect - AFK Guard and Connection Log (Monster Hunter Wilds)

**Download:** [Nexus Mods](https://www.nexusmods.com/monsterhunterwilds/mods/5161)

A REFramework script for Monster Hunter Wilds (PC). It does four things:

1. **AFK guard.** After 30 minutes without input, the game moves you to Online Single Player with the message *"Switched to Online Single Player due to inactivity"*. That also takes you out of your lobby, your quest session and your **Link Party**. The AFK guard stops that kick, so you are still with your friends when you come back.
2. **Disconnect log.** Every time the game reports a network problem, the mod writes down when it happened and what the game said. Examples: a communication error, a closed lobby connection, Offline Mode, a lost session. It also notes when the game engine drops a player from the quest or Link Party, and why. Then you can tell whether drops come from your own connection or from the server. **Copy report** puts the log on the clipboard to send.
3. **Steady link (experiment, off by default).** It raises how often your game sends the engine's "I'm still here" health checks in quests and the Link Party.
   - It is meant for connections that pause for a moment, such as mobile data.
   - With a pause like that, the engine may decide one player is gone (`PeerNorecvTimeout`) while everyone else stays.
   - Its effect is not proven yet.
4. **Wait for Steam (on by default).** When Steam loses its connection for a moment, the game waits up to 30 seconds for it to come back instead of going to Offline Mode at once.
   - It is meant for drops with the code `C1081-AAA-AAA2` or `C1082-AAA-AAA2`.
   - Tested in game against a short Steam-only drop. Whether it saves real drops is not proven yet.

> **Status: 0.1.2 beta.**
> - The AFK guard is tested in game.
> - The steady link experiment takes effect, but whether it prevents drops is what this beta should find out.
> - Wait for Steam is tested in game against a short Steam-only drop: off, the game went offline at once; on, it stayed online. Whether it saves real drops is what this beta should find out.
> - [Send a disconnect report](#help-test-it-report-a-disconnect) if you drop out of a Link Party or quest.

## What the AFK guard does, and what it does not do

The game counts the seconds since your last keyboard, mouse or controller input, but only while you are online with other players. It acts on that count twice:

| No input for | What the game does | With Anti Disconnect |
|---|---|---|
| 3 minutes | Other players see you as **Idle** | Unchanged: you still show as Idle |
| 30 minutes | Kicks you to Online Single Player | **Stopped** |

How it works:

- The guard holds the game's idle counter one minute below the kick limit.
- It does not press keys and does not change your save.
- It does not send anything to Capcom's servers.
- It does not touch other game code. The game's own check reads this counter and nothing else.

**Quests with other players.** In a quest with a player outside your Link Party (for example an SOS), the 30-minute kick still applies by default. Staying AFK in someone else's quest gets you rewards for nothing. You can turn on *"Also during quests with players outside my Link Party"* if you want the guard there too.

## What it cannot fix

A mod cannot repair a bad connection. These drops still happen:

- packet loss and weak Wi‑Fi
- your provider's problems
- the server closing your lobby connection
- maintenance
- another player's bad connection

The connection time limits are on Capcom's servers and in Microsoft PlayFab, not in the game, so they cannot be raised. For those drops, the log tells you what happened. Later versions will reconnect for you.

Capcom's own tips are in the support FAQ:

- [network troubleshooting](https://www.monsterhunter.com/support/wilds/en/faq/detail/040)
- [ports](https://www.monsterhunter.com/support/wilds/en/faq/detail/041)
- [IPv4 over IPv6](https://www.monsterhunter.com/support/wilds/en/faq/detail/096)

The tips are:

- use a cable or 5 GHz Wi‑Fi
- turn on UPnP
- allow the game through your firewall
- avoid VPNs

## Install

1. Install [REFramework](https://github.com/praydog/REFramework-nightly/releases) for Monster Hunter Wilds.
2. Download the zip from the [Nexus Mods page](https://www.nexusmods.com/monsterhunterwilds/mods/5161?tab=files) and install it in one of these ways:
   - Import the zip in Fluffy Mod Manager.
   - Or copy its `reframework` folder into the game folder (next to `MonsterHunterWilds.exe`).
3. Start the game.
4. Press **Insert** to open the REFramework menu and open **Anti Disconnect**.

## Settings

| Setting | Default | What it does |
|---|---|---|
| Stop the AFK kick | On | Holds the idle counter below the 30-minute kick while you are online with others |
| Also during quests with players outside my Link Party | Off | Also stops the kick in quests with players outside your Link Party |
| Tell me when I come back | On | Shows *"Welcome back! You had no input for 34 minutes. Anti Disconnect kept you online"* after the guard saved you |
| Experiment: send "I'm still here" signals more often | Off | The engine's highest health check rate in quests and the Link Party; the old rate comes back when you turn it off |
| Experiment: when Steam drops for a moment, wait up to 30 seconds | On | The game waits for Steam to log back on before it goes to Offline Mode; the game's own wait comes back when you turn it off |
| Language / Bahasa | English | English or Bahasa Indonesia |

The menu shows what the guard is doing right now. Examples:

- *protecting you in the lobby*
- *not protecting you in this quest, because it has players outside your Link Party*

It also shows how long you have been without input.

## The disconnect log

- The menu shows the newest entries.
- All entries (up to 300) are in `reframework/data/AntiDisconnect/events.json`.
- The same lines also go to `re2_framework_log.txt` in English.

Example:

```
21:03:14  Network error: WebSocketClient / Timeout
21:03:15  Lobby connection closed
21:03:15  Lobby: online with others -> not connected
21:03:16  Game error COMMON_BE_OFFLINE (106005), area CONTEXT
```

The log never stores other players' names, hunter IDs or lobby IDs.

## Help test it: report a disconnect

The goal of this beta is to learn why one player drops out of a Link Party or quest while everyone else stays connected, and whether the experiments stop it.

1. Play as usual. "Wait for Steam" is on by default; leave it on.
2. If your drops show `PeerNorecvTimeout` in the log, also try "steady link" for about as long as you played without it.
3. After every drop:
   - take a screenshot of the error code;
   - press **Insert → Anti Disconnect → Copy report**;
   - send it with the [disconnect report form](https://github.com/zamcoder/anti-disconnected-mhwilds/issues/new?template=disconnect-report.yml), or post it in the [Bugs tab on Nexus](https://www.nexusmods.com/monsterhunterwilds/mods/5161?tab=bugs).

The report says how you were connected and what the game and its engine said before you dropped. It holds no names or IDs.

**On Steam, please add Steam's own log.** Open `C:\Program Files (x86)\Steam\logs\connection_log.txt` and copy the lines from the minute you dropped. The first real report showed this kind of drop:
- the game's platform connection reported `Context / LinkStateInactive` (code `C1081-AAA-AAA2`);
- the game went to Offline Mode at once, although the connections to the other players were fine;
- Steam's log showed that the PC's network went away for about 6 seconds, and Steam lost its connection for about a second. The game went offline in that same second.

"Wait for Steam" is the experiment for this kind of drop. Steam's log lines include your Steam ID (`[U:1:...]`); remove it before you post the lines in public.

For a bug in the mod itself (an error in its menu, a crash), use the [bug form](https://github.com/zamcoder/anti-disconnected-mhwilds/issues/new?template=bug-report.yml).

## Compatibility

- Checked against game build 24705561 (version 1.42) with a REFramework nightly from September 2026.
- If a game update removes something the mod uses, the menu says so ("not available on this game version") instead of breaking.
- Works next to other mods, including *Better Network Errors*: the AFK warning simply never comes.

## Credits and license

- [REFramework](https://github.com/praydog/REFramework) by praydog makes the script possible.
- The game text dump by [dtlnor](https://github.com/dtlnor/MHWsTextDump) helped map the game's network messages.
- MIT license (see `LICENSE`).

## For developers

- `tools\check.py` runs the offline tests (Lua 5.4 through lupa): `.venv\Scripts\python.exe -I tools\check.py`.
- `tools\deploy.ps1` installs the mod into the game:
  - `-Dev afk-test` adds the in-game test panel;
  - `-RemoveDev` and `-Remove` take things out again.
- `tools\package.ps1` builds the Fluffy Mod Manager zip in `dist\`.
- How the kick works inside the game, with the class and method names, is documented at the top of `src/reframework/autorun/AntiDisconnect/game.lua`.
