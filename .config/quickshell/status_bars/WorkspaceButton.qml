import QtQuick

Rectangle {
    id: root

    required property var workspace
    property color backgroundColor: "#100f0f"
    property color hoverColor: "#1c1b1a"
    property color textColor: "#cecdc3"
    property color mutedColor: "#878580"
    property color urgentColor: "#d14d41"
    property color bottomBorderColor: "#403e3c"

    implicitWidth: 22
    implicitHeight: 28
    radius: 5
    color: workspace.urgent ? urgentColor : (mouseArea.containsMouse ? hoverColor : backgroundColor)

    Text {
        anchors.centerIn: parent
        text: {
            if (root.workspace.active)
                return ""
            if (root.workspace.name && root.workspace.name.length > 0)
                return root.workspace.name
            const coords = root.workspace.coordinates
            return coords && coords.length > 0 ? String(coords[0] + 1) : "•"
        }
        color: root.workspace.urgent ? backgroundColor : (root.workspace.shouldDisplay ? textColor : mutedColor)
        font.family: "IosevkaTerm Nerd Font Propo"
        font.pixelSize: 14
        font.weight: root.workspace.active ? Font.Bold : Font.Medium
        renderType: Text.NativeRendering
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: root.bottomBorderColor
    }


    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.workspace.activate()
    }

    Behavior on color {
        ColorAnimation { duration: 100 }
    }
}
