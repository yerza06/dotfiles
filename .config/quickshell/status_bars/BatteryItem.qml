import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Батарея в панели: пилюля с процентом и глифом, мигающая при низком заряде,
// и окно с подробностями по ПКМ.
StatusItem {
    id: root

    property color baseBackground: "#100f0f"
    property color baseHoverBackground: "#1c1b1a"
    property color textColor: "#cecdc3"
    property color mutedTextColor: "#878580"
    property color popupHoverColor: "#282726"
    property color popupBorderColor: "#575653"
    property color popupSeparatorColor: "#403e3c"
    property color popupTrackColor: "#282726"
    property color greenColor: "#879a39"
    property color orangeColor: "#da702c"
    property color redColor: "#d14d41"

    readonly property var device: UPower.displayDevice
    readonly property bool ready: device && device.ready

    // displayDevice — синтетический агрегат: Capacity и NativePath у него
    // пустые, поэтому здоровье и число циклов берутся у настоящей батареи.
    readonly property var hardwareDevice: {
        const devices = UPower.devices ? UPower.devices.values : []
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].isLaptopBattery)
                return devices[i]
        }
        return null
    }

    readonly property bool popupVisible: popup.visible

    // Момент последнего закрытия окна. Клик мимо, которым композитор снимает
    // захват, долетает и до самого виджета — без этой отсечки окно тут же
    // открылось бы снова.
    property double popupClosedAt: 0

    readonly property bool warning: ready && !batteryCharging()
        && batteryPercent() > 15
        && batteryPercent() <= 30
    readonly property bool critical: ready && !batteryCharging()
        && batteryPercent() >= 0
        && batteryPercent() <= 15
    readonly property bool alertActive: warning || critical
    readonly property color alertColor: critical ? redColor : orangeColor
    property bool alertInverted: false

    function batteryPercent() {
        const battery = UPower.displayDevice
        if (!battery || !battery.ready)
            return 0
        return Math.round(battery.percentage <= 1 ? battery.percentage * 100 : battery.percentage)
    }

    function batteryCharging() {
        const battery = UPower.displayDevice
        return battery && battery.iconName.indexOf("charging") !== -1
    }

    function batteryIcon() {
        if (batteryCharging())
            return "󰂄"
        const value = batteryPercent()
        if (value >= 90) return "󰁹"
        if (value >= 80) return "󰂂"
        if (value >= 70) return "󰂁"
        if (value >= 60) return "󰂀"
        if (value >= 50) return "󰁿"
        if (value >= 40) return "󰁾"
        if (value >= 30) return "󰁽"
        if (value >= 20) return "󰁼"
        if (value >= 10) return "󰁻"
        return "󰂎"
    }

    function profileGlyph() {
        switch (PowerProfiles.profile) {
        case PowerProfile.Performance:
            return ""
        case PowerProfile.PowerSaver:
            return ""
        default:
            return ""
        }
    }

    function profileLabel() {
        switch (PowerProfiles.profile) {
        case PowerProfile.Performance:
            return "Мощность"
        case PowerProfile.PowerSaver:
            return "Эконом"
        default:
            return "Баланс"
        }
    }

    // Демон сам роняет производительность при перегреве и «ноутбуке на
    // коленях»: без подсказки об этом узнать неоткуда.
    function degradationLabel() {
        switch (PowerProfiles.degradationReason) {
        case PerformanceDegradationReason.LapDetected:
            return "Снижен: ноутбук на коленях"
        case PerformanceDegradationReason.HighTemperature:
            return "Снижен: перегрев"
        default:
            return ""
        }
    }

    function batteryColor() {
        if (batteryCharging())
            return greenColor
        const value = batteryPercent()
        return value <= 15 ? redColor : (value <= 30 ? orangeColor : textColor)
    }

    // Порядок совпадает с кнопками в окне: Эконом → Баланс → Мощность.
    function cycleProfile() {
        if (PowerProfiles.profile === PowerProfile.PowerSaver)
            PowerProfiles.profile = PowerProfile.Balanced
        else if (PowerProfiles.profile === PowerProfile.Balanced)
            PowerProfiles.profile = PowerProfiles.hasPerformanceProfile
                ? PowerProfile.Performance
                : PowerProfile.PowerSaver
        else
            PowerProfiles.profile = PowerProfile.PowerSaver
    }

    function togglePopup() {
        if (!popup.visible && Date.now() - popupClosedAt < 200)
            return
        popup.visible = !popup.visible
    }

    text: batteryPercent() + "% " + batteryIcon()
    foreground: alertActive ? (alertInverted ? alertColor : baseBackground)
        : (batteryCharging() ? baseBackground : batteryColor())
    background: batteryCharging() ? greenColor
        : (alertActive ? (alertInverted ? baseBackground : alertColor) : baseBackground)
    // Пилюля стала кликабельной, поэтому наведение подсвечивается — но только
    // когда цвет не занят зарядкой или миганием.
    hoverBackground: (batteryCharging() || alertActive) ? background : baseHoverBackground
    horizontalPadding: 6
    tooltipTitle: profileGlyph() + "  Профиль: " + profileLabel()
    // Пока окно открыто, подсказка не нужна — она бы легла поверх него.
    tooltipText: {
        if (popupVisible)
            return ""
        const degraded = degradationLabel()
        const hint = "ЛКМ — сменить профиль\nПКМ — подробности"
        return degraded.length > 0 ? degraded + "\n" + hint : hint
    }

    onAlertActiveChanged: {
        if (!alertActive)
            alertInverted = false
    }

    // Батарею выдернули, пока окно открыто: данных больше нет, окно закрываем.
    onReadyChanged: {
        if (!ready)
            popup.visible = false
    }

    onPressed: button => {
        if (button === Qt.LeftButton)
            root.cycleProfile()
        else if (button === Qt.RightButton)
            root.togglePopup()
    }

    Timer {
        interval: root.critical ? 380 : 500
        repeat: true
        running: root.alertActive
        onTriggered: root.alertInverted = !root.alertInverted
    }

    BatteryPopup {
        id: popup

        // visible выставляется только вручную: композитор закрывает окно сам,
        // и биндинг после первого такого закрытия сломался бы.
        visible: false
        anchor.item: root
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.bottom: 4
        device: root.device
        hardwareDevice: root.hardwareDevice
        percent: root.batteryPercent()
        charging: root.batteryCharging()
        icon: root.batteryIcon()
        levelColor: root.batteryColor()
        backgroundColor: root.baseBackground
        hoverColor: root.popupHoverColor
        textColor: root.textColor
        mutedTextColor: root.mutedTextColor
        borderColor: root.popupBorderColor
        separatorColor: root.popupSeparatorColor
        trackColor: root.popupTrackColor
        disabledColor: root.popupSeparatorColor
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
}
