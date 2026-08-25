import QtQuick
import Quickshell
import Quickshell.Wayland
import "KeyNavigation.js" as KeyNavigation

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
    readonly property int subTabsHeight: 36
    readonly property int footerHeight: 36

    readonly property bool hasSubs: Glyphs.subcategories.length > 1

    // Первым чипом всегда «Все», дальше подразделы текущего раздела.
    readonly property var subModel: [{
        id: "",
        label: "Все",
        count: Glyphs.countOf(Glyphs.category)
    }].concat(Glyphs.subcategories)

    readonly property var current: (grid.currentIndex >= 0 && grid.currentIndex < Glyphs.results.length)
                                   ? Glyphs.results[grid.currentIndex]
                                   : null

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    color: "transparent"
    visible: false
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-emojimenu"
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
        // Набор статичен, перечитывать нечего. Открываемся на «Частых»: на
        // четырнадцати тысячах записей список «Всё» сам по себе бесполезен.
        Glyphs.category = Glyphs.countOf("freq") > 0 ? "freq" : "emoji"
        // Раздел мог и не смениться, а фильтр по подразделу с прошлого раза
        // сбросить всё равно нужно — иначе меню открывается «в середине».
        Glyphs.subcategory = ""
        search.text = String(initialQuery || "")
        Glyphs.query = search.text
        search.selectAll()
        grid.currentIndex = 0
        grid.positionViewAtBeginning()
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
        const count = Glyphs.results.length
        if (count === 0)
            return
        grid.currentIndex = Math.max(0, Math.min(count - 1, grid.currentIndex + delta))
        grid.positionViewAtIndex(grid.currentIndex, GridView.Contain)
    }

    function activate() {
        if (!win.current)
            return
        Glyphs.copy(win.current)
        close()
    }

    // Убирает символ из «Частых». Сам символ никуда не девается — он часть
    // набора, удалить его нельзя, можно только забыть счётчик.
    function forgetCurrent() {
        if (!win.current)
            return
        const index = grid.currentIndex
        Glyphs.forget(win.current)
        // Во вкладке «Частые» сетка схлопывается под курсором; остаёмся на месте.
        grid.currentIndex = Math.max(0, Math.min(Glyphs.results.length - 1, index))
    }

    function askClear() {
        if (Glyphs.countOf("freq") === 0)
            return
        confirmChoice = 0
        confirming = true
        disarmHover()
    }

    function confirmYes() {
        confirming = false
        confirmChoice = 0
        Glyphs.clearUsage()
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

        // Разрушающие действия проверяются до навигации, и Ctrl+Shift+Delete —
        // строго до голого Shift+Delete, иначе очистка забыла бы один символ.
        if (event.modifiers & Qt.ControlModifier) {
            if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) {
                askClear()
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_P) {
                Glyphs.togglePin(win.current)
                event.accepted = true
                return
            }
        }

        if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) {
            forgetCurrent()
            event.accepted = true
            return
        }

        const navigation = KeyNavigation.actionFor(event.key, event.modifiers, grid.columns)
        if (navigation !== null) {
            if (navigation.kind === "category")
                Glyphs.cycleCategory(navigation.delta)
            else if (navigation.kind === "subcategory")
                Glyphs.cycleSubcategory(navigation.delta)
            else
                move(navigation.delta)
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
        case Qt.Key_PageDown:
            move(grid.columns * 3)
            break
        case Qt.Key_PageUp:
            move(-grid.columns * 3)
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
        target: Glyphs

        function onResultsChanged() {
            grid.currentIndex = Glyphs.results.length > 0 ? 0 : -1
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
                        text: ""
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

                            onTextChanged: Glyphs.query = text
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
                            text: "Поиск по символам"
                            color: Theme.tx3
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            visible: search.text.length === 0
                        }
                    }

                    Text {
                        id: counter

                        anchors.verticalCenter: parent.verticalCenter
                        text: Glyphs.loading ? "…" : String(Glyphs.results.length)
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
                        model: Glyphs.categories

                        delegate: Rectangle {
                            id: chip

                            required property var modelData

                            readonly property bool active: Glyphs.category === chip.modelData.id

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
                                    text: Glyphs.countOf(chip.modelData.id)
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
                                    Glyphs.category = chip.modelData.id
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

            // Полоса подразделов. Показывается только там, где делить есть что:
            // у «Частых», «Закреплённых» и каомодзи подразделов нет.
            Item {
                width: parent.width
                height: win.subTabsHeight
                visible: win.hasSubs

                Flickable {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    clip: true
                    // Подразделов у «Символов» и «Иконок» больше, чем влезает в
                    // ширину карточки, поэтому полоса прокручивается.
                    contentWidth: subRow.width
                    contentHeight: height
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.HorizontalFlick

                    Row {
                        id: subRow

                        height: parent.height
                        spacing: 4

                        Repeater {
                            model: win.subModel

                            delegate: Rectangle {
                                id: subChip

                                required property var modelData

                                readonly property bool active: Glyphs.subcategory === subChip.modelData.id

                                anchors.verticalCenter: parent.verticalCenter
                                width: subChipRow.width + 15
                                height: 24
                                radius: 7
                                color: subChip.active ? Theme.ui2 : (subChipArea.containsMouse ? Theme.bg2 : "transparent")

                                Behavior on color {
                                    ColorAnimation { duration: 90 }
                                }

                                Row {
                                    id: subChipRow

                                    anchors.centerIn: parent
                                    spacing: 5

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: subChip.modelData.label
                                        color: subChip.active ? Theme.tx : Theme.tx2
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: subChip.active ? Font.DemiBold : Font.Normal
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: subChip.modelData.count
                                        color: Theme.tx3
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                    }
                                }

                                MouseArea {
                                    id: subChipArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Glyphs.subcategory = subChip.modelData.id
                                        search.forceActiveFocus()
                                    }
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
                visible: win.hasSubs
            }

            Item {
                id: body

                width: parent.width
                height: card.height - win.headerHeight - win.tabsHeight - win.footerHeight
                        - (win.hasSubs ? win.subTabsHeight + 1 : 0) - 3

                GridView {
                    id: grid

                    readonly property int columns: Math.max(1, Math.floor(width / 104))

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    width: parent.width - 28
                    // Только целые ряды, чтобы снизу не выглядывала половина плитки.
                    height: Math.max(cellHeight, Math.floor((parent.height - 20) / cellHeight) * cellHeight)
                    clip: true
                    visible: !win.confirming
                    cellWidth: Math.floor(width / columns)
                    cellHeight: 96
                    model: Glyphs.results
                    highlightMoveDuration: 0
                    snapMode: GridView.SnapToRow
                    boundsBehavior: Flickable.StopAtBounds
                    cacheBuffer: 96 * 4

                    delegate: EmojiTile {
                        required property var modelData
                        required property int index

                        width: grid.cellWidth
                        height: grid.cellHeight
                        entry: modelData
                        selected: grid.currentIndex === index

                        onMoved: (x, y) => win.noteMotion(x, y)
                        onHovered: {
                            if (win.hoverArmed)
                                grid.currentIndex = index
                        }
                        onActivated: {
                            grid.currentIndex = index
                            win.activate()
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: Glyphs.results.length === 0 && !win.confirming
                    text: {
                        if (Glyphs.loading)
                            return "Читаем набор…"
                        if (Glyphs.category === "freq" && Glyphs.query.length === 0)
                            return "Пока ничего не вставлено"
                        if (Glyphs.category === "pinned" && Glyphs.query.length === 0)
                            return "Ничего не закреплено"
                        return "Ничего не найдено"
                    }
                    color: Theme.tx3
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }

                Loader {
                    anchors.fill: parent
                    active: win.confirming

                    sourceComponent: ConfirmDialog {
                        question: "Очистить историю частых символов?"
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
                    id: hints

                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 22
                    spacing: 16
                    visible: !win.confirming

                    Text {
                        text: "↑↓  ряд"
                        color: Theme.tx3
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }

                    Text {
                        text: "Ctrl+←→  символ"
                        color: Theme.tx3
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }

                    Text {
                        text: "Tab  подраздел"
                        color: Theme.tx3
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        visible: win.hasSubs
                    }

                    Text {
                        text: "Ctrl+Tab  раздел"
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

                    // Забывание и очистка имеют смысл только там, где есть что
                    // забывать, поэтому в остальных разделах подсказку не показываем.
                    Text {
                        text: "Shift+Del  забыть"
                        color: Theme.tx3
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        visible: Glyphs.category === "freq"
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

                // Превью-панели больше нет, поэтому подробности о выбранном
                // символе живут здесь: имя, кодпоинт и счётчик вставок.
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 22
                    width: Math.max(0, parent.width - hints.width - 44)
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideLeft
                    text: {
                        if (win.confirming)
                            return ""
                        if (Glyphs.category === "freq" && !win.current)
                            return "Ctrl+Shift+Del  очистить частые"
                        if (!win.current)
                            return ""
                        const parts = [win.current.n]
                        if (win.current.u.length > 0)
                            parts.push(win.current.u)
                        const used = Glyphs.useCount(win.current)
                        if (used > 0)
                            parts.push(used + "×")
                        return parts.join("   ")
                    }
                    color: Theme.tx3
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
            }
        }
    }
}
