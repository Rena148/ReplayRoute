<div align="center">
  <br>
  <p>
    <img src="docs/brand/replayroute-icon.png" width="112" height="112" alt="ReplayRoute icon">
  </p>
  <h1>ReplayRoute</h1>
  <p>
    <b>English</b> · <a href="README.es.md">Español</a>
  </p>
  <p>
    <b>Save the replay. Keep it organized.</b><br>
    A lightweight OBS Studio Lua script for <b>64-bit Windows</b> that routes Replay Buffer clips straight into per-game folders — without launching external processes, console windows, or network requests.
  </p>
  <p>
    <a href="#releases--download"><img alt="Version 2.3.1" src="https://img.shields.io/badge/version-2.3.1-2563eb?style=flat-square"></a>
    <img alt="Platform: Windows x64" src="https://img.shields.io/badge/Windows_x64-OBS_Studio_(LuaJIT)-1e293b?style=flat-square">
    <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-3a3a3a?style=flat-square"></a>
    <img alt="No telemetry · Offline" src="https://img.shields.io/badge/offline-no_telemetry-16a34a?style=flat-square">
  </p>
  <p>
    <a href="https://github.com/Rena148/ReplayRoute/releases/latest/download/obs_replay_organizer.lua"><img alt="Download obs_replay_organizer.lua" src="https://img.shields.io/badge/Download-obs__replay__organizer.lua_(v2.3.1)-2563eb?style=for-the-badge&logo=lua&logoColor=white" height="40"></a>
    <a href="https://github.com/Rena148/ReplayRoute/archive/refs/tags/v2.3.1.zip"><img alt="Download Source ZIP" src="https://img.shields.io/badge/Source_Archive-.zip-334155?style=for-the-badge" height="40"></a>
  </p>
  <p>
    <sub>Only <code>obs_replay_organizer.lua</code> is needed to run inside OBS Studio · <a href="#releases--download">All releases &amp; direct files</a></sub>
  </p>
  <p>
    <a href="#features">Features</a> ·
    <a href="#releases--download">Download</a> ·
    <a href="#quick-start">Quick start</a> ·
    <a href="#managing-games-and-clips">Manage games</a> ·
    <a href="#behavior-and-limits">Behavior &amp; limits</a> ·
    <a href="#tests">Tests</a> ·
    <a href="docs/GUIDE.md">User guide</a>
  </p>
</div>

<br>

<p align="center">
  <img src="docs/preview.png" width="840" alt="ReplayRoute 2.3.1 inside OBS Studio Scripts with Manage games and settings collapsed">
  <br>
  <sub>Main script panel in OBS Studio showing Replay Buffer state, pending/unclassified counters, and collapsed controls.</sub>
</p>

<br>

<table>
  <tr>
    <td width="25%" valign="top">
      <h3>🎮 Game Capture aware</h3>
      Reads the active executable directly from visible Game Capture hooks (including fullscreen) and handles Alt-Tab gaps for up to 45 seconds while the game process is alive.
    </td>
    <td width="25%" valign="top">
      <h3>📁 Smart auto-folders</h3>
      Strips technical suffixes (such as <code>-Win64-Shipping</code> or <code>_dx12</code>), reuses uniquely matching existing folders inside <b>Base folder</b>, or creates new folders automatically.
    </td>
    <td width="25%" valign="top">
      <h3>🛡️ Crash-safe queue</h3>
      Tracks moves in a persistent JSON journal, never overwrites existing clips, retries temporary Windows file locks, and blocks slow cross-drive or network copies.
    </td>
    <td width="25%" valign="top">
      <h3>⚙️ Manage inside OBS</h3>
      Edit <b>Game list</b>, reclassify clips manually, prune empty leftover folders, hide clips already deleted from disk, and archive older months right inside OBS Scripts.
    </td>
  </tr>
</table>

<br>

## Releases & Download

