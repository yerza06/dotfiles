import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Окно мониторинга по ПКМ на SystemMonitorItem: загрузка CPU, памяти, диска и
// видеокарт с полосами, скорость сети и load average.
// Данные собирает scripts/system-monitor.sh, и работает он, только пока окно
// открыто: в самой пилюле цифр нет, опрашивать систему в фоне незачем.
// Как окна сети и батареи, окно «липкое»: grabFocus отдаёт ему клавиатуру и
// заставляет композитор закрыть его по клику мимо.
PopupWindow {
    id: popupRoot

    property string icon: ""
    property color backgroundColor: "#100f0f"
    property color hoverColor: "#282726"
    property color textColor: "#cecdc3"
    property color mutedTextColor: "#878580"
    property color borderColor: "#575653"
    property color separatorColor: "#403e3c"
    property color trackColor: "#282726"
    property color accentColor: "#4385be"
    property color orangeColor: "#da702c"
    property color redColor: "#d14d41"
    property string fontFamily: "IosevkaTerm Nerd Font Propo"

    signal closeRequested()

    // Последняя строка скрипта; null — после открытия данных ещё нет.
    property var stats: null

    readonly property var gpus: stats && stats.gpus ? stats.gpus : []

    function applyStats(rawText) {
        try {
            stats = JSON.parse(rawText)
        } catch (error) {
            return
        }
    }

    function percentOf(used, total) {
        return total > 0 ? Math.round(100 * used / total) : -1
    }

    // Пара «занято/всего» с общей единицей; от 100 ГБ десятые — уже шум.
    function formatPair(usedBytes, totalBytes) {
        const gib = 1024 * 1024 * 1024
        const digits = totalBytes >= 100 * gib ? 0 : 1
        return (usedBytes / gib).toFixed(digits) + "/"
            + (totalBytes / gib).toFixed(digits) + " ГБ"
    }

    function joinValue(percent, extra) {
        if (percent < 0)
            return "—"
        return extra.length > 0 ? percent + "% | " + extra : percent + "%"
    }

    function cpuValue() {
        if (!stats)
            return "—"
        return joinValue(stats.cpu, stats.cpuTemp >= 0 ? stats.cpuTemp + "°C" : "")
    }

    function memPercent() {
        return stats ? percentOf(stats.memUsed, stats.memTotal) : -1
    }

    function memValue() {
        if (!stats)
            return "—"
        return joinValue(memPercent(),
            formatPair(stats.memUsed * 1024, stats.memTotal * 1024))
    }

    // Процент считается как у df — от места, доступного пользователю: в размер
    // раздела входит ещё и резерв файловой системы.
    function diskPercent() {
        return stats ? percentOf(stats.diskUsed, stats.diskUsed + stats.diskAvail) : -1
    }

    function diskValue() {
        if (!stats)
            return "—"
        return joinValue(diskPercent(), formatPair(stats.diskUsed, stats.diskSize))
    }

    function gpuPercent(gpu) {
        return gpu && gpu.state === "active" ? gpu.busy : -1
    }

    // У NVIDIA есть температура, у встроенной Intel — только частота.
    function gpuValue(gpu) {
        if (!gpu)
            return "—"
        if (gpu.state === "sleep")
            return "сон"
        let extra = ""
        if (gpu.temp >= 0)
            extra = gpu.temp + "°C"
        else if (gpu.freq > 0)
            extra = gpu.freq + " МГц"
        return joinValue(gpu.busy, extra)
    }

    function gpuDetail(gpu) {
        if (!gpu)
            return ""
        if (gpu.memTotal > 0)
            return gpu.name + " · " + gpu.memUsed + "/" + gpu.memTotal + " МБ"
        return gpu.name
    }

    function netValue() {
        if (!stats)
            return "—"
        return NetworkFormat.formatRate(stats.rx) + " ↓ | ↑ "
            + NetworkFormat.formatRate(stats.tx)
    }

    function loadLabel() {
        if (!stats || !stats.load)
            return "Сбор данных…"
        return "Load average " + stats.load.map(value => value.toFixed(2)).join(" · ")
    }

    function handleKey(event) {
        if (event.key !== Qt.Key_Escape)
            return
        closeRequested()
        event.accepted = true
    }

    implicitWidth: frame.implicitWidth
    implicitHeight: frame.implicitHeight
    color: "transparent"
    grabFocus: true

    // Прошлые цифры при повторном открытии были бы враньём, поэтому до первой
    // строки нового замера везде прочерки.
    onVisibleChanged: {
        if (visible) {
            stats = null
            frame.forceActiveFocus()
        }
    }

    Process {
        command: ["/home/yerza/.config/quickshell/status_bars/scripts/system-monitor.sh"]
        running: popupRoot.visible
        stdout: SplitParser {
            onRead: data => popupRoot.applyStats(data)
        }
    }

    Rectangle {
        id: frame

        anchors.fill: parent
        // Ширина фиксированная: иначе окно прыгало бы при каждом обновлении
        // цифр.
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
                    color: popupRoot.textColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 26
                    renderType: Text.NativeRendering
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "Система"
                        color: popupRoot.textColor
                        font.family: popupRoot.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        renderType: Text.NativeRendering
                    }

                    Text {
                        Layout.fillWidth: true
                        text: popupRoot.loadLabel()
                        color: popupRoot.mutedTextColor
                        font.family: popupRoot.fontFamily
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }
                }
            }

            SystemMetricRow {
                glyph: ""
                label: "CPU"
                value: popupRoot.cpuValue()
                percent: popupRoot.stats ? popupRoot.stats.cpu : -1
                textColor: popupRoot.textColor
                mutedTextColor: popupRoot.mutedTextColor
                trackColor: popupRoot.trackColor
                accentColor: popupRoot.accentColor
                orangeColor: popupRoot.orangeColor
                redColor: popupRoot.redColor
                fontFamily: popupRoot.fontFamily
            }

            SystemMetricRow {
                glyph: ""
                label: "RAM"
                value: popupRoot.memValue()
                percent: popupRoot.memPercent()
                textColor: popupRoot.textColor
                mutedTextColor: popupRoot.mutedTextColor
                trackColor: popupRoot.trackColor
                accentColor: popupRoot.accentColor
                orangeColor: popupRoot.orangeColor
                redColor: popupRoot.redColor
                fontFamily: popupRoot.fontFamily
            }

            SystemMetricRow {
                glyph: "󰋊"
                label: "DISK"
                value: popupRoot.diskValue()
                percent: popupRoot.diskPercent()
                textColor: popupRoot.textColor
                mutedTextColor: popupRoot.mutedTextColor
                trackColor: popupRoot.trackColor
                accentColor: popupRoot.accentColor
                orangeColor: popupRoot.orangeColor
                redColor: popupRoot.redColor
                fontFamily: popupRoot.fontFamily
            }

            // Строки видеокарт видны и до первого замера, чтобы окно не
            // вырастало через долю секунды после открытия.
            SystemMetricRow {
                visible: !popupRoot.stats || popupRoot.gpus.length > 0
                glyph: "󰢮"
                label: "GPU1"
                value: popupRoot.gpuValue(popupRoot.gpus[0])
                detail: popupRoot.gpuDetail(popupRoot.gpus[0])
                percent: popupRoot.gpuPercent(popupRoot.gpus[0])
                textColor: popupRoot.textColor
                mutedTextColor: popupRoot.mutedTextColor
                trackColor: popupRoot.trackColor
                accentColor: popupRoot.accentColor
                orangeColor: popupRoot.orangeColor
                redColor: popupRoot.redColor
                fontFamily: popupRoot.fontFamily
            }

            SystemMetricRow {
                visible: !popupRoot.stats || popupRoot.gpus.length > 1
                glyph: "󰢮"
                label: "GPU2"
                value: popupRoot.gpuValue(popupRoot.gpus[1])
                detail: popupRoot.gpuDetail(popupRoot.gpus[1])
                percent: popupRoot.gpuPercent(popupRoot.gpus[1])
                textColor: popupRoot.textColor
                mutedTextColor: popupRoot.mutedTextColor
                trackColor: popupRoot.trackColor
                accentColor: popupRoot.accentColor
                orangeColor: popupRoot.orangeColor
                redColor: popupRoot.redColor
                fontFamily: popupRoot.fontFamily
            }

            SystemMetricRow {
                glyph: "󰓢"
                label: "NET"
                value: popupRoot.netValue()
                showBar: false
                textColor: popupRoot.textColor
                mutedTextColor: popupRoot.mutedTextColor
                fontFamily: popupRoot.fontFamily
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: popupRoot.separatorColor
            }

            DeviceRow {
                showMark: false
                label: "btop…"
                labelColor: popupRoot.textColor
                hoverColor: popupRoot.hoverColor
                textColor: popupRoot.textColor
                mutedTextColor: popupRoot.mutedTextColor
                markColor: popupRoot.separatorColor
                fontFamily: popupRoot.fontFamily
                onActivated: {
                    Quickshell.execDetached(["kitty", "--start-as=fullscreen", "btop"])
                    popupRoot.closeRequested()
                }
            }
        }
    }
}
