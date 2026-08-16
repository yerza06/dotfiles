import QtQuick
import Quickshell

Rectangle {
    id: root

    property var player: null
    property color backgroundColor: "#100f0f"
    property color hoverColor: "#1c1b1a"
    property color textColor: "#cecdc3"
    property color mutedBorderColor: "#575653"
    property color spotifyColor: "#879a39"
    property color browserColor: "#da702c"
    property color chromiumColor: "#4385be"
    property color bottomBorderColor: "#403e3c"
    property string fontFamily: "IosevkaTerm Nerd Font Propo"

    readonly property string playerKey: {
        if (!player)
            return ""
        return (player.desktopEntry || player.identity || "").toLowerCase()
    }
    readonly property bool playing: player !== null && player.isPlaying
    readonly property color accentColor: {
        if (playerKey.indexOf("spotify") !== -1)
            return spotifyColor
        if (playerKey.indexOf("firefox") !== -1
                || playerKey.indexOf("zen") !== -1
                || playerKey.indexOf("vlc") !== -1)
            return browserColor
        if (playerKey.indexOf("telegram") !== -1
                || playerKey.indexOf("chromium") !== -1
                || playerKey.indexOf("helium") !== -1)
            return chromiumColor
        return backgroundColor
    }
    readonly property color sideBorderColor: playing
        ? (accentColor === backgroundColor ? "transparent" : accentColor)
        : mutedBorderColor

    visible: player !== null
    implicitWidth: visible ? labelMetrics.advanceWidth + 12 : 0
    implicitHeight: 28
    radius: playing ? 3 : 0
    color: playing ? accentColor : (mouseArea.containsMouse ? hoverColor : backgroundColor)

    function playerIcon() {
        if (playerKey.indexOf("spotify") !== -1)
            return ""
        if (playerKey.indexOf("mpv") !== -1)
            return "󰎇"
        if (playerKey.indexOf("chromium") !== -1
                || playerKey.indexOf("helium") !== -1)
            return ""
        if (playerKey.indexOf("firefox") !== -1 || playerKey.indexOf("zen") !== -1)
            return "󰈹"
        if (playerKey.indexOf("vlc") !== -1)
            return "󰕼"
        if (playerKey.indexOf("telegram") !== -1)
            return ""
        return ""
    }

    function tooltipText() {
        if (!player)
            return ""
        return "  " + (player.trackTitle || "Неизвестная композиция")
            + "\n  " + (player.trackArtist || "Неизвестный исполнитель")
    }

    TextMetrics {
        id: labelMetrics
        font: label.font
        text: label.text
    }

    Text {
        id: label
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        text: root.playerIcon()
        color: root.playing && root.accentColor !== root.backgroundColor
            ? root.backgroundColor
            : root.textColor
        font.family: root.fontFamily
        font.pixelSize: 14
        font.weight: Font.Medium
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        renderType: Text.NativeRendering
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: root.sideBorderColor
    }

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: root.sideBorderColor
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: root.bottomBorderColor
    }

    PopupWindow {
        id: trackTooltip

        anchor.item: root
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.bottom: 4
        visible: mouseArea.containsMouse
        implicitWidth: Math.min(Math.max(titleMetrics.advanceWidth, artistMetrics.advanceWidth) + 24, 420)
        implicitHeight: 58
        color: "transparent"
        grabFocus: false

        Rectangle {
            anchors.fill: parent
            color: root.backgroundColor
            border.width: 1
            border.color: root.mutedBorderColor
            radius: 5

            Column {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                Text {
                    id: tooltipTitle
                    width: parent.width
                    text: "  " + (root.player && root.player.trackTitle
                        ? root.player.trackTitle : "Неизвестная композиция")
                    color: root.textColor
                    font.family: root.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                }

                Text {
                    id: tooltipArtist
                    width: parent.width
                    text: "  " + (root.player && root.player.trackArtist
                        ? root.player.trackArtist : "Неизвестный исполнитель")
                    color: root.textColor
                    font.family: root.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                }
            }
        }
    }

    TextMetrics {
        id: titleMetrics
        font: tooltipTitle.font
        text: tooltipTitle.text
    }

    TextMetrics {
        id: artistMetrics
        font: tooltipArtist.font
        text: tooltipArtist.text
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: mouse => {
            if (!root.player)
                return
            if (mouse.button === Qt.LeftButton && root.player.canTogglePlaying)
                root.player.togglePlaying()
            else if (mouse.button === Qt.MiddleButton && root.player.canGoPrevious)
                root.player.previous()
            else if (mouse.button === Qt.RightButton && root.player.canGoNext)
                root.player.next()
        }

    }

    Behavior on color {
        ColorAnimation { duration: 100 }
    }
}
