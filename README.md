# Anti Disconnect - AFK Guard and Connection Log (Monster Hunter Wilds)

A REFramework script for Monster Hunter Wilds (PC). It does three things:

1. **AFK guard.** After 30 minutes without input, the game moves you to Online Single Player with the message *"Switched to Online Single Player due to inactivity"*. That also takes you out of your lobby, your quest session and your **Link Party**. The AFK guard stops that kick, so you are still with your friends when you come back.
2. **Disconnect log.** Every time the game reports a network problem, the mod writes down when it happened and what the game said. Examples: a communication error, a closed lobby connection, Offline Mode, a lost session. It also notes when the game engine drops a player from the quest or Link Party, and why. Then you can tell whether drops come from your own connection or from the server. **Copy report** puts the log on the clipboard to send.
3. **Steady link (experiment, off by default).** It raises how often your game sends the engine's "I'm still here" health checks in quests and the Link Party.
   - It is meant for connections that pause for a moment, such as mobile data.
   - With a pause like that, the engine may decide one player is gone (`PeerNorecvTimeout`) while everyone else stays.
   - Its effect is not proven yet.

> **Status: 0.1.0 beta.**
> - The AFK guard is tested in game.
> - The steady link experiment takes effect, but whether it prevents drops is what this beta should find out.
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
2. Install the mod in one of these ways:
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

The goal of this beta is to learn why one player drops out of a Link Party or quest while everyone else stays connected, and whether the steady link experiment stops it. Most useful is an A/B test:

1. Play as usual with the experiment **off** until you drop once or twice.
2. Play about as long with the experiment **on**.
3. After every drop:
   - take a screenshot of the error code;
   - press **Insert → Anti Disconnect → Copy report**;
   - send it with the [disconnect report form](https://github.com/zamcoder/anti-disconnected-mhwilds/issues/new?template=disconnect-report.yml), or post it in the Bugs tab on Nexus.

The report says how you were connected and what the game and its engine said before you dropped. It holds no names or IDs.

**On Steam, please add Steam's own log.** Open `C:\Program Files (x86)\Steam\logs\connection_log.txt` and copy the lines from the minute you dropped. The first real report showed this kind of drop:
- the game's platform connection reported `Context / LinkStateInactive` (code `C1081-AAA-AAA2`);
- the game went to Offline Mode at once, although the connections to the other players were fine.

Steam's log shows whether Steam lost its connection at that moment.

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
