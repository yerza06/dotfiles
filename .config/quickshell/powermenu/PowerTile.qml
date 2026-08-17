import QtQuick

Item {
    id: tile

    required property var entry
    required property bool selected

    readonly property color accent: Theme[tile.entry.accent]

    signal activated()
    signal hovered()
    // Scene coordinates of every pointer motion. The window uses them to tell a
    // real mouse move from the stray motion event a freshly shown surface gets,
    // so a menu popping up under an idle cursor keeps its keyboard selection.
    signal moved(real x, real y)

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: tile.selected ? Theme.ui : Theme.bg2
        border.width: 1
        border.color: tile.selected ? Theme.ui3 : Theme.ui

        Behavior on color {
            ColorAnimation { duration: 90 }
        }

        Behavior on border.color {
            ColorAnimation { duration: 90 }
        }

        Column {
            anchors.centerIn: parent
            width: parent.width - 12
            spacing: 8

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.entry.icon
                color: tile.selected ? tile.accent : Theme.tx2
                font.family: Theme.fontFamily
                font.pixelSize: 30

                Behavior on color {
                    ColorAnimation { duration: 90 }
                }
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: tile.entry.label
                color: tile.selected ? Theme.tx : Theme.tx2
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: tile.selected ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: tile.hovered()
        onPositionChanged: mouse => {
            const point = tile.mapToItem(null, mouse.x, mouse.y)
            tile.moved(point.x, point.y)
            tile.hovered()
        }
        onClicked: tile.activated()
    }
}
