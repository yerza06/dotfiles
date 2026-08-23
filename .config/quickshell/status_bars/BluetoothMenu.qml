import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth

// Меню Bluetooth в стиле Flexoki: тумблер адаптера и список известных устройств.
PopupWindow {
    id: menuRoot

    property color backgroundColor: "#100f0f"
    property color hoverColor: "#282726"
    property color textColor: "#cecdc3"
    property color mutedTextColor: "#878580"
    property color borderColor: "#575653"
    property color separatorColor: "#403e3c"
    property string fontFamily: "IosevkaTerm Nerd Font Propo"

    signal closeRequested()

    readonly property bool chainHovered: frameHover.hovered

    readonly property var adapter: Bluetooth.defaultAdapter

    // Сопряжённые устройства, подключённые сверху. Обнаружение новых — в bluetui.
    readonly property var knownDevices: {
        if (!adapter || !adapter.devices)
            return []
        const result = []
        const all = adapter.devices.values
        for (let i = 0; i < all.length; i++) {
            const device = all[i]
            if (device.connected || device.paired || device.bonded)
                result.push(device)
        }
        result.sort((left, right) => {
            if (left.connected !== right.connected)
                return left.connected ? -1 : 1
            return 0
        })
        return result
    }

    function deviceLabel(device) {
        if (!device)
            return ""
        return device.deviceName || device.name || device.address || ""
    }

    function deviceDetail(device) {
        if (!device || !device.batteryAvailable)
            return ""
        const value = device.battery
        return Math.round(value > 1 ? value : value * 100) + "%"
    }

    function deviceBusy(device) {
        if (!device)
            return false
        return device.state === BluetoothDeviceState.Connecting
            || device.state === BluetoothDeviceState.Disconnecting
    }

    // Меню не закрываем: подключение асинхронное, пользователь видит индикатор.
    function toggleDevice(device) {
        if (!device)
            return
        if (device.connected)
            device.disconnect()
        else
            device.connect()
    }

    implicitWidth: frame.implicitWidth
    implicitHeight: frame.implicitHeight
    color: "transparent"
    grabFocus: false

    Rectangle {
        id: frame

        anchors.fill: parent
        implicitWidth: Math.max(240, Math.min(400, content.implicitWidth + 24))
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
                text: "Bluetooth"
                color: menuRoot.mutedTextColor
                font.family: menuRoot.fontFamily
                font.pixelSize: 11
                font.weight: Font.Medium
                renderType: Text.NativeRendering
            }

            DeviceRow {
                visible: menuRoot.adapter !== null
                current: menuRoot.adapter && menuRoot.adapter.enabled
                label: "Адаптер"
                detail: menuRoot.adapter && menuRoot.adapter.enabled ? "вкл" : "выкл"
                hoverColor: menuRoot.hoverColor
                textColor: menuRoot.textColor
                mutedTextColor: menuRoot.mutedTextColor
                markColor: menuRoot.separatorColor
                fontFamily: menuRoot.fontFamily
                onActivated: {
                    if (menuRoot.adapter)
                        menuRoot.adapter.enabled = !menuRoot.adapter.enabled
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 5
                Layout.bottomMargin: 5
                implicitHeight: 1
                color: menuRoot.separatorColor
            }

            Repeater {
                model: menuRoot.knownDevices

                delegate: DeviceRow {
                    required property var modelData

                    current: modelData.connected
                    busy: menuRoot.deviceBusy(modelData)
                    label: menuRoot.deviceLabel(modelData)
                    detail: menuRoot.deviceDetail(modelData)
                    hoverColor: menuRoot.hoverColor
                    textColor: menuRoot.textColor
                    mutedTextColor: menuRoot.mutedTextColor
                    markColor: menuRoot.separatorColor
                    fontFamily: menuRoot.fontFamily
                    onActivated: menuRoot.toggleDevice(modelData)
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                verticalAlignment: Text.AlignVCenter
                visible: menuRoot.knownDevices.length === 0
                text: menuRoot.adapter && menuRoot.adapter.enabled
                    ? "Устройств не найдено"
                    : "Bluetooth выключен"
                color: menuRoot.mutedTextColor
                font.family: menuRoot.fontFamily
                font.pixelSize: 12
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
                label: "Настройки Bluetooth…"
                labelColor: menuRoot.textColor
                hoverColor: menuRoot.hoverColor
                textColor: menuRoot.textColor
                mutedTextColor: menuRoot.mutedTextColor
                markColor: menuRoot.separatorColor
                fontFamily: menuRoot.fontFamily
                onActivated: {
                    Quickshell.execDetached(["kitty", "bluetui"])
                    menuRoot.closeRequested()
                }
            }
        }
    }
}
