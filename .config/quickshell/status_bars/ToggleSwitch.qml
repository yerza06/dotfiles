import QtQuick

// Тумблер-пилюля: дорожка с бегунком, который переезжает при переключении.
// Отличается от строки DeviceRow тем, что состояние видно без чтения приписки —
// нужен там, где переключатель стоит в шапке, а не в списке.
Item {
    id: control

    property bool checked: false
    // Аппаратный выключатель (rfkill) — тумблер гаснет и перестаёт нажиматься.
    property bool available: true
    property color accentColor: "#4385be"
    property color trackColor: "#403e3c"
    property color knobColor: "#cecdc3"
    property color disabledColor: "#403e3c"

    signal toggled()

    readonly property real inset: 2
    readonly property real knobSize: height - inset * 2

    implicitWidth: 36
    implicitHeight: 18

    Rectangle {
        id: track

        anchors.fill: parent
        radius: height / 2
        color: {
            if (!control.available)
                return "transparent"
            return control.checked ? control.accentColor : control.trackColor
        }
        border.width: control.available ? 0 : 1
        border.color: control.disabledColor

        Behavior on color {
            ColorAnimation { duration: 120 }
        }
    }

    Rectangle {
        id: knob

        y: control.inset
        x: control.checked
            ? control.width - control.knobSize - control.inset
            : control.inset
        width: control.knobSize
        height: control.knobSize
        radius: height / 2
        color: control.available ? control.knobColor : control.disabledColor
        // Выключенный бегунок чуть приглушён — иначе он спорит по яркости
        // с погасшей дорожкой и состояние читается хуже.
        opacity: control.checked ? 1 : 0.7

        Behavior on x {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }

        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: control.available
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: control.toggled()
    }
}
