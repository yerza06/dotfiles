import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    id: root

    property var targetScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    property bool pendingOpen: false

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

    // Resolves which monitor is focused before showing, so the menu never
    // appears on the wrong screen in a multi-monitor setup.
    function requestOpen() {
        if (menu.opened)
            return
        pendingOpen = true
        outputProbe.running = false
        outputProbe.running = true
        openFallback.restart()
    }

    function openNow() {
        if (!pendingOpen)
            return
        pendingOpen = false
        openFallback.stop()
        menu.open()
    }

    IpcHandler {
        target: "power"

        function toggle(): void {
            if (menu.opened)
                menu.close()
            else
                root.requestOpen()
        }

        function open(): void {
            root.requestOpen()
        }

        function close(): void {
            root.pendingOpen = false
            menu.close()
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

    // Shows the menu anyway if the compositor query never answers.
    Timer {
        id: openFallback
        interval: 200
        onTriggered: root.openNow()
    }

    PowerMenu {
        id: menu
        screen: root.targetScreen
    }
}
