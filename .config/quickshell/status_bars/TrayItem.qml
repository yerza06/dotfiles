import QtQuick
import Quickshell

Rectangle {
    id: root

    required property var trayItem
    required property var parentWindow
    property color backgroundColor: "#100f0f"
    property color hoverColor: "#1c1b1a"
    property color bottomBorderColor: "#403e3c"
    property color menuTextColor: "#cecdc3"
    property color menuHoverColor: "#282726"
    property color menuDisabledColor: "#575653"
    property color menuBorderColor: "#575653"
    property color menuSeparatorColor: "#403e3c"

    property bool menuVisible: false

    readonly property bool hasMenu: trayItem !== null && trayItem.hasMenu
    readonly property bool menuChainHovered: mouseArea.containsMouse || menu.chainHovered

    implicitWidth: 26
    implicitHeight: 28
    color: mouseArea.containsMouse || menuVisible ? hoverColor : backgroundColor

    onMenuChainHoveredChanged: {
        if (menuChainHovered)
            menuCloseTimer.stop()
        else if (menuVisible)
            menuCloseTimer.restart()
    }

    function showMenu() {
        if (!hasMenu)
            return
        menuCloseTimer.stop()
        menuVisible = true
    }

    function toggleMenu() {
        if (menuVisible)
            menuVisible = false
        else
            showMenu()
    }

    // Меню закрывается, когда курсор ушёл и с иконки, и со всей цепочки подменю.
    Timer {
        id: menuCloseTimer
        interval: 400
        repeat: false
        onTriggered: {
            if (!root.menuChainHovered)
                root.menuVisible = false
        }
    }

    TrayMenu {
        id: menu

        menuHandle: root.trayItem ? root.trayItem.menu : null
        visible: root.menuVisible && root.hasMenu
        anchor.item: root
        anchor.edges: Edges.Bottom | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        backgroundColor: root.backgroundColor
        hoverColor: root.menuHoverColor
        textColor: root.menuTextColor
        disabledColor: root.menuDisabledColor
        borderColor: root.menuBorderColor
        separatorColor: root.menuSeparatorColor
        onCloseRequested: root.menuVisible = false
    }

    Image {
        anchors.centerIn: parent
        width: 17
        height: 17
        source: root.trayItem ? root.trayItem.icon : ""
        sourceSize.width: 34
        sourceSize.height: 34
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: root.bottomBorderColor
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: mouse => {
            if (!root.trayItem)
                return

            if (mouse.button === Qt.LeftButton) {
                if (root.trayItem.onlyMenu && root.hasMenu)
                    root.toggleMenu()
                else
                    root.trayItem.activate()
            } else if (mouse.button === Qt.RightButton) {
                root.toggleMenu()
            } else if (mouse.button === Qt.MiddleButton) {
                root.trayItem.secondaryActivate()
            }
        }

        onWheel: wheel => {
            if (!root.trayItem)
                return
            if (wheel.angleDelta.y !== 0)
                root.trayItem.scroll(wheel.angleDelta.y, false)
            else if (wheel.angleDelta.x !== 0)
                root.trayItem.scroll(wheel.angleDelta.x, true)
        }
    }

    Behavior on color {
        ColorAnimation { duration: 100 }
    }
}
