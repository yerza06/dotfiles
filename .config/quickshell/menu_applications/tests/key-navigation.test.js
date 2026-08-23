import { readFileSync } from "node:fs"
import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"

const testDir = dirname(fileURLToPath(import.meta.url))
const sourcePath = resolve(testDir, "../KeyNavigation.js")

let source = ""
try {
    source = readFileSync(sourcePath, "utf8")
} catch (error) {
    throw new Error(`Key navigation module is missing: ${sourcePath}`)
}

const Qt = {
    Key_Left: 1,
    Key_Right: 2,
    Key_Up: 3,
    Key_Down: 4,
    Key_H: 5,
    Key_L: 6,
    Key_Tab: 7,
    Key_Backtab: 8,
    ControlModifier: 1 << 0,
    ShiftModifier: 1 << 1
}

const loadActionFor = new Function(
    "Qt",
    `${source.replace(/^\.pragma library\s*$/m, "")}\nreturn actionFor`
)
const actionFor = loadActionFor(Qt)

function expectAction(name, key, modifiers, columns, expected) {
    const actual = actionFor(key, modifiers, columns)
    const serializedActual = JSON.stringify(actual)
    const serializedExpected = JSON.stringify(expected)
    if (serializedActual !== serializedExpected)
        throw new Error(`${name}: expected ${serializedExpected}, got ${serializedActual}`)
}

const ctrl = Qt.ControlModifier
const ctrlShift = Qt.ControlModifier | Qt.ShiftModifier
const columns = 5

expectAction("Ctrl+Left selects the previous app", Qt.Key_Left, ctrl, columns, { kind: "move", delta: -1 })
expectAction("Ctrl+Right selects the next app", Qt.Key_Right, ctrl, columns, { kind: "move", delta: 1 })
expectAction("Ctrl+Up selects the app above", Qt.Key_Up, ctrl, columns, { kind: "move", delta: -columns })
expectAction("Ctrl+Down selects the app below", Qt.Key_Down, ctrl, columns, { kind: "move", delta: columns })

expectAction("Ctrl+Shift+Left selects the previous category", Qt.Key_Left, ctrlShift, columns, { kind: "category", delta: -1 })
expectAction("Ctrl+Shift+Right selects the next category", Qt.Key_Right, ctrlShift, columns, { kind: "category", delta: 1 })
expectAction("Ctrl+Tab keeps selecting the next category", Qt.Key_Tab, ctrl, columns, { kind: "category", delta: 1 })
expectAction("Ctrl+Shift+Tab keeps selecting the previous category", Qt.Key_Backtab, ctrlShift, columns, { kind: "category", delta: -1 })
expectAction("Ctrl+Shift+Up has no launcher action", Qt.Key_Up, ctrlShift, columns, null)
expectAction("Ctrl+Shift+Down has no launcher action", Qt.Key_Down, ctrlShift, columns, null)

expectAction("bare Left stays in the search field", Qt.Key_Left, 0, columns, null)
expectAction("bare Right stays in the search field", Qt.Key_Right, 0, columns, null)
expectAction("bare Up stays in the search field", Qt.Key_Up, 0, columns, null)
expectAction("bare Down stays in the search field", Qt.Key_Down, 0, columns, null)
expectAction("Ctrl+h no longer changes categories", Qt.Key_H, ctrl, columns, null)
expectAction("Ctrl+l no longer changes categories", Qt.Key_L, ctrl, columns, null)

console.log("key navigation tests passed")
