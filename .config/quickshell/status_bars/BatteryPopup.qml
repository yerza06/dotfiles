import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Окно батареи по ПКМ на BatteryItem: крупный глиф с процентом, полоса заряда,
// остаток времени, ёмкость с износом, переключатель профиля питания и текущее
// потребление в ваттах.
// Как календарь и окно плеера, окно «липкое»: grabFocus отдаёт ему клавиатуру и
// заставляет композитор закрыть его по клику мимо, поэтому таймера автозакрытия
// по уходу курсора здесь нет — в отличие от меню панели.
PopupWindow {
    id: popupRoot

    property var device: null
    // Настоящая батарея, а не агрегат UPower: только у неё есть Capacity и
    // NativePath, нужные для здоровья и числа циклов.
    property var hardwareDevice: null
    // Процент, глиф и цвет уровня считает BatteryItem — окно и пилюля в панели
    // должны показывать ровно одно и то же.
    property int percent: 0
    property bool charging: false
    property string icon: ""
    property color levelColor: textColor
    property color backgroundColor: "#100f0f"
    property color hoverColor: "#282726"
    property color textColor: "#cecdc3"
    property color mutedTextColor: "#878580"
    property color borderColor: "#575653"
    property color separatorColor: "#403e3c"
    property color trackColor: "#282726"
    property color disabledColor: "#403e3c"
    property color greenColor: "#879a39"
    property color orangeColor: "#da702c"
    property color redColor: "#d14d41"
    property string fontFamily: "IosevkaTerm Nerd Font Propo"

    signal closeRequested()

    // Quickshell 0.3.1 не пробрасывает ChargeCycles из UPower, поэтому число
    // циклов читается из sysfs. -1 — ещё не прочитано или файла нет.
    property int cycleCount: -1

    readonly property real changeRate: device ? device.changeRate : 0
    readonly property real energyNow: device ? device.energy : 0
    readonly property real energyFull: device ? device.energyCapacity : 0
    readonly property bool healthKnown: hardwareDevice !== null
        && hardwareDevice.healthSupported
    readonly property real health: healthKnown ? hardwareDevice.healthPercentage : 0
    readonly property real secondsLeft: {
        if (!device)
            return 0
        return charging ? device.timeToFull : device.timeToEmpty
    }

    function stateLabel() {
        if (!device)
            return "Нет данных"
        switch (device.state) {
        case UPowerDeviceState.Charging:
            return "Зарядка"
        case UPowerDeviceState.Discharging:
            return "Разряжается"
        case UPowerDeviceState.FullyCharged:
            return "Заряжена"
        case UPowerDeviceState.Empty:
            return "Разряжена"
        case UPowerDeviceState.PendingCharge:
            return "Ожидание зарядки"
        case UPowerDeviceState.PendingDischarge:
            return "Ожидание разрядки"
        default:
            return "Неизвестно"
        }
    }

    function formatDuration(seconds) {
        const total = Math.max(0, Math.floor(seconds))
        if (total <= 0)
            return ""
        const hours = Math.floor(total / 3600)
        const minutes = Math.floor((total % 3600) / 60)
        if (hours > 0)
            return hours + " ч " + minutes + " мин"
        return Math.max(1, minutes) + " мин"
    }

    function formatEnergy(value) {
        return value > 0 ? value.toFixed(1) + " Вт·ч" : "—"
    }

    // Команда назначается в функции, а не биндингом: биндинг и running
    // срабатывают в непредсказуемом порядке, и процесс успевает стартовать
    // со старым путём — та же причина, что у ipProcess в NetworkItem.
    function readCycleCount() {
        if (!hardwareDevice || !hardwareDevice.nativePath) {
            cycleCount = -1
            return
        }
        cycleProcess.running = false
        cycleProcess.command = ["cat",
            "/sys/class/power_supply/" + hardwareDevice.nativePath + "/cycle_count"]
        cycleProcess.running = true
    }

    function applyProfile(profile) {
        if (profile === PowerProfile.Performance && !PowerProfiles.hasPerformanceProfile)
            return
        PowerProfiles.profile = profile
    }

    function handleKey(event) {
        switch (event.key) {
        case Qt.Key_Escape:
            popupRoot.closeRequested()
            break
        case Qt.Key_1:
            popupRoot.applyProfile(PowerProfile.PowerSaver)
            break
        case Qt.Key_2:
            popupRoot.applyProfile(PowerProfile.Balanced)
            break
        case Qt.Key_3:
            popupRoot.applyProfile(PowerProfile.Performance)
            break
        default:
            return
        }

        event.accepted = true
    }

    implicitWidth: frame.implicitWidth
    implicitHeight: frame.implicitHeight
    color: "transparent"
    grabFocus: true

    onVisibleChanged: {
        if (visible) {
            frame.forceActiveFocus()
            readCycleCount()
        }
    }

    // Устройства UPower приходят по D-Bus асинхронно и могут появиться уже
    // после того, как окно открыли.
    onHardwareDeviceChanged: {
        if (visible)
            readCycleCount()
    }

    Process {
        id: cycleProcess

        stdout: StdioCollector {
            onStreamFinished: {
                const value = parseInt(text.trim())
                popupRoot.cycleCount = isNaN(value) ? -1 : value
            }
        }
    }

    Rectangle {
        id: frame

        anchors.fill: parent
        // Ширина фиксированная: иначе окно прыгало бы при каждом изменении
        // остатка времени и потребления.
        implicitWidth: 320
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
                    color: popupRoot.levelColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 30
                    renderType: Text.NativeRendering

                    Behavior on color {
                        ColorAnimation { duration: 100 }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "Батарея"
                        color: popupRoot.textColor
                        font.family: popupRoot.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        renderType: Text.NativeRendering
                    }

                    Text {
                        Layout.fillWidth: true
                        text: popupRoot.stateLabel()
                        color: popupRoot.mutedTextColor
                        font.family: popupRoot.fontFamily
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }
                }

                Text {
                    text: popupRoot.percent + "%"
                    color: popupRoot.levelColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 22
                    font.weight: Font.Bold
                    renderType: Text.NativeRendering

                    Behavior on color {
                        ColorAnimation { duration: 100 }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 8
                radius: 4
                color: popupRoot.trackColor

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.max(0, Math.min(parent.width,
                        parent.width * popupRoot.percent / 100))
                    radius: 4
                    color: popupRoot.levelColor

                    // Полоса ползёт плавно: заряд меняется скачками по проценту,
                    // и без анимации бар дёргается.
                    Behavior on width {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }

                    Behavior on color {
                        ColorAnimation { duration: 100 }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: popupRoot.formatDuration(popupRoot.secondsLeft).length > 0
                spacing: 0

                Text {
                    text: popupRoot.charging ? "До полной зарядки" : "Осталось"
                    color: popupRoot.mutedTextColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: popupRoot.formatDuration(popupRoot.secondsLeft)
                    color: popupRoot.textColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    renderType: Text.NativeRendering
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 4
                columnSpacing: 14
                rowSpacing: 4

                Text {
                    text: "Заряд"
                    color: popupRoot.mutedTextColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: popupRoot.formatEnergy(popupRoot.energyNow)
                    color: popupRoot.textColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }

                Text {
                    text: "Ёмкость"
                    color: popupRoot.mutedTextColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: popupRoot.formatEnergy(popupRoot.energyFull)
                    color: popupRoot.textColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }

                Text {
                    text: "Здоровье"
                    color: popupRoot.mutedTextColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: popupRoot.healthKnown
                        ? Math.round(popupRoot.health) + "%" : "—"
                    color: popupRoot.textColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }

                Text {
                    text: "Циклы"
                    color: popupRoot.mutedTextColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: popupRoot.cycleCount >= 0 ? popupRoot.cycleCount + "" : "—"
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
                spacing: 6

                Text {
                    text: "ПРОФИЛЬ ПИТАНИЯ"
                    color: popupRoot.mutedTextColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 10
                    font.letterSpacing: 1
                    renderType: Text.NativeRendering
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    BatteryProfileButton {
                        glyph: ""
                        label: "Эконом"
                        active: PowerProfiles.profile === PowerProfile.PowerSaver
                        backgroundColor: popupRoot.backgroundColor
                        hoverColor: popupRoot.hoverColor
                        textColor: popupRoot.textColor
                        mutedTextColor: popupRoot.mutedTextColor
                        disabledColor: popupRoot.disabledColor
                        accentColor: popupRoot.greenColor
                        fontFamily: popupRoot.fontFamily
                        onActivated: popupRoot.applyProfile(PowerProfile.PowerSaver)
                    }

                    BatteryProfileButton {
                        glyph: ""
                        label: "Баланс"
                        active: PowerProfiles.profile === PowerProfile.Balanced
                        backgroundColor: popupRoot.backgroundColor
                        hoverColor: popupRoot.hoverColor
                        textColor: popupRoot.textColor
                        mutedTextColor: popupRoot.mutedTextColor
                        disabledColor: popupRoot.disabledColor
                        accentColor: popupRoot.textColor
                        fontFamily: popupRoot.fontFamily
                        onActivated: popupRoot.applyProfile(PowerProfile.Balanced)
                    }

                    BatteryProfileButton {
                        glyph: ""
                        label: "Мощность"
                        active: PowerProfiles.profile === PowerProfile.Performance
                        available: PowerProfiles.hasPerformanceProfile
                        backgroundColor: popupRoot.backgroundColor
                        hoverColor: popupRoot.hoverColor
                        textColor: popupRoot.textColor
                        mutedTextColor: popupRoot.mutedTextColor
                        disabledColor: popupRoot.disabledColor
                        accentColor: popupRoot.redColor
                        fontFamily: popupRoot.fontFamily
                        onActivated: popupRoot.applyProfile(PowerProfile.Performance)
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: popupRoot.separatorColor
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: ""
                    color: popupRoot.mutedTextColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 12
                    renderType: Text.NativeRendering
                }

                Text {
                    text: popupRoot.charging ? "Зарядка" : "Потребление"
                    color: popupRoot.mutedTextColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: popupRoot.changeRate > 0
                        ? popupRoot.changeRate.toFixed(1) + " Вт" : "—"
                    color: popupRoot.changeRate > 0
                        ? (popupRoot.charging ? popupRoot.greenColor : popupRoot.orangeColor)
                        : popupRoot.mutedTextColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    renderType: Text.NativeRendering
                }
            }
        }
    }
}
