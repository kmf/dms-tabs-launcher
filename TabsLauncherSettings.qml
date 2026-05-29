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
        description: "List open browser tabs in the launcher (via BroTab)"
        defaultValue: true
    }

    StringSetting {
        settingKey: "btPath"
        label: "BroTab Path"
        description: "Path to the bt executable (e.g. /home/user/.local/bin/bt). Leave as 'bt' to use PATH."
        defaultValue: "bt"
    }

    ToggleSetting {
        id: noTriggerToggle
        settingKey: "noTrigger"
        label: "Always Active (No Trigger)"
        description: value ? "Tabs always appear in the launcher." : "Use a trigger keyword to list tabs."
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
        label: "Launcher Trigger"
        description: "Example: '\\tab' or 'tabs'"
        defaultValue: "tab"
    }
}
