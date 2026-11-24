# Changelog

## 2.3.0 — 2026-11-24

- Identify the executable reported by an active Game Capture hook, including fullscreen capture. Recognize registered games in Window Capture.
- Remember capture loss in the same program scene for up to 45 seconds while the game process is running.
- Strip common technical executable suffixes (`-Win64-Shipping`, `_dx12`, etc.), reuse uniquely matching existing folders in **Base folder**, and remove empty leftover game folders after reclassification.
- Compact OBS Scripts labels with hover tooltips and prioritize game management controls inside **Manage games and settings** for wider input space.
- Apply game-list edits together, retain games learned while editing and fill in the executable when a clip is selected.
- Page the clip selector and optionally finish tracking auto-routed clips from previous calendar months.
- Support drive roots and dot-prefixed base directories. Check mounted volumes before moving a clip.
- Test hook loss, scene changes, nested and hidden sources, rule edits, folder matching, empty folder cleanup, archive persistence and destination paths.

## 2.2.0 — 2026-11-18

- Remember a newly detected Game Capture executable after its first successful move.
- Group manual game management and recovery under **Manage games and advanced settings**.

## 2.1.0 — 2026-11-05

- Automatically create executable-named folders for unknown specific Game Capture targets, with an enabled-by-default toggle.
- Keep ambiguous targets and unknown foreground-only detections unclassified.
- Preserve automatic routing metadata across reloads and allow later reclassification with friendly rules.
- Validate generated folder names and preserve non-overwriting moves.
- Add tests for automatic routing, option disabling, rule precedence, unsafe names, ambiguous captures, persistence, and reclassification.

## 2.0.1 — 2026-11-05

- Rename the project to **ReplayRoute**.
- Translate the interface, messages, comments, documentation, and repository description into English.
- Use `Unclassified` as the default for new installations while retaining existing folder preferences.
- Keep the Lua filename and state schema unchanged for upgrade compatibility.

## 2.0.0 — 2026-11-05

Initial public recovery-enabled version:

- Non-replacing moves and numbered collision suffixes.
- Visible Game Capture target and foreground-window detection, with ambiguity handling.
- Persistent JSON queue, backup, and interrupted-move reconciliation.
- Bounded retries for temporary failures and manual review for permanent errors.
- Rules editing and reclassification within OBS script properties.
- Replay Buffer state checks and bounded history.
- Cross-drive copy and network-destination rejection.
- Windows tests with real file operations and simulated OBS events.
