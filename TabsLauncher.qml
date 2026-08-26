import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

QtObject {
    id: root

    property var pluginService: null
    property string trigger: "tab"
    property bool enabled: true
    property string tabctlPath: "tabctl"
    property int refreshIntervalMs: 5000

    signal itemsChanged

    // [{ id, title, url, profile }]
    property var tabs: []
    property bool _loading: false
    property string currentCategory: ""
    // Resolved tabctl absolute path. dms.service has a minimal PATH so a bare
    // "tabctl" usually fails — we look it up in common install locations once.
    property string _resolvedTabctlPath: ""

    function effectiveTabctlPath() {
        if (root.tabctlPath && root.tabctlPath !== "tabctl")
            return root.tabctlPath;
        return root._resolvedTabctlPath || "tabctl";
    }

    // Strategies in order: current PATH, user's login shell (loads rc/profile so
    // PATH additions like ~/.local/bin are picked up), systemd user-manager PATH,
    // then a brute-force scan of common install locations as a final safety net.
    readonly property string _resolveScript:
        "p=$(command -v tabctl 2>/dev/null); [ -n \"$p\" ] && { echo \"$p\"; exit 0; };" +
        "if [ -n \"$SHELL\" ] && [ -x \"$SHELL\" ]; then" +
        "  p=$(\"$SHELL\" -lc 'command -v tabctl' 2>/dev/null);" +
        "  [ -n \"$p\" ] && { echo \"$p\"; exit 0; };" +
        "fi;" +
        "if command -v bash >/dev/null 2>&1; then" +
        "  p=$(bash -lc 'command -v tabctl' 2>/dev/null);" +
        "  [ -n \"$p\" ] && { echo \"$p\"; exit 0; };" +
        "fi;" +
        "if command -v systemctl >/dev/null 2>&1; then" +
        "  spath=$(systemctl --user show-environment 2>/dev/null | sed -n 's/^PATH=//p');" +
        "  if [ -n \"$spath\" ]; then" +
        "    IFS=:;" +
        "    for d in $spath; do" +
        "      [ -x \"$d/tabctl\" ] && { echo \"$d/tabctl\"; exit 0; };" +
        "    done;" +
        "    unset IFS;" +
        "  fi;" +
        "fi;" +
        "for p in \"$HOME/.local/bin/tabctl\" \"$HOME/bin/tabctl\" /usr/local/bin/tabctl /usr/bin/tabctl; do" +
        "  [ -x \"$p\" ] && { echo \"$p\"; exit 0; };" +
        "done;" +
        "exit 1"

    property var resolveProcess: Process {
        command: ["sh", "-c", root._resolveScript]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let p = (text || "").trim();
                if (p.length > 0) {
                    root._resolvedTabctlPath = p;
                    console.log("[TabsLauncher] Resolved tabctl to", p);
                    root.refreshTabs();
                } else {
                    console.warn("[TabsLauncher] tabctl not found on system; set 'tabctl Path' in plugin settings to override");
                }
            }
        }
    }

    // tabctl list output is TSV: <tab_id>\t<title>\t<url>
    property var listProcess: Process {
        command: [root.effectiveTabctlPath(), "list"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.parseTabs(text);
            }
        }

        onExited: exitCode => {
            root._loading = false;
            if (exitCode !== 0)
                console.warn("[TabsLauncher] tabctl list exited with", exitCode);
        }
    }

    function refreshTabs() {
        if (root._loading)
            return;
        if (root.tabctlPath === "tabctl" && root._resolvedTabctlPath.length === 0) {
            // Path not resolved yet. Kick off the resolver; its callback will
            // re-trigger refreshTabs once a real path is known.
            if (!root.resolveProcess.running)
                root.resolveProcess.running = true;
            return;
        }
        root._loading = true;
        root.listProcess.command = [root.effectiveTabctlPath(), "list"];
        root.listProcess.running = true;
    }

    // Tab IDs are <browser>.<window_id>.<tab_id>. Extra profiles of the same
    // browser get a numeric suffix (firefox2, chrome3) — that suffix is the
    // profile group, so keep it.
    function profileFromTabId(tabId) {
        let id = tabId || "";
        let dot = id.indexOf(".");
        if (dot < 0)
            return "";
        return id.substring(0, dot);
    }

    function prettyNameForFamily(family) {
        // tabctl Keys lowercased. Compound editions/channels need spaces.
        switch (family) {
        case "braveorigin":
            return "Brave Origin";
        case "braveoriginbeta":
            return "Brave Origin Beta";
        case "braveoriginnightly":
            return "Brave Origin Nightly";
        case "braveorigindevelopment":
            return "Brave Origin Development";
        case "bravebeta":
            return "Brave Beta";
        case "bravenightly":
            return "Brave Nightly";
        case "bravedevelopment":
            return "Brave Development";
        case "librewolf":
            return "LibreWolf";
        default:
            if (!family)
                return "";
            return family.charAt(0).toUpperCase() + family.slice(1);
        }
    }

    function displayNameForProfile(profile) {
        let p = profile || "";
        let m = p.match(/^([A-Za-z]+)([0-9]*)$/);
        if (!m)
            return p;
        let pretty = root.prettyNameForFamily(m[1].toLowerCase());
        if (m[2])
            return pretty + " " + m[2];
        return pretty;
    }

    function iconForBrowserName(name) {
        let n = (name || "").toLowerCase();
        // Brave Origin is a separate product (icon brave-origin). Match it
        // before the generic "brave" prefix, including extra profiles
        // (braveorigin2) and channels (braveoriginnightly).
        if (n.indexOf("braveorigin") !== -1 || n.indexOf("brave-origin") !== -1)
            return "brave-origin";
        if (n.indexOf("brave") !== -1)
            return "brave-browser";
        if (n.indexOf("librewolf") !== -1)
            return "librewolf";
        if (n.indexOf("firefox") !== -1)
            return "firefox";
        if (n.indexOf("zen") !== -1)
            return "zen-browser";
        if (n.indexOf("helium") !== -1)
            return "helium";
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
        return root.iconForBrowserName(tab.profile || root.profileFromTabId(tab.id));
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
                url: parts[2],
                profile: root.profileFromTabId(parts[0])
            });
        }
        root.tabs = result;
        if (root.currentCategory.length > 0) {
            let stillThere = false;
            for (let i = 0; i < result.length; i++) {
                if (result[i].profile === root.currentCategory) {
                    stillThere = true;
                    break;
                }
            }
            if (!stillThere)
                root.currentCategory = "";
        }
        root.itemsChanged();
        if (root.pluginService)
            root.pluginService.requestLauncherUpdate("tabsLauncher");
    }

    function uniqueProfiles() {
        let profiles = [];
        let seen = {};
        for (let i = 0; i < root.tabs.length; i++) {
            let p = root.tabs[i].profile || root.profileFromTabId(root.tabs[i].id);
            if (!p || seen[p])
                continue;
            seen[p] = true;
            profiles.push(p);
        }
        return profiles;
    }

    // Profiles become a category dropdown when the plugin is active. Empty
    // query keeps tabs grouped by profile instead of flattening them.
    function getCategories() {
        let profiles = root.uniqueProfiles();
        if (profiles.length < 2)
            return [];
        let cats = [{
                id: "",
                name: "All",
                searchTerm: ""
            }];
        for (let i = 0; i < profiles.length; i++) {
            cats.push({
                id: profiles[i],
                name: root.displayNameForProfile(profiles[i]),
                searchTerm: ""
            });
        }
        return cats;
    }

    function setCategory(categoryId) {
        let next = categoryId || "";
        if (root.currentCategory === next)
            return;
        root.currentCategory = next;
    }

    // DMS calls getItems synchronously on each keystroke, so we filter the
    // cached tab list rather than re-running tabctl list.
    function getItems(query) {
        if (!root.enabled)
            return [];

        const q = (query || "").trim().toLowerCase();
        const cat = root.currentCategory || "";
        let grouped = [];
        let groupIndex = {};

        for (let i = 0; i < root.tabs.length; i++) {
            let t = root.tabs[i];
            let profile = t.profile || root.profileFromTabId(t.id);
            if (cat.length > 0 && profile !== cat)
                continue;
            if (q.length > 0) {
                let title = (t.title || "").toLowerCase();
                let url = (t.url || "").toLowerCase();
                let profileKey = profile.toLowerCase();
                let profileName = root.displayNameForProfile(profile).toLowerCase();
                if (title.indexOf(q) === -1 && url.indexOf(q) === -1 && profileKey.indexOf(q) === -1 && profileName.indexOf(q) === -1)
                    continue;
            }
            if (groupIndex[profile] === undefined) {
                groupIndex[profile] = grouped.length;
                grouped.push({
                    profile: profile,
                    tabs: []
                });
            }
            grouped[groupIndex[profile]].tabs.push(t);
        }

        let matches = [];
        let limit = q.length > 0 ? 50 : 200;
        for (let g = 0; g < grouped.length; g++) {
            for (let j = 0; j < grouped[g].tabs.length; j++) {
                matches.push(grouped[g].tabs[j]);
                if (matches.length >= limit)
                    return matches.map(tabToItem);
            }
        }
        return matches.map(tabToItem);
    }

    function collapseWhitespace(s) {
        return (s || "").replace(/\s+/g, " ").trim();
    }

    function truncate(s, max) {
        s = root.collapseWhitespace(s);
        if (s.length <= max)
            return s;
        return s.substring(0, Math.max(0, max - 1)) + "…";
    }

    function compactUrl(url) {
        let u = root.collapseWhitespace(url);
        u = u.replace(/^https?:\/\//i, "");
        u = u.replace(/^www\./i, "");
        return root.truncate(u, 56);
    }

    function tabToItem(tab) {
        let profile = tab.profile || root.profileFromTabId(tab.id);
        let profileName = root.displayNameForProfile(profile);
        return {
            // Search highlighting uses RichText, which ignores maximumLineCount
            // and overflows the row — keep these short enough for one line.
            name: root.truncate(tab.title || tab.url, 56),
            icon: iconForTab(tab),
            comment: profileName + " · " + root.compactUrl(tab.url),
            action: "activate:" + tab.id,
            categories: [profileName],
            keywords: [profile, profileName],
            _tabId: tab.id,
            _url: tab.url,
            _profile: profile
        };
    }

    function executeItem(item) {
        if (!item || !item._tabId)
            return;
        Quickshell.execDetached([root.effectiveTabctlPath(), "activate", "--focused", item._tabId]);
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
                    Quickshell.execDetached([root.effectiveTabctlPath(), "close", item._tabId]);
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
        root.tabctlPath = root.pluginService.loadPluginData("tabsLauncher", "tabctlPath", "tabctl");
        root.refreshIntervalMs = root.pluginService.loadPluginData("tabsLauncher", "refreshIntervalMs", 5000);

        let noTrigger = root.pluginService.loadPluginData("tabsLauncher", "noTrigger", false);
        root.trigger = noTrigger ? "" : root.pluginService.loadPluginData("tabsLauncher", "trigger", "tab");

        if (!root.enabled) {
            root.tabs = [];
            root.itemsChanged();
            return;
        }

        if (root.tabctlPath === "tabctl" && root._resolvedTabctlPath.length === 0) {
            root.resolveProcess.running = true;
        } else {
            root.refreshTabs();
        }
    }

    Component.onCompleted: {
        // pluginService may not be injected yet at component completion, but
        // tabctl path resolution doesn't depend on it — start it now so
        // refreshTabs is ready by the time anyone wants the tab list.
        if (root._resolvedTabctlPath.length === 0 && !root.resolveProcess.running)
            root.resolveProcess.running = true;
        root.updateSettings();
    }

    onPluginServiceChanged: {
        if (root.pluginService)
            root.updateSettings();
    }

    property var settingsListener: Connections {
        target: root.pluginService
        function onPluginDataChanged(pluginId) {
            if (pluginId === "tabsLauncher")
                root.updateSettings();
        }
    }

    property var refreshTimer: Timer {
        interval: root.refreshIntervalMs
        running: root.enabled
        repeat: true
        onTriggered: root.refreshTabs()
    }
}
