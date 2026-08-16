import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    property bool lightTheme: false
    property int cpuUsage: 0
    property int memoryUsage: 0
    property real loadOne: 0
    property real loadFive: 0
    property real loadFifteen: 0
    property int memoryUsedKiB: 0
    property int memoryTotalKiB: 0
    property string audioOutputType: "speaker"

    function updateTheme(value) {
        const setting = String(value).trim()
        if (setting.length === 0)
            return
        lightTheme = setting.indexOf("prefer-dark") === -1
    }

    function updateAudioOutputType(value) {
        const kind = String(value).trim()
        if (kind.length > 0)
            audioOutputType = kind
    }

    function updateSystemStats(value) {
        const fields = String(value).trim().split(/\s+/)
        if (fields.length < 7)
            return

        const cpu = parseInt(fields[0])
        const memory = parseInt(fields[1])
        if (!isNaN(cpu))
            cpuUsage = Math.max(0, Math.min(100, cpu))
        if (!isNaN(memory))
            memoryUsage = Math.max(0, Math.min(100, memory))

        loadOne = parseFloat(fields[2]) || 0
        loadFive = parseFloat(fields[3]) || 0
        loadFifteen = parseFloat(fields[4]) || 0
        memoryUsedKiB = parseInt(fields[5]) || 0
        memoryTotalKiB = parseInt(fields[6]) || 0
    }

    Process {
        command: ["gsettings", "get", "org.gnome.desktop.interface", "color-scheme"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.updateTheme(text)
        }
    }

    Process {
        command: ["gsettings", "monitor", "org.gnome.desktop.interface", "color-scheme"]
        running: true
        stdout: SplitParser {
            onRead: data => root.updateTheme(data)
        }
    }

    Process {
        command: ["/home/yerza/.config/quickshell/status_bars/scripts/system-stats.sh"]
        running: true
        stdout: SplitParser {
            onRead: data => root.updateSystemStats(data)
        }
    }

    Process {
        command: ["/home/yerza/.config/quickshell/status_bars/scripts/audio-output.sh"]
        running: true
        stdout: SplitParser {
            onRead: data => root.updateAudioOutputType(data)
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: Bar {
            required property var modelData
            targetScreen: modelData
            lightTheme: root.lightTheme
            cpuUsage: root.cpuUsage
            memoryUsage: root.memoryUsage
            loadOne: root.loadOne
            loadFive: root.loadFive
            loadFifteen: root.loadFifteen
            memoryUsedKiB: root.memoryUsedKiB
            memoryTotalKiB: root.memoryTotalKiB
            audioOutputType: root.audioOutputType
        }
    }
}
