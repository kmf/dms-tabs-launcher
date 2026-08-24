# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) launcher plugin that lists open browser tabs and activates one when selected. Tabs come from [tabctl](https://github.com/slastra/tabctl) — the plugin shells out to the `tabctl` CLI; the actual browser-side integration is tabctl's WebExtension + D-Bus mediator.

Sister plugin / structural template: [kmf/dms-obsidian-search](https://github.com/kmf/dms-obsidian-search). Same author, same plugin shape — mirror its conventions when in doubt.

## Layout

- `plugin.json` — DMS plugin manifest (id `tabsLauncher`, trigger `\tab`).
- `TabsLauncher.qml` — main `QtObject` the launcher loads. Implements `getItems(query)`, `executeItem(item)`, `getContextMenuActions(item)`, `updateSettings()`.
- `TabsLauncherSettings.qml` — `PluginSettings` UI (toggles + string fields). Only widgets known to exist in DMS are used: `ToggleSetting`, `StringSetting`, `StyledText`. Do not introduce `NumberSetting` etc. without confirming they exist in the target DMS version.
- `README.md`, `LICENSE` (MIT), `.gitignore` — standard.

## Architectural notes worth knowing before editing

- **`tabctl list` cannot be called synchronously on every keystroke.** DMS calls `getItems` synchronously, so we cache `tabs` in memory, refresh it from a background `Quickshell.Io.Process` on a `Timer` (default 5s) and on startup, and filter the cache inside `getItems`. Do not change `getItems` to invoke `tabctl` directly.
- **`tabctl list` output is TSV** of `<tab_id>\t<title>\t<url>`. `tab_id` looks like `firefox.1.2` or `brave.1234.5678` (`<browser>.<window_id>.<tab_id>`) and is what every other `tabctl` subcommand takes. Extra profiles of the same browser get a numeric suffix (`firefox2`, `chrome3`) — that suffix **is** the profile group; do not strip it.
- **Empty queries group tabs by profile** (firefox, then firefox2, …). `getCategories` / `setCategory` expose those profiles as the launcher category dropdown when more than one is connected. Browser icons still come from the tab ID prefix (`firefox2` matches Firefox).
- **Tab activation uses `tabctl activate --focused <tab_id>`** so the window is focused too, not just the tab.
- **Settings are persisted via `pluginService.loadPluginData / saveValue`** keyed under the plugin id `tabsLauncher`. `updateSettings()` is the single source of truth for applying settings — re-run it when settings change rather than scattering reads.
- **The `noTrigger` setting** is paired with `trigger`: toggling it on writes an empty `trigger`, toggling it off restores the user's keyword. This mirrors dms-obsidian-search; keep the pair in sync if you touch either.
- **`tabctl` is not on `dms.service`'s `PATH`.** The systemd unit runs with an empty `Environment=`, so a bare `["tabctl", "list"]` fails with "Process failed to start, likely because the binary could not be found." `resolveProcess` runs `_resolveScript` on startup, which tries `command -v tabctl`, then `$SHELL -lc 'command -v tabctl'` (loads the user's profile so PATH additions are picked up), then `bash -lc`, then `systemctl --user show-environment` for the user-manager PATH, and finally a brute-force scan of common install dirs. The result is cached in `_resolvedTabctlPath`. Always spawn `tabctl` via `effectiveTabctlPath()`, never via the raw `tabctlPath` property. If you add another external binary, factor out a similar resolver — do not hardcode paths.

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org/). Common scopes here: `launcher`, `settings`, `manifest`, `docs`. Examples: `feat(launcher): cache tabctl list across queries`, `fix(launcher): handle empty tabctl output`, `docs: document refresh interval`.

## Testing changes

There is no automated test suite — this is a QML plugin loaded by a running DMS instance. To verify a change manually:

1. Copy the files to `~/.config/DankMaterialShell/plugins/tabsLauncher/`.
2. Restart DMS (or its plugin host).
3. Open the launcher, type `\tab <query>`, and confirm the expected tabs appear and activate.

`tabctl list` must work on the shell before the plugin will show anything — sanity-check that first when results are empty.
