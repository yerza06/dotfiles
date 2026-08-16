import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    property var layoutNames: []
    property bool lightTheme: false

    signal layoutSwitched(string languageName, string languageCode)

    function updateTheme(value) {
        const setting = String(value).trim()
        if (setting.length > 0)
            lightTheme = setting.indexOf("prefer-dark") === -1
    }

    function languageInfo(name) {
        const normalized = String(name)
        if (normalized.indexOf("English") !== -1)
            return { name: "English", code: "EN" }
        if (normalized.indexOf("Russian") !== -1)
            return { name: "Русский", code: "RU" }
        if (normalized.indexOf("Kazakh") !== -1)
            return { name: "Қазақша", code: "KZ" }

        return {
            name: normalized.length > 0 ? normalized : "Неизвестный язык",
            code: normalized.substring(0, 2).toUpperCase() || "--"
        }
    }

    function handleNiriEvent(rawText) {
        try {
            const event = JSON.parse(String(rawText).trim())

            // The first event supplies the configured layout names. It must not
            // display a toast because no user-initiated switch happened yet.
            if (event.KeyboardLayoutsChanged) {
                const state = event.KeyboardLayoutsChanged.keyboard_layouts
                layoutNames = state.names || []
                return
            }

            if (event.KeyboardLayoutSwitched) {
                const index = event.KeyboardLayoutSwitched.idx
                const info = languageInfo(layoutNames[index] || "")
                layoutSwitched(info.name, info.code)
            }
        } catch (error) {
            console.warn("Could not parse Niri event:", error)
        }
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
        command: ["niri", "msg", "--json", "event-stream"]
        running: true
        stdout: SplitParser {
            onRead: data => root.handleNiriEvent(data)
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: LayoutToast {
            required property var modelData
            targetScreen: modelData
            lightTheme: root.lightTheme

            Connections {
                target: root

                function onLayoutSwitched(languageName, languageCode) {
                    showLanguage(languageName, languageCode)
                }
            }
        }
    }
}
