import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

ShellRoot {
    id: root

    property bool lightTheme: false
    property var hoveredNotifications: []

    function updateTheme(value) {
        const setting = String(value).trim()
        if (setting.length > 0)
            lightTheme = setting.indexOf("prefer-dark") === -1
    }

    function setNotificationHovered(notification, hovered) {
        const notifications = hoveredNotifications.slice()
        const index = notifications.indexOf(notification)

        if (hovered && index === -1) {
            notifications.push(notification)
            hoveredNotifications = notifications
        } else if (!hovered && index !== -1) {
            notifications.splice(index, 1)
            hoveredNotifications = notifications
        }
    }

    Process {
        command: ["gsettings", "get", "org.gnome.desktop.interface", "color-scheme"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.updateTheme(text)
        }
    }

    Process {
        command: ["gsettings", "monitor", "org.gnome.desktop.interface", "color-scheme"]
        running: true
        stdout: SplitParser {
            onRead: data => root.updateTheme(data)
        }
    }

    NotificationServer {
        id: notificationServer
        keepOnReload: true
        persistenceSupported: false
        bodySupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: true
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true
        inlineReplySupported: false

        onNotification: notification => {
            notification.tracked = true
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: NotificationPopup {
            required property var modelData
            targetScreen: modelData
            lightTheme: root.lightTheme
            notifications: notificationServer.trackedNotifications
            hoveredNotifications: root.hoveredNotifications
            onNotificationHoverChanged: (notification, hovered) =>
                root.setNotificationHovered(notification, hovered)
        }
    }
}
