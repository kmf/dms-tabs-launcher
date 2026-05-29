# Browser Tabs Launcher for DMS

A [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) launcher plugin that lists every open browser tab and lets you jump to one from the launcher. Tabs are sourced via [BroTab](https://github.com/balta2ar/brotab).

![Screenshot](screenshot.png)

## Features

- Lists open tabs across every browser BroTab is connected to
- Filters by title or URL as you type
- Activates the selected tab (focuses both tab and browser window)
- Per-browser icons (Brave, Chrome, Chromium, Firefox, LibreWolf, Vivaldi, Opera) resolved via `bt clients` + `/proc` walk
- Context menu: copy URL, close tab, refresh tab list
- Always-active mode (skip trigger keyword)
- Background refresh so tab changes are picked up without re-running `bt list` on every keystroke

## Installing BroTab

The plugin shells out to the `bt` CLI, which talks to a WebExtension in your browser via a native-messaging host. All three pieces must be installed for tabs to show up.

1. **Install the `bt` CLI** (pick one):
   ```bash
   pipx install brotab        # preferred
   uv tool install brotab     # alternative
   pip install --user brotab  # alternative
   ```
2. **Install the native-messaging host manifests**:
   ```bash
   bt install
   ```
3. **Install the browser extension** in every browser you want indexed:
   - Firefox / LibreWolf: <https://addons.mozilla.org/firefox/addon/brotab/>
   - Chrome / Chromium / Brave / Vivaldi: <https://chrome.google.com/webstore/detail/brotab/mhpeahbikehnfkfnmopaigggliclhmnc/>
4. **Restart each browser** and verify with:
   ```bash
   bt clients   # should list one row per running browser
   bt list      # should print TSV of open tabs
   ```

If `bt clients` is empty after a browser restart, the native-messaging manifest is missing for that browser — re-run `bt install` and restart the browser again.

## Installing the plugin

Copy the plugin to your DMS plugins directory:

```bash
mkdir -p ~/.config/DankMaterialShell/plugins/tabsLauncher
cp TabsLauncher.qml TabsLauncherSettings.qml plugin.json \
  ~/.config/DankMaterialShell/plugins/tabsLauncher/
```

Restart DMS (`dms restart`) to discover the new plugin.

## Usage

Type `\tab` in the DMS launcher followed by your search query, or leave the query empty to see every open tab.

## Settings

Configure via DMS plugin settings:

| Setting | Description | Default |
|---|---|---|
| Enable Plugin | Toggle the plugin on/off | on |
| BroTab Path | Path to the `bt` executable | `bt` (PATH) |
| Always Active | Show results without trigger keyword | off |
| Launcher Trigger | Keyword to activate the list | `tab` |

## Requirements

- DankMaterialShell >= 1.4.0
- Quickshell
- [BroTab](https://github.com/balta2ar/brotab) — see [Installing BroTab](#installing-brotab) above. The plugin auto-discovers `bt` via the user's login shell (`$SHELL -lc`) so installs to `~/.local/bin`, pipx venvs, etc. work without further configuration.

## License

MIT
