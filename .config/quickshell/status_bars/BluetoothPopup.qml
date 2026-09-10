import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth

// Окно Bluetooth: адаптер с тумблером, видимость и сопряжаемость, списки
// подключённых и доступных устройств.
//
// Ведёт себя как календарь и окно сети, а не как меню по ПКМ: по уходу курсора
// не закрывается — только повторным ПКМ, кликом мимо (за это отвечает grabFocus)
// или Esc. Сканирование эфира не включаем: окно показывает только сопряжённые
// устройства, новые добавляются через bluetui.
PopupWindow {
    id: popupRoot

    property var adapter: null
    property string icon: ""
    property color iconColor: "#4385be"
    property color backgroundColor: "#100f0f"
    property color hoverColor: "#282726"
    property color textColor: "#cecdc3"
    property color mutedTextColor: "#878580"
    property color borderColor: "#575653"
    property color separatorColor: "#403e3c"
    property color trackColor: "#282726"
    property color accentColor: "#4385be"
    property color greenColor: "#879a39"
    property color orangeColor: "#da702c"
    property color redColor: "#d14d41"
    property string fontFamily: "IosevkaTerm Nerd Font Propo"

    // Раскрыт может быть только один блок настроек. Храним адрес, а не ссылку
    // на устройство: список пересоздаётся при каждом обновлении модели.
    property string expandedAddress: ""

    signal closeRequested()

    readonly property bool adapterEnabled: adapter !== null && adapter.enabled
    readonly property bool adapterBlocked: adapter !== null
        && adapter.state === BluetoothAdapterState.Blocked

    readonly property var pairedDevices: {
        if (!adapter || !adapter.devices)
            return []
        return BluetoothFormat.sortDevices(
            BluetoothFormat.filterPaired(adapter.devices.values))
    }
    readonly property var connectedDevices: pairedDevices.filter(device => device.connected)
    readonly property var availableDevices: pairedDevices.filter(device => !device.connected)

    readonly property string headerDetail: {
        const parts = [BluetoothFormat.adapterStateLabel(adapter)]
        if (adapter && adapter.adapterId)
            parts.push(adapter.adapterId)
        if (adapterEnabled && connectedDevices.length > 0)
            parts.push(connectedDevices.length + " подключено")
        return parts.join(" · ")
    }

    function toggleDevice(device) {
        if (!device)
            return
        // Окно не закрываем: так виден переход ◐ и результат подключения.
        if (device.connected)
            device.disconnect()
        else
            device.connect()
    }

    function toggleExpanded(device) {
        if (!device)
            return
        expandedAddress = expandedAddress === device.address ? "" : device.address
        if (expandedAddress.length === 0)
            frame.forceActiveFocus()
    }

    function collapse() {
        expandedAddress = ""
        frame.forceActiveFocus()
    }

    function applyRename(device, name) {
        const trimmed = String(name).trim()
        // Пустое имя не пишем: BlueZ вернул бы устройство к заводскому Name,
        // а пользователь этого не просил.
        if (device && trimmed.length > 0)
            device.name = trimmed
        collapse()
    }

    function handleKey(event) {
        if (event.key !== Qt.Key_Escape)
            return
        // Первый Esc сворачивает настройки устройства, второй закрывает окно.
        if (expandedAddress.length > 0)
            collapse()
        else
            closeRequested()
        event.accepted = true
    }

    implicitWidth: frame.implicitWidth
    implicitHeight: frame.implicitHeight
    color: "transparent"
    grabFocus: true

    onVisibleChanged: {
        if (visible)
            frame.forceActiveFocus()
        else
            expandedAddress = ""
    }

    Rectangle {
        id: frame

        anchors.fill: parent
        // Ширина фиксирована: иначе окно дёргалось бы при смене заряда
        // и появлении длинных имён.
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
                    color: popupRoot.adapterEnabled
                        ? popupRoot.iconColor
                        : popupRoot.mutedTextColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 26
                    renderType: Text.NativeRendering
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: popupRoot.adapter && popupRoot.adapter.name
                            ? popupRoot.adapter.name
                            : "Bluetooth"
                        color: popupRoot.textColor
                        font.family: popupRoot.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }

                    Text {
                        Layout.fillWidth: true
                        text: popupRoot.headerDetail
                        color: popupRoot.mutedTextColor
                        font.family: popupRoot.fontFamily
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }
                }

                ToggleSwitch {
                    visible: popupRoot.adapter !== null
                    checked: popupRoot.adapterEnabled
                    // Заблокированный rfkill адаптер гаснет и не нажимается.
                    available: popupRoot.adapter !== null && !popupRoot.adapterBlocked
                    accentColor: popupRoot.accentColor
                    trackColor: popupRoot.trackColor
                    knobColor: popupRoot.textColor
                    disabledColor: popupRoot.separatorColor
                    onToggled: popupRoot.adapter.enabled = !popupRoot.adapter.enabled
                }
            }

            // Видимость и сопряжаемость гаснут при выключенном адаптере:
            // BlueZ всё равно не даст их переключить.
            ColumnLayout {
                Layout.fillWidth: true
                visible: popupRoot.adapter !== null
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: "Видимость"
                        color: popupRoot.adapterEnabled
                            ? popupRoot.textColor
                            : popupRoot.mutedTextColor
                        font.family: popupRoot.fontFamily
                        font.pixelSize: 12
                        renderType: Text.NativeRendering
                    }

                    ToggleSwitch {
                        implicitWidth: 30
                        implicitHeight: 15
                        checked: popupRoot.adapter !== null && popupRoot.adapter.discoverable
                        available: popupRoot.adapterEnabled
                        accentColor: popupRoot.accentColor
                        trackColor: popupRoot.trackColor
                        knobColor: popupRoot.textColor
                        disabledColor: popupRoot.separatorColor
                        onToggled: popupRoot.adapter.discoverable = !popupRoot.adapter.discoverable
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: "Разрешить сопряжение"
                        color: popupRoot.adapterEnabled
                            ? popupRoot.textColor
                            : popupRoot.mutedTextColor
                        font.family: popupRoot.fontFamily
                        font.pixelSize: 12
                        renderType: Text.NativeRendering
                    }

                    ToggleSwitch {
                        implicitWidth: 30
                        implicitHeight: 15
                        checked: popupRoot.adapter !== null && popupRoot.adapter.pairable
                        available: popupRoot.adapterEnabled
                        accentColor: popupRoot.accentColor
                        trackColor: popupRoot.trackColor
                        knobColor: popupRoot.textColor
                        disabledColor: popupRoot.separatorColor
                        onToggled: popupRoot.adapter.pairable = !popupRoot.adapter.pairable
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: popupRoot.separatorColor
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: popupRoot.connectedDevices.length > 0
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 2
                    text: "ПОДКЛЮЧЕНО"
                    color: popupRoot.mutedTextColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 10
                    font.letterSpacing: 1
                    renderType: Text.NativeRendering
                }

                Repeater {
                    model: popupRoot.connectedDevices

                    delegate: BluetoothDeviceRow {
                        required property var modelData

                        glyph: BluetoothFormat.deviceGlyph(modelData)
                        label: BluetoothFormat.deviceLabel(modelData)
                        detail: BluetoothFormat.deviceDetail(modelData)
                        address: modelData.address
                        current: modelData.connected
                        busy: BluetoothFormat.deviceBusy(modelData)
                        expanded: popupRoot.expandedAddress === modelData.address
                        trusted: modelData.trusted
                        batteryAvailable: BluetoothFormat.hasBattery(modelData)
                        batteryPercent: BluetoothFormat.batteryPercent(modelData)
                        hoverColor: popupRoot.hoverColor
                        textColor: popupRoot.textColor
                        mutedTextColor: popupRoot.mutedTextColor
                        markColor: popupRoot.separatorColor
                        trackColor: popupRoot.trackColor
                        accentColor: popupRoot.accentColor
                        greenColor: popupRoot.greenColor
                        orangeColor: popupRoot.orangeColor
                        redColor: popupRoot.redColor
                        fontFamily: popupRoot.fontFamily
                        onActivated: popupRoot.toggleDevice(modelData)
                        onExpandToggled: popupRoot.toggleExpanded(modelData)
                        onTrustToggled: modelData.trusted = !modelData.trusted
                        onRenameRequested: name => popupRoot.applyRename(modelData, name)
                        onRenameCancelled: popupRoot.collapse()
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: popupRoot.availableDevices.length > 0
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 2
                    text: "ДОСТУПНО"
                    color: popupRoot.mutedTextColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 10
                    font.letterSpacing: 1
                    renderType: Text.NativeRendering
                }

                Repeater {
                    model: popupRoot.availableDevices

                    delegate: BluetoothDeviceRow {
                        required property var modelData

                        glyph: BluetoothFormat.deviceGlyph(modelData)
                        label: BluetoothFormat.deviceLabel(modelData)
                        detail: BluetoothFormat.deviceDetail(modelData)
                        address: modelData.address
                        current: modelData.connected
                        busy: BluetoothFormat.deviceBusy(modelData)
                        expanded: popupRoot.expandedAddress === modelData.address
                        trusted: modelData.trusted
                        batteryAvailable: BluetoothFormat.hasBattery(modelData)
                        batteryPercent: BluetoothFormat.batteryPercent(modelData)
                        hoverColor: popupRoot.hoverColor
                        textColor: popupRoot.textColor
                        mutedTextColor: popupRoot.mutedTextColor
                        markColor: popupRoot.separatorColor
                        trackColor: popupRoot.trackColor
                        accentColor: popupRoot.accentColor
                        greenColor: popupRoot.greenColor
                        orangeColor: popupRoot.orangeColor
                        redColor: popupRoot.redColor
                        fontFamily: popupRoot.fontFamily
                        onActivated: popupRoot.toggleDevice(modelData)
                        onExpandToggled: popupRoot.toggleExpanded(modelData)
                        onTrustToggled: modelData.trusted = !modelData.trusted
                        onRenameRequested: name => popupRoot.applyRename(modelData, name)
                        onRenameCancelled: popupRoot.collapse()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: popupRoot.adapter === null
                    || !popupRoot.adapterEnabled
                    || popupRoot.pairedDevices.length === 0
                text: {
                    if (!popupRoot.adapter)
                        return "Адаптер не найден"
                    if (popupRoot.adapterBlocked)
                        return "Bluetooth заблокирован — снимите блокировку rfkill"
                    if (!popupRoot.adapterEnabled)
                        return "Bluetooth выключен"
                    return "Нет сопряжённых устройств — добавьте их в bluetui"
                }
                color: popupRoot.mutedTextColor
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
                label: "Настройки Bluetooth…"
                labelColor: popupRoot.textColor
                hoverColor: popupRoot.hoverColor
                textColor: popupRoot.textColor
                mutedTextColor: popupRoot.mutedTextColor
                markColor: popupRoot.separatorColor
                fontFamily: popupRoot.fontFamily
                onActivated: {
                    Quickshell.execDetached(["kitty", "bluetui"])
                    popupRoot.closeRequested()
                }
            }
        }
    }
}
