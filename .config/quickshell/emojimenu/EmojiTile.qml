import QtQuick

Item {
    id: tile

    required property var entry
    required property bool selected

    // Каомодзи — строка в десяток знаков; в поле под один глиф она не влезает,
    // поэтому рисуется мелко и с переносом.
    readonly property bool wide: tile.entry.g === "kaomoji"

    signal activated()
    signal hovered()
    signal moved(real x, real y)

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
            width: parent.width - 10
            spacing: 6

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: 38

                Text {
                    anchors.centerIn: parent
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: tile.entry.c
                    color: tile.selected ? Theme.tx : Theme.tx2
                    font.family: Glyphs.fontFor(tile.entry.g)
                    font.pixelSize: tile.wide ? 11 : 28
                    wrapMode: tile.wide ? Text.WrapAnywhere : Text.NoWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: tile.entry.n
                color: tile.selected ? Theme.tx2 : Theme.tx3
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.weight: tile.selected ? Font.DemiBold : Font.Normal
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }

        // Закреплённое помечается уголком, а не строкой: в плитке нет места под
        // подпись, а отличать закреплённое от обычного всё равно нужно.
        Text {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 5
            anchors.rightMargin: 7
            visible: Glyphs.isPinned(tile.entry)
            text: ""
            color: Theme.yellow
            font.family: Theme.fontFamily
            font.pixelSize: 9
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: tile.hovered()
        onPositionChanged: mouse => {
            const point = mapToItem(null, mouse.x, mouse.y)
            tile.moved(point.x, point.y)
            tile.hovered()
        }
        onClicked: tile.activated()
    }
}
