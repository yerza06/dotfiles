import QtQuick
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: root

    required property var audioNode
    property color backgroundColor: "#100f0f"
    property color hoverColor: "#1c1b1a"
    property color textColor: "#cecdc3"
    property color mutedColor: "#d14d41"
    property color trackColor: "#403e3c"
    property color popupBorderColor: "#575653"
    property color bottomBorderColor: "#403e3c"
    property string fontFamily: "IosevkaTerm Nerd Font Propo"
    property bool microphoneMode: false
    property bool sliderEnabled: true
    property bool popupVisible: false
    property color mutedTextColor: "#878580"
    property color menuHoverColor: "#282726"
    property color menuBorderColor: "#575653"
    property color menuSeparatorColor: "#403e3c"
    // headphones | speaker | hdmi | unknown — приходит из scripts/audio-output.sh
    property string outputType: "speaker"

    property bool menuVisible: false

    readonly property bool menuChainHovered: buttonMouse.containsMouse || deviceMenu.chainHovered

    readonly property bool audioReady: audioNode !== null && audioNode.audio !== null
    readonly property real volumeValue: audioReady ? audioNode.audio.volume : 0
    readonly property bool muted: !audioReady || audioNode.audio.muted

    implicitWidth: label.implicitWidth + 12
    implicitHeight: 28
    radius: 3
    color: buttonMouse.containsMouse ? hoverColor : backgroundColor

    function volumePercent() {
        return Math.round(volumeValue * 100)
    }

    function volumeIcon() {
        if (microphoneMode)
            return muted ? "" : ""
        if (outputType === "headphones")
            return muted ? "󰋌" : ""
        if (muted)
            return ""
        if (outputType === "hdmi")
            return ""
        const value = volumePercent()
        return value < 34 ? "" : (value < 67 ? "" : "")
    }

    onMenuChainHoveredChanged: {
        if (menuChainHovered)
            menuCloseTimer.stop()
        else if (menuVisible)
            menuCloseTimer.restart()
    }

    function toggleMenu() {
        menuCloseTimer.stop()
        menuVisible = !menuVisible
    }

    function openPopup() {
        closeTimer.stop()
        popupVisible = true
    }

    function schedulePopupClose() {
        closeTimer.restart()
    }

    function setVolumeFromPosition(position, availableWidth) {
        if (!audioReady || availableWidth <= 0)
            return
        audioNode.audio.volume = Math.max(0, Math.min(1, position / availableWidth))
    }

    Timer {
        id: closeTimer
        interval: 220
        repeat: false
        onTriggered: root.popupVisible = false
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

    Text {
        id: label
        anchors.centerIn: parent
        text: root.volumeIcon() + " " + root.volumePercent() + "%"
        color: root.muted ? root.mutedColor : root.textColor
        font.family: root.fontFamily
        font.pixelSize: 14
        font.weight: Font.Medium
        renderType: Text.NativeRendering
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: root.bottomBorderColor
    }

    AudioDeviceMenu {
        id: deviceMenu

        visible: root.menuVisible
        microphoneMode: root.microphoneMode
        anchor.item: root
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        backgroundColor: root.backgroundColor
        hoverColor: root.menuHoverColor
        textColor: root.textColor
        mutedTextColor: root.mutedTextColor
        borderColor: root.menuBorderColor
        separatorColor: root.menuSeparatorColor
        fontFamily: root.fontFamily
        onCloseRequested: root.menuVisible = false
    }

    PopupWindow {
        id: volumePopup

        anchor.item: root
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        visible: root.popupVisible && root.audioReady && !root.menuVisible
        implicitWidth: frame.implicitWidth
        implicitHeight: frame.implicitHeight
        color: "transparent"
        grabFocus: false

        Rectangle {
            id: frame

            anchors.fill: parent
            implicitWidth: Math.max(220, Math.min(380, content.implicitWidth + 24))
            implicitHeight: content.implicitHeight + 14
            color: root.backgroundColor
            border.width: 1
            border.color: root.popupBorderColor
            radius: 5

            HoverHandler {
                onHoveredChanged: {
                    if (hovered)
                        root.openPopup()
                    else
                        root.schedulePopupClose()
                }
            }

            ColumnLayout {
                id: content

                anchors.fill: parent
                anchors.topMargin: 7
                anchors.bottomMargin: 7
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 0

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: 3
                    text: root.volumeIcon() + "  "
                        + (root.microphoneMode ? "Микрофон" : "Громкость")
                        + "  " + root.volumePercent() + "%"
                    color: root.muted ? root.mutedColor : root.textColor
                    font.family: root.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    renderType: Text.NativeRendering
                }

                Item {
                    id: sliderArea

                    Layout.fillWidth: true
                    Layout.preferredHeight: 22

                    Rectangle {
                        id: volumeTrack
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 6
                        radius: 3
                        color: root.trackColor

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: Math.max(0, Math.min(parent.width, parent.width * root.volumeValue))
                            radius: 3
                            color: root.muted ? root.mutedColor : root.textColor
                        }

                        Rectangle {
                            width: 12
                            height: 12
                            radius: 6
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(parent.width - width,
                                parent.width * root.volumeValue - width / 2))
                            color: root.muted ? root.mutedColor : root.textColor
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.sliderEnabled
                        acceptedButtons: Qt.LeftButton
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.openPopup()
                        onExited: root.schedulePopupClose()
                        onPressed: mouse => root.setVolumeFromPosition(mouse.x, width)
                        onPositionChanged: mouse => {
                            if (pressed)
                                root.setVolumeFromPosition(mouse.x, width)
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        id: buttonMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        onEntered: root.openPopup()
        onExited: root.schedulePopupClose()

        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                Quickshell.execDetached(["kitty", "pulsemixer"])
            else if (mouse.button === Qt.RightButton)
                root.toggleMenu()
            else if (mouse.button === Qt.MiddleButton && root.audioReady)
                root.audioNode.audio.muted = !root.audioNode.audio.muted
        }

        onWheel: wheel => {
            if (!root.audioReady)
                return
            const direction = wheel.angleDelta.y > 0 ? 1 : -1
            root.audioNode.audio.volume = Math.max(0,
                Math.min(1.5, root.audioNode.audio.volume + direction * 0.05))
            wheel.accepted = true
        }
    }

    Behavior on color {
        ColorAnimation { duration: 100 }
    }
}
