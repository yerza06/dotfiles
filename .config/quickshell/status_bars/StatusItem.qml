import QtQuick
import Quickshell

Rectangle {
    id: root

    required property string text
    property color foreground: "#cecdc3"
    property color hoverForeground: foreground
    property color background: "transparent"
    property color hoverBackground: "#282726"
    property color borderColor: "transparent"
    property color bottomBorderColor: "#403e3c"
    property string tooltipTitle: ""
    property string tooltipText: ""
    property bool tooltipForceVisible: false
    property color tooltipBackground: "#100f0f"
    property color tooltipBorderColor: "#575653"
    property color tooltipTextColor: foreground
    property string fontFamily: "IosevkaTerm Nerd Font Propo"
    property int horizontalPadding: 6
    property bool highlighted: false

    signal pressed(int button)
    signal scrolled(int direction)

    implicitWidth: label.implicitWidth + horizontalPadding * 2
    implicitHeight: 28
    radius: 3
    color: mouseArea.containsMouse ? hoverBackground : background
    border.width: highlighted ? 1 : 0
    border.color: borderColor

    Behavior on color {
        ColorAnimation { duration: 100 }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: mouseArea.containsMouse ? root.hoverForeground : root.foreground
        font.family: root.fontFamily
        font.pixelSize: 14
        font.weight: Font.Medium
        renderType: Text.NativeRendering
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: root.bottomBorderColor
    }

    PopupWindow {
        anchor.item: root
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.bottom: 4
        visible: (mouseArea.containsMouse || root.tooltipForceVisible)
            && root.tooltipText.length > 0
        implicitWidth: 280
        implicitHeight: 72
        color: "transparent"
        grabFocus: false

        Rectangle {
            anchors.fill: parent
            color: root.tooltipBackground
            border.width: 1
            border.color: root.tooltipBorderColor
            radius: 5

            Column {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                Text {
                    text: root.tooltipTitle
                    color: root.tooltipTextColor
                    font.family: root.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    renderType: Text.NativeRendering
                }

                Text {
                    text: root.tooltipText
                    color: root.tooltipTextColor
                    font.family: root.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    renderType: Text.NativeRendering
                }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => root.pressed(mouse.button)
        onWheel: wheel => root.scrolled(wheel.angleDelta.y > 0 ? 1 : -1)
    }
}
