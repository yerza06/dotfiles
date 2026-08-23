import QtQuick
import QtQuick.Layouts
import Quickshell

// Подсказка при наведении: заголовок и многострочное тело.
// Ширина подбирается по содержимому, якорь задаёт родитель.
PopupWindow {
    id: tooltipRoot

    property string title: ""
    property string text: ""
    property color backgroundColor: "#100f0f"
    property color borderColor: "#575653"
    property color titleColor: "#cecdc3"
    property color textColor: "#878580"
    property string fontFamily: "IosevkaTerm Nerd Font Propo"

    implicitWidth: frame.implicitWidth
    implicitHeight: frame.implicitHeight
    color: "transparent"
    grabFocus: false

    Rectangle {
        id: frame

        anchors.fill: parent
        implicitWidth: Math.max(180, Math.min(360, content.implicitWidth + 16))
        implicitHeight: content.implicitHeight + 16
        color: tooltipRoot.backgroundColor
        border.width: 1
        border.color: tooltipRoot.borderColor
        radius: 5

        ColumnLayout {
            id: content

            anchors.fill: parent
            anchors.margins: 8
            spacing: 4

            Text {
                Layout.fillWidth: true
                visible: tooltipRoot.title.length > 0
                text: tooltipRoot.title
                color: tooltipRoot.titleColor
                font.family: tooltipRoot.fontFamily
                font.pixelSize: 14
                font.weight: Font.Bold
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
            }

            Text {
                Layout.fillWidth: true
                visible: tooltipRoot.text.length > 0
                text: tooltipRoot.text
                color: tooltipRoot.textColor
                font.family: tooltipRoot.fontFamily
                font.pixelSize: 14
                font.weight: Font.Medium
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
            }
        }
    }
}
