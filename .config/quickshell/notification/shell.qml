import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

ShellRoot {
    id: root

    property bool lightTheme: false

    function updateTheme(value) {
        const setting = String(value).trim()
        if (setting.length > 0)
            lightTheme = setting.indexOf("prefer-dark") === -1
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

    NotificationPopup {
        lightTheme: root.lightTheme
        notifications: notificationServer.trackedNotifications
    }
}
