import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

Rectangle {
    id: card

    required property var notification
    required property bool lightTheme
    required property color bg
    required property color bg2
    required property color ui
    required property color ui2
    required property color ui3
    required property color tx
    required property color tx2
    required property color red
    required property color orange
    required property color blue

    property int remainingMs: timeoutFor(notification)
    readonly property bool hovered: cardHover.hovered
    readonly property color accent: notification.urgency === NotificationUrgency.Critical
                                    ? red
                                    : (notification.urgency === NotificationUrgency.Low ? tx2 : blue)
    readonly property string iconSource: resolveIcon(notification)

    function timeoutFor(item) {
        if (item.expireTimeout > 0)
            return Math.max(1000, Math.min(15000, item.expireTimeout))
        return item.urgency === NotificationUrgency.Critical ? 10000 : 5000
    }

    function resolveIcon(item) {
        if (item.image)
            return item.image
        if (item.appIcon) {
            if (String(item.appIcon).indexOf("/") !== -1 || String(item.appIcon).indexOf("file:") === 0)
                return item.appIcon
            return Quickshell.iconPath(item.appIcon, true)
        }
        return ""
    }

    implicitHeight: content.implicitHeight + 28
    radius: 5
    color: bg
    border.width: 1
    border.color: ui3
    clip: true

    Rectangle {
        width: 10
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        color: card.accent
        topLeftRadius: 5
        bottomLeftRadius: 5
        topRightRadius: 0
        bottomRightRadius: 0
    }

    RowLayout {
        id: content
        anchors.fill: parent
        anchors.leftMargin: 22
        anchors.rightMargin: 16
        anchors.topMargin: 14
        anchors.bottomMargin: 14
        spacing: 12

        Rectangle {
            visible: card.iconSource.length > 0
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: visible ? 60 : 0
            Layout.preferredHeight: visible ? 60 : 0
            radius: 5
            color: card.bg2
            border.width: 1
            border.color: card.ui

            Image {
                anchors.centerIn: parent
                width: 50
                height: 50
                source: card.iconSource
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                sourceSize.width: 55
                sourceSize.height: 55
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: card.notification.appName || "Уведомление"
                    color: card.tx2
                    font.family: "IosevkaTerm Nerd Font Propo"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Text {
                    text: card.notification.urgency === NotificationUrgency.Critical ? "СРОЧНО" : ""
                    visible: text.length > 0
                    color: card.red
                    font.family: "IosevkaTerm Nerd Font Propo"
                    font.pixelSize: 10
                    font.weight: Font.Bold
                }

                Rectangle {
                    width: 24
                    height: 24
                    radius: 7
                    color: closeArea.containsMouse ? card.ui2 : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        color: card.tx2
                        font.family: "IosevkaTerm Nerd Font Propo"
                        font.pixelSize: 15
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.notification.dismiss()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: card.notification.summary || "Без заголовка"
                color: card.tx
                font.family: "IosevkaTerm Nerd Font Propo"
                font.pixelSize: 15
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: card.notification.body || ""
                color: card.tx2
                font.family: "IosevkaTerm Nerd Font Propo"
                font.pixelSize: 13
                lineHeight: 1.18
                wrapMode: Text.Wrap
                maximumLineCount: 5
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }

            Flow {
                Layout.fillWidth: true
                visible: card.notification.actions.length > 0
                spacing: 7

                Repeater {
                    model: card.notification.actions

                    delegate: Rectangle {
                        required property var modelData
                        height: 29
                        width: Math.min(180, actionLabel.implicitWidth + 22)
                        radius: 8
                        color: actionArea.containsMouse ? card.accent : card.bg2
                        border.width: 1
                        border.color: actionArea.containsMouse ? card.accent : card.ui3

                        Text {
                            id: actionLabel
                            anchors.centerIn: parent
                            width: Math.min(158, implicitWidth)
                            text: modelData.text
                            color: actionArea.containsMouse ? card.bg : card.tx
                            font.family: "IosevkaTerm Nerd Font Propo"
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }

                        MouseArea {
                            id: actionArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                modelData.invoke()
                                if (!card.notification.resident)
                                    card.notification.dismiss()
                            }
                        }
                    }
                }
            }
        }
    }

    HoverHandler {
        id: cardHover
    }

    Timer {
        interval: 100
        repeat: true
        running: card.notification && !card.notification.resident
        onTriggered: {
            if (card.hovered)
                return
            card.remainingMs -= interval
            if (card.remainingMs <= 0) {
                stop()
                card.notification.expire()
            }
        }
    }
}
