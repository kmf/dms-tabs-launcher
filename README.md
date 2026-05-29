# Browser Tabs Launcher for DMS

A [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) launcher plugin that lists every open browser tab and lets you jump to one from the launcher. Tabs are sourced via [BroTab](https://github.com/balta2ar/brotab).

## Features

- Lists open tabs across every browser BroTab is connected to
- Filters by title or URL as you type
- Activates the selected tab (focuses both tab and browser window)
- Context menu: copy URL, close tab, refresh tab list
- URL-based icon guesses for common sites (YouTube, GitHub, Gmail, etc.)
- Always-active mode (skip trigger keyword)
- Background refresh so tab changes are picked up without re-running `bt list` on every keystroke

## Installation

Copy the plugin to your DMS plugins directory:

```bash
mkdir -p ~/.config/DankMaterialShell/plugins/tabsLauncher
cp TabsLauncher.qml TabsLauncherSettings.qml plugin.json \
  ~/.config/DankMaterialShell/plugins/tabsLauncher/
```

Restart DMS to discover the new plugin.

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
- [BroTab](https://github.com/balta2ar/brotab) installed (`bt` on `$PATH`) with the browser extension paired

## License

MIT
