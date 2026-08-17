import QtQuick
import Quickshell.Widgets

Item {
    id: tile

    required property var entry
    required property bool selected

    signal activated()
    signal hovered()

    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        radius: 12
        color: tile.selected ? Theme.ui : "transparent"
        border.width: 1
        border.color: tile.selected ? Theme.ui3 : "transparent"

        Behavior on color {
            ColorAnimation { duration: 90 }
        }

        Column {
            anchors.centerIn: parent
            width: parent.width - 16
            spacing: 8

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                implicitWidth: 46
                implicitHeight: 46

                IconImage {
                    id: icon

                    anchors.fill: parent
                    asynchronous: true
                    mipmap: true
                    source: Apps.iconSource(tile.entry)
                    visible: status === Image.Ready
                }

                // Some entries point at a missing theme icon or an AppImage that
                // Qt cannot decode; fall back to an initial instead of a blank.
                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: Theme.ui2
                    visible: !icon.visible

                    Text {
                        anchors.centerIn: parent
                        text: String(tile.entry.name || "?").charAt(0).toUpperCase()
                        color: Theme.tx2
                        font.family: Theme.fontFamily
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                    }
                }
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: tile.entry.name
                color: tile.selected ? Theme.tx : Theme.tx2
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: tile.selected ? Font.DemiBold : Font.Normal
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: tile.hovered()
        onClicked: tile.activated()
    }
}
