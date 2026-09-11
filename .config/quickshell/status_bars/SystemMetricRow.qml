import QtQuick
import QtQuick.Layouts

// Строка окна мониторинга: глиф, метка и значение, под ними — необязательная
// приглушённая подпись и полоса загрузки.
ColumnLayout {
    id: row

    property string glyph: ""
    property string label: ""
    property string value: "—"
    property string detail: ""
    // -1 — значения нет (данные ещё не пришли или карта спит): полоса пустая.
    property real percent: -1
    property bool showBar: true
    property color textColor: "#cecdc3"
    property color mutedTextColor: "#878580"
    property color trackColor: "#282726"
    property color accentColor: "#4385be"
    property color orangeColor: "#da702c"
    property color redColor: "#d14d41"
    property string fontFamily: "IosevkaTerm Nerd Font Propo"

    readonly property color levelColor: {
        if (percent >= 90)
            return redColor
        if (percent >= 70)
            return orangeColor
        return accentColor
    }

    Layout.fillWidth: true
    spacing: 4

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            Layout.preferredWidth: 16
            horizontalAlignment: Text.AlignHCenter
            text: row.glyph
            color: row.textColor
            font.family: row.fontFamily
            font.pixelSize: 13
            renderType: Text.NativeRendering
        }

        Text {
            text: row.label
            color: row.textColor
            font.family: row.fontFamily
            font.pixelSize: 12
            font.weight: Font.Bold
            renderType: Text.NativeRendering
        }

        Item {
            Layout.fillWidth: true
        }

        Text {
            text: row.value
            color: row.textColor
            font.family: row.fontFamily
            font.pixelSize: 12
            font.weight: Font.Medium
            renderType: Text.NativeRendering
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.leftMargin: 24
        visible: row.detail.length > 0
        text: row.detail
        color: row.mutedTextColor
        font.family: row.fontFamily
        font.pixelSize: 11
        elide: Text.ElideRight
        renderType: Text.NativeRendering
    }

    Rectangle {
        Layout.fillWidth: true
        visible: row.showBar
        implicitHeight: 6
        radius: 3
        color: row.trackColor

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Math.max(0, Math.min(parent.width,
                parent.width * row.percent / 100))
            radius: 3
            color: row.levelColor

            // Показатели приходят раз в секунду — без анимации полоса дёргается.
            Behavior on width {
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
            }

            Behavior on color {
                ColorAnimation { duration: 100 }
            }
        }
    }
}
