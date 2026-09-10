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
    property color popupHoverColor: "#282726"
    property color popupBorderColor: "#575653"
    property color popupSeparatorColor: "#403e3c"
    property color popupTrackColor: "#282726"
    property color accentColor: "#4385be"
    property color greenColor: "#879a39"
    property color orangeColor: "#da702c"
    property color redColor: "#d14d41"
    property color tooltipBorderColor: "#575653"
    property string fontFamily: "IosevkaTerm Nerd Font Propo"

    readonly property bool popupVisible: popup.visible
    // Композитор закрывает окно сам по клику мимо, поэтому повторный ПКМ
    // сразу после этого должен открывать окно, а не считаться вторым нажатием.
    property real popupClosedAt: 0

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool adapterEnabled: adapter !== null && adapter.enabled
    readonly property var connectedDevices: adapter && adapter.devices
        ? adapter.devices.values.filter(device => device.connected)
        : []
    readonly property int connectedCount: connectedDevices.length

    // Глиф и цвет считаются здесь и передаются в окно — панель и окно
    // всегда показывают одно и то же.
    readonly property string glyph: adapterEnabled ? "" : "󰂲"

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
            const battery = BluetoothFormat.batteryText(device)
            lines.push(BluetoothFormat.deviceLabel(device)
                + (battery.length > 0 ? " — " + battery : ""))
        }
        return lines.join("\n")
    }

    // Адаптер может исчезнуть при открытом окне — показывать станет нечего.
    onAdapterChanged: {
        if (!adapter)
            popup.visible = false
    }

    function togglePopup() {
        if (!popup.visible && Date.now() - popupClosedAt < 200)
            return
        popup.visible = !popup.visible
    }

    implicitWidth: label.implicitWidth + 12
    implicitHeight: 28
    radius: 3
    color: buttonMouse.containsMouse ? hoverColor : backgroundColor

    Behavior on color {
        ColorAnimation { duration: 100 }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.glyph + (root.adapterEnabled && root.connectedCount > 0
            ? " " + root.connectedCount
            : "")
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

    BluetoothPopup {
        id: popup

        // visible выставляется только вручную: композитор закрывает окно сам,
        // и биндинг после первого такого закрытия сломался бы.
        visible: false
        anchor.item: root
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.bottom: 4
        adapter: root.adapter
        icon: root.glyph
        iconColor: root.activeColor
        backgroundColor: root.backgroundColor
        hoverColor: root.popupHoverColor
        textColor: root.textColor
        mutedTextColor: root.mutedTextColor
        borderColor: root.popupBorderColor
        separatorColor: root.popupSeparatorColor
        trackColor: root.popupTrackColor
        accentColor: root.accentColor
        greenColor: root.greenColor
        orangeColor: root.orangeColor
        redColor: root.redColor
        fontFamily: root.fontFamily
        onVisibleChanged: {
            if (!visible)
                root.popupClosedAt = Date.now()
        }
        onCloseRequested: popup.visible = false
    }

    Tooltip {
        visible: buttonMouse.containsMouse && !root.popupVisible
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
                root.togglePopup()
            else if (mouse.button === Qt.MiddleButton && root.adapter)
                root.adapter.enabled = !root.adapter.enabled
        }
    }
}
