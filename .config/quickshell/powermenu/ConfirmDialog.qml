import QtQuick

// Replaces the tile row inside the same card, so the card never jumps size.
Item {
    id: dialog

    required property var entry
    // 0 — «Нет», 1 — «Да». Starts on «Нет» so a stray Enter is harmless.
    required property int choice

    readonly property color accent: Theme[dialog.entry.accent]

    signal picked(int index)
    signal moved(real x, real y)
    signal confirmed()
    signal cancelled()

    Column {
        anchors.centerIn: parent
        spacing: 18

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: dialog.entry.question
            color: Theme.tx
            font.family: Theme.fontFamily
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            Repeater {
                model: [
                    { index: 0, label: "Нет" },
                    { index: 1, label: "Да" }
                ]

                delegate: Rectangle {
                    required property var modelData

                    readonly property bool selected: dialog.choice === modelData.index

                    width: 132
                    height: 44
                    radius: 10
                    color: selected ? Theme.ui : Theme.bg2
                    border.width: 1
                    border.color: selected ? Theme.ui3 : Theme.ui

                    Behavior on color {
                        ColorAnimation { duration: 90 }
                    }

                    Behavior on border.color {
                        ColorAnimation { duration: 90 }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: {
                            if (!parent.selected)
                                return Theme.tx2
                            return modelData.index === 1 ? dialog.accent : Theme.tx
                        }
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: parent.selected ? Font.DemiBold : Font.Normal

                        Behavior on color {
                            ColorAnimation { duration: 90 }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: dialog.picked(modelData.index)
                        onPositionChanged: mouse => {
                            const point = mapToItem(null, mouse.x, mouse.y)
                            dialog.moved(point.x, point.y)
                            dialog.picked(modelData.index)
                        }
                        onClicked: {
                            dialog.picked(modelData.index)
                            if (modelData.index === 1)
                                dialog.confirmed()
                            else
                                dialog.cancelled()
                        }
                    }
                }
            }
        }
    }
}
