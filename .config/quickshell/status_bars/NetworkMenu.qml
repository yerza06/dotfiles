import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking

// Меню выбора сети в стиле Flexoki: проводные устройства, тумблер Wi-Fi и список точек.
PopupWindow {
    id: menuRoot

    property color backgroundColor: "#100f0f"
    property color hoverColor: "#282726"
    property color textColor: "#cecdc3"
    property color mutedTextColor: "#878580"
    property color borderColor: "#575653"
    property color separatorColor: "#403e3c"
    property color errorColor: "#d14d41"
    property string fontFamily: "IosevkaTerm Nerd Font Propo"

    // Сеть, для которой сейчас спрашивается пароль. null — поле ввода скрыто.
    property var pskTarget: null
    property string pskError: ""

    signal closeRequested()

    readonly property bool chainHovered: frameHover.hovered
    readonly property bool pskActive: pskTarget !== null

    readonly property var allDevices: Networking.devices ? Networking.devices.values : []

    // Docker-мосты и veth не управляются NetworkManager — их в меню быть не должно.
    readonly property var wiredDevices: {
        const result = []
        for (let i = 0; i < allDevices.length; i++) {
            const device = allDevices[i]
            if (device.type === DeviceType.Wired && device.nmManaged)
                result.push(device)
        }
        return result
    }

    readonly property var wifiDevice: {
        for (let i = 0; i < allDevices.length; i++) {
            const device = allDevices[i]
            if (device.type === DeviceType.Wifi && device.nmManaged)
                return device
        }
        return null
    }

    // Список ограничен десятью точками: меню не должно вырастать на весь экран.
    readonly property var wifiNetworks: {
        if (!wifiDevice || !wifiDevice.networks)
            return []
        return NetworkFormat.sortNetworks(wifiDevice.networks.values).slice(0, 10)
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

    function wiredDetail(device) {
        if (device.connected)
            return NetworkFormat.speedLabel(device) || "подключено"
        return device.hasLink ? "кабель подключён" : "нет кабеля"
    }

    function activateWired(device) {
        if (device.connected)
            device.disconnect()
        else if (device.network)
            device.network.connect()
    }

    implicitWidth: frame.implicitWidth
    implicitHeight: frame.implicitHeight
    color: "transparent"
    // Клавиатура нужна только на время ввода пароля.
    grabFocus: menuRoot.pskActive

    onVisibleChanged: {
        if (!visible)
            cancelPsk()
    }

    onPskTargetChanged: {
        pskField.text = ""
        if (pskTarget)
            pskField.forceActiveFocus()
    }

    Connections {
        target: menuRoot.pskTarget

        function onConnectionFailed(reason) {
            menuRoot.pskError = ConnectionFailReason.toString(reason)
        }
    }

    Rectangle {
        id: frame

        anchors.fill: parent
        implicitWidth: Math.max(260, Math.min(400, content.implicitWidth + 24))
        implicitHeight: content.implicitHeight + 12
        color: menuRoot.backgroundColor
        border.width: 1
        border.color: menuRoot.borderColor
        radius: 5

        HoverHandler {
            id: frameHover
        }

        ColumnLayout {
            id: content

            anchors.fill: parent
            anchors.topMargin: 6
            anchors.bottomMargin: 6
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 0

            Text {
                Layout.fillWidth: true
                Layout.bottomMargin: 2
                text: "Сеть"
                color: menuRoot.mutedTextColor
                font.family: menuRoot.fontFamily
                font.pixelSize: 11
                font.weight: Font.Medium
                renderType: Text.NativeRendering
            }

            Repeater {
                model: menuRoot.wiredDevices

                delegate: DeviceRow {
                    required property var modelData

                    current: modelData.connected
                    label: modelData.name
                    detail: menuRoot.wiredDetail(modelData)
                    hoverColor: menuRoot.hoverColor
                    textColor: menuRoot.textColor
                    mutedTextColor: menuRoot.mutedTextColor
                    markColor: menuRoot.separatorColor
                    fontFamily: menuRoot.fontFamily
                    onActivated: menuRoot.activateWired(modelData)
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 5
                Layout.bottomMargin: 5
                visible: menuRoot.wiredDevices.length > 0
                implicitHeight: 1
                color: menuRoot.separatorColor
            }

            DeviceRow {
                visible: Networking.wifiHardwareEnabled
                current: Networking.wifiEnabled
                label: "Wi-Fi"
                detail: Networking.wifiEnabled ? "вкл" : "выкл"
                hoverColor: menuRoot.hoverColor
                textColor: menuRoot.textColor
                mutedTextColor: menuRoot.mutedTextColor
                markColor: menuRoot.separatorColor
                fontFamily: menuRoot.fontFamily
                onActivated: Networking.wifiEnabled = !Networking.wifiEnabled
            }

            Repeater {
                model: menuRoot.wifiNetworks

                delegate: DeviceRow {
                    required property var modelData

                    current: modelData.connected
                    busy: modelData.stateChanging
                    label: modelData.name
                    detail: menuRoot.networkDetail(modelData)
                    hoverColor: menuRoot.hoverColor
                    textColor: menuRoot.textColor
                    mutedTextColor: menuRoot.mutedTextColor
                    markColor: menuRoot.separatorColor
                    fontFamily: menuRoot.fontFamily
                    onActivated: menuRoot.activateNetwork(modelData)
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                verticalAlignment: Text.AlignVCenter
                visible: menuRoot.wifiNetworks.length === 0
                text: Networking.wifiEnabled ? "Сетей не найдено" : "Wi-Fi выключен"
                color: menuRoot.mutedTextColor
                font.family: menuRoot.fontFamily
                font.pixelSize: 12
                renderType: Text.NativeRendering
            }

            Rectangle {
                id: pskFrame

                Layout.fillWidth: true
                Layout.topMargin: 5
                Layout.preferredHeight: 26
                visible: menuRoot.pskActive
                color: "transparent"
                border.width: 1
                border.color: menuRoot.borderColor
                radius: 3

                TextInput {
                    id: pskField

                    anchors.fill: parent
                    anchors.leftMargin: 7
                    anchors.rightMargin: 7
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    color: menuRoot.textColor
                    selectionColor: menuRoot.hoverColor
                    selectedTextColor: menuRoot.textColor
                    font.family: menuRoot.fontFamily
                    font.pixelSize: 12
                    clip: true
                    renderType: Text.NativeRendering

                    Keys.onReturnPressed: menuRoot.submitPsk(text)
                    Keys.onEnterPressed: menuRoot.submitPsk(text)
                    Keys.onEscapePressed: menuRoot.cancelPsk()

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        visible: pskField.text.length === 0
                        text: menuRoot.pskTarget
                            ? "Пароль для " + menuRoot.pskTarget.name
                            : ""
                        color: menuRoot.mutedTextColor
                        font.family: menuRoot.fontFamily
                        font.pixelSize: 12
                        renderType: Text.NativeRendering
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 4
                visible: menuRoot.pskError.length > 0
                text: menuRoot.pskError
                color: menuRoot.errorColor
                font.family: menuRoot.fontFamily
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                renderType: Text.NativeRendering
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 5
                Layout.bottomMargin: 5
                implicitHeight: 1
                color: menuRoot.separatorColor
            }

            DeviceRow {
                showMark: false
                label: "Настройки сети…"
                labelColor: menuRoot.textColor
                hoverColor: menuRoot.hoverColor
                textColor: menuRoot.textColor
                mutedTextColor: menuRoot.mutedTextColor
                markColor: menuRoot.separatorColor
                fontFamily: menuRoot.fontFamily
                onActivated: {
                    Quickshell.execDetached(["kitty", "nmtui"])
                    menuRoot.closeRequested()
                }
            }
        }
    }
}
