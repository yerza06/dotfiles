.pragma library

function actionFor(key, modifiers, columns) {
    const controlPressed = (modifiers & Qt.ControlModifier) !== 0
    if (!controlPressed)
        return null

    if (key === Qt.Key_Tab)
        return { kind: "category", delta: 1 }
    if (key === Qt.Key_Backtab)
        return { kind: "category", delta: -1 }

    const shiftPressed = (modifiers & Qt.ShiftModifier) !== 0
    if (shiftPressed) {
        if (key === Qt.Key_Left)
            return { kind: "category", delta: -1 }
        if (key === Qt.Key_Right)
            return { kind: "category", delta: 1 }
        return null
    }

    switch (key) {
    case Qt.Key_Left:
        return { kind: "move", delta: -1 }
    case Qt.Key_Right:
        return { kind: "move", delta: 1 }
    case Qt.Key_Up:
        return { kind: "move", delta: -columns }
    case Qt.Key_Down:
        return { kind: "move", delta: columns }
    default:
        return null
    }
}
