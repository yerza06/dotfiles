import QtQuick
import Quickshell
import Quickshell.Widgets

Item {
    id: root

    required property var item
    required property int dockIndex
    required property int pinnedIndex

    property bool tooltipReady: false
    property real dragOffset: 0
    readonly property int iconSize: 48
    readonly property bool dragging: dragHandler.active
    readonly property bool menuVisible: contextMenu.visible

    signal hoverRequested(int index)
    signal hoverReleased(int index)
    signal interactionLockChanged(bool locked)
    signal dragStateChanged(bool active)
    signal reorderRequested(int fromIndex, real centerX)

    implicitWidth: iconSize
    implicitHeight: 64
    z: dragging ? 10 : 0

    transform: Translate {
        x: root.dragOffset
    }

    Item {
        id: iconFrame
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        width: root.iconSize
        height: root.iconSize
        scale: root.dragging ? 1.08 : 1

        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            radius: Math.round(width * 0.25)
            color: root.item.active || mouseArea.containsMouse ? Theme.ui2 : "transparent"
            border.width: root.item.active ? 1 : 0
            border.color: Theme.ui3

            Behavior on color { ColorAnimation { duration: 100 } }
        }

        IconImage {
            id: icon
            anchors.centerIn: parent
            width: Math.max(32, parent.width - 10)
            height: width
            asynchronous: true
            mipmap: true
            source: DockModel.iconSource(root.item)
            visible: status === Image.Ready
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.max(32, parent.width - 10)
            height: width
            radius: Math.round(width * 0.24)
            color: Theme.ui
            visible: !icon.visible

            Text {
                anchors.centerIn: parent
                text: String(root.item.name || "?").charAt(0).toUpperCase()
                color: Theme.tx
                font.family: Theme.fontFamily
                font.pixelSize: 18
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.bottom
            anchors.topMargin: 4
            width: root.item.windows.length > 0 ? 6 : 0
            height: width
            radius: width / 2
            color: Theme.blue

            Behavior on width { NumberAnimation { duration: 120 } }
        }

        Rectangle {
            visible: root.item.windows.length > 1
            anchors.right: parent.right
            anchors.rightMargin: -4
            anchors.top: parent.top
            anchors.topMargin: -4
            width: 19
            height: 19
            radius: 10
            color: Theme.ui3
            border.width: 1
            border.color: Theme.bg

            Text {
                anchors.centerIn: parent
                text: root.item.windows.length > 9 ? "9+" : String(root.item.windows.length)
                color: Theme.tx
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
            }
        }
    }

    Timer {
        id: tooltipTimer
        interval: 450
        repeat: false
        onTriggered: root.tooltipReady = true
    }

    DockTooltip {
        id: tooltip
        visible: root.tooltipReady && mouseArea.containsMouse && !root.menuVisible && !root.dragging
        anchor.item: root
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        anchor.margins.top: 10
        title: root.item.name
        detail: root.item.windows.length === 0
            ? "Не запущено"
            : root.item.windows.length + " " + (root.item.windows.length === 1 ? "окно" : "окон")
    }

    DockMenu {
        id: contextMenu
        visible: false
        anchor.item: root
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        anchor.margins.top: 10
        item: root.item
        onCloseRequested: root.interactionLockChanged(false)
    }

    DragHandler {
        id: dragHandler
        target: null
        enabled: root.item.pinned
        xAxis.enabled: true
        yAxis.enabled: false

        onTranslationChanged: {
            if (active)
                root.dragOffset = activeTranslation.x
        }

        onActiveChanged: {
            root.dragStateChanged(active)
            if (!active) {
                const center = root.x + root.width / 2 + root.dragOffset
                root.reorderRequested(root.pinnedIndex, center)
                root.dragOffset = 0
                persistentTranslation = Qt.point(0, 0)
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: root.item.entry || root.item.windows.length > 0
            ? Qt.PointingHandCursor
            : Qt.ArrowCursor

        onEntered: {
            root.hoverRequested(root.dockIndex)
            root.tooltipReady = false
            tooltipTimer.restart()
        }

        onExited: {
            root.hoverReleased(root.dockIndex)
            tooltipTimer.stop()
            root.tooltipReady = false
        }

        onClicked: mouse => {
            if (root.dragging)
                return
            if (mouse.button === Qt.LeftButton)
                DockModel.activateOrLaunch(root.item)
            else if (mouse.button === Qt.MiddleButton)
                DockModel.launchNew(root.item)
            else if (mouse.button === Qt.RightButton) {
                root.tooltipReady = false
                contextMenu.visible = !contextMenu.visible
                root.interactionLockChanged(contextMenu.visible)
            }
        }
    }
}
