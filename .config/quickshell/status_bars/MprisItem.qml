import QtQuick
import Quickshell

Rectangle {
    id: root

    property var player: null
    property var players: []
    property string pinnedPlayerId: ""
    property color backgroundColor: "#100f0f"
    property color hoverColor: "#1c1b1a"
    property color textColor: "#cecdc3"
    property color mutedTextColor: "#878580"
    property color mutedBorderColor: "#575653"
    property color spotifyColor: "#879a39"
    property color browserColor: "#da702c"
    property color chromiumColor: "#4385be"
    property color bottomBorderColor: "#403e3c"
    property color menuHoverColor: "#282726"
    property color menuBorderColor: "#575653"
    property color menuSeparatorColor: "#403e3c"
    property string fontFamily: "IosevkaTerm Nerd Font Propo"

    property bool menuVisible: false

    signal pinRequested(string playerId)

    readonly property bool menuChainHovered: mouseArea.containsMouse || mprisMenu.chainHovered

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

    function toggleMenu() {
        menuCloseTimer.stop()
        menuVisible = !menuVisible
    }

    onMenuChainHoveredChanged: {
        if (menuChainHovered)
            menuCloseTimer.stop()
        else if (menuVisible)
            menuCloseTimer.restart()
    }

    // Меню закрывается, когда курсор ушёл и с виджета, и с самого меню.
    Timer {
        id: menuCloseTimer
        interval: 400
        repeat: false
        onTriggered: {
            if (!root.menuChainHovered)
                root.menuVisible = false
        }
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

    MprisMenu {
        id: mprisMenu

        visible: root.menuVisible
        anchor.item: root
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        players: root.players
        currentPlayer: root.player
        pinnedPlayerId: root.pinnedPlayerId
        backgroundColor: root.backgroundColor
        hoverColor: root.menuHoverColor
        textColor: root.textColor
        mutedTextColor: root.mutedTextColor
        borderColor: root.menuBorderColor
        separatorColor: root.menuSeparatorColor
        fontFamily: root.fontFamily
        onPinRequested: playerId => root.pinRequested(playerId)
        onCloseRequested: root.menuVisible = false
    }

    Tooltip {
        visible: mouseArea.containsMouse && !root.menuVisible
        anchor.item: root
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.bottom: 4
        title: "  " + (root.player && root.player.trackTitle
            ? root.player.trackTitle : "Неизвестная композиция")
        text: "  " + (root.player && root.player.trackArtist
            ? root.player.trackArtist : "Неизвестный исполнитель")
        backgroundColor: root.backgroundColor
        borderColor: root.mutedBorderColor
        titleColor: root.textColor
        textColor: root.mutedTextColor
        fontFamily: root.fontFamily
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                root.toggleMenu()
                return
            }
            if (!root.player)
                return
            if (mouse.button === Qt.LeftButton && root.player.canTogglePlaying)
                root.player.togglePlaying()
            else if (mouse.button === Qt.MiddleButton && root.player.canGoPrevious)
                root.player.previous()
        }
    }

    Behavior on color {
        ColorAnimation { duration: 100 }
    }
}
