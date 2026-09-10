import QtQuick
import QtQuick.Layouts

// Строка устройства Bluetooth: глиф типа, метка состояния, название, приписка
// и раскрывающийся блок с настройками.
//
// Общий DeviceRow не подошёл: у него жёсткая раскладка на anchors под
// «метка + название + приписка» и уже пять потребителей. Здесь нужны ещё глиф
// типа, полоса заряда и раскрытие — расширять общий делегат ради этого значило бы
// рисковать остальными пятью.
Item {
    id: row

    property string glyph: ""
    property string label: ""
    property string detail: ""
    property string address: ""
    property bool current: false
    property bool busy: false
    property bool expanded: false
    property bool trusted: false
    property bool batteryAvailable: false
    property int batteryPercent: 0

    property color hoverColor: "#282726"
    property color textColor: "#cecdc3"
    property color mutedTextColor: "#878580"
    property color markColor: "#403e3c"
    property color trackColor: "#282726"
    property color accentColor: "#4385be"
    property color greenColor: "#879a39"
    property color orangeColor: "#da702c"
    property color redColor: "#d14d41"
    property string fontFamily: "IosevkaTerm Nerd Font Propo"

    // Подключить/отключить — основное действие по строке.
    signal activated()
    signal expandToggled()
    signal trustToggled()
    signal renameRequested(string name)
    signal renameCancelled()

    // Зелёный у батареи в панели занят зарядкой, а у Bluetooth-устройства
    // состояния «заряжается» нет — поэтому выше 30 % он свободен.
    readonly property color batteryColor: batteryPercent <= 15
        ? redColor
        : (batteryPercent <= 30 ? orangeColor : greenColor)

    // Фокус полю не даём: раскрывают строку обычно ради заряда и доверия,
    // а перехваченный ввод превратил бы случайный Enter в переименование.
    // При сворачивании возвращаем текущее имя — иначе отменённая правка
    // всплыла бы при повторном раскрытии.
    onExpandedChanged: {
        if (!expanded)
            renameField.text = row.label
    }

    Layout.fillWidth: true
    Layout.preferredHeight: 24 + (expanded ? details.implicitHeight + 8 : 0)

    Rectangle {
        id: headerBackground

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: -6
        anchors.rightMargin: -6
        height: 24
        radius: 3
        color: rowHover.hovered || row.expanded ? row.hoverColor : "transparent"

        Behavior on color {
            ColorAnimation { duration: 90 }
        }
    }

    Text {
        id: mark

        anchors.left: parent.left
        anchors.verticalCenter: headerBackground.verticalCenter
        text: row.busy ? "◐" : (row.current ? "●" : "○")
        color: row.current || row.busy ? row.textColor : row.markColor
        font.family: row.fontFamily
        font.pixelSize: 11
        renderType: Text.NativeRendering
    }

    Text {
        id: typeGlyph

        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.verticalCenter: headerBackground.verticalCenter
        text: row.glyph
        color: row.current ? row.textColor : row.mutedTextColor
        font.family: row.fontFamily
        font.pixelSize: 13
        renderType: Text.NativeRendering
    }

    Text {
        id: rowLabel

        anchors.left: parent.left
        anchors.leftMargin: 38
        anchors.right: rowDetail.visible ? rowDetail.left : expandButton.left
        anchors.rightMargin: 8
        anchors.verticalCenter: headerBackground.verticalCenter
        text: row.label
        color: row.current ? row.textColor : row.mutedTextColor
        font.family: row.fontFamily
        font.pixelSize: 12
        elide: Text.ElideRight
        renderType: Text.NativeRendering
    }

    Text {
        id: rowDetail

        anchors.right: expandButton.left
        anchors.rightMargin: 8
        anchors.verticalCenter: headerBackground.verticalCenter
        visible: row.detail.length > 0
        text: row.detail
        color: row.batteryAvailable && !row.busy ? row.batteryColor : row.mutedTextColor
        font.family: row.fontFamily
        font.pixelSize: 11
        horizontalAlignment: Text.AlignRight
        renderType: Text.NativeRendering
    }

    // Шеврон, а не карандаш: за ним не только переименование, но и заряд,
    // доверие и адрес. Живёт в своей MouseArea — иначе клик по нему подключал бы
    // устройство вместо раскрытия настроек.
    Text {
        id: expandButton

        anchors.right: parent.right
        anchors.verticalCenter: headerBackground.verticalCenter
        text: row.expanded ? "󰅀" : "󰅂"
        color: row.expanded
            ? row.accentColor
            : (expandHover.hovered ? row.textColor : row.markColor)
        font.family: row.fontFamily
        font.pixelSize: 12
        renderType: Text.NativeRendering

        HoverHandler {
            id: expandHover
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            onClicked: row.expandToggled()
        }
    }

    ColumnLayout {
        id: details

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 38
        anchors.top: headerBackground.bottom
        anchors.topMargin: 6
        visible: row.expanded
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            visible: row.batteryAvailable
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 4
                radius: 2
                color: row.trackColor

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(100, row.batteryPercent)) / 100
                    height: parent.height
                    radius: parent.radius
                    color: row.batteryColor

                    Behavior on width {
                        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                    }
                }
            }

            Text {
                text: row.batteryPercent + "%"
                color: row.batteryColor
                font.family: row.fontFamily
                font.pixelSize: 11
                renderType: Text.NativeRendering
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: "Доверенное устройство"
                color: row.mutedTextColor
                font.family: row.fontFamily
                font.pixelSize: 11
                renderType: Text.NativeRendering
            }

            ToggleSwitch {
                implicitWidth: 30
                implicitHeight: 15
                checked: row.trusted
                accentColor: row.accentColor
                trackColor: row.trackColor
                knobColor: row.textColor
                disabledColor: row.markColor
                onToggled: row.trustToggled()
            }
        }

        // Переименование пишет в device.name (алиас BlueZ): deviceName только
        // для чтения. Enter применяет, Esc отменяет и сворачивает блок.
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 22
            radius: 3
            color: "transparent"
            border.width: 1
            border.color: renameField.activeFocus ? row.accentColor : row.markColor

            TextInput {
                id: renameField

                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                verticalAlignment: TextInput.AlignVCenter
                text: row.label
                color: row.textColor
                selectionColor: row.accentColor
                selectedTextColor: row.textColor
                font.family: row.fontFamily
                font.pixelSize: 11
                clip: true
                renderType: Text.NativeRendering

                onAccepted: row.renameRequested(text)
                Keys.onEscapePressed: event => {
                    row.renameCancelled()
                    event.accepted = true
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: row.address
            color: row.mutedTextColor
            font.family: row.fontFamily
            font.pixelSize: 10
            renderType: Text.NativeRendering
        }
    }

    HoverHandler {
        id: rowHover
    }

    MouseArea {
        anchors.left: parent.left
        anchors.right: expandButton.left
        anchors.top: parent.top
        height: 24
        enabled: !row.busy
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: row.activated()
    }
}
