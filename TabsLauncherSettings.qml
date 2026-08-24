import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "tabsLauncher"

    StyledText {
        width: parent.width
        text: "Browser Tabs Launcher"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    ToggleSetting {
        settingKey: "enabled"
        label: "Enable Plugin"
        description: "List open browser tabs in the launcher (via tabctl)"
        defaultValue: true
    }

    StringSetting {
        settingKey: "tabctlPath"
        label: "tabctl Path"
        description: "Path to the tabctl executable (e.g. /home/user/.local/bin/tabctl). Leave as 'tabctl' to use PATH."
        defaultValue: "tabctl"
    }

    ToggleSetting {
        id: noTriggerToggle
        settingKey: "noTrigger"
        label: "Always Active"
        description: value ? "Tabs always appear in the launcher. Type a title or URL to filter." : "Use a trigger prefix to list open tabs. Type the trigger followed by a search term."
        defaultValue: false
        onValueChanged: {
            if (value) {
                root.saveValue("trigger", "");
            } else {
                root.saveValue("trigger", triggerSetting.value || "tab");
            }
        }
    }

    StringSetting {
        id: triggerSetting
        visible: !noTriggerToggle.value
        settingKey: "trigger"
        label: "Trigger"
        description: "Prefix character(s) to list open tabs (e.g., \\tab, @, tabs)"
        placeholder: "\\tab"
        defaultValue: "tab"
    }
}
