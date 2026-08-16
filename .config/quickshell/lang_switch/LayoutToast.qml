import QtQuick
import Quickshell

PanelWindow {
    id: toastWindow

    required property var targetScreen
    required property bool lightTheme

    property string languageName: ""
    property string languageCode: "--"

    readonly property color backgroundColor: lightTheme ? "#fffcf0" : "#1c1b1a"
    readonly property color borderColor: lightTheme ? "#cecdc3" : "#403e3c"
    readonly property color primaryTextColor: lightTheme ? "#100f0f" : "#cecdc3"
    readonly property color secondaryTextColor: lightTheme ? "#6f6a69" : "#878580"
    readonly property color accentColor: {
        if (languageCode === "EN") return lightTheme ? "#af3029" : "#d14d41"
        if (languageCode === "RU") return lightTheme ? "#205ea6" : "#4385be"
        if (languageCode === "KZ") return lightTheme ? "#ad8301" : "#d0a215"
        return lightTheme ? "#5e409d" : "#8b7ec8"
    }

    function showLanguage(name, code) {
        languageName = name
        languageCode = code
        toastAnimation.stop()
        toastCard.opacity = 0
        toastCard.scale = 0.94
        toastAnimation.start()
    }

    screen: targetScreen
    anchors.bottom: true
    margins.bottom: 64
    implicitWidth: 310
    implicitHeight: 68
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: false

    // The toast is informational and must never intercept pointer input.
    mask: Region {}

    Rectangle {
        id: toastCard

        anchors.fill: parent
        opacity: 0
        scale: 0.94
        radius: 12
        color: toastWindow.backgroundColor
        border.width: 1
        border.color: toastWindow.borderColor

        Rectangle {
            id: codeBadge

            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            height: 44
            radius: 10
            color: toastWindow.accentColor

            Text {
                anchors.centerIn: parent
                text: toastWindow.languageCode
                color: toastWindow.lightTheme ? "#fffcf0" : "#100f0f"
                font.family: "IosevkaTerm Nerd Font Propo"
                font.pixelSize: 16
                font.weight: Font.Bold
                renderType: Text.NativeRendering
            }
        }

        Text {
            anchors.left: codeBadge.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.top: parent.top
            anchors.topMargin: 11
            text: "Язык переключён"
            color: toastWindow.secondaryTextColor
            font.family: "IosevkaTerm Nerd Font Propo"
            font.pixelSize: 12
            font.weight: Font.Medium
            renderType: Text.NativeRendering
        }

        Text {
            anchors.left: codeBadge.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            text: toastWindow.languageName
            color: toastWindow.primaryTextColor
            elide: Text.ElideRight
            font.family: "IosevkaTerm Nerd Font Propo"
            font.pixelSize: 16
            font.weight: Font.DemiBold
            renderType: Text.NativeRendering
        }
    }

    SequentialAnimation {
        id: toastAnimation

        ParallelAnimation {
            NumberAnimation {
                target: toastCard
                property: "opacity"
                from: 0
                to: 1
                duration: 140
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: toastCard
                property: "scale"
                from: 0.94
                to: 1
                duration: 180
                easing.type: Easing.OutBack
            }
        }

        PauseAnimation { duration: 1450 }

        NumberAnimation {
            target: toastCard
            property: "opacity"
            from: 1
            to: 0
            duration: 220
            easing.type: Easing.InCubic
        }
    }
}
