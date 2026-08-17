import QtQuick

Item {
    id: row

    required property var entry
    required property bool selected

    signal activated()
    signal hovered()
    signal moved(real x, real y)

    // Images need their thumbnail decoded before anything can be shown; the
    // request is queued and answered out of band.
    Component.onCompleted: Clips.requestThumb(row.entry)
    onEntryChanged: Clips.requestThumb(row.entry)

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.topMargin: 1
        anchors.bottomMargin: 1
        radius: 10
        color: row.selected ? Theme.ui : "transparent"
        border.width: 1
        border.color: row.selected ? Theme.ui3 : "transparent"

        Behavior on color {
            ColorAnimation { duration: 90 }
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 12
                text: row.entry.pinned ? "" : ""
                color: Theme.yellow
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                height: 30

                Image {
                    id: thumb

                    anchors.fill: parent
                    asynchronous: true
                    cache: true
                    fillMode: Image.PreserveAspectCrop
                    clip: true
                    smooth: true
                    sourceSize.width: 60
                    sourceSize.height: 60
                    source: Clips.thumbSource(row.entry)
                    visible: status === Image.Ready
                }

                // Placeholder while the image decodes, and the permanent icon
                // for text entries.
                Text {
                    anchors.centerIn: parent
                    visible: !thumb.visible
                    text: row.entry.kind === "image" ? "" : ""
                    color: row.selected ? Theme.tx2 : Theme.tx3
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 12 - 30 - parent.spacing * 2
                text: row.entry.preview
                color: row.selected ? Theme.tx : Theme.tx2
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: row.selected ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: row.hovered()
        onPositionChanged: mouse => {
            const point = mapToItem(null, mouse.x, mouse.y)
            row.moved(point.x, point.y)
            row.hovered()
        }
        onClicked: row.activated()
    }
}
