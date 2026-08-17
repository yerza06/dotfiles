import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: win

    property bool opened: false
    // True while «очистить историю?» waits for an answer.
    property bool confirming: false
    property int confirmChoice: 0

    // Hover only takes over the selection once the pointer has actually moved.
    // The menu pops up under an idle cursor, and without this the row that
    // happens to sit there would steal the selection straight away.
    property bool hoverArmed: false
    property real hoverX: NaN
    property real hoverY: NaN

    readonly property int cardWidth: Math.min(1060, Math.round(win.width * 0.86))
    readonly property int cardHeight: Math.min(680, Math.round(win.height * 0.84))

    readonly property int headerHeight: 62
    readonly property int tabsHeight: 44
    readonly property int footerHeight: 36
    readonly property int rowHeight: 40

    readonly property var current: (list.currentIndex >= 0 && list.currentIndex < Clips.results.length)
                                   ? Clips.results[list.currentIndex]
                                   : null

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    color: "transparent"
    visible: false
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-buffermenu"
    // Grabbing the keyboard only while open keeps the compositor from routing
    // key events here when the menu is idle.
    WlrLayershell.keyboardFocus: win.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function disarmHover() {
        hoverArmed = false
        hoverX = NaN
        hoverY = NaN
    }

    // Showing the surface delivers one motion event on its own, so arming has
    // to compare against the first reported position rather than just count it.
    function noteMotion(x, y) {
        if (hoverArmed)
            return
        if (isNaN(hoverX)) {
            hoverX = x
            hoverY = y
            return
        }
        if (Math.abs(x - hoverX) + Math.abs(y - hoverY) > 4)
            hoverArmed = true
    }

    function open(initialQuery) {
        if (opened)
            return
        hideTimer.stop()
        Clips.reload()
        Clips.category = "all"
        search.text = String(initialQuery || "")
        Clips.query = search.text
        search.selectAll()
        list.currentIndex = 0
        list.positionViewAtBeginning()
        confirming = false
        confirmChoice = 0
        disarmHover()
        visible = true
        opened = true
        search.forceActiveFocus()
    }

    function close() {
        if (!opened)
            return
        opened = false
        confirming = false
        hideTimer.restart()
    }

    function move(delta) {
        const count = Clips.results.length
        if (count === 0)
            return
        list.currentIndex = Math.max(0, Math.min(count - 1, list.currentIndex + delta))
        list.positionViewAtIndex(list.currentIndex, ListView.Contain)
    }

    function activate() {
        if (!win.current)
            return
        Clips.copy(win.current)
        close()
    }

    function removeCurrent() {
        if (!win.current)
            return
        const index = list.currentIndex
        Clips.remove(win.current)
        // The list shrinks under the cursor; stay on the same slot.
        list.currentIndex = Math.max(0, Math.min(Clips.results.length - 1, index))
    }

    function askWipe() {
        if (Clips.entries.length === 0)
            return
        confirmChoice = 0
        confirming = true
        disarmHover()
    }

    function confirmYes() {
        confirming = false
        confirmChoice = 0
        Clips.wipe()
    }

    function confirmNo() {
        confirming = false
        confirmChoice = 0
        disarmHover()
    }

    function handleConfirmKey(event) {
        switch (event.key) {
        case Qt.Key_Escape:
            confirmNo()
            break
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_KP_Enter:
            if (confirmChoice === 1)
                confirmYes()
            else
                confirmNo()
            break
        case Qt.Key_Left:
        case Qt.Key_Right:
        case Qt.Key_Tab:
        case Qt.Key_Backtab:
            confirmChoice = confirmChoice === 1 ? 0 : 1
            break
        default:
            return
        }

        event.accepted = true
    }

    function handleKey(event) {
        if (confirming) {
            handleConfirmKey(event)
            return
        }

        if (event.modifiers & Qt.ControlModifier) {
            // Ctrl+Shift+Delete has to be caught before the plain Shift+Delete
            // below, or wiping would delete a single row instead.
            if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) {
                askWipe()
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_P) {
                Clips.togglePin(win.current)
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
                Clips.cycleCategory(1)
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) {
                Clips.cycleCategory(-1)
                event.accepted = true
                return
            }
        }

        if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) {
            removeCurrent()
            event.accepted = true
            return
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
            move(1)
            break
        case Qt.Key_Up:
            move(-1)
            break
        case Qt.Key_PageDown:
            move(8)
            break
        case Qt.Key_PageUp:
            move(-8)
            break
        case Qt.Key_Tab:
            Clips.cycleCategory(1)
            break
        case Qt.Key_Backtab:
            Clips.cycleCategory(-1)
            break
        default:
            // ← and → are left alone so the query stays editable.
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
        target: Clips

        function onResultsChanged() {
            list.currentIndex = Clips.results.length > 0 ? 0 : -1
            list.positionViewAtBeginning()
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
                        text: ""
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

                            onTextChanged: Clips.query = text
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
                            text: "Поиск по буферу"
                            color: Theme.tx3
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            visible: search.text.length === 0
                        }
                    }

                    Text {
                        id: counter

                        anchors.verticalCenter: parent.verticalCenter
                        text: Clips.loading ? "…" : String(Clips.results.length)
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

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Repeater {
                        model: Clips.categories

                        delegate: Rectangle {
                            id: chip

                            required property var modelData

                            readonly property bool active: Clips.category === chip.modelData.id

                            width: chipRow.width + 17
                            height: 28
                            radius: 8
                            color: chip.active ? Theme.ui : (chipArea.containsMouse ? Theme.bg2 : "transparent")
                            border.width: 1
                            border.color: chip.active ? Theme.ui3 : "transparent"

                            Behavior on color {
                                ColorAnimation { duration: 90 }
                            }

                            Row {
                                id: chipRow

                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: chip.modelData.icon
                                    color: chip.active ? Theme.orange : Theme.tx3
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: chip.modelData.label
                                    color: chip.active ? Theme.tx : Theme.tx2
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: chip.active ? Font.DemiBold : Font.Normal
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Clips.countOf(chip.modelData.id)
                                    color: Theme.tx3
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                }
                            }

                            MouseArea {
                                id: chipArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Clips.category = chip.modelData.id
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
                id: body

                width: parent.width
                height: card.height - win.headerHeight - win.tabsHeight - win.footerHeight - 3

                Row {
                    anchors.fill: parent
                    visible: !win.confirming

                    Item {
                        width: Math.round(body.width * 0.46)
                        height: parent.height

                        ListView {
                            id: list

                            anchors.fill: parent
                            anchors.topMargin: 8
                            anchors.bottomMargin: 8
                            clip: true
                            model: Clips.results
                            highlightMoveDuration: 0
                            boundsBehavior: Flickable.StopAtBounds
                            cacheBuffer: win.rowHeight * 8

                            delegate: ClipRow {
                                required property var modelData
                                required property int index

                                width: list.width
                                height: win.rowHeight
                                entry: modelData
                                selected: list.currentIndex === index

                                onMoved: (x, y) => win.noteMotion(x, y)
                                onHovered: {
                                    if (win.hoverArmed)
                                        list.currentIndex = index
                                }
                                onActivated: {
                                    list.currentIndex = index
                                    win.activate()
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: Clips.results.length === 0
                            text: Clips.loading ? "Читаем историю…" : "Ничего не найдено"
                            color: Theme.tx3
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                        }
                    }

                    Rectangle {
                        width: 1
                        height: parent.height
                        color: Theme.ui
                    }

                    ClipPreview {
                        width: body.width - Math.round(body.width * 0.46) - 1
                        height: parent.height
                        entry: win.current
                    }
                }

                Loader {
                    anchors.fill: parent
                    active: win.confirming

                    sourceComponent: ConfirmDialog {
                        question: "Очистить всю историю буфера обмена?"
                        choice: win.confirmChoice

                        onMoved: (x, y) => win.noteMotion(x, y)
                        onPicked: index => {
                            if (win.hoverArmed)
                                win.confirmChoice = index
                        }
                        onConfirmed: win.confirmYes()
                        onCancelled: win.confirmNo()
                    }
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
                    visible: !win.confirming

                    Text {
                        text: "↑↓  выбор"
                        color: Theme.tx3
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }

                    Text {
                        text: "Tab  раздел"
                        color: Theme.tx3
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }

                    Text {
                        text: "Enter  копировать"
                        color: Theme.tx3
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }

                    Text {
                        text: "Ctrl+P  закрепить"
                        color: Theme.tx3
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }

                    Text {
                        text: "Shift+Del  удалить"
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

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 22
                    spacing: 16
                    visible: win.confirming

                    Text {
                        text: "←→  выбор"
                        color: Theme.tx3
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }

                    Text {
                        text: "Enter  подтвердить"
                        color: Theme.tx3
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }

                    Text {
                        text: "Esc  отмена"
                        color: Theme.tx3
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 22
                    text: win.confirming ? "" : "Ctrl+Shift+Del  очистить всё"
                    color: Theme.tx3
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
            }
        }
    }
}
