import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    id: root

    property var targetScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    property bool pendingOpen: false
    property string pendingQuery: ""
    property string pendingCategory: "all"

    function screenByName(name) {
        const screens = Quickshell.screens
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].name === name)
                return screens[i]
        }
        return null
    }

    function applyFocusedOutput(payload) {
        try {
            const output = JSON.parse(String(payload).trim())
            const screen = root.screenByName(output.name)
            if (screen)
                root.targetScreen = screen
        } catch (error) {
            // Not on Niri, or the reply was unusable — fall back to screen 0.
        }
    }

    // Resolves which monitor is focused before showing, so the launcher never
    // appears on the wrong screen in a multi-monitor setup.
    function requestOpen(query, category) {
        if (launcher.opened)
            return
        pendingOpen = true
        pendingQuery = String(query || "")
        pendingCategory = String(category || "all")
        outputProbe.running = false
        outputProbe.running = true
        openFallback.restart()
    }

    function openNow() {
        if (!pendingOpen)
            return
        pendingOpen = false
        openFallback.stop()
        launcher.open(pendingQuery, pendingCategory)
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            if (launcher.opened)
                launcher.close()
            else
                root.requestOpen("", "all")
        }

        function open(): void {
            root.requestOpen("", "all")
        }

        // Opens with the search field pre-filled, e.g. `... ipc call launcher search fire`.
        function search(query: string): void {
            root.requestOpen(query, "all")
        }

        // Opens on one category tab, e.g. `... ipc call launcher group development`.
        function group(category: string): void {
            root.requestOpen("", category)
        }

        function close(): void {
            root.pendingOpen = false
            launcher.close()
        }
    }

    Process {
        id: outputProbe

        command: ["niri", "msg", "--json", "focused-output"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.applyFocusedOutput(text)
                root.openNow()
            }
        }

        onExited: root.openNow()
    }

    // Shows the launcher anyway if the compositor query never answers.
    Timer {
        id: openFallback
        interval: 200
        onTriggered: root.openNow()
    }

    Launcher {
        id: launcher
        screen: root.targetScreen
    }
}