ReplayRoute does not require an installer. **`obs_replay_organizer.lua` is the only file OBS Studio needs**; documentation and automated tests live in `docs/` and `tests/`.

| Download option | What you get | Link |
|---|---|---|
| **Standalone script (Recommended)** | Single `obs_replay_organizer.lua` file for OBS (1-click direct download from Releases) | [`obs_replay_organizer.lua` (v2.3.1)](https://github.com/Rena148/ReplayRoute/releases/latest/download/obs_replay_organizer.lua) · [View source](https://github.com/Rena148/ReplayRoute/blob/v2.3.1/obs_replay_organizer.lua) |
| **Full source archive (`.zip`)** | Complete `v2.3.1` repository including guide, screenshots, and LuaJIT test suite | [`ReplayRoute-v2.3.1.zip`](https://github.com/Rena148/ReplayRoute/archive/refs/tags/v2.3.1.zip) |
| **Releases & older versions** | Tagged versions, release notes, and full version history | [GitHub Releases](https://github.com/Rena148/ReplayRoute/releases) · [Tags](https://github.com/Rena148/ReplayRoute/tags) · [Changelog](CHANGELOG.md) |

### Recent versions

- **`v2.3.1`** — Minimal default game list (Deadlock only), automatic pruning of deleted `unclassified` and `auto_routed` clips on open/refresh/retry, refreshed previews and bilingual documentation.
- **`v2.3.0`** — Native fullscreen Game Capture hook detection, 45-second Alt-Tab grace with Windows process check, technical suffix stripping, smart existing folder reuse, empty folder cleanup, and compact OBS UI.
- **`v2.2.0`** — Simplified **Add or update rule** workflow inside OBS.

See [CHANGELOG.md](CHANGELOG.md) for the complete history.

## Quick start

1. Download [`obs_replay_organizer.lua`](https://github.com/Rena148/ReplayRoute/releases/latest/download/obs_replay_organizer.lua) (or download and extract [`ReplayRoute-v2.3.1.zip`](https://github.com/Rena148/ReplayRoute/archive/refs/tags/v2.3.1.zip)) to a permanent writable folder on your PC.
2. Open **OBS → Tools → Scripts → `+`** and load `obs_replay_organizer.lua`.
3. Set **Base folder** to a local directory on the **same drive and volume as your original clips** (the default placeholder `D:\Videos` should match your drive).
4. Enable and configure Replay Buffer in **OBS → Settings → Output**, and bind a hotkey to save replays.
5. Launch a game with **Game Capture** set to **Capture any fullscreen application** or **Capture specific window**, save a replay, and click **Refresh status** to check the destination.

> [!NOTE]
> Keep the filename `obs_replay_organizer.lua` unchanged when upgrading so existing OBS settings and your pending queue carry over cleanly. Load only one copy of the script.

## Features

- **Zero overwrites:** filename collisions automatically receive numbered suffixes (`clip (1).mp4`) and native Win32 moves disallow replacing existing files.
- **Game-aware routing:** inspects visible OBS capture sources (`Game Capture` and `Window Capture`, including inside groups and nested scenes).
- **Minimal defaults:** ships only with Deadlock (`project8.exe` / `deadlock.exe`); all other games are learned automatically or added explicitly.
- **Recoverable moves:** persistent JSON queue (`obs_organizer_state.json` + `.bak`) reconciles moves across OBS restarts.
- **Bounded retries:** locked files wait with increasing delays up to six attempts before pausing for manual review.
- **Built-in cleanup:** deleted clips disappear from **Clip to reclassify** when **Base folder** is accessible, and empty leftover folders are removed after reclassifying.
- **Optional auto-start:** can request Replay Buffer startup when OBS finishes loading.

## Managing games and clips

<p align="center">
  <img src="docs/preview-manage.png" width="840" alt="ReplayRoute 2.3.1 with Manage games and settings expanded showing Game list, Clip to reclassify, and reclassification actions">
  <br>
  <sub>Expanded <b>Manage games and settings</b> view: rule editor, clip selector, and manual reassignment buttons.</sub>
</p>

When **Auto-create game folders** is enabled (default), ReplayRoute inspects the executable from Game Capture, strips common technical suffixes (`-Win64-Shipping`, `_dx12`, etc.), reuses a uniquely matching subfolder already inside **Base folder** (for example `rocketleague.exe` → `Rocket League`), or creates a folder from the cleaned name and remembers the rule after the move succeeds.

Inside **Manage games and settings**:

- **Edit multiple rules at once:** modify **Game list** (`exe = Folder name`, one per line) and click **Apply game list and retry**.

  ```text
  newgame.exe = My Game
  anothergame.exe = Another Game
  ```

- **Rename a game and move tracked clips:** fill in **Executable** and **Folder**, then click **Save rule and reclassify**. Empty automatic subfolders left behind inside **Base folder** are removed automatically.
- **Reclassify a single clip:** choose an entry in **Clip to reclassify** (newest first, 50 per page; selecting a clip pre-fills its executable when known), enter a **Folder**, and click **Assign to selected clip**.
- **Archive previous months:** click **Finish tracking … older clips** when available to mark old `auto_routed` clips complete without moving them again.
- **Sync deleted files:** manually deleted `unclassified` or `auto_routed` clips clear out automatically from **Clip to reclassify** and status counts when you open **Scripts**, expand **Manage games and settings**, click **Refresh status**, or apply rules (while preserving entries whenever **Base folder** is unmounted).

## Updating

Back up your existing `obs_replay_organizer.lua` and `obs_organizer_state.json`. Replace `obs_replay_organizer.lua` in the same folder and click **Reload (`↻`)** in OBS. Existing OBS settings, **Base folder**, and your saved **Game list** remain intact. Do not run another clip-moving script on the same files simultaneously.

## Behavior and limits

<details>
<summary>Expand technical details on detection, safety limits, and storage</summary>

- If Game Capture loses its hook on Alt-Tab, ReplayRoute remembers the last confirmed executable on that source for up to 45 seconds in the same scene while the process is running. With no live hook, a specific-window Game Capture target or a recognized foreground game can identify the clip; ambiguous targets route to your unclassified folder.
- Only new Replay Buffer saves and saved queue entries are processed; ReplayRoute does not scan existing video folders.
- Moves stay on the same local volume (`MoveFileExW` without `COPY_ALLOWED`). Cross-drive and network targets are blocked instead of performing slow copies on the OBS thread.
- The queue journal tracks move state, not video integrity, and pauses moves if queue persistence fails.
- Processing is event-driven with short timers rather than polling; **Refresh status** updates panel counts and history on demand.
- Runtime state is stored beside the script in `obs_organizer_state.json` and `obs_organizer_state.json.bak` (ignored by Git).

</details>

## Tests

Requirements: **Windows x64**, **64-bit Python**, and **OBS Studio** installed. Python is only required to run the test suite, not to use ReplayRoute.

```powershell
python tests/run_lua.py tests/test_organizer.lua
```

For a custom OBS installation path:

```powershell
$env:OBS_BIN = 'E:\Apps\obs-studio\bin\64bit'
python tests/run_lua.py tests/test_organizer.lua
```

The suite executes under OBS's bundled LuaJIT and `libobs` using real temporary files, Win32 process snapshots, file lock tests, simulated capture/scene signals, and JSON persistence.

> [!IMPORTANT]
> Automated tests do not replace real-world validation: test saving a replay inside OBS during live gameplay to confirm behavior on your setup.

## Documentation & License

- [User guide (English)](docs/GUIDE.md) · [Guía de usuario (Español)](docs/GUIDE.es.md)
- [Changelog](CHANGELOG.md)
- **License:** [MIT](LICENSE) — Copyright © 2026 Rena148. OBS Studio and LuaJIT are not redistributed and keep their respective licenses. ReplayRoute is an independent script, not an official OBS project.
