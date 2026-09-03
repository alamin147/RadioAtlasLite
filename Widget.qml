import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    function launchRadioAtlas() {
        if (!pluginService || !pluginId)
            return

        const pluginDir = pluginService.getPluginPath(pluginId)
        if (!pluginDir)
            return

        // Keep the Lite app standalone: the DankBar widget only launches
        // the exact same run.sh users can execute manually.
        Quickshell.execDetached(["bash", pluginDir + "/run.sh"])
    }

    horizontalBarPill: Component {
        StyledRect {
            width: Theme.iconSize + Theme.spacingM * 2
            height: parent.widgetThickness
            radius: Theme.cornerRadius
            color: mouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh

            DankIcon {
                anchors.centerIn: parent
                name: "radio"
                size: Theme.iconSizeSmall
                color: Theme.surfaceText
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.launchRadioAtlas()
            }
        }
    }

    verticalBarPill: Component {
        StyledRect {
            width: parent.widgetThickness
            height: Theme.iconSize + Theme.spacingM * 2
            radius: Theme.cornerRadius
            color: mouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh

            DankIcon {
                anchors.centerIn: parent
                name: "radio"
                size: Theme.iconSizeSmall
                color: Theme.surfaceText
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.launchRadioAtlas()
            }
        }
    }
}
