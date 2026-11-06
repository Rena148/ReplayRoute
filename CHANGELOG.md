# Changelog

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
