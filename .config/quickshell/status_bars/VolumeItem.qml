import QtQuick
import Quickshell

Rectangle {
    id: root

    required property var audioNode
    property color backgroundColor: "#100f0f"
    property color hoverColor: "#1c1b1a"
    property color textColor: "#cecdc3"
    property color mutedColor: "#d14d41"
    property color trackColor: "#403e3c"
    property color bottomBorderColor: "#403e3c"
    property string fontFamily: "IosevkaTerm Nerd Font Propo"
    property bool microphoneMode: false
    property color mutedTextColor: "#878580"
    property color popupHoverColor: "#282726"
    property color popupBorderColor: "#575653"
    property color popupSeparatorColor: "#403e3c"
    property color accentColor: "#4385be"
    // headphones | speaker | hdmi | unknown — приходит из scripts/audio-output.sh
    property string outputType: "speaker"

    readonly property bool popupVisible: audioPopup.visible

    // Момент последнего закрытия окна звука. Клик мимо, которым композитор
    // снимает захват, долетает и до самого виджета — без этой отсечки окно
    // тут же открылось бы снова.
    property double popupClosedAt: 0

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

    function togglePopup() {
        if (!audioPopup.visible && Date.now() - popupClosedAt < 200)
            return
        audioPopup.visible = !audioPopup.visible
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

    AudioPopup {
        id: audioPopup

        // visible выставляется только вручную: композитор закрывает окно сам,
        // и биндинг после первого такого закрытия сломался бы.
        visible: false
        anchor.item: root
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.bottom: 4
        node: root.audioNode
        microphoneMode: root.microphoneMode
        icon: root.volumeIcon()
        backgroundColor: root.backgroundColor
        hoverColor: root.popupHoverColor
        textColor: root.textColor
        mutedTextColor: root.mutedTextColor
        borderColor: root.popupBorderColor
        separatorColor: root.popupSeparatorColor
        trackColor: root.trackColor
        accentColor: root.accentColor
        mutedColor: root.mutedColor
        fontFamily: root.fontFamily

        onVisibleChanged: {
            if (!visible)
                root.popupClosedAt = Date.now()
        }
        onCloseRequested: audioPopup.visible = false
    }

    Tooltip {
        visible: buttonMouse.containsMouse && !root.popupVisible
        anchor.item: root
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.bottom: 4
        title: root.volumeIcon() + "  "
            + (root.microphoneMode ? "Микрофон" : "Громкость")
            + "  " + root.volumePercent() + "%"
        text: audioPopup.deviceName(audioPopup.currentNode)
            || "Устройство не выбрано"
        backgroundColor: root.backgroundColor
        borderColor: root.popupBorderColor
        titleColor: root.muted ? root.mutedColor : root.textColor
        textColor: root.mutedTextColor
        fontFamily: root.fontFamily
    }

    MouseArea {
        id: buttonMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.togglePopup()
            else if (mouse.button === Qt.MiddleButton)
                Quickshell.execDetached(["kitty", "pulsemixer"])
            else if (root.audioReady)
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
