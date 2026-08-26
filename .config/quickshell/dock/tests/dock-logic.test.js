import { readFileSync } from "node:fs"
import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"

const testDir = dirname(fileURLToPath(import.meta.url))
const sourcePath = resolve(testDir, "../DockLogic.js")
const source = readFileSync(sourcePath, "utf8")
const api = new Function(
    `${source.replace(/^\.pragma library\s*$/m, "")}\nreturn { restorePins, buildItems, movePin, nextWindowIndex, cleanCommand, shouldHide }`
)()

function assertEqual(name, actual, expected) {
    const got = JSON.stringify(actual)
    const want = JSON.stringify(expected)
    if (got !== want)
        throw new Error(`${name}: expected ${want}, got ${got}`)
}

function screen(name) {
    return { name }
}

function entry(id, name) {
    return { id, name }
}

const defaults = ["kitty", "firefox", "dev.sendoff.app", "spotify-launcher"]

assertEqual(
    "missing state restores the initial pins",
    api.restorePins("", defaults),
    defaults
)
assertEqual(
    "malformed state restores the initial pins",
    api.restorePins("not json", defaults),
    defaults
)
assertEqual(
    "versioned state preserves an intentionally empty dock",
    api.restorePins('{"version":1,"pins":[]}', defaults),
    []
)
assertEqual(
    "restored pins discard empty and duplicate identifiers",
    api.restorePins('{"version":1,"pins":["kitty","","kitty","firefox"]}', defaults),
    ["kitty", "firefox"]
)

const laptop = screen("eDP-1")
const external = screen("HDMI-A-1")
const entries = {
    kitty: entry("kitty", "kitty"),
    firefox: entry("firefox", "Firefox"),
    spotify: entry("spotify-launcher", "Spotify"),
    "sendoff-desktop": entry("dev.sendoff.app", "Sendoff")
}
const byId = id => Object.values(entries).find(value => value.id === id) || null
const byWindow = window => entries[window.appId] || null

const kittyOne = { appId: "kitty", title: "shell", screens: [laptop], activated: true }
const kittyTwo = { appId: "kitty", title: "logs", screens: [laptop], activated: false }
const firefoxWindow = { appId: "firefox", title: "Docs", screens: [external], activated: true }
const notesWindow = { appId: "local.notes", title: "Notes", screens: [laptop], activated: false }
const items = api.buildItems(
    ["firefox", "kitty", "missing-entry"],
    [kittyOne, kittyTwo, firefoxWindow, notesWindow],
    laptop,
    byId,
    byWindow
)

assertEqual(
    "pinned entries keep pin order and include only windows from the target screen",
    items.pinned.map(item => ({ id: item.entryId, windows: item.windows.map(window => window.title) })),
    [
        { id: "firefox", windows: [] },
        { id: "kitty", windows: ["shell", "logs"] }
    ]
)
assertEqual(
    "unknown running apps use a stable app-id fallback",
    items.running.map(item => ({ key: item.key, name: item.name, pinned: item.pinned })),
    [{ key: "app:local.notes", name: "local.notes", pinned: false }]
)
assertEqual(
    "an active window marks its grouped application active",
    items.pinned.map(item => item.active),
    [false, true]
)

assertEqual(
    "moving a pin produces a reordered copy",
    api.movePin(["kitty", "firefox", "spotify-launcher"], 0, 2),
    ["firefox", "spotify-launcher", "kitty"]
)
assertEqual(
    "moving outside the pin range leaves the order unchanged",
    api.movePin(["kitty", "firefox"], -1, 1),
    ["kitty", "firefox"]
)
assertEqual("window cycling starts at the first window", api.nextWindowIndex([kittyOne, kittyTwo], null), 0)
assertEqual("window cycling advances after the active window", api.nextWindowIndex([kittyOne, kittyTwo], kittyOne), 1)
assertEqual("window cycling wraps to the first window", api.nextWindowIndex([kittyOne, kittyTwo], kittyTwo), 0)
assertEqual("window cycling reports an empty group", api.nextWindowIndex([], null), -1)

assertEqual(
    "desktop field codes are removed before terminal launch",
    api.cleanCommand(["tool", "--flag", "%U", "literal%value", "%f"]),
    ["tool", "--flag", "literal%value"]
)

assertEqual(
    "moving from the reveal strip onto an icon keeps the dock open",
    api.shouldHide(false, false, false, 2),
    false
)
assertEqual(
    "hovering the card gap keeps the dock open",
    api.shouldHide(false, false, true, -1),
    false
)
assertEqual(
    "the dock hides only after every hover and interaction lock is gone",
    api.shouldHide(false, false, false, -1),
    true
)
assertEqual(
    "an open popup keeps the dock visible",
    api.shouldHide(true, false, false, -1),
    false
)

console.log("dock logic tests passed")
