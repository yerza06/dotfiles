import QtQuick
import Quickshell

// Часы по центру панели. ЛКМ открывает календарь.
Rectangle {
    id: root

    required property date currentDate
    property color backgroundColor: "#100f0f"
    property color hoverColor: "#1c1b1a"
    property color textColor: "#cecdc3"
    property color mutedTextColor: "#878580"
    property color borderColor: "#575653"
    property color separatorColor: "#403e3c"
    property color bottomBorderColor: "#403e3c"
    property color menuHoverColor: "#282726"
    property color accentColor: "#4385be"
    property color weekendColor: "#d14d41"
    property string fontFamily: "IosevkaTerm Nerd Font Propo"

    readonly property bool calendarVisible: calendar.visible

    // Момент последнего закрытия календаря. Клик мимо, которым композитор
    // снимает захват, может долететь и до самих часов — без этой отсечки
    // календарь тут же открылся бы снова.
    property double closedAt: 0

    function toggleCalendar() {
        if (!calendar.visible && Date.now() - closedAt < 200)
            return
        calendar.visible = !calendar.visible
    }

    implicitWidth: clockText.implicitWidth + 12
    implicitHeight: 28
    radius: 3
    color: clockMouse.containsMouse || calendar.visible ? hoverColor : backgroundColor

    Behavior on color {
        ColorAnimation { duration: 100 }
    }

    Text {
        id: clockText

        anchors.centerIn: parent
        text: Qt.formatDateTime(root.currentDate, "ddd, dd MMM  ·  HH:mm:ss")
        color: root.textColor
        font.family: root.fontFamily
        font.pixelSize: 14
        font.weight: Font.Medium
        renderType: Text.NativeRendering
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: root.bottomBorderColor
    }

    CalendarPopup {
        id: calendar

        // visible выставляется только вручную: композитор закрывает окно сам,
        // и биндинг после первого такого закрытия сломался бы.
        visible: false
        anchor.item: root
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.bottom: 4
        currentDate: root.currentDate
        backgroundColor: root.backgroundColor
        hoverColor: root.menuHoverColor
        textColor: root.textColor
        mutedTextColor: root.mutedTextColor
        borderColor: root.borderColor
        separatorColor: root.separatorColor
        accentColor: root.accentColor
        weekendColor: root.weekendColor
        fontFamily: root.fontFamily

        onVisibleChanged: {
            if (!visible)
                root.closedAt = Date.now()
        }
        onCloseRequested: calendar.visible = false
    }

    MouseArea {
        id: clockMouse

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggleCalendar()
    }
}
