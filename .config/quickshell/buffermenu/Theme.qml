pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Flexoki palette, identical to the one the status bar, the notification popups
// and the launcher use, so the clipboard menu reads as part of the same shell.
Singleton {
    id: root

    property bool light: false

    readonly property color bg: light ? "#fffcf0" : "#100f0f"
    readonly property color bg2: light ? "#f2f0e5" : "#1c1b1a"
    readonly property color ui: light ? "#e6e4d9" : "#282726"
    readonly property color ui2: light ? "#dad8ce" : "#343331"
    readonly property color ui3: light ? "#cecdc3" : "#403e3c"
    readonly property color tx: light ? "#100f0f" : "#cecdc3"
    readonly property color tx2: light ? "#6f6a69" : "#878580"
    readonly property color tx3: light ? "#b7b5ac" : "#575653"
    readonly property color red: light ? "#af3029" : "#d14d41"
    readonly property color orange: light ? "#bc5215" : "#da702c"
    readonly property color yellow: light ? "#ad8301" : "#d0a215"
    readonly property color green: light ? "#66800b" : "#879a39"
    readonly property color cyan: light ? "#24837b" : "#3aa99f"
    readonly property color blue: light ? "#205ea6" : "#4385be"
    readonly property color purple: light ? "#5e409d" : "#8b7ec8"
    readonly property color magenta: light ? "#a02f6f" : "#ce5d97"

    // Backdrop behind the clipboard menu card.
    readonly property color scrim: light ? Qt.rgba(0.06, 0.06, 0.06, 0.30)
                                         : Qt.rgba(0, 0, 0, 0.50)

    readonly property string fontFamily: "IosevkaTerm Nerd Font Propo"

    function apply(value) {
        const setting = String(value).trim()
        if (setting.length > 0)
            light = setting.indexOf("prefer-dark") === -1
    }

    Process {
        command: ["gsettings", "get", "org.gnome.desktop.interface", "color-scheme"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.apply(text)
        }
    }

    Process {
        command: ["gsettings", "monitor", "org.gnome.desktop.interface", "color-scheme"]
        running: true
        stdout: SplitParser {
            onRead: data => root.apply(data)
        }
    }
}
