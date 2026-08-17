import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: win

    property bool opened: false

    readonly property int cardWidth: Math.min(980, Math.round(win.width * 0.86))
    readonly property int cardHeight: Math.min(664, Math.round(win.height * 0.84))

    readonly property int headerHeight: 62
    readonly property int tabsHeight: 44
    readonly property int footerHeight: 36

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    color: "transparent"
    visible: false
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-launcher"
    // Grabbing the keyboard only while open keeps the compositor from routing
    // key events here when the launcher is idle.
    WlrLayershell.keyboardFocus: win.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function open(initialQuery, initialCategory) {
        if (opened)
            return
        hideTimer.stop()
        Apps.category = String(initialCategory || "all")
        search.text = String(initialQuery || "")
        Apps.query = search.text
        search.selectAll()
        grid.currentIndex = 0
        grid.positionViewAtBeginning()
        visible = true
        opened = true
        search.forceActiveFocus()
    }

    function close() {
        if (!opened)
            return
        opened = false
        hideTimer.restart()
    }

    function move(delta) {
        const count = Apps.results.length
        if (count === 0)
            return
        grid.currentIndex = Math.max(0, Math.min(count - 1, grid.currentIndex + delta))
    }

    function activate() {
        const results = Apps.results
        if (grid.currentIndex < 0 || grid.currentIndex >= results.length)
            return
        Apps.launch(results[grid.currentIndex])
        close()
    }

    function handleKey(event) {
        // Ctrl+←/→ and the Vim-style Ctrl+h/l walk the category tabs; the bare
        // arrows stay with the grid. Ctrl+h loses its readline "backspace"
        // meaning inside the search field, which is the intended trade.
        if (event.modifiers & Qt.ControlModifier) {
            if (event.key === Qt.Key_Right || event.key === Qt.Key_L || event.key === Qt.Key_Tab) {
                Apps.cycleCategory(1)
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Left || event.key === Qt.Key_H || event.key === Qt.Key_Backtab) {
                Apps.cycleCategory(-1)
                event.accepted = true
                return
            }
        }

        switch (event.key) {
        case Qt.Key_Escape:
            close()
            break
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_KP_Enter:
            activate()
            break
        case Qt.Key_Down:
            move(grid.columns)
            break
        case Qt.Key_Up:
            move(-grid.columns)
            break
        case Qt.Key_PageDown:
            move(grid.columns * 2)
            break
        case Qt.Key_PageUp:
            move(-grid.columns * 2)
            break
        case Qt.Key_Tab:
            move(1)
            break
        case Qt.Key_Backtab:
            move(-1)
            break
        case Qt.Key_Right:
            // Only steal the arrow once the text cursor has nowhere left to go,
            // so editing the query still works.
            if (search.cursorPosition < search.text.length)
                return
            move(1)
            break
        case Qt.Key_Left:
            if (search.cursorPosition > 0)
                return
            move(-1)
            break
        default:
            return
        }

        event.accepted = true
    }

    Timer {
        id: hideTimer
        interval: 200
        onTriggered: win.visible = false
    }

    Connections {
        target: Apps

        function onResultsChanged() {
            grid.currentIndex = Apps.results.length > 0 ? 0 : -1
            grid.positionViewAtBeginning()
        }
    }

    Rectangle {
        id: backdrop

        anchors.fill: parent
        color: Theme.scrim
        opacity: win.opened ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: win.close()
        }
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: win.cardWidth
        height: win.cardHeight
        radius: 16
        color: Theme.bg
        border.width: 1
        border.color: Theme.ui2
        clip: true

        opacity: win.opened ? 1 : 0
        scale: win.opened ? 1 : 0.97

        Behavior on opacity {
            NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
        }

        Behavior on scale {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        // Swallow clicks so they do not reach the backdrop.
        MouseArea {
            anchors.fill: parent
        }

        Column {
            anchors.fill: parent

            Item {
                width: parent.width
                height: win.headerHeight

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 22
                    anchors.rightMargin: 22
                    spacing: 12

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ""
                        color: Theme.tx3
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                    }

                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 34 - counter.width - parent.spacing * 2
                        height: 26

                        TextInput {
                            id: search

                            anchors.fill: parent
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.tx
                            selectionColor: Theme.blue
                            selectedTextColor: Theme.bg
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            font.weight: Font.Medium
                            clip: true

                            onTextChanged: Apps.query = text
                            Keys.onPressed: event => win.handleKey(event)

                            cursorDelegate: Rectangle {
                                width: 2
                                color: Theme.orange

                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite
                                    running: search.activeFocus

                                    NumberAnimation { to: 0; duration: 500; easing.type: Easing.InOutQuad }
                                    NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutQuad }
                                }
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Поиск приложений"
                            color: Theme.tx3
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            visible: search.text.length === 0
                        }
                    }

                    Text {
                        id: counter

                        anchors.verticalCenter: parent.verticalCenter
                        text: Apps.results.length
                        color: Theme.tx3
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.ui
            }

            Item {
                width: parent.width
                height: win.tabsHeight

                ListView {
                    id: tabs

                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    orientation: ListView.Horizontal
                    clip: true
                    spacing: 4
                    model: Apps.visibleCategories
                    boundsBehavior: Flickable.StopAtBounds
                    currentIndex: Apps.categoryIndex()
                    // Keeps the active tab on screen when Ctrl+←/→ runs off the edge.
                    highlightRangeMode: ListView.ApplyRange
                    preferredHighlightBegin: 0
                    preferredHighlightEnd: width

                    delegate: Item {
                        id: tab

                        required property var modelData

                        readonly property bool active: Apps.category === tab.modelData.id

                        width: chip.width
                        height: tabs.height

                        Rectangle {
                            id: chip

                            anchors.verticalCenter: parent.verticalCenter
                            width: chipRow.width + 17
                            height: 28
                            radius: 8
                            color: tab.active ? Theme.ui : (chipArea.containsMouse ? Theme.bg2 : "transparent")
                            border.width: 1
                            border.color: tab.active ? Theme.ui3 : "transparent"

                            Behavior on color {
                                ColorAnimation { duration: 90 }
                            }

                            Row {
                                id: chipRow

                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: tab.modelData.icon
                                    color: tab.active ? Theme.orange : Theme.tx3
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: tab.modelData.label
                                    color: tab.active ? Theme.tx : Theme.tx2
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: tab.active ? Font.DemiBold : Font.Normal
                                }
                            }

                            MouseArea {
                                id: chipArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Apps.category = tab.modelData.id
                                    search.forceActiveFocus()
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.ui
            }

            Item {
                width: parent.width
                height: card.height - win.headerHeight - win.tabsHeight - win.footerHeight - 3

                GridView {
                    id: grid

                    readonly property int columns: Math.max(1, Math.floor(width / 172))

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 12
                    width: parent.width - 28
                    // Whole rows only, so a half-cut tile never peeks out the bottom.
                    height: Math.max(cellHeight, Math.floor((parent.height - 24) / cellHeight) * cellHeight)
                    clip: true
                    cellWidth: Math.floor(width / columns)
                    cellHeight: 118
                    model: Apps.results
                    highlightMoveDuration: 0
                    snapMode: GridView.SnapToRow
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: AppTile {
                        required property var modelData
                        required property int index

                        width: grid.cellWidth
                        height: grid.cellHeight
                        entry: modelData
                        selected: grid.currentIndex === index

                        onHovered: grid.currentIndex = index
                        onActivated: {
                            grid.currentIndex = index
                            win.activate()
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: Apps.results.length === 0
                    text: "Ничего не найдено"
                    color: Theme.tx3
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                }
            }

            Item {
                width: parent.width
                height: win.footerHeight

                Rectangle {
                    anchors.top: parent.top
                    width: parent.width
                    height: 1
                    color: Theme.ui
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 22
                    spacing: 16

                    Text {
                        text: "↑↓←→  выбор"
                        color: Theme.tx3
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }

                    Text {
                        text: "Ctrl+h l  категория"
                        color: Theme.tx3
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }

                    Text {
                        text: "Enter  запуск"
                        color: Theme.tx3
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }

                    Text {
                        text: "Esc  закрыть"
                        color: Theme.tx3
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 22
                    text: {
                        const results = Apps.results
                        if (grid.currentIndex < 0 || grid.currentIndex >= results.length)
                            return ""
                        return results[grid.currentIndex].comment || results[grid.currentIndex].genericName || ""
                    }
                    color: Theme.tx3
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, card.width - 480)
                }
            }
        }
    }
}
