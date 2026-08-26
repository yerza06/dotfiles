import QtQuick
import Quickshell

PopupWindow {
    id: tooltip

    property string title: ""
    property string detail: ""

    color: "transparent"
    grabFocus: false
    implicitWidth: Math.max(120, Math.min(320, content.implicitWidth + 20))
    implicitHeight: content.implicitHeight + 14

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: Theme.bg
        border.width: 1
        border.color: Theme.ui3

        Column {
            id: content
            anchors.centerIn: parent
            spacing: 2

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tooltip.title
                color: Theme.tx
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: text.length > 0
                text: tooltip.detail
                color: Theme.tx2
                font.family: Theme.fontFamily
                font.pixelSize: 11
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
            }
        }
    }
}
