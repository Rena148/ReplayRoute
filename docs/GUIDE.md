# ReplayRoute user guide

## Loading or upgrading

In **OBS → Tools → Scripts**, add `obs_replay_organizer.lua` or select the existing script and click **Reload**. The description should show **ReplayRoute 2.0.1**. Do not load a second copy.

Keep the existing filename and location when upgrading. Settings keys are unchanged: base folder, unclassified folder, date subfolders, Replay Buffer auto-start, and game rules. Existing folder names are preserved rather than renamed. New installations default to `Unclassified`.

## Rules and reclassification

Each rule maps a process executable to a single folder name:

```text
newgame.exe = My Game
```

Use the **Executable** and **Folder** fields, then **Save rule and reclassify**. The multiline **Games** field also supports adding, editing, and removing rules. Invalid or duplicate entries pause new moves until corrected.

The status panel shows executables associated with unresolved clips. If detection was ambiguous, select a clip, enter the folder, and click **Assign folder to selected clip**. A manual assignment does not create a reusable rule without an executable.

Click **Retry pending clips and apply rules** after correcting a destination, permission, or rule.

## Game detection

ReplayRoute inspects visible Game Capture sources in the program scene, including nested scenes and groups. A source configured to capture a specific window provides its executable target. That setting does not prove the hook is active.

Multiple targets, or disagreement with another recognized foreground game, are treated as ambiguous. Without a specific target, the recognized foreground executable is used. No continuous process polling or full process scan is performed. Switching away from the game when saving can leave a clip unclassified.

The bundled `javaw.exe = Minecraft` rule matches a generic Java executable. Remove that rule if other Java applications make it ambiguous on your system.

## File protection

The native move never allows replacement of an existing destination. Numbered suffixes resolve collisions; the move call itself rejects replacement if another file appears after the name check.

The queue records intent before moving. An interruption after the rename can be reconciled on reload. Pending entries live in `obs_organizer_state.json`, with `.bak` backup, beside the script. Keep these files when updating or relocating the installation.

Occupied files receive at most six attempts, with increasing delays. Permanent errors remain blocked for review. No long video copy is performed inside an OBS timer: destinations on another drive or network drive are rejected. Mount points that resolve to another volume can also fail safely.

If queue persistence fails, moves pause. If both queue files are unreadable, they are preserved for investigation instead of overwritten. Repair the state and reload the script.

The queue is not a video backup. It cannot repair a recording OBS never finished, detect every external file modification, or protect against hardware failure.

## Status and history

Click **Refresh status** for Replay Buffer state, pending/blocked/unclassified counts, and recent events. **Script Log** also shows session messages. There is no continuous UI-refresh timer.

Replay Buffer startup is requested only when enabled, then its state is checked. Enable Replay Buffer and configure encoding in OBS first. Failure messages point to **Settings → Output** and the OBS log.

History is capped at 80 messages and completed receipts at 100 entries. Unresolved clips are not discarded to meet those limits. Existing libraries are not scanned retroactively.

## First-run check

1. Open a game and configure Game Capture for it.
2. Save a replay.
3. Confirm the expected folder and refresh the status panel.
4. Open the video and confirm normal playback.

## Rollback

Close OBS, restore your backed-up Lua file under its original name, and reopen OBS. Preserve the queue JSON if it contains unresolved clips. Do not run the older PowerShell organizer on the same files simultaneously.

## Implementation references

- [OBS scripting](https://docs.obsproject.com/scripting)
- [OBS JSON settings API](https://docs.obsproject.com/reference-settings)
- [OBS Game Capture implementation](https://github.com/obsproject/obs-studio/blob/master/plugins/win-capture/game-capture.c)
