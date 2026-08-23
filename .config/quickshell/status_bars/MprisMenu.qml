import QtQuick
import QtQuick.Layouts
import Quickshell

// Меню выбора активного MPRIS-плеера в стиле Flexoki.
// Закреплённый плеер идентифицируется по dbusName, пустая строка — автовыбор.
PopupWindow {
    id: menuRoot

    property var players: []
    property var currentPlayer: null
    property string pinnedPlayerId: ""
    property color backgroundColor: "#100f0f"
    property color hoverColor: "#282726"
    property color textColor: "#cecdc3"
    property color mutedTextColor: "#878580"
    property color borderColor: "#575653"
    property color separatorColor: "#403e3c"
    property string fontFamily: "IosevkaTerm Nerd Font Propo"

    signal pinRequested(string playerId)
    signal closeRequested()

    readonly property bool chainHovered: frameHover.hovered

    function playerLabel(player) {
        if (!player)
            return ""
        return player.identity || player.dbusName || ""
    }

    // Название трека обрезается здесь: у правой приписки в DeviceRow нет elide,
    // и длинный заголовок с YouTube распёр бы меню и наехал на метку.
    function playerDetail(player) {
        if (!player)
            return ""
        const mark = player.isPlaying ? "▶ " : ""
        const title = player.trackTitle || ""
        if (title.length === 0)
            return mark.length > 0 ? "▶" : ""
        return mark + (title.length > 28 ? title.slice(0, 27) + "…" : title)
    }

    function selectPlayer(player) {
        if (!player)
            return
        menuRoot.pinRequested(player.dbusName)
        menuRoot.closeRequested()
    }

    function selectAuto() {
        menuRoot.pinRequested("")
        menuRoot.closeRequested()
    }

    implicitWidth: frame.implicitWidth
    implicitHeight: frame.implicitHeight
    color: "transparent"
    grabFocus: false

    Rectangle {
        id: frame

        anchors.fill: parent
        implicitWidth: Math.max(200, Math.min(400, content.implicitWidth + 24))
        implicitHeight: content.implicitHeight + 12
        color: menuRoot.backgroundColor
        border.width: 1
        border.color: menuRoot.borderColor
        radius: 5

        HoverHandler {
            id: frameHover
        }

        ColumnLayout {
            id: content

            anchors.fill: parent
            anchors.topMargin: 6
            anchors.bottomMargin: 6
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 0

            Text {
                Layout.fillWidth: true
                Layout.bottomMargin: 2
                text: "Плеер"
                color: menuRoot.mutedTextColor
                font.family: menuRoot.fontFamily
                font.pixelSize: 11
                font.weight: Font.Medium
                renderType: Text.NativeRendering
            }

            DeviceRow {
                visible: menuRoot.players.length > 0
                current: menuRoot.pinnedPlayerId.length === 0
                label: "Автовыбор"
                hoverColor: menuRoot.hoverColor
                textColor: menuRoot.textColor
                mutedTextColor: menuRoot.mutedTextColor
                markColor: menuRoot.separatorColor
                fontFamily: menuRoot.fontFamily
                onActivated: menuRoot.selectAuto()
            }

            Repeater {
                model: menuRoot.players

                delegate: DeviceRow {
                    required property var modelData

                    current: modelData.dbusName === menuRoot.pinnedPlayerId
                    label: menuRoot.playerLabel(modelData)
                    detail: menuRoot.playerDetail(modelData)
                    hoverColor: menuRoot.hoverColor
                    textColor: menuRoot.textColor
                    mutedTextColor: menuRoot.mutedTextColor
                    markColor: menuRoot.separatorColor
                    fontFamily: menuRoot.fontFamily
                    onActivated: menuRoot.selectPlayer(modelData)
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                verticalAlignment: Text.AlignVCenter
                visible: menuRoot.players.length === 0
                text: "Плееров не найдено"
                color: menuRoot.mutedTextColor
                font.family: menuRoot.fontFamily
                font.pixelSize: 12
                renderType: Text.NativeRendering
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 5
                Layout.bottomMargin: 5
                implicitHeight: 1
                visible: nextRow.visible
                color: menuRoot.separatorColor
            }

            // Действие повторяемое, поэтому меню не закрывается.
            DeviceRow {
                id: nextRow

                visible: menuRoot.currentPlayer !== null
                    && menuRoot.currentPlayer.canGoNext
                showMark: false
                label: "Следующий трек"
                labelColor: menuRoot.textColor
                hoverColor: menuRoot.hoverColor
                textColor: menuRoot.textColor
                mutedTextColor: menuRoot.mutedTextColor
                markColor: menuRoot.separatorColor
                fontFamily: menuRoot.fontFamily
                onActivated: menuRoot.currentPlayer.next()
            }
        }
    }
}
