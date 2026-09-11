import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    property bool lightTheme: false
    property string audioOutputType: "speaker"
    // dbusName закреплённого MPRIS-плеера; пустая строка — автовыбор.
    // Живёт здесь, а не в Bar, чтобы выбор был общим для всех мониторов.
    property string pinnedMprisPlayerId: ""

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
            audioOutputType: root.audioOutputType
            pinnedMprisPlayerId: root.pinnedMprisPlayerId
            onPinPlayerRequested: playerId => root.pinnedMprisPlayerId = playerId
        }
    }
}
