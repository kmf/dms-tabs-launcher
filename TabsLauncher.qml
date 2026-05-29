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

    // bt list output is TSV: <tab_id>\t<title>\t<url>
    property var listProcess: Process {
        command: [root.btPath, "list"]
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
        root.listProcess.command = [root.btPath, "list"];
        root.listProcess.running = true;
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
            icon: iconForUrl(tab.url),
            comment: tab.url,
            action: "activate:" + tab.id,
            _tabId: tab.id,
            _url: tab.url
        };
    }

    function iconForUrl(url) {
        if (!url)
            return "tab";
        let u = url.toLowerCase();
        if (u.indexOf("youtube.com") !== -1 || u.indexOf("youtu.be") !== -1)
            return "play_circle";
        if (u.indexOf("github.com") !== -1 || u.indexOf("gitlab.com") !== -1 || u.indexOf("bitbucket.org") !== -1)
            return "code";
        if (u.indexOf("docs.google.com") !== -1)
            return "description";
        if (u.indexOf("google.com/search") !== -1)
            return "search";
        if (u.indexOf("mail.google.com") !== -1)
            return "mail";
        if (u.indexOf("calendar.google.com") !== -1)
            return "calendar_month";
        if (u.indexOf("stackoverflow.com") !== -1 || u.indexOf("stackexchange.com") !== -1)
            return "help";
        if (u.indexOf("reddit.com") !== -1)
            return "forum";
        if (u.indexOf("slack.com") !== -1)
            return "tag";
        return "tab";
    }

    function executeItem(item) {
        if (!item || !item._tabId)
            return;
        Quickshell.execDetached([root.btPath, "activate", "--focused", item._tabId]);
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
                    Quickshell.execDetached([root.btPath, "close", item._tabId]);
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
        } else {
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
