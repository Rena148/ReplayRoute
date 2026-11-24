# ReplayRoute user guide

[English](#loading-or-upgrading) · [Español](GUIDE.es.md)

## Loading or upgrading

In **OBS → Tools → Scripts**, add `obs_replay_organizer.lua` or select the existing script and click **Reload**. The description should show **ReplayRoute 2.3.1**.

Keep the existing filename and location when upgrading to retain settings and the pending queue. Set **Base folder** to a writable local directory on the same drive and volume as your clips. A drive root such as `D:\` and a directory such as `D:\.clips` are supported. New installations use `Unclassified` for ambiguous clips.

## Rules and reclassification

### Automatic folders for unknown games

The **Auto-create game folders** setting defaults to enabled. Open a game with a visible Game Capture source and save a replay. If OBS identifies `newgame.exe`, ReplayRoute strips common technical suffixes (`-win64-shipping`, `_dx12`, etc.), reuses a uniquely matching subfolder already in **Base folder** if one exists, or creates a new folder from the cleaned name, then adds the rule to your game list after the move succeeds. An explicit rule supplies your preferred folder name.

An unknown foreground window or ordinary Window Capture cannot register a new game. Conflicting captures and unsafe executable names go to your unclassified folder. Automatic folder names are limited to 120 bytes.

Open **Manage games and settings** to change rules or reclassify a clip. Tracked clips remain available across reloads. To see games learned while the Scripts window is open, click **Refresh status**. If you are editing the list, apply your draft first. ReplayRoute merges newly learned games with your edits.

Each rule maps a process executable to a single folder name:

```text
newgame.exe = My Game
```

Use **Executable** and **Folder**, then **Save rule and reclassify**. To edit multiple mappings, change **Game list** and click **Apply game list and retry**. Both actions validate the draft before applying it. Until then, incoming clips use the saved rules. Invalid or duplicate entries leave those rules in place. Reloading the script discards unapplied edits. Empty game subfolders left behind inside **Base folder** after reclassifying clips are removed automatically (your original clips folder and unclassified folder are never removed).

Select a clip to fill in its executable when available. Enter a folder and click **Assign to selected clip** to move only that clip. The selector shows 50 entries per page, newest first. Use its page button to reach older clips.

If you manually delete tracked `unclassified` or `auto_routed` clips from disk, ReplayRoute automatically removes them from **Clip to reclassify** and status counters when you open **Scripts**, expand **Manage games and settings**, click **Refresh status**, or click **Apply game list and retry** (as long as **Base folder** is accessible).

Click **Apply game list and retry** after correcting a destination, permission, or rule.

## Game detection

ReplayRoute checks visible Game Capture and Window Capture sources in the program scene, including groups and nested scenes. A live Game Capture hook identifies the executable even in fullscreen mode. A live Window Capture can identify a game already on your list. If two visible captures identify different games, the clip goes to your unclassified folder.

If Game Capture releases the game during Alt-Tab, ReplayRoute remembers the last confirmed executable on that source for 45 seconds. It checks the Windows process list only when a saved replay needs that fallback. Changing the program scene or hiding the source clears its remembered game. With no live hook, a specific-window Game Capture setting still supplies a candidate, even on sources without hook information. A disagreement with another candidate or a known foreground game leaves the clip unclassified. A known foreground game can identify a clip when there is no capture candidate.

Deadlock (`project8.exe` and `deadlock.exe`) is included by default so its Valve codename maps cleanly to `Deadlock`. All other games are learned automatically from **Game Capture** or can be added in **Game list**.

## File protection

The native move never allows replacement of an existing destination. Numbered suffixes resolve collisions; the move call itself rejects replacement if another file appears after the name check.

The queue records intent before moving. An interruption after the rename can be reconciled on reload. Pending entries live in `obs_organizer_state.json`, with `.bak` backup, beside the script. Keep these files when updating or relocating the installation.

Occupied files receive at most six attempts with increasing delays. Permanent errors remain blocked for review. ReplayRoute checks the source and destination volume before renaming the file, including mount points within a drive letter.

If queue persistence fails, moves pause. If both queue files are unreadable, they are preserved for investigation instead of overwritten. Repair the state and reload the script.

The queue is not a video backup. It cannot repair a recording OBS never finished, detect every external file modification, or protect against hardware failure.

## Status and history

Click **Refresh status** for Replay Buffer state, pending/blocked/unclassified counts, and recent events. **Script Log** also shows session messages. There is no continuous UI-refresh timer.

Replay Buffer startup is requested only when enabled, then its state is checked. Enable Replay Buffer and configure encoding in OBS first. Failure messages point to **Settings → Output** and the OBS log.

History is capped at 80 messages and completed receipts at 100 entries. Open advanced settings to see recent events. If auto-routed clips from previous calendar months have the folders you want, **Finish tracking** marks them complete. Their files stay where they are and later game renames skip them. Clips from this month, blocked moves and unclassified clips stay available. The action appears when eligible clips exist.

## First-run check

1. Open a game with **Game Capture → Capture any fullscreen application** visible in your program scene.
2. Save a replay. Check the folder, playback and executable shown under **Refresh status**.
3. Keep the game running, Alt-Tab to another app and save a second replay within 45 seconds. Check that both clips are in the same game folder.

## Rollback

Close OBS, restore your backed-up Lua file under its original name, and reopen OBS. Preserve the queue JSON if it contains unresolved clips. Do not run the older PowerShell organizer on the same files simultaneously.

## Implementation references

- [OBS scripting](https://docs.obsproject.com/scripting)
- [OBS JSON settings API](https://docs.obsproject.com/reference-settings)
- [OBS Game Capture implementation](https://github.com/obsproject/obs-studio/blob/master/plugins/win-capture/game-capture.c)
