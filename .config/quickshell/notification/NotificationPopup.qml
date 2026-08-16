import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

PanelWindow {
    id: popup

    required property bool lightTheme
    required property var notifications

    readonly property int cardWidth: 460
    readonly property int cardGap: 10
    readonly property int outerMargin: 14

    readonly property color bg: lightTheme ? "#fffcf0" : "#100f0f"
    readonly property color bg2: lightTheme ? "#f2f0e5" : "#1c1b1a"
    readonly property color ui: lightTheme ? "#e6e4d9" : "#282726"
    readonly property color ui2: lightTheme ? "#dad8ce" : "#343331"
    readonly property color ui3: lightTheme ? "#cecdc3" : "#403e3c"
    readonly property color tx: lightTheme ? "#100f0f" : "#cecdc3"
    readonly property color tx2: lightTheme ? "#6f6a69" : "#878580"
    readonly property color red: lightTheme ? "#af3029" : "#d14d41"
    readonly property color orange: lightTheme ? "#bc5215" : "#da702c"
    readonly property color blue: lightTheme ? "#205ea6" : "#4385be"

    anchors.top: true
    anchors.right: true
    margins.top: outerMargin
    margins.right: outerMargin
    implicitWidth: cardWidth
    implicitHeight: Math.max(1, notificationColumn.implicitHeight)
    color: "transparent"
    aboveWindows: true
    focusable: false
    exclusionMode: ExclusionMode.Ignore
    mask: Region { item: notificationColumn }

    Column {
        id: notificationColumn
        width: popup.cardWidth
        spacing: popup.cardGap

        Repeater {
            model: popup.notifications

            delegate: NotificationCard {
                required property var modelData
                width: popup.cardWidth
                notification: modelData
                lightTheme: popup.lightTheme
                bg: popup.bg
                bg2: popup.bg2
                ui: popup.ui
                ui2: popup.ui2
                ui3: popup.ui3
                tx: popup.tx
                tx2: popup.tx2
                red: popup.red
                orange: popup.orange
                blue: popup.blue
            }
        }
    }
}
