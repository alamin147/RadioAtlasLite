import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    function launchRadioAtlas() {
        if (!pluginService || !pluginId) {
            console.warn("Radio Atlas Lite: plugin context is unavailable")
            return
        }

        let pluginDir = String(pluginService.getPluginPath(pluginId) || "")
        if (pluginDir.startsWith("file://"))
            pluginDir = pluginDir.substring(7)
        if (!pluginDir) {
            console.warn("Radio Atlas Lite: could not resolve the plugin directory")
            return
        }

        // Keep the Lite app standalone: the DankBar widget only launches
        // the exact same run.sh users can execute manually.
        Quickshell.execDetached(["bash", pluginDir + "/run.sh"])
    }

    // BasePill owns the pointer handler. Using its supported action hook keeps
    // clicks working across DMS bar orientations and avoids a nested MouseArea
    // consuming the event before PluginComponent can dispatch it.
    pillClickAction: function() {
        root.launchRadioAtlas()
    }

    horizontalBarPill: Component {
        Item {
            implicitWidth: root.iconSize
            implicitHeight: root.iconSize

            DankIcon {
                anchors.centerIn: parent
                name: "radio"
                size: root.iconSize
                color: Theme.widgetIconColor
            }
        }
    }

    verticalBarPill: Component {
        Item {
            implicitWidth: root.iconSize
            implicitHeight: root.iconSize

            DankIcon {
                anchors.centerIn: parent
                name: "radio"
                size: root.iconSize
                color: Theme.widgetIconColor
            }
        }
    }
}
