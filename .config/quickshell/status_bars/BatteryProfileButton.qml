import QtQuick
import QtQuick.Layouts

// Прямоугольная кнопка профиля питания в окне батареи.
// От круглой MprisControlButton отличается подписью рядом с глифом и тем,
// что делит ширину поровну с соседями: три профиля должны выглядеть как
// один сегментированный переключатель.
Item {
    id: button

    property string glyph: ""
    property string label: ""
    // Профиль выбран сейчас — кнопка красится акцентом и обводится рамкой.
    property bool active: false
    property bool available: true
    property color backgroundColor: "#100f0f"
    property color hoverColor: "#282726"
    property color textColor: "#cecdc3"
    property color mutedTextColor: "#878580"
    property color disabledColor: "#403e3c"
    property color accentColor: "#4385be"
    property string fontFamily: "IosevkaTerm Nerd Font Propo"

    signal activated()

    readonly property color contentColor: {
        if (!available)
            return disabledColor
        return active ? accentColor : mutedTextColor
    }

    Layout.fillWidth: true
    implicitHeight: 30
    Layout.preferredHeight: 30

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: {
            if (!button.available)
                return "transparent"
            if (button.active)
                return button.hoverColor
            return buttonHover.hovered ? button.hoverColor : "transparent"
        }
        border.width: button.active ? 1 : 0
        border.color: button.accentColor

        Behavior on color {
            ColorAnimation { duration: 100 }
        }
    }

    RowLayout {
        anchors.centerIn: parent
        spacing: 5

        Text {
            text: button.glyph
            color: button.contentColor
            font.family: button.fontFamily
            font.pixelSize: 13
            renderType: Text.NativeRendering

            Behavior on color {
                ColorAnimation { duration: 100 }
            }
        }

        Text {
            text: button.label
            color: button.contentColor
            font.family: button.fontFamily
            font.pixelSize: 11
            font.weight: button.active ? Font.Bold : Font.Medium
            renderType: Text.NativeRendering

            Behavior on color {
                ColorAnimation { duration: 100 }
            }
        }
    }

    HoverHandler {
        id: buttonHover

        enabled: button.available
    }

    MouseArea {
        anchors.fill: parent
        enabled: button.available
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: button.activated()
    }
}
