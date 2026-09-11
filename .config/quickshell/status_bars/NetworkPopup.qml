import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// Окно сети по ПКМ на NetworkItem: шапка с именем сети и тумблером Wi-Fi,
// показатели соединения и список точек доступа с вводом пароля.
// Как окна батареи и плеера, окно «липкое»: grabFocus отдаёт ему клавиатуру и
// заставляет композитор закрыть его по клику мимо, поэтому таймера автозакрытия
// по уходу курсора здесь нет — в отличие от меню панели.
PopupWindow {
    id: popupRoot

    // Устройства и имя сети считает NetworkItem — панель и окно должны
    // показывать ровно одно и то же.
    property var wiredDevice: null
    property var wifiDevice: null
    property var activeWifiNetwork: null
    property string activeName: ""
    property string interfaceName: ""
    property string icon: ""
    property bool connected: false
    property color backgroundColor: "#100f0f"
    property color hoverColor: "#282726"
    property color textColor: "#cecdc3"
    property color mutedTextColor: "#878580"
    property color borderColor: "#575653"
    property color separatorColor: "#403e3c"
    property color disabledColor: "#403e3c"
    property color accentColor: "#4385be"
    property color greenColor: "#879a39"
    property color redColor: "#d14d41"
    property string fontFamily: "IosevkaTerm Nerd Font Propo"

    // Куда пинговать. Не шлюз: интересна связь с интернетом, а не с роутером.
    property string pingTarget: "1.1.1.1"

    signal closeRequested()

    // Сеть, для которой сейчас спрашивается пароль. null — поле ввода скрыто.
    property var pskTarget: null
    property string pskError: ""

    property string ipAddress: ""
    property string gateway: ""
    // -1 — ещё не измерено или узел не ответил.
    property real pingMs: -1
    property real packetLoss: -1
    property real rxTotal: 0
    property real txTotal: 0
    property real rxRate: 0
    property real txRate: 0
    // Предыдущий замер счётчиков: скорость считается по дельте, потому что
    // sysfs отдаёт только суммарные байты с момента поднятия интерфейса.
    property real lastRx: -1
    property real lastTx: -1
    property double lastSampleAt: 0

    readonly property bool pskActive: pskTarget !== null

    readonly property var wifiNetworks: {
        if (!wifiDevice || !wifiDevice.networks)
            return []
        return NetworkFormat.sortNetworks(wifiDevice.networks.values)
    }

    readonly property var knownNetworks: {
        const result = []
        for (let i = 0; i < wifiNetworks.length && result.length < 4; i++) {
            if (wifiNetworks[i].known || wifiNetworks[i].connected)
                result.push(wifiNetworks[i])
        }
        return result
    }

    readonly property var otherNetworks: {
        const result = []
        for (let i = 0; i < wifiNetworks.length && result.length < 6; i++) {
            if (!wifiNetworks[i].known && !wifiNetworks[i].connected)
                result.push(wifiNetworks[i])
        }
        return result
    }

    function qualityLabel() {
        if (wiredDevice) {
            const speed = NetworkFormat.speedLabel(wiredDevice)
            return speed.length > 0 ? "Ethernet · " + speed : "Ethernet"
        }
        if (activeWifiNetwork) {
            const parts = ["Wi-Fi", NetworkFormat.signalPercent(activeWifiNetwork) + "%"]
            const security = NetworkFormat.securityLabel(activeWifiNetwork)
            if (security.length > 0)
                parts.push(security)
            return parts.join(" · ")
        }
        if (!Networking.wifiEnabled)
            return "Wi-Fi выключен"
        return "Нет подключения"
    }

    function networkDetail(network) {
        return (NetworkFormat.isSecured(network) ? " " : "")
            + NetworkFormat.signalPercent(network) + "%"
    }

    function activateNetwork(network) {
        if (!network)
            return
        pskError = ""
        if (network.connected) {
            network.disconnect()
            return
        }
        if (network.known || !NetworkFormat.isSecured(network)) {
            network.connect()
            return
        }
        pskTarget = network
    }

    function submitPsk(psk) {
        if (!pskTarget || psk.length === 0)
            return
        pskError = ""
        pskTarget.connectWithPsk(psk)
        pskTarget = null
    }

    function cancelPsk() {
        pskTarget = null
        pskError = ""
    }

    // Команды назначаются в функциях, а не биндингами: порядок пересчёта
    // биндинга и running не определён, и процесс успевает стартовать со старым
    // именем устройства — та же причина, что у ipProcess в NetworkItem.
    function refreshRoute() {
        if (interfaceName.length === 0)
            return
        addrProcess.running = false
        addrProcess.command = ["ip", "-j", "-4", "addr", "show", interfaceName]
        addrProcess.running = true
        gatewayProcess.running = false
        gatewayProcess.command = ["ip", "-j", "route", "show", "default", "dev", interfaceName]
        gatewayProcess.running = true
    }

    // Три пакета занимают около двух секунд, поэтому новый запуск ждёт прошлый.
    function refreshPing() {
        if (interfaceName.length === 0 || pingProcess.running)
            return
        pingProcess.command = ["ping", "-n", "-q", "-c", "3", "-W", "1",
            "-I", interfaceName, pingTarget]
        pingProcess.running = true
    }

    function refreshCounters() {
        if (interfaceName.length === 0 || countersProcess.running)
            return
        const base = "/sys/class/net/" + interfaceName + "/statistics/"
        countersProcess.command = ["cat", base + "rx_bytes", base + "tx_bytes"]
        countersProcess.running = true
    }

    function applyCounters(rawText) {
        const lines = rawText.trim().split("\n")
        if (lines.length < 2)
            return
        const rx = parseInt(lines[0])
        const tx = parseInt(lines[1])
        if (isNaN(rx) || isNaN(tx))
            return

        const now = Date.now()
        const elapsed = (now - lastSampleAt) / 1000
        // Первый замер после открытия только запоминает базу: считать скорость
        // не от чего, а счётчики могли копиться часами.
        if (lastRx >= 0 && lastTx >= 0 && elapsed > 0) {
            rxRate = Math.max(0, (rx - lastRx) / elapsed)
            txRate = Math.max(0, (tx - lastTx) / elapsed)
        }
        lastRx = rx
        lastTx = tx
        lastSampleAt = now
        rxTotal = rx
        txTotal = tx
    }

    function applyPing(rawText) {
        const loss = rawText.match(/([\d.]+)% packet loss/)
        packetLoss = loss ? parseFloat(loss[1]) : -1
        const rtt = rawText.match(/=\s*[\d.]+\/([\d.]+)\//)
        pingMs = rtt ? parseFloat(rtt[1]) : -1
    }

    function resetStats() {
        ipAddress = ""
        gateway = ""
        pingMs = -1
        packetLoss = -1
        rxRate = 0
        txRate = 0
        rxTotal = 0
        txTotal = 0
        lastRx = -1
        lastTx = -1
        lastSampleAt = 0
    }

    function refreshAll() {
        refreshRoute()
        refreshPing()
        refreshCounters()
    }

    function pingText() {
        return pingMs >= 0 ? Math.round(pingMs) + " мс" : "—"
    }

    function lossText() {
        return packetLoss >= 0 ? Math.round(packetLoss) + "%" : "—"
    }

    function lossColor() {
        if (packetLoss < 0)
            return mutedTextColor
        if (packetLoss >= 20)
            return redColor
        return packetLoss > 0 ? textColor : greenColor
    }

    function handleKey(event) {
        if (event.key !== Qt.Key_Escape)
            return
        // Первый Esc убирает поле пароля, второй закрывает окно.
        if (pskActive)
            cancelPsk()
        else
            closeRequested()
        event.accepted = true
    }

    implicitWidth: frame.implicitWidth
    implicitHeight: frame.implicitHeight
    color: "transparent"
    grabFocus: true

    onVisibleChanged: {
        if (visible) {
            frame.forceActiveFocus()
            resetStats()
            refreshAll()
        } else {
            cancelPsk()
        }
    }

    // Интерфейс сменился — прошлые адреса и счётчики больше не относятся к делу.
    onInterfaceNameChanged: {
        resetStats()
        if (visible)
            refreshAll()
    }

    onPskTargetChanged: {
        pskField.text = ""
        if (pskTarget)
            pskField.forceActiveFocus()
    }

    Connections {
        target: popupRoot.pskTarget

        function onConnectionFailed(reason) {
            popupRoot.pskError = ConnectionFailReason.toString(reason)
        }
    }

    // Счётчики читаются чаще остального: скорость должна выглядеть живой.
    Timer {
        interval: 1000
        repeat: true
        running: popupRoot.visible
        onTriggered: popupRoot.refreshCounters()
    }

    Timer {
        interval: 5000
        repeat: true
        running: popupRoot.visible
        onTriggered: {
            popupRoot.refreshRoute()
            popupRoot.refreshPing()
        }
    }

    Process {
        id: addrProcess

        stdout: StdioCollector {
            onStreamFinished: popupRoot.ipAddress = NetworkFormat.parseIp(text)
        }
    }

    Process {
        id: gatewayProcess

        stdout: StdioCollector {
            onStreamFinished: popupRoot.gateway = NetworkFormat.parseGateway(text)
        }
    }

    Process {
        id: pingProcess

        stdout: StdioCollector {
            onStreamFinished: popupRoot.applyPing(text)
        }
    }

    Process {
        id: countersProcess

        stdout: StdioCollector {
            onStreamFinished: popupRoot.applyCounters(text)
        }
    }

    Rectangle {
        id: frame

        anchors.fill: parent
        // Ширина фиксированная: иначе окно прыгало бы при каждом обновлении
        // скоростей и при смене длины имени сети.
        implicitWidth: 340
        implicitHeight: content.implicitHeight + 24
        color: popupRoot.backgroundColor
        border.width: 1
        border.color: popupRoot.borderColor
        radius: 5
        focus: true

        Keys.onPressed: event => popupRoot.handleKey(event)

        ColumnLayout {
            id: content

            anchors.fill: parent
            anchors.topMargin: 12
            anchors.bottomMargin: 12
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: popupRoot.icon
                    color: popupRoot.connected ? popupRoot.textColor : popupRoot.mutedTextColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 26
                    renderType: Text.NativeRendering
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: popupRoot.activeName
                        color: popupRoot.textColor
                        font.family: popupRoot.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }

                    Text {
                        Layout.fillWidth: true
                        text: popupRoot.qualityLabel()
                        color: popupRoot.mutedTextColor
                        font.family: popupRoot.fontFamily
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }
                }

                ToggleSwitch {
                    checked: Networking.wifiEnabled
                    available: Networking.wifiHardwareEnabled
                    accentColor: popupRoot.accentColor
                    trackColor: popupRoot.separatorColor
                    knobColor: popupRoot.textColor
                    disabledColor: popupRoot.disabledColor
                    onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 4
                columnSpacing: 14
                rowSpacing: 4

                Text {
                    text: "Пинг"
                    color: popupRoot.mutedTextColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: popupRoot.pingText()
                    color: popupRoot.textColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }

                Text {
                    text: "Потери"
                    color: popupRoot.mutedTextColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: popupRoot.lossText()
                    color: popupRoot.lossColor()
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }

                Text {
                    text: "Приём"
                    color: popupRoot.mutedTextColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: NetworkFormat.formatRate(popupRoot.rxRate)
                    color: popupRoot.textColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }

                Text {
                    text: "Отдача"
                    color: popupRoot.mutedTextColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: NetworkFormat.formatRate(popupRoot.txRate)
                    color: popupRoot.textColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }

                Text {
                    text: "Принято"
                    color: popupRoot.mutedTextColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: NetworkFormat.formatBytes(popupRoot.rxTotal)
                    color: popupRoot.textColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }

                Text {
                    text: "Отдано"
                    color: popupRoot.mutedTextColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: NetworkFormat.formatBytes(popupRoot.txTotal)
                    color: popupRoot.textColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }

                Text {
                    text: "IP-адрес"
                    color: popupRoot.mutedTextColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: popupRoot.ipAddress.length > 0 ? popupRoot.ipAddress : "—"
                    color: popupRoot.textColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }

                Text {
                    text: "Шлюз"
                    color: popupRoot.mutedTextColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: popupRoot.gateway.length > 0 ? popupRoot.gateway : "—"
                    color: popupRoot.textColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: popupRoot.separatorColor
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    Layout.bottomMargin: 2
                    visible: popupRoot.knownNetworks.length > 0
                    text: "ИЗВЕСТНЫЕ СЕТИ"
                    color: popupRoot.mutedTextColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 10
                    font.letterSpacing: 1
                    renderType: Text.NativeRendering
                }

                Repeater {
                    model: popupRoot.knownNetworks

                    delegate: DeviceRow {
                        required property var modelData

                        current: modelData.connected
                        busy: modelData.stateChanging
                        label: modelData.name
                        detail: popupRoot.networkDetail(modelData)
                        hoverColor: popupRoot.hoverColor
                        textColor: popupRoot.textColor
                        mutedTextColor: popupRoot.mutedTextColor
                        markColor: popupRoot.separatorColor
                        fontFamily: popupRoot.fontFamily
                        onActivated: popupRoot.activateNetwork(modelData)
                    }
                }

                Text {
                    Layout.topMargin: popupRoot.knownNetworks.length > 0 ? 6 : 0
                    Layout.bottomMargin: 2
                    visible: popupRoot.otherNetworks.length > 0
                    text: "ДОСТУПНЫЕ СЕТИ"
                    color: popupRoot.mutedTextColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 10
                    font.letterSpacing: 1
                    renderType: Text.NativeRendering
                }

                Repeater {
                    model: popupRoot.otherNetworks

                    delegate: DeviceRow {
                        required property var modelData

                        current: modelData.connected
                        busy: modelData.stateChanging
                        label: modelData.name
                        detail: popupRoot.networkDetail(modelData)
                        hoverColor: popupRoot.hoverColor
                        textColor: popupRoot.textColor
                        mutedTextColor: popupRoot.mutedTextColor
                        markColor: popupRoot.separatorColor
                        fontFamily: popupRoot.fontFamily
                        onActivated: popupRoot.activateNetwork(modelData)
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 24
                    verticalAlignment: Text.AlignVCenter
                    visible: popupRoot.wifiNetworks.length === 0
                    text: Networking.wifiEnabled ? "Сетей не найдено" : "Wi-Fi выключен"
                    color: popupRoot.mutedTextColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 12
                    renderType: Text.NativeRendering
                }
            }

            Rectangle {
                id: pskFrame

                Layout.fillWidth: true
                Layout.preferredHeight: 26
                visible: popupRoot.pskActive
                color: "transparent"
                border.width: 1
                border.color: popupRoot.borderColor
                radius: 3

                TextInput {
                    id: pskField

                    anchors.fill: parent
                    anchors.leftMargin: 7
                    anchors.rightMargin: 7
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    color: popupRoot.textColor
                    selectionColor: popupRoot.hoverColor
                    selectedTextColor: popupRoot.textColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 12
                    clip: true
                    renderType: Text.NativeRendering

                    Keys.onReturnPressed: popupRoot.submitPsk(text)
                    Keys.onEnterPressed: popupRoot.submitPsk(text)
                    Keys.onEscapePressed: popupRoot.cancelPsk()

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        visible: pskField.text.length === 0
                        text: popupRoot.pskTarget
                            ? "Пароль для " + popupRoot.pskTarget.name
                            : ""
                        color: popupRoot.mutedTextColor
                        font.family: popupRoot.fontFamily
                        font.pixelSize: 12
                        renderType: Text.NativeRendering
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: popupRoot.pskError.length > 0
                text: popupRoot.pskError
                color: popupRoot.redColor
                font.family: popupRoot.fontFamily
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                renderType: Text.NativeRendering
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: popupRoot.separatorColor
            }

            DeviceRow {
                showMark: false
                label: "Настройки сети…"
                labelColor: popupRoot.textColor
                hoverColor: popupRoot.hoverColor
                textColor: popupRoot.textColor
                mutedTextColor: popupRoot.mutedTextColor
                markColor: popupRoot.separatorColor
                fontFamily: popupRoot.fontFamily
                onActivated: {
                    Quickshell.execDetached(["kitty", "nmtui"])
                    popupRoot.closeRequested()
                }
            }
        }
    }
}
