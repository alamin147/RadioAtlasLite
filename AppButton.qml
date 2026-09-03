import QtQuick

Rectangle {
    id: root

    property string text: ""
    property bool active: false
    property bool enabled: true
    property color foreground: "#e8eaed"
    property color accent: "#8ab4f8"
    property color background: "#1c2127"
    property color hoverBackground: "#29313a"
    property int fontSize: 13
    property int horizontalPadding: 12
    property int buttonHeight: 34
    property string tooltip: ""

    signal clicked()

    implicitWidth: label.implicitWidth + horizontalPadding * 2
    implicitHeight: buttonHeight
    radius: 8
    color: !enabled ? Qt.rgba(1, 1, 1, 0.035)
                    : active ? Qt.rgba(accent.r, accent.g, accent.b, 0.18)
                    : mouse.containsMouse ? hoverBackground : background
    border.width: active ? 1 : 0
    border.color: accent
    opacity: enabled ? 1 : 0.45

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.active ? root.accent : root.foreground
        font.pixelSize: root.fontSize
        font.bold: root.active
        textFormat: Text.PlainText
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: root.enabled
        onClicked: root.clicked()
    }
}
