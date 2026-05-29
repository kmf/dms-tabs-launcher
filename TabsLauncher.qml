import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

QtObject {
    id: root

    property var pluginService: null
    property string trigger: "tab"
    property bool enabled: true
    property string btPath: "bt"
    property int refreshIntervalMs: 5000

    signal itemsChanged

    // [{ id, title, url }]
    property var tabs: []
    property bool _loading: false
    // Resolved bt absolute path. dms.service has a minimal PATH so a bare
    // "bt" usually fails — we look it up in common install locations once.
    property string _resolvedBtPath: ""
    // Tab ID prefix (e.g. "a.") -> freedesktop icon name (e.g. "brave-browser").
    // bt clients reports "chrome/chromium" for every Chromium-based browser,
    // so we identify the actual browser by walking bt_mediator's PPID to
    // /proc/<ppid>/comm.
    property var clientIcons: ({})

    function effectiveBtPath() {
        if (root.btPath && root.btPath !== "bt")
            return root.btPath;
        return root._resolvedBtPath || "bt";
    }

    property var resolveProcess: Process {
        command: ["sh", "-c", "for p in \"$HOME/.local/bin/bt\" /usr/local/bin/bt /usr/bin/bt; do [ -x \"$p\" ] && { echo \"$p\"; exit 0; }; done; command -v bt 2>/dev/null"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let p = (text || "").trim();
                if (p.length > 0) {
                    root._resolvedBtPath = p;
                    console.log("[TabsLauncher] Resolved bt to", p);
                    root.refreshClients();
                    root.refreshTabs();
                } else {
                    console.warn("[TabsLauncher] bt not found on system");
                }
            }
        }
    }

    // bt list output is TSV: <tab_id>\t<title>\t<url>
    property var listProcess: Process {
        command: [root.effectiveBtPath(), "list"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.parseTabs(text);
            }
        }

        onExited: exitCode => {
            root._loading = false;
            if (exitCode !== 0)
                console.warn("[TabsLauncher] bt list exited with", exitCode);
        }
    }

    function refreshTabs() {
        if (root._loading)
            return;
        root._loading = true;
        root.listProcess.command = [root.effectiveBtPath(), "list"];
        root.listProcess.running = true;
    }

    property var clientsProcess: Process {
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let map = {};
                let lines = (text || "").split("\n");
                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i];
                    if (!line)
                        continue;
                    let parts = line.split("\t");
                    if (parts.length < 2)
                        continue;
                    map[parts[0]] = root.iconForBrowserName(parts[1]);
                }
                root.clientIcons = map;
                root.itemsChanged();
            }
        }
    }

    function refreshClients() {
        let bt = root.effectiveBtPath();
        if (!bt || bt === "bt")
            return;
        // bt clients gives us "<prefix>\t<host>\t<pid>\t<browser>". The pid is
        // bt_mediator (a Python helper), so we read its parent's comm to get
        // the actual browser binary name.
        root.clientsProcess.command = ["sh", "-c",
            bt + " clients | while IFS=\"\t\" read -r prefix host pid browser; do " +
            "  ppid=$(awk '/^PPid:/ {print $2}' /proc/$pid/status 2>/dev/null); " +
            "  [ -n \"$ppid\" ] || continue; " +
            "  name=$(cat /proc/$ppid/comm 2>/dev/null); " +
            "  [ -n \"$name\" ] || continue; " +
            "  printf '%s\t%s\n' \"$prefix\" \"$name\"; " +
            "done"];
        root.clientsProcess.running = true;
    }

    function iconForBrowserName(name) {
        let n = (name || "").toLowerCase();
        if (n.indexOf("brave") !== -1)
            return "brave-browser";
        if (n.indexOf("firefox") !== -1)
            return "firefox";
        if (n.indexOf("librewolf") !== -1)
            return "librewolf";
        if (n.indexOf("chromium") !== -1)
            return "chromium";
        if (n.indexOf("chrome") !== -1)
            return "google-chrome";
        if (n.indexOf("vivaldi") !== -1)
            return "vivaldi";
        if (n.indexOf("opera") !== -1)
            return "opera";
        return "tab";
    }

    function iconForTab(tab) {
        if (!tab || !tab.id)
            return "tab";
        let dot = tab.id.indexOf(".");
        if (dot < 0)
            return "tab";
        let prefix = tab.id.substring(0, dot + 1);
        return root.clientIcons[prefix] || "tab";
    }

    function parseTabs(rawData) {
        let result = [];
        let lines = (rawData || "").split("\n");
        for (let i = 0; i < lines.length; i++) {
            let line = lines[i];
            if (!line)
                continue;
            let parts = line.split("\t");
            if (parts.length < 3)
                continue;
            result.push({
                id: parts[0],
                title: parts[1],
                url: parts[2]
            });
        }
        root.tabs = result;
        root.itemsChanged();
    }

    // DMS calls getItems synchronously on each keystroke, so we filter the
    // cached tab list rather than re-running bt list (which can take 100ms+).
    function getItems(query) {
        if (!root.enabled)
            return [];

        const q = (query || "").trim().toLowerCase();
        let matches = [];

        for (let i = 0; i < root.tabs.length; i++) {
            let t = root.tabs[i];
            if (q.length === 0) {
                matches.push(t);
            } else {
                let title = (t.title || "").toLowerCase();
                let url = (t.url || "").toLowerCase();
                if (title.indexOf(q) !== -1 || url.indexOf(q) !== -1)
                    matches.push(t);
            }
            if (matches.length >= 50)
                break;
        }

        return matches.map(tabToItem);
    }

    function tabToItem(tab) {
        return {
            name: tab.title || tab.url,
            icon: iconForTab(tab),
            comment: tab.url,
            action: "activate:" + tab.id,
            _tabId: tab.id,
            _url: tab.url
        };
    }

    function executeItem(item) {
        if (!item || !item._tabId)
            return;
        Quickshell.execDetached([root.effectiveBtPath(), "activate", "--focused", item._tabId]);
    }

    function getContextMenuActions(item) {
        if (!item)
            return [];
        return [
            {
                icon: "content_copy",
                text: "Copy URL",
                action: () => {
                    let url = item._url || "";
                    Quickshell.execDetached(["sh", "-c", "echo -n '" + url.replace(/'/g, "'\\''") + "' | dms cl copy"]);
                }
            },
            {
                icon: "close",
                text: "Close tab",
                action: () => {
                    Quickshell.execDetached([root.effectiveBtPath(), "close", item._tabId]);
                    root.refreshTabs();
                }
            },
            {
                icon: "refresh",
                text: "Refresh tab list",
                action: () => root.refreshTabs()
            }
        ];
    }

    function updateSettings() {
        if (!root.pluginService)
            return;

        root.enabled = root.pluginService.loadPluginData("tabsLauncher", "enabled", true);
        root.btPath = root.pluginService.loadPluginData("tabsLauncher", "btPath", "bt");
        root.refreshIntervalMs = root.pluginService.loadPluginData("tabsLauncher", "refreshIntervalMs", 5000);

        let noTrigger = root.pluginService.loadPluginData("tabsLauncher", "noTrigger", false);
        root.trigger = noTrigger ? "" : root.pluginService.loadPluginData("tabsLauncher", "trigger", "tab");

        if (!root.enabled) {
            root.tabs = [];
            root.itemsChanged();
            return;
        }

        if (root.btPath === "bt" && root._resolvedBtPath.length === 0) {
            root.resolveProcess.running = true;
        } else {
            root.refreshClients();
            root.refreshTabs();
        }
    }

    Component.onCompleted: root.updateSettings()

    property var settingsListener: Connections {
        target: root.pluginService
        function onPluginDataChanged(pluginId) {
            if (pluginId === "tabsLauncher")
                root.updateSettings();
        }
    }

    property var initTimer: Timer {
        interval: 500
        running: true
        repeat: false
        onTriggered: root.refreshTabs()
    }

    property var refreshTimer: Timer {
        interval: root.refreshIntervalMs
        running: root.enabled
        repeat: true
        onTriggered: root.refreshTabs()
    }
}
