import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

Rectangle {
    id: root

    property color backgroundColor: "#100f0f"
    property color hoverColor: "#1c1b1a"
    property color textColor: "#cecdc3"
    property color mutedTextColor: "#878580"
    property color offlineColor: "#d14d41"
    property color bottomBorderColor: "#403e3c"
    property color menuHoverColor: "#282726"
    property color menuBorderColor: "#575653"
    property color menuSeparatorColor: "#403e3c"
    property color tooltipBorderColor: "#575653"
    property string fontFamily: "IosevkaTerm Nerd Font Propo"

    property bool menuVisible: false

    // Quickshell.Networking отдаёт в device.address MAC, поэтому IP берём у `ip`.
    property string ipAddress: ""

    readonly property bool menuChainHovered: buttonMouse.containsMouse || networkMenu.chainHovered

    readonly property var devices: Networking.devices ? Networking.devices.values : []

    // Кабель (Ethernet или USB-тетеринг) имеет приоритет над Wi-Fi.
    readonly property var wiredDevice: {
        for (let i = 0; i < devices.length; i++) {
            const device = devices[i]
            if (device.type === DeviceType.Wired && device.nmManaged && device.connected)
                return device
        }
        return null
    }

    readonly property var wifiDevice: {
        for (let i = 0; i < devices.length; i++) {
            const device = devices[i]
            if (device.type === DeviceType.Wifi && device.nmManaged && device.connected)
                return device
        }
        return null
    }

    readonly property bool connected: wiredDevice !== null || wifiDevice !== null

    readonly property var activeWifiNetwork: {
        if (!wifiDevice || !wifiDevice.networks)
            return null
        const networks = wifiDevice.networks.values
        for (let i = 0; i < networks.length; i++) {
            if (networks[i].connected)
                return networks[i]
        }
        return null
    }

    readonly property string activeName: {
        if (wiredDevice)
            return wiredDevice.name
        if (activeWifiNetwork)
            return activeWifiNetwork.name
        return "offline"
    }

    readonly property string activeDeviceName: {
        if (wiredDevice)
            return wiredDevice.name
        if (wifiDevice)
            return wifiDevice.name
        return ""
    }

    function networkIcon() {
        if (wiredDevice)
            return ""
        if (wifiDevice)
            return ""
        return "󰤭"
    }

    function parseIp(rawText) {
        try {
            const data = JSON.parse(rawText)
            if (data.length > 0 && data[0].addr_info && data[0].addr_info.length > 0)
                return data[0].addr_info[0].local || ""
        } catch (error) {
            return ""
        }
        return ""
    }

    // Команда задаётся здесь, а не биндингом: порядок пересчёта биндинга и
    // обработчика onActiveDeviceNameChanged не определён, и процесс успевал
    // стартовать со старым именем устройства.
    function refreshIp() {
        if (activeDeviceName.length === 0)
            return
        ipProcess.command = ["ip", "-j", "-4", "addr", "show", activeDeviceName]
        ipProcess.running = true
    }

    function tooltipBody() {
        const lines = []
        if (wiredDevice) {
            lines.push("Ethernet: " + wiredDevice.name)
            const speed = networkMenu.speedLabel(wiredDevice)
            if (speed.length > 0)
                lines.push("Скорость: " + speed)
        } else if (activeWifiNetwork) {
            lines.push("Wi-Fi: " + activeWifiNetwork.name)
            lines.push("Сигнал: " + networkMenu.signalPercent(activeWifiNetwork) + "%")
            const security = networkMenu.securityLabel(activeWifiNetwork)
            if (security.length > 0)
                lines.push("Защита: " + security)
        } else {
            return "Нет подключения"
        }
        if (ipAddress.length > 0)
            lines.push("IP: " + ipAddress)
        return lines.join("\n")
    }

    function toggleMenu() {
        menuCloseTimer.stop()
        menuVisible = !menuVisible
    }

    // Устройство сменилось — прошлый адрес больше не относится к делу.
    onActiveDeviceNameChanged: {
        ipAddress = ""
        refreshIp()
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
    color: connected
        ? (buttonMouse.containsMouse ? hoverColor : backgroundColor)
        : offlineColor

    Behavior on color {
        ColorAnimation { duration: 100 }
    }

    Process {
        id: ipProcess

        stdout: StdioCollector {
            onStreamFinished: root.ipAddress = root.parseIp(text)
        }
    }

    // Меню закрывается, когда курсор ушёл и с виджета, и с самого меню.
    Timer {
        id: menuCloseTimer
        interval: 400
        repeat: false
        onTriggered: {
            if (!root.menuChainHovered && !networkMenu.pskActive)
                root.menuVisible = false
        }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.networkIcon()
        color: root.connected ? root.textColor : root.backgroundColor
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

    NetworkMenu {
        id: networkMenu

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
        errorColor: root.offlineColor
        fontFamily: root.fontFamily
        onCloseRequested: root.menuVisible = false
    }

    Tooltip {
        visible: buttonMouse.containsMouse && !root.menuVisible
        anchor.item: root
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.bottom: 4
        title: root.networkIcon() + "  Сеть"
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
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onEntered: root.refreshIp()

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                Quickshell.execDetached(["kitty", "nmtui"])
            else if (mouse.button === Qt.RightButton)
                root.toggleMenu()
        }
    }
}
