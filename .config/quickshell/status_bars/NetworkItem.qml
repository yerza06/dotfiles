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
    property color popupHoverColor: "#282726"
    property color popupBorderColor: "#575653"
    property color popupSeparatorColor: "#403e3c"
    property color tooltipBorderColor: "#575653"
    property color accentColor: "#4385be"
    property color greenColor: "#879a39"
    property string fontFamily: "IosevkaTerm Nerd Font Propo"

    // Quickshell.Networking отдаёт в device.address MAC, поэтому IP берём у `ip`.
    property string ipAddress: ""

    // Момент последнего закрытия окна. Клик мимо, которым композитор снимает
    // захват, долетает и до самого виджета — без этой отсечки окно тут же
    // открылось бы снова.
    property double popupClosedAt: 0

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

    // Wi-Fi адаптер независимо от подключения: список точек и сканирование
    // нужны и когда соединения нет.
    readonly property var wifiHardware: {
        for (let i = 0; i < devices.length; i++) {
            const device = devices[i]
            if (device.type === DeviceType.Wifi && device.nmManaged)
                return device
        }
        return null
    }

    readonly property bool connected: wiredDevice !== null || wifiDevice !== null

    // Сканирование крутится, только пока открыто окно.
    readonly property bool scanRequested: popup.visible

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
        const clickHint = "ЛКМ — Wi-Fi вкл/выкл\nПКМ — окно сети\nСКМ — nmtui"
        const lines = []
        if (wiredDevice) {
            lines.push("Ethernet: " + wiredDevice.name)
            const speed = NetworkFormat.speedLabel(wiredDevice)
            if (speed.length > 0)
                lines.push("Скорость: " + speed)
        } else if (activeWifiNetwork) {
            lines.push("Wi-Fi: " + activeWifiNetwork.name)
            lines.push("Сигнал: " + NetworkFormat.signalPercent(activeWifiNetwork) + "%")
            const security = NetworkFormat.securityLabel(activeWifiNetwork)
            if (security.length > 0)
                lines.push("Защита: " + security)
        } else {
            return (Networking.wifiEnabled ? "Нет подключения" : "Wi-Fi выключен")
                + "\n" + clickHint
        }
        if (ipAddress.length > 0)
            lines.push("IP: " + ipAddress)
        lines.push(clickHint)
        return lines.join("\n")
    }

    // Присваивание, а не Binding: Quickshell не применяет к scannerEnabled
    // биндинг с target/property — свойство остаётся выключенным.
    function applyScanner() {
        if (wifiHardware)
            wifiHardware.scannerEnabled = scanRequested
    }

    function togglePopup() {
        if (!popup.visible && Date.now() - popupClosedAt < 200)
            return
        popup.visible = !popup.visible
    }

    // Устройства приходят по D-Bus асинхронно, но могут оказаться на месте уже
    // к моменту создания виджета — тогда сигналов об изменении не будет.
    Component.onCompleted: applyScanner()

    onScanRequestedChanged: applyScanner()

    onWifiHardwareChanged: applyScanner()

    // Устройство сменилось — прошлый адрес больше не относится к делу.
    onActiveDeviceNameChanged: {
        ipAddress = ""
        refreshIp()
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
            onStreamFinished: root.ipAddress = NetworkFormat.parseIp(text)
        }
    }

    // Сканер приходится взводить повторно: NetworkManager гасит его сам после
    // очередного обхода эфира, и с одного присваивания список так и остался бы
    // из одних известных сетей.
    Timer {
        // Реже, чем хотелось бы: непрерывное сканирование заметно поднимает
        // пинг, а его же окно и показывает.
        interval: 10000
        repeat: true
        running: root.scanRequested
        triggeredOnStart: true
        onTriggered: root.applyScanner()
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

    NetworkPopup {
        id: popup

        // visible выставляется только вручную: композитор закрывает окно сам,
        // и биндинг после первого такого закрытия сломался бы.
        visible: false
        anchor.item: root
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.bottom: 4
        wiredDevice: root.wiredDevice
        wifiDevice: root.wifiHardware
        activeWifiNetwork: root.activeWifiNetwork
        activeName: root.connected ? root.activeName : "Нет сети"
        interfaceName: root.activeDeviceName
        icon: root.networkIcon()
        connected: root.connected
        backgroundColor: root.backgroundColor
        hoverColor: root.popupHoverColor
        textColor: root.textColor
        mutedTextColor: root.mutedTextColor
        borderColor: root.popupBorderColor
        separatorColor: root.popupSeparatorColor
        disabledColor: root.popupSeparatorColor
        accentColor: root.accentColor
        greenColor: root.greenColor
        redColor: root.offlineColor
        fontFamily: root.fontFamily

        onVisibleChanged: {
            if (!visible)
                root.popupClosedAt = Date.now()
        }
        onCloseRequested: popup.visible = false
    }

    Tooltip {
        visible: buttonMouse.containsMouse && !popup.visible
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
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        onEntered: root.refreshIp()

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                Networking.wifiEnabled = !Networking.wifiEnabled
            else if (mouse.button === Qt.RightButton)
                root.togglePopup()
            else if (mouse.button === Qt.MiddleButton)
                Quickshell.execDetached(["kitty", "nmtui"])
        }
    }
}
