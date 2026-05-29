# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) launcher plugin that lists open browser tabs and activates one when selected. Tabs come from [BroTab](https://github.com/balta2ar/brotab) — the plugin shells out to the `bt` CLI; the actual browser-side integration is BroTab's WebExtension.

Sister plugin / structural template: [kmf/dms-obsidian-search](https://github.com/kmf/dms-obsidian-search). Same author, same plugin shape — mirror its conventions when in doubt.

## Layout

- `plugin.json` — DMS plugin manifest (id `tabsLauncher`, trigger `\tab`).
- `TabsLauncher.qml` — main `QtObject` the launcher loads. Implements `getItems(query)`, `executeItem(item)`, `getContextMenuActions(item)`, `updateSettings()`.
- `TabsLauncherSettings.qml` — `PluginSettings` UI (toggles + string fields). Only widgets known to exist in DMS are used: `ToggleSetting`, `StringSetting`, `StyledText`. Do not introduce `NumberSetting` etc. without confirming they exist in the target DMS version.
- `README.md`, `LICENSE` (MIT), `.gitignore` — standard.

## Architectural notes worth knowing before editing

- **`bt list` is slow (100ms+) and cannot be called synchronously on every keystroke.** DMS calls `getItems` synchronously, so we cache `tabs` in memory, refresh it from a background `Quickshell.Io.Process` on a `Timer` (default 5s) and on startup, and filter the cache inside `getItems`. Do not change `getItems` to invoke `bt` directly.
- **`bt list` output is TSV** of `<tab_id>\t<title>\t<url>`. `tab_id` looks like `a.1416043737.1416043738` (prefix.window.tab) and is what every other `bt` subcommand takes.
- **Tab activation uses `bt activate --focused <tab_id>`** so the window is focused too, not just the tab.
- **Settings are persisted via `pluginService.loadPluginData / saveValue`** keyed under the plugin id `tabsLauncher`. `updateSettings()` is the single source of truth for applying settings — re-run it when settings change rather than scattering reads.
- **The `noTrigger` setting** is paired with `trigger`: toggling it on writes an empty `trigger`, toggling it off restores the user's keyword. This mirrors dms-obsidian-search; keep the pair in sync if you touch either.
- **`bt` is not on `dms.service`'s `PATH`.** The systemd unit runs with an empty `Environment=`, so a bare `["bt", "list"]` fails with "Process failed to start, likely because the binary could not be found." `resolveProcess` runs a shell on startup to look up `bt` in `$HOME/.local/bin`, `/usr/local/bin`, `/usr/bin`, then `command -v bt`, and caches the absolute path in `_resolvedBtPath`. Always spawn `bt` via `effectiveBtPath()`, never via the raw `btPath` property. If you add another external binary, do the same.

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org/). Common scopes here: `launcher`, `settings`, `manifest`, `docs`. Examples: `feat(launcher): cache bt list across queries`, `fix(launcher): handle empty bt output`, `docs: document refresh interval`.

## Testing changes

There is no automated test suite — this is a QML plugin loaded by a running DMS instance. To verify a change manually:

1. Copy the files to `~/.config/DankMaterialShell/plugins/tabsLauncher/`.
2. Restart DMS (or its plugin host).
3. Open the launcher, type `\tab <query>`, and confirm the expected tabs appear and activate.

`bt list` must work on the shell before the plugin will show anything — sanity-check that first when results are empty.
