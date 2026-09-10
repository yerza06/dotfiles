import QtQuick
import QtQuick.Layouts

// Круглая кнопка транспорта медиаплеера: предыдущий, play/pause, следующий.
// От CalendarButton отличается тремя вещами: круглой формой с настраиваемым
// размером, состоянием «недоступна» (плеер не умеет canGoNext и подобное)
// и заливкой акцентом для главной кнопки.
Item {
    id: button

    property string text: ""
    property int pixelSize: 15
    property int size: 30
    property bool filled: false
    // Режим включён (перемешивание, повтор) — глиф красится акцентом,
    // как зелёные иконки в Spotify.
    property bool active: false
    property bool available: true
    property color backgroundColor: "#100f0f"
    property color hoverColor: "#282726"
    property color textColor: "#cecdc3"
    property color mutedTextColor: "#575653"
    property color accentColor: "#4385be"
    property string fontFamily: "IosevkaTerm Nerd Font Propo"

    signal activated()

    readonly property color glyphColor: {
        if (!available)
            return mutedTextColor
        if (filled)
            return backgroundColor
        return active ? accentColor : textColor
    }

    implicitWidth: size
    implicitHeight: size
    Layout.preferredWidth: size
    Layout.preferredHeight: size

    Rectangle {
        anchors.fill: parent
        radius: button.size / 2
        color: {
            if (!button.available)
                return "transparent"
            if (button.filled)
                return buttonHover.hovered
                    ? Qt.lighter(button.accentColor, 1.15)
                    : button.accentColor
            return buttonHover.hovered ? button.hoverColor : "transparent"
        }

        Behavior on color {
            ColorAnimation { duration: 100 }
        }
    }

    Text {
        id: label

        anchors.centerIn: parent
        text: button.text
        color: button.glyphColor
        font.family: button.fontFamily
        font.pixelSize: button.pixelSize
        font.weight: Font.Medium
        renderType: Text.NativeRendering

        Behavior on color {
            ColorAnimation { duration: 100 }
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
