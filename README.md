# ReplayRoute

**Save the replay. Keep it organized.**

ReplayRoute sorts OBS Studio Replay Buffer clips into game folders. A single Lua script for **64-bit Windows**, running inside OBS without launching shell processes or console windows.

**Version 2.1.0** · English interface · MIT license · No accounts, network requests, or telemetry.

## Features

- **No overwrites:** filename collisions receive numbered suffixes.
- **Game-aware routing:** checks configured Game Capture targets, then a recognized foreground game.
- **Automatic folders for new games:** an unregistered, specific Game Capture target such as `newgame.exe` can route to `newgame` without adding a rule first.
- **Recoverable moves:** a persistent JSON queue tracks pending work across reloads.
- **Bounded retries:** temporary file locks are retried; persistent failures remain available for review.
- **Rules inside OBS:** add, edit, or remove executable-to-folder mappings without editing Lua.
- **Manual reclassification:** assign ambiguous clips to a folder and retry failed moves.
- **Visible status:** check pending items, recent history, and actual Replay Buffer state.
- **Optional auto-start:** request Replay Buffer startup when the script loads.

## Quick start

1. Download this repository using **Code → Download ZIP** and extract it to a writable folder.
2. Open **OBS → Tools → Scripts → +** and select `obs_replay_organizer.lua`.
3. Set **Base folder** to a local folder on the **same drive as your original clips**. The initial example is `D:\Videos`; change it to match your computer.
4. Enable and configure Replay Buffer in **Settings → Output**, and assign a hotkey to save replays.
5. Save a replay, check its destination, and click **Refresh status**.

The Lua filename is intentionally unchanged for compatibility with existing installations. Load only one copy of the script.

## Add a game

**Automatically create folders for unknown games (Game Capture only)** is enabled by default. It uses the executable name without `.exe`, not a guessed commercial game title. Existing rules take priority. Multiple conflicting targets, unsafe folder names, and unknown foreground windows do not trigger automatic folder creation. Fullscreen/hotkey capture modes do not expose a specific configured target for this feature.

Auto-routed clips remain available for reclassification. Add a friendly rule and click **Save rule and reclassify** to move tracked clips to that folder. This moves those clips; it does not rename or delete the old directory. Disabling the option affects future detections, not clips already queued. Auto-routed records remain in the queue until classified, so the state file can grow with those clips.

Enter its executable and desired folder in the script properties, then click **Save rule and reclassify**. You can also edit the multiline rules field:

```text
newgame.exe = My Game
anothergame.exe = Another Game
```

To correct an ambiguous clip, select **Clip to reclassify**, enter a folder, and click **Assign folder to selected clip**. A manual assignment changes that clip only; it does not invent an executable rule.

## Updating

Back up the existing Lua file and queue JSON. Replace the Lua file in the same location, then click **Reload** in OBS. Existing settings and game rules remain compatible, including custom folder names. Older queue entries may retain their original log language until processed.

Do not run another organizer on the same clips at the same time.

## Behavior and limits

- Game Capture provides its **configured target**, not proof that OBS successfully hooked the game. Conflicting capture targets or foreground-game signals are left unclassified.
- Only new replay events and saved queue entries are processed. ReplayRoute does not scan an existing video library.
- Moves stay on the same local drive. Cross-drive copies and network destinations are blocked to avoid long copy operations inside OBS.
- The queue records moves; it is not a video backup and cannot repair incomplete recordings or disk failures.
- If queue storage fails, moves pause. A failed move leaves the source file in place when it has not already moved.
- Event-driven processing reduces unnecessary work, but is not zero-cost or background-thread execution. Same-volume moves are normally quick, not instantaneous.
- Click **Refresh status** to update the panel; it does not refresh continuously.

Runtime state lives beside the script in `obs_organizer_state.json` and its `.bak` backup. These files can contain local paths and are excluded from Git.

## Tests

Requirements: Windows x64, 64-bit Python, and OBS Studio installed. Python is **only required for tests**, not to use ReplayRoute.

```powershell
python tests/run_lua.py tests/test_organizer.lua
```

For a custom OBS installation:

```powershell
$env:OBS_BIN = 'E:\Apps\obs-studio\bin\64bit'
python tests/run_lua.py tests/test_organizer.lua
```

The suite uses installed LuaJIT/libobs, real temporary file moves, and real JSON persistence. OBS scenes, events, and UI functions are simulated. Coverage includes collisions, exclusive locks, retry limits, reload recovery, persistence failure, ambiguous captures, manual reclassification, duplicate events, interrupted moves, and cross-drive rejection.

**Still requires real-world validation:** saving a replay inside OBS and measuring performance during gameplay. Passing the tests does not establish that the project is fault-proof.

[User guide](docs/GUIDE.md) · [Changelog](CHANGELOG.md)

## License

MIT. Copyright © 2026 Rena148. OBS and LuaJIT are not redistributed and retain their respective licenses. ReplayRoute is an independent project, not an official OBS plugin.
