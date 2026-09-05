import QtQuick
import Quickshell

PopupWindow {
    id: menu

    property var item: null
    readonly property var windows: item && item.windows ? item.windows : []
    readonly property bool canLaunch: item !== null && item.entry !== null

    signal closeRequested()

    color: "transparent"
    grabFocus: true
    implicitWidth: 280
    implicitHeight: frame.implicitHeight

    function closeMenu() {
        visible = false
    }

    onVisibleChanged: {
        if (!visible)
            closeRequested()
    }

    Rectangle {
        id: frame
        anchors.fill: parent
        implicitHeight: menuColumn.implicitHeight + 12
        radius: 10
        color: Theme.bg
        border.width: 1
        border.color: Theme.ui3

        Column {
            id: menuColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 6
            spacing: 2

            Text {
                width: parent.width
                height: 28
                leftPadding: 9
                rightPadding: 9
                verticalAlignment: Text.AlignVCenter
                text: menu.item ? menu.item.name : "Приложение"
                color: Theme.tx
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
            }

            Repeater {
                model: menu.windows

                delegate: Rectangle {
                    id: windowRow
                    required property var modelData

                    width: menuColumn.width
                    height: 30
                    radius: 6
                    color: windowHover.hovered ? Theme.ui : "transparent"

                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: 14
                        radius: 2
                        color: windowRow.modelData.activated ? Theme.blue : Theme.ui3
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: windowRow.modelData.title || menu.item.name
                        color: windowRow.modelData.activated ? Theme.tx : Theme.tx2
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                        renderType: Text.NativeRendering
                    }

                    HoverHandler { id: windowHover }
                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        onTapped: {
                            windowRow.modelData.activate()
                            menu.closeMenu()
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width - 12
                height: 1
                anchors.horizontalCenter: parent.horizontalCenter
                color: Theme.ui3
            }

            Repeater {
                model: [
                    { id: "new", label: "Новое окно", icon: "＋", enabled: menu.canLaunch },
                    {
                        id: "pin",
                        label: menu.item && menu.item.pinned ? "Убрать из дока" : "Закрепить в доке",
                        icon: menu.item && menu.item.pinned ? "−" : "◆",
                        enabled: menu.canLaunch
                    },
                    { id: "close", label: "Закрыть все окна", icon: "×", enabled: menu.windows.length > 0 }
                ]

                delegate: Rectangle {
                    id: actionRow
                    required property var modelData

                    width: menuColumn.width
                    height: 30
                    radius: 6
                    color: actionHover.hovered && modelData.enabled ? Theme.ui : "transparent"
                    opacity: modelData.enabled ? 1 : 0.42

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                        horizontalAlignment: Text.AlignHCenter
                        text: actionRow.modelData.icon
                        color: actionRow.modelData.id === "close" ? Theme.red : Theme.tx2
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        renderType: Text.NativeRendering
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 32
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: actionRow.modelData.label
                        color: actionRow.modelData.id === "close" ? Theme.red : Theme.tx
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        textFormat: Text.PlainText
                        renderType: Text.NativeRendering
                    }

                    HoverHandler { id: actionHover }
                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        enabled: actionRow.modelData.enabled
                        onTapped: {
                            const actionId = actionRow.modelData.id
                            const targetItem = menu.item
                            menu.closeMenu()
                            if (actionId === "new")
                                DockModel.launchNew(targetItem)
                            else if (actionId === "pin")
                                DockModel.togglePin(targetItem.entryId)
                            else if (actionId === "close")
                                DockModel.closeAll(targetItem)
                        }
                    }
                }
            }
        }
    }
}
