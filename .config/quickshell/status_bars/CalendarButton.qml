import QtQuick
import QtQuick.Layouts

// Кнопка шапки календаря: стрелки листания и название месяца.
Item {
    id: button

    property string text: ""
    property int pixelSize: 14
    property bool bold: false
    property color hoverColor: "#282726"
    property color textColor: "#cecdc3"
    property string fontFamily: "IosevkaTerm Nerd Font Propo"

    signal activated()

    implicitWidth: Math.max(24, label.implicitWidth + 10)
    implicitHeight: 24
    Layout.preferredHeight: 24

    Rectangle {
        anchors.fill: parent
        radius: 3
        color: buttonHover.hovered ? button.hoverColor : "transparent"

        Behavior on color {
            ColorAnimation { duration: 90 }
        }
    }

    Text {
        id: label

        anchors.centerIn: parent
        text: button.text
        color: button.textColor
        font.family: button.fontFamily
        font.pixelSize: button.pixelSize
        font.weight: button.bold ? Font.Bold : Font.Medium
        renderType: Text.NativeRendering
    }

    HoverHandler {
        id: buttonHover
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: button.activated()
    }
}
