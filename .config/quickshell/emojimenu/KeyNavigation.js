.pragma library

// Раскладка навигации по сетке. Вынесена отдельно от окна по той же причине,
// что и в лаунчере: это чистая функция, её можно читать и править, не пробираясь
// через шестьсот строк разметки.
//
// Голые ← и → намеренно не занимаются — они остаются за правкой строки поиска.
// Символ влево/вправо переносится на Ctrl, ряд вверх/вниз — на голые ↑ и ↓,
// с редактированием они не конфликтуют.
function actionFor(key, modifiers, columns) {
    const controlPressed = (modifiers & Qt.ControlModifier) !== 0

    if (controlPressed) {
        switch (key) {
        case Qt.Key_Tab:
            return { kind: "category", delta: 1 }
        case Qt.Key_Backtab:
            return { kind: "category", delta: -1 }
        case Qt.Key_Right:
            return { kind: "move", delta: 1 }
        case Qt.Key_Left:
            return { kind: "move", delta: -1 }
        default:
            return null
        }
    }

    switch (key) {
    case Qt.Key_Tab:
        return { kind: "subcategory", delta: 1 }
    case Qt.Key_Backtab:
        return { kind: "subcategory", delta: -1 }
    case Qt.Key_Down:
        return { kind: "move", delta: columns }
    case Qt.Key_Up:
        return { kind: "move", delta: -columns }
    default:
        return null
    }
}
