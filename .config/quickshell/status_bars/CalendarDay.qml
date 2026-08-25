import QtQuick

// Одна ячейка сетки месяца: число с подсветкой сегодняшнего дня.
Item {
    id: cell

    property int day: 1
    property bool inMonth: true
    property bool weekend: false
    property bool today: false
    property color backgroundColor: "#100f0f"
    property color hoverColor: "#282726"
    property color textColor: "#cecdc3"
    property color mutedTextColor: "#878580"
    property color accentColor: "#4385be"
    property color weekendColor: "#d14d41"
    property string fontFamily: "IosevkaTerm Nerd Font Propo"

    Rectangle {
        anchors.fill: parent
        radius: 3
        color: cell.today
            ? cell.accentColor
            : (cellHover.hovered ? cell.hoverColor : "transparent")

        Behavior on color {
            ColorAnimation { duration: 90 }
        }
    }

    Text {
        anchors.centerIn: parent
        text: cell.day
        color: {
            if (cell.today)
                return cell.backgroundColor
            if (!cell.inMonth)
                return cell.mutedTextColor
            return cell.weekend ? cell.weekendColor : cell.textColor
        }
        opacity: cell.inMonth ? 1 : 0.55
        font.family: cell.fontFamily
        font.pixelSize: 12
        font.weight: cell.today ? Font.Bold : Font.Medium
        renderType: Text.NativeRendering
    }

    HoverHandler {
        id: cellHover
    }
}
