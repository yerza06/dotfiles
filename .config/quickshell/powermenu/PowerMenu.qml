import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: win

    property bool opened: false
    property int currentIndex: 0
    // Non-null while a destructive action waits for confirmation.
    property var pending: null
    property int confirmChoice: 0
    // Hover only takes over the selection once the pointer has actually moved.
    // Without this the menu, popping up under an idle cursor, would preselect
    // whatever tile happens to sit there — and «Да» in the confirm dialog.
    // Showing the surface delivers one motion event on its own, so arming has
    // to compare against the first reported position rather than just count it.
    property bool hoverArmed: false
    property real hoverX: NaN
    property real hoverY: NaN

    function disarmHover() {
        hoverArmed = false
        hoverX = NaN
        hoverY = NaN
    }

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

    readonly property int cardWidth: Math.min(718, Math.round(win.width * 0.92))
    readonly property int tileSize: Math.max(72, Math.floor((cardWidth - 44 - 50) / 6))
    readonly property int contentHeight: tileSize + 24
    readonly property int cardHeight: 46 + 1 + contentHeight + 1 + 34

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    color: "transparent"
    visible: false
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-powermenu"
    // Grabbing the keyboard only while open keeps the compositor from routing
    // key events here when the menu is idle.
    WlrLayershell.keyboardFocus: win.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function open() {
        if (opened)
            return
        hideTimer.stop()
        Actions.refresh()
        currentIndex = 0
        pending = null
        confirmChoice = 0
        disarmHover()
        visible = true
        opened = true
        content.forceActiveFocus()
    }

    function close() {
        if (!opened)
            return
        opened = false
        pending = null
        hideTimer.restart()
    }

    function move(delta) {
        const count = Actions.items.length
        currentIndex = Math.max(0, Math.min(count - 1, currentIndex + delta))
    }

    function activate() {
        const entry = Actions.items[currentIndex]
        if (!entry)
            return

        if (entry.confirm) {
            pending = entry
            confirmChoice = 0
            // The dialog appears where the pointer already is; disarm so it
            // cannot jump straight onto «Да».
            disarmHover()
            return
        }

        close()
        Actions.run(entry)
    }

    function confirmYes() {
        const entry = pending
        close()
        Actions.run(entry)
    }

    function confirmNo() {
        pending = null
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
        if (pending) {
            handleConfirmKey(event)
            return
        }

        // 1…6 jump straight to a tile.
        if (event.key >= Qt.Key_1 && event.key < Qt.Key_1 + Actions.items.length) {
            currentIndex = event.key - Qt.Key_1
            activate()
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
        case Qt.Key_Right:
        case Qt.Key_Tab:
            move(1)
            break
        case Qt.Key_Left:
        case Qt.Key_Backtab:
            move(-1)
            break
        case Qt.Key_Home:
            currentIndex = 0
            break
        case Qt.Key_End:
            currentIndex = Actions.items.length - 1
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

    FocusScope {
        id: content

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => win.handleKey(event)

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
                    height: 46

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 22
                        text: "󰥔  uptime: " + Actions.uptime
                        color: Theme.tx3
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.ui
                }

                Item {
                    width: parent.width
                    height: win.contentHeight

                    Row {
                        anchors.centerIn: parent
                        spacing: 10
                        visible: !win.pending

                        Repeater {
                            model: Actions.items

                            delegate: PowerTile {
                                required property var modelData
                                required property int index

                                width: win.tileSize
                                height: win.tileSize
                                entry: modelData
                                selected: win.currentIndex === index

                                onMoved: (x, y) => win.noteMotion(x, y)
                                onHovered: {
                                    if (win.hoverArmed)
                                        win.currentIndex = index
                                }
                                onActivated: {
                                    win.currentIndex = index
                                    win.activate()
                                }
                            }
                        }
                    }

                    Loader {
                        anchors.fill: parent
                        active: win.pending !== null

                        sourceComponent: ConfirmDialog {
                            entry: win.pending
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

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.ui
                }

                Item {
                    width: parent.width
                    height: 34

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 22
                        spacing: 16

                        Text {
                            text: "←  →  выбор"
                            color: Theme.tx3
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }

                        Text {
                            text: win.pending ? "Enter  подтвердить" : "Enter  действие"
                            color: Theme.tx3
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }

                        Text {
                            text: win.pending ? "Esc  отмена" : "Esc  закрыть"
                            color: Theme.tx3
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: 22
                        text: win.pending ? "" : "1…6  быстрый выбор"
                        color: Theme.tx3
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }
            }
        }
    }
}
