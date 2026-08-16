import QtQuick
import QtQuick.Layouts
import Quickshell

// Отрисовывает DBusMenu приложения из трея своими средствами, в палитре бара.
// Подменю открывается рекурсивно: тот же компонент, привязанный к строке-родителю.
PopupWindow {
    id: menuRoot

    required property var menuHandle
    property color backgroundColor: "#100f0f"
    property color hoverColor: "#282726"
    property color textColor: "#cecdc3"
    property color disabledColor: "#575653"
    property color borderColor: "#575653"
    property color separatorColor: "#403e3c"
    property string fontFamily: "IosevkaTerm Nerd Font Propo"

    // Строка, чьё подменю сейчас раскрыто.
    property var submenuEntry: null
    property var submenuAnchor: null
    property var pendingSubmenuEntry: null
    property var pendingSubmenuAnchor: null

    // Подменю создаётся во время выполнения: QML запрещает статическую рекурсию типа.
    property var submenuComponent: null
    property var submenuWindow: null

    // Курсор внутри этого меню или любого из открытых подменю.
    readonly property bool chainHovered: frameHover.hovered
        || (submenuWindow !== null && submenuWindow.visible && submenuWindow.chainHovered)

    signal closeRequested()

    color: "transparent"
    implicitWidth: frame.implicitWidth
    implicitHeight: frame.implicitHeight

    onVisibleChanged: {
        if (!visible)
            closeSubmenu()
    }

    function requestSubmenu(entry, anchorItem) {
        pendingSubmenuEntry = entry
        pendingSubmenuAnchor = anchorItem
        submenuTimer.restart()
    }

    function closeSubmenu() {
        submenuTimer.stop()
        pendingSubmenuEntry = null
        pendingSubmenuAnchor = null
        submenuEntry = null
        submenuAnchor = null
        destroySubmenu()
    }

    function destroySubmenu() {
        if (submenuWindow === null)
            return
        const window = submenuWindow
        submenuWindow = null
        window.visible = false
        window.destroy()
    }

    function applySubmenu() {
        destroySubmenu()
        if (submenuEntry === null || submenuAnchor === null)
            return

        if (submenuComponent === null)
            submenuComponent = Qt.createComponent(Qt.resolvedUrl("TrayMenu.qml"))
        if (submenuComponent.status !== Component.Ready) {
            console.warn("TrayMenu: не удалось загрузить подменю:", submenuComponent.errorString())
            return
        }

        const window = submenuComponent.createObject(menuRoot, {
            menuHandle: submenuEntry,
            backgroundColor: backgroundColor,
            hoverColor: hoverColor,
            textColor: textColor,
            disabledColor: disabledColor,
            borderColor: borderColor,
            separatorColor: separatorColor,
            fontFamily: fontFamily
        })
        if (window === null) {
            console.warn("TrayMenu: не удалось создать подменю")
            return
        }

        window.anchor.item = submenuAnchor
        window.anchor.edges = Edges.Right | Edges.Top
        window.anchor.gravity = Edges.Right | Edges.Bottom
        window.closeRequested.connect(menuRoot.closeRequested)
        window.visible = true
        submenuWindow = window
    }

    QsMenuOpener {
        id: opener
        menu: menuRoot.menuHandle
    }

    // Небольшая задержка, чтобы подменю не мигало при проходе курсора по списку.
    Timer {
        id: submenuTimer
        interval: 130
        repeat: false
        onTriggered: {
            menuRoot.submenuEntry = menuRoot.pendingSubmenuEntry
            menuRoot.submenuAnchor = menuRoot.pendingSubmenuAnchor
            menuRoot.applySubmenu()
        }
    }

    Rectangle {
        id: frame

        anchors.fill: parent
        implicitWidth: Math.min(420, Math.max(150, column.implicitWidth + 12))
        implicitHeight: column.implicitHeight + 12
        color: menuRoot.backgroundColor
        border.width: 1
        border.color: menuRoot.borderColor
        radius: 5

        HoverHandler {
            id: frameHover
        }

        // Отступ слева нужен, только если у пунктов есть иконки или отметки.
        readonly property bool gutterNeeded: {
            const entries = opener.children ? opener.children.values : []
            for (let i = 0; i < entries.length; i++) {
                const entry = entries[i]
                if (entry.isSeparator)
                    continue
                if (entry.buttonType !== QsMenuButtonType.None)
                    return true
                if (entry.icon && String(entry.icon).length > 0)
                    return true
            }
            return false
        }

        readonly property bool arrowNeeded: {
            const entries = opener.children ? opener.children.values : []
            for (let i = 0; i < entries.length; i++) {
                if (!entries[i].isSeparator && entries[i].hasChildren)
                    return true
            }
            return false
        }

        readonly property int leftGutter: gutterNeeded ? 24 : 9
        readonly property int rightGutter: arrowNeeded ? 22 : 10

        ColumnLayout {
            id: column
            anchors.fill: parent
            anchors.margins: 6
            spacing: 0

            Repeater {
                model: opener.children

                delegate: Item {
                    id: row

                    required property var modelData
                    readonly property var entry: modelData
                    readonly property bool separator: entry.isSeparator
                    readonly property bool submenu: !separator && entry.hasChildren
                    readonly property bool active: !separator && entry.enabled

                    Layout.fillWidth: true
                    Layout.preferredHeight: separator ? 7 : 26
                    implicitWidth: separator
                        ? 0
                        : frame.leftGutter + label.implicitWidth + frame.rightGutter

                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: 3
                        anchors.bottomMargin: 3
                        visible: row.separator
                        color: "transparent"

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 4
                            anchors.rightMargin: 4
                            height: 1
                            color: menuRoot.separatorColor
                        }
                    }

                    Rectangle {
                        id: highlight
                        anchors.fill: parent
                        radius: 3
                        visible: !row.separator
                        color: rowHover.hovered && row.active ? menuRoot.hoverColor : "transparent"

                        Behavior on color {
                            ColorAnimation { duration: 90 }
                        }
                    }

                    // Отметка чекбокса или радиокнопки.
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !row.separator && row.entry.buttonType !== QsMenuButtonType.None
                        text: {
                            if (row.entry.buttonType === QsMenuButtonType.CheckBox)
                                return row.entry.checkState === Qt.Unchecked ? "" : "✓"
                            return row.entry.checkState === Qt.Checked ? "●" : "○"
                        }
                        color: row.active ? menuRoot.textColor : menuRoot.disabledColor
                        font.family: menuRoot.fontFamily
                        font.pixelSize: 12
                        renderType: Text.NativeRendering
                    }

                    Image {
                        anchors.left: parent.left
                        anchors.leftMargin: 7
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14
                        height: 14
                        visible: !row.separator
                            && row.entry.buttonType === QsMenuButtonType.None
                            && String(row.entry.icon).length > 0
                        source: row.separator ? "" : row.entry.icon
                        sourceSize.width: 28
                        sourceSize.height: 28
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        asynchronous: true
                        opacity: row.active ? 1.0 : 0.45
                    }

                    Text {
                        id: label
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: frame.leftGutter
                        anchors.rightMargin: frame.rightGutter
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !row.separator
                        text: row.separator ? "" : String(row.entry.text).replace(/_([^_])/g, "$1")
                        color: row.active ? menuRoot.textColor : menuRoot.disabledColor
                        font.family: menuRoot.fontFamily
                        font.pixelSize: 13
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        visible: row.submenu
                        text: "▸"
                        color: row.active ? menuRoot.textColor : menuRoot.disabledColor
                        font.family: menuRoot.fontFamily
                        font.pixelSize: 12
                        renderType: Text.NativeRendering
                    }

                    HoverHandler {
                        id: rowHover
                        enabled: !row.separator
                        onHoveredChanged: {
                            if (!hovered)
                                return
                            if (row.submenu && row.active)
                                menuRoot.requestSubmenu(row.entry, row)
                            else
                                menuRoot.requestSubmenu(null, null)
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: row.active && !row.submenu
                        acceptedButtons: Qt.LeftButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            row.entry.triggered()
                            menuRoot.closeRequested()
                        }
                    }
                }
            }
        }
    }
}
