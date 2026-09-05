pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "DockLogic.js" as DockLogic

Singleton {
    id: root

    readonly property var defaultPins: [
        "kitty",
        "firefox",
        "dev.sendoff.app",
        "spotify-launcher"
    ]
    readonly property string terminal: "kitty"
    readonly property var toplevels: ToplevelManager.toplevels
        ? ToplevelManager.toplevels.values
        : []
    readonly property var desktopEntries: DesktopEntries.applications
        ? DesktopEntries.applications.values
        : []

    property var pins: []
    property bool stateLoaded: false

    function entryForWindow(window) {
        if (!window)
            return null
        return DesktopEntries.heuristicLookup(String(window.appId || ""))
    }

    function itemsForScreen(screen) {
        const currentPins = pins
        const windows = toplevels
        // Keep the binding dependent on the asynchronous desktop-entry index.
        const entries = desktopEntries
        return DockLogic.buildItems(
            currentPins,
            windows,
            screen,
            id => DesktopEntries.byId(id),
            window => root.entryForWindow(window)
        )
    }

    function persistPins() {
        if (!stateLoaded)
            return
        pinsFile.setText(JSON.stringify({ version: 1, pins: pins }))
    }

    function togglePin(entryId) {
        const id = String(entryId || "")
        if (id.length === 0)
            return

        const next = pins.slice()
        const index = next.indexOf(id)
        if (index === -1)
            next.push(id)
        else
            next.splice(index, 1)
        pins = next
        persistPins()
    }

    function movePin(fromIndex, toIndex) {
        const next = DockLogic.movePin(pins, fromIndex, toIndex)
        if (JSON.stringify(next) === JSON.stringify(pins))
            return
        pins = next
        persistPins()
    }

    function launchNew(item) {
        if (!item || !item.entry)
            return

        const entry = item.entry
        if (entry.runInTerminal) {
            const command = DockLogic.cleanCommand(entry.command)
            if (command.length > 0) {
                Quickshell.execDetached([root.terminal, "-e"].concat(command))
                return
            }
        }
        entry.execute()
    }

    function activateOrLaunch(item) {
        if (!item)
            return
        const windows = item.windows || []
        if (windows.length === 0) {
            launchNew(item)
            return
        }

        let activeWindow = null
        for (let i = 0; i < windows.length; i++) {
            if (windows[i].activated) {
                activeWindow = windows[i]
                break
            }
        }
        const index = DockLogic.nextWindowIndex(windows, activeWindow)
        if (index >= 0)
            windows[index].activate()
    }

    function closeAll(item) {
        if (!item || !item.windows)
            return
        const windows = item.windows.slice()
        for (let i = 0; i < windows.length; i++)
            windows[i].close()
    }

    function iconSource(item) {
        if (!item || !item.entry)
            return ""
        const icon = String(item.entry.icon || "")
        if (icon.length === 0)
            return ""
        if (icon.indexOf("/") === 0)
            return "file://" + icon
        return Quickshell.iconPath(icon, "application-x-executable")
    }

    FileView {
        id: pinsFile
        path: Quickshell.statePath("pins.json")
        printErrors: false

        onLoaded: {
            root.pins = DockLogic.restorePins(text(), root.defaultPins)
            root.stateLoaded = true
        }

        onLoadFailed: {
            root.pins = DockLogic.restorePins("", root.defaultPins)
            root.stateLoaded = true
        }
    }

    Component.onCompleted: {
        const path = pinsFile.path
        const separator = path.lastIndexOf("/")
        if (separator > 0)
            Quickshell.execDetached(["mkdir", "-p", path.substring(0, separator)])
    }
}
