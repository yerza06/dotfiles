import QtQuick
import Quickshell

// Пилюля мониторинга системы: одна иконка вместо прежних CPU и RAM.
// ЛКМ открывает btop, ПКМ — окно с загрузкой CPU, памяти, диска, видеокарт
// и скоростью сети.
Rectangle {
    id: root

    property color backgroundColor: "#100f0f"
    property color hoverColor: "#1c1b1a"
    property color textColor: "#cecdc3"
    property color mutedTextColor: "#878580"
    property color bottomBorderColor: "#403e3c"
    property color tooltipBorderColor: "#575653"
    property color popupHoverColor: "#282726"
    property color popupBorderColor: "#575653"
    property color popupSeparatorColor: "#403e3c"
    property color popupTrackColor: "#282726"
    property color accentColor: "#4385be"
    property color orangeColor: "#da702c"
    property color redColor: "#d14d41"
    property string fontFamily: "IosevkaTerm Nerd Font Propo"

    readonly property string icon: ""
    readonly property bool popupVisible: popup.visible

    // Момент последнего закрытия окна. Клик мимо, которым композитор снимает
    // захват, долетает и до самого виджета — без этой отсечки окно тут же
    // открылось бы снова.
    property double popupClosedAt: 0

    function togglePopup() {
        if (!popup.visible && Date.now() - popupClosedAt < 200)
            return
        popup.visible = !popup.visible
    }

    implicitWidth: label.implicitWidth + 12
    implicitHeight: 28
    radius: 3
    color: buttonMouse.containsMouse ? hoverColor : backgroundColor

    Behavior on color {
        ColorAnimation { duration: 100 }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.icon
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

    SystemMonitorPopup {
        id: popup

        // visible выставляется только вручную: композитор закрывает окно сам,
        // и биндинг после первого такого закрытия сломался бы.
        visible: false
        anchor.item: root
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.bottom: 4
        icon: root.icon
        backgroundColor: root.backgroundColor
        hoverColor: root.popupHoverColor
        textColor: root.textColor
        mutedTextColor: root.mutedTextColor
        borderColor: root.popupBorderColor
        separatorColor: root.popupSeparatorColor
        trackColor: root.popupTrackColor
        accentColor: root.accentColor
        orangeColor: root.orangeColor
        redColor: root.redColor
        fontFamily: root.fontFamily

        onVisibleChanged: {
            if (!visible)
                root.popupClosedAt = Date.now()
        }
        onCloseRequested: popup.visible = false
    }

    Tooltip {
        visible: buttonMouse.containsMouse && !popup.visible
        anchor.item: root
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.bottom: 4
        title: root.icon + "  Система"
        text: "ЛКМ — btop\nПКМ — окно мониторинга"
        backgroundColor: root.backgroundColor
        borderColor: root.tooltipBorderColor
        titleColor: root.textColor
        textColor: root.mutedTextColor
        fontFamily: root.fontFamily
    }

    MouseArea {
        id: buttonMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                Quickshell.execDetached(["kitty", "--start-as=fullscreen", "btop"])
            else if (mouse.button === Qt.RightButton)
                root.togglePopup()
        }
    }
}
