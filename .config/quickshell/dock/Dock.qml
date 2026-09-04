import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "DockLogic.js" as DockLogic

PanelWindow {
    id: dock

    required property var targetScreen

    property bool revealed: false
    property bool dragging: false
    property var lockingItem: null
    property int hoveredIndex: -1

    readonly property var screenItems: DockModel.itemsForScreen(targetScreen)
    readonly property var pinnedItems: screenItems.pinned || []
    readonly property var runningItems: screenItems.running || []
    readonly property bool interactionLocked: dragging || lockingItem !== null
    readonly property int panelPadding: 28

    screen: targetScreen
    anchors.bottom: true
    implicitWidth: Math.max(260, dockCard.width + panelPadding * 2)
    implicitHeight: 100
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: lockingItem !== null
    mask: Region { item: inputRegion }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-dock"
    WlrLayershell.keyboardFocus: lockingItem !== null
        ? WlrKeyboardFocus.OnDemand
        : WlrKeyboardFocus.None

    function showDock() {
        hideTimer.stop()
        revealed = true
    }

    function scheduleHide() {
        if (DockLogic.shouldHide(interactionLocked, inputHover.hovered, cardHover.hovered, hoveredIndex))
            hideTimer.restart()
    }

    function itemEntered(index) {
        hoveredIndex = index
        showDock()
    }

    function itemLeft(index) {
        if (hoveredIndex !== index)
            return
        hoveredIndex = -1
        scheduleHide()
    }

    function nearestPinnedIndex(centerX) {
        if (pinnedItems.length === 0)
            return -1

        let nearest = 0
        let distance = Number.POSITIVE_INFINITY
        for (let i = 0; i < pinnedItems.length; i++) {
            const child = pinnedRepeater.itemAt(i)
            if (!child)
                continue
            const childCenter = child.x + child.width / 2
            const candidate = Math.abs(centerX - childCenter)
            if (candidate < distance) {
                distance = candidate
                nearest = i
            }
        }
        return nearest
    }

    onInteractionLockedChanged: {
        if (interactionLocked)
            showDock()
        else
            scheduleHide()
    }

    Timer {
        id: hideTimer
        interval: 350
        repeat: false
        onTriggered: {
            if (DockLogic.shouldHide(
                    dock.interactionLocked,
                    inputHover.hovered,
                    cardHover.hovered,
                    dock.hoveredIndex)) {
                dock.revealed = false
                dock.hoveredIndex = -1
            }
        }
    }

    Item {
        id: inputRegion
        x: dock.revealed ? dockCard.x : Math.round((dock.width - width) / 2)
        y: dock.revealed ? dockCard.y : dock.height - 2
        width: dock.revealed ? dockCard.width : Math.max(260, dockCard.width + 36)
        height: dock.revealed ? dock.height - dockCard.y : 2

        HoverHandler {
            id: inputHover
            onHoveredChanged: {
                if (hovered)
                    dock.showDock()
                else
                    dock.scheduleHide()
            }
        }
    }

    Rectangle {
        id: dockCard
        x: Math.round((dock.width - width) / 2)
        y: dock.revealed ? dock.height - height - 12 : dock.height - 2
        width: dockRow.implicitWidth + 24
        height: 72
        radius: 18
        color: Theme.dockBackground
        border.width: 1
        border.color: Theme.ui3
        opacity: dock.revealed ? 1 : 0

        layer.enabled: true
        layer.effect: MultiEffect {
            autoPaddingEnabled: true
            shadowEnabled: true
            shadowBlur: 0.78
            shadowOpacity: Theme.light ? 0.32 : 0.52
            shadowColor: Theme.light ? "#100f0f" : "#000000"
            shadowVerticalOffset: 5
            shadowScale: 1.015
        }

        Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 140 } }

        HoverHandler {
            id: cardHover
            onHoveredChanged: {
                if (hovered)
                    dock.showDock()
                else
                    dock.scheduleHide()
            }
        }

        Row {
            id: dockRow
            anchors.centerIn: parent
            spacing: 10

            Repeater {
                id: pinnedRepeater
                model: dock.pinnedItems

                delegate: DockItem {
                    id: pinnedItem
                    required property var modelData
                    required property int index

                    item: modelData
                    dockIndex: index
                    pinnedIndex: index

                    onHoverRequested: value => dock.itemEntered(value)
                    onHoverReleased: value => dock.itemLeft(value)
                    onInteractionLockChanged: locked => {
                        dock.lockingItem = locked
                            ? pinnedItem
                            : (dock.lockingItem === pinnedItem ? null : dock.lockingItem)
                    }
                    onDragStateChanged: active => dock.dragging = active
                    onReorderRequested: (fromIndex, centerX) => {
                        const target = dock.nearestPinnedIndex(centerX)
                        if (target >= 0)
                            DockModel.movePin(fromIndex, target)
                    }
                }
            }

            Item {
                visible: dock.pinnedItems.length > 0 && dock.runningItems.length > 0
                width: visible ? 7 : 0
                height: 64

                Rectangle {
                    anchors.centerIn: parent
                    width: 1
                    height: 32
                    color: Theme.ui3
                }
            }

            Repeater {
                model: dock.runningItems

                delegate: DockItem {
                    id: runningItem
                    required property var modelData
                    required property int index

                    item: modelData
                    dockIndex: dock.pinnedItems.length + index
                    pinnedIndex: -1

                    onHoverRequested: value => dock.itemEntered(value)
                    onHoverReleased: value => dock.itemLeft(value)
                    onInteractionLockChanged: locked => {
                        dock.lockingItem = locked
                            ? runningItem
                            : (dock.lockingItem === runningItem ? null : dock.lockingItem)
                    }
                    onDragStateChanged: active => dock.dragging = active
                }
            }
        }
    }

    Component.onCompleted: revealed = false
}
