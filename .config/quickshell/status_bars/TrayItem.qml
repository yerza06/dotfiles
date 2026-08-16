import QtQuick

Rectangle {
    id: root

    required property var trayItem
    required property var parentWindow
    property color backgroundColor: "#100f0f"
    property color hoverColor: "#1c1b1a"
    property color bottomBorderColor: "#403e3c"

    implicitWidth: 26
    implicitHeight: 28
    color: mouseArea.containsMouse ? hoverColor : backgroundColor

    function showMenu() {
        if (!trayItem || !trayItem.hasMenu)
            return
        const position = root.mapToItem(null, 0, root.height)
        trayItem.display(parentWindow, Math.round(position.x), Math.round(position.y))
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
                if (root.trayItem.onlyMenu && root.trayItem.hasMenu)
                    root.showMenu()
                else
                    root.trayItem.activate()
            } else if (mouse.button === Qt.RightButton) {
                root.showMenu()
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
