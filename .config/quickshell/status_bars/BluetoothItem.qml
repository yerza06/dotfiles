import QtQuick
import Quickshell
import Quickshell.Bluetooth

Rectangle {
    id: root

    property color backgroundColor: "#100f0f"
    property color hoverColor: "#1c1b1a"
    property color textColor: "#cecdc3"
    property color mutedTextColor: "#878580"
    property color activeColor: "#4385be"
    property color bottomBorderColor: "#403e3c"
    property color menuHoverColor: "#282726"
    property color menuBorderColor: "#575653"
    property color menuSeparatorColor: "#403e3c"
    property color tooltipBorderColor: "#575653"
    property string fontFamily: "IosevkaTerm Nerd Font Propo"

    property bool menuVisible: false

    readonly property bool menuChainHovered: buttonMouse.containsMouse || bluetoothMenu.chainHovered

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool adapterEnabled: adapter !== null && adapter.enabled
    readonly property var connectedDevices: adapter && adapter.devices
        ? adapter.devices.values.filter(device => device.connected)
        : []
    readonly property int connectedCount: connectedDevices.length

    function tooltipBody() {
        if (!adapter)
            return "Адаптер не найден"
        if (!adapter.enabled)
            return "Выключен"
        if (connectedDevices.length === 0)
            return "Нет подключённых устройств"
        const lines = []
        for (let i = 0; i < connectedDevices.length; i++) {
            const device = connectedDevices[i]
            const battery = bluetoothMenu.deviceDetail(device)
            lines.push(bluetoothMenu.deviceLabel(device)
                + (battery.length > 0 ? " — " + battery : ""))
        }
        return lines.join("\n")
    }

    function toggleMenu() {
        menuCloseTimer.stop()
        menuVisible = !menuVisible
    }

    onMenuChainHoveredChanged: {
        if (menuChainHovered)
            menuCloseTimer.stop()
        else if (menuVisible)
            menuCloseTimer.restart()
    }

    implicitWidth: label.implicitWidth + 12
    implicitHeight: 28
    radius: 3
    color: buttonMouse.containsMouse ? hoverColor : backgroundColor

    Behavior on color {
        ColorAnimation { duration: 100 }
    }

    // Меню закрывается, когда курсор ушёл и с виджета, и с самого меню.
    Timer {
        id: menuCloseTimer
        interval: 400
        repeat: false
        onTriggered: {
            if (!root.menuChainHovered)
                root.menuVisible = false
        }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.adapterEnabled
            ? ("" + (root.connectedCount > 0 ? " " + root.connectedCount : ""))
            : "󰂲"
        color: root.adapterEnabled ? root.activeColor : root.mutedTextColor
        font.family: root.fontFamily
        font.pixelSize: 14
        font.weight: Font.Medium
        renderType: Text.NativeRendering
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: root.bottomBorderColor
    }

    BluetoothMenu {
        id: bluetoothMenu

        visible: root.menuVisible
        anchor.item: root
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        backgroundColor: root.backgroundColor
        hoverColor: root.menuHoverColor
        textColor: root.textColor
        mutedTextColor: root.mutedTextColor
        borderColor: root.menuBorderColor
        separatorColor: root.menuSeparatorColor
        fontFamily: root.fontFamily
        onCloseRequested: root.menuVisible = false
    }

    Tooltip {
        visible: buttonMouse.containsMouse && !root.menuVisible
        anchor.item: root
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.bottom: 4
        title: "  Bluetooth"
        text: root.tooltipBody()
        backgroundColor: root.backgroundColor
        borderColor: root.tooltipBorderColor
        titleColor: root.textColor
        textColor: root.mutedTextColor
        fontFamily: root.fontFamily
    }

    MouseArea {
        id: buttonMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                Quickshell.execDetached(["kitty", "bluetui"])
            else if (mouse.button === Qt.RightButton)
                root.toggleMenu()
            else if (mouse.button === Qt.MiddleButton && root.adapter)
                root.adapter.enabled = !root.adapter.enabled
        }
    }
}
