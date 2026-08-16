import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.WindowManager

PanelWindow {
    id: bar

    required property var targetScreen
    required property bool lightTheme
    required property int cpuUsage
    required property int memoryUsage
    required property real loadOne
    required property real loadFive
    required property real loadFifteen
    required property int memoryUsedKiB
    required property int memoryTotalKiB
    required property string audioOutputType
    property var workspaceProjection: WindowManager.screenProjection(targetScreen)
    property string networkName: "offline"
    property bool networkConnected: false
    property string keyboardLayout: "--"
    property var keyboardLayoutNames: []
    property var activeMprisPlayer: {
        const players = Mpris.players.values
        if (!players || players.length === 0)
            return null
        for (let i = 0; i < players.length; i++) {
            if (players[i].isPlaying)
                return players[i]
        }
        return players[0]
    }
    property date currentDate: new Date()

    // Flexoki Light/Dark — mirrors the user's Waybar palettes.
    readonly property color bg: lightTheme ? "#fffcf0" : "#100f0f"
    readonly property color bg2: lightTheme ? "#f2f0e5" : "#1c1b1a"
    readonly property color ui: lightTheme ? "#e6e4d9" : "#282726"
    readonly property color ui3: lightTheme ? "#cecdc3" : "#403e3c"
    readonly property color tx3: lightTheme ? "#b7b5ac" : "#575653"
    readonly property color text: lightTheme ? "#100f0f" : "#cecdc3"
    readonly property color muted: lightTheme ? "#6f6a69" : "#878580"
    readonly property color red: lightTheme ? "#af3029" : "#d14d41"
    readonly property color orange: lightTheme ? "#bc5215" : "#da702c"
    readonly property color yellow: lightTheme ? "#ad8301" : "#d0a215"
    readonly property color green: lightTheme ? "#66800b" : "#879a39"
    readonly property color blue: lightTheme ? "#205ea6" : "#4385be"
    readonly property color purple: lightTheme ? "#5e409d" : "#8b7ec8"

    function workspaceNumber(workspace) {
        const number = parseInt(workspace.name)
        if (!isNaN(number))
            return number
        if (workspace.coordinates && workspace.coordinates.length > 0)
            return workspace.coordinates[workspace.coordinates.length - 1] + 1
        return 999
    }

    function sortedWorkspaces() {
        if (!workspaceProjection)
            return []
        const result = []
        const workspaces = workspaceProjection.windowsets
        for (let i = 0; i < workspaces.length; i++) {
            if (workspaces[i].shouldDisplay)
                result.push(workspaces[i])
        }
        result.sort((left, right) => workspaceNumber(left) - workspaceNumber(right))
        return result
    }

    function formatGiB(kibibytes) {
        return (Math.max(0, kibibytes) / 1048576).toFixed(1)
    }

    function volumePercent() {
        const sink = Pipewire.defaultAudioSink
        return sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0
    }

    function volumeIcon() {
        const sink = Pipewire.defaultAudioSink
        if (!sink || !sink.audio || sink.audio.muted)
            return ""
        const value = volumePercent()
        return value < 34 ? "" : (value < 67 ? "" : "")
    }

    function microphonePercent() {
        const source = Pipewire.defaultAudioSource
        return source && source.audio ? Math.round(source.audio.volume * 100) : 0
    }

    function microphoneIcon() {
        const source = Pipewire.defaultAudioSource
        return !source || !source.audio || source.audio.muted ? "" : ""
    }

    function updateKeyboardLayout(rawText) {
        try {
            const event = JSON.parse(rawText)
            if (event.KeyboardLayoutsChanged) {
                const state = event.KeyboardLayoutsChanged.keyboard_layouts
                keyboardLayoutNames = state.names || []
                setKeyboardLayoutName(keyboardLayoutNames[state.current_idx] || "")
                return
            }

            if (event.KeyboardLayoutSwitched) {
                const index = event.KeyboardLayoutSwitched.idx
                setKeyboardLayoutName(keyboardLayoutNames[index] || "")
                return
            }

            if (event.names && event.current_idx !== undefined) {
                keyboardLayoutNames = event.names
                setKeyboardLayoutName(keyboardLayoutNames[event.current_idx] || "")
            }
        } catch (error) {
            keyboardLayout = "--"
        }
    }

    function setKeyboardLayoutName(name) {
        if (name.indexOf("English") !== -1)
            keyboardLayout = "US"
        else if (name.indexOf("Russian") !== -1)
            keyboardLayout = "RU"
        else if (name.indexOf("Kazakh") !== -1)
            keyboardLayout = "KZ"
        else
            keyboardLayout = name.substring(0, 2).toUpperCase() || "--"
    }

    function keyboardLayoutColor() {
        if (keyboardLayout === "US") return red
        if (keyboardLayout === "RU") return blue
        if (keyboardLayout === "KZ") return yellow
        return muted
    }

    function updateNetwork(rawText) {
        const lines = rawText.trim().split("\n")
        for (let i = 0; i < lines.length; i++) {
            const fields = lines[i].split(":")
            if ((fields[0] === "wifi" || fields[0] === "ethernet") && fields[1] === "connected") {
                networkConnected = true
                networkName = fields.slice(2).join(":") || fields[0]
                return
            }
        }
        networkConnected = false
        networkName = "offline"
    }

    function networkIcon() {
        if (!networkConnected)
            return "󰤭"
        return networkName === "ethernet" ? "" : ""
    }

    function powerProfileIcon() {
        switch (PowerProfiles.profile) {
        case PowerProfile.Performance:
            return ""
        case PowerProfile.PowerSaver:
            return ""
        default:
            return ""
        }
    }

    function powerProfileColor() {
        switch (PowerProfiles.profile) {
        case PowerProfile.Performance:
            return red
        case PowerProfile.PowerSaver:
            return green
        default:
            return text
        }
    }

    function cyclePowerProfile() {
        if (PowerProfiles.profile === PowerProfile.Performance)
            PowerProfiles.profile = PowerProfile.PowerSaver
        else if (PowerProfiles.profile === PowerProfile.PowerSaver)
            PowerProfiles.profile = PowerProfile.Balanced
        else if (PowerProfiles.hasPerformanceProfile)
            PowerProfiles.profile = PowerProfile.Performance
        else
            PowerProfiles.profile = PowerProfile.PowerSaver
    }

    function batteryPercent() {
        const battery = UPower.displayDevice
        if (!battery || !battery.ready)
            return 0
        return Math.round(battery.percentage <= 1 ? battery.percentage * 100 : battery.percentage)
    }

    function batteryCharging() {
        const battery = UPower.displayDevice
        return battery && battery.iconName.indexOf("charging") !== -1
    }

    function batteryIcon() {
        if (batteryCharging())
            return "󰂄"
        const value = batteryPercent()
        if (value >= 90) return "󰁹"
        if (value >= 80) return "󰂂"
        if (value >= 70) return "󰂁"
        if (value >= 60) return "󰂀"
        if (value >= 50) return "󰁿"
        if (value >= 40) return "󰁾"
        if (value >= 30) return "󰁽"
        if (value >= 20) return "󰁼"
        if (value >= 10) return "󰁻"
        return "󰂎"
    }

    function batteryColor() {
        if (batteryCharging())
            return green
        const value = batteryPercent()
        return value <= 15 ? red : (value <= 30 ? orange : text)
    }

    screen: targetScreen
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 28
    color: bg

    PwObjectTracker {
        objects: {
            const nodes = []
            if (Pipewire.defaultAudioSink)
                nodes.push(Pipewire.defaultAudioSink)
            if (Pipewire.defaultAudioSource)
                nodes.push(Pipewire.defaultAudioSource)
            return nodes
        }
    }

    Process {
        id: networkProcess
        command: ["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "device", "status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: bar.updateNetwork(text)
        }
    }

    Process {
        id: keyboardLayoutProcess
        command: ["niri", "msg", "--json", "event-stream"]
        running: true
        stdout: SplitParser {
            onRead: data => bar.updateKeyboardLayout(data)
        }
    }

    Timer {
        interval: 3000
        repeat: true
        running: true
        onTriggered: networkProcess.running = true
    }


    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: bar.currentDate = new Date()
    }

    Rectangle {
        anchors.fill: parent
        color: bg

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: ui3
        }

        RowLayout {
            id: leftSection
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            StatusItem {
                text: ""
                foreground: bar.text
                hoverForeground: bg
                background: bg
                hoverBackground: bar.text
                bottomBorderColor: ui3
                horizontalPadding: 10
                onPressed: button => {
                    if (button === Qt.LeftButton)
                        Quickshell.execDetached(["fuzzel"])
                    else if (button === Qt.MiddleButton)
                        Quickshell.execDetached(["/home/yerza/.local/bin/toggle-theme-script.sh"])
                }
            }

            RowLayout {
                spacing: 2

                Repeater {
                    model: bar.sortedWorkspaces()

                    delegate: WorkspaceButton {
                        required property var modelData
                        workspace: modelData
                        backgroundColor: bg
                        hoverColor: bg2
                        textColor: bar.text
                        mutedColor: muted
                        urgentColor: red
                        bottomBorderColor: ui3
                    }
                }
            }

            MprisItem {
                player: bar.activeMprisPlayer
                backgroundColor: bg
                hoverColor: bg2
                textColor: bar.text
                mutedBorderColor: tx3
                spotifyColor: green
                browserColor: orange
                chromiumColor: blue
                bottomBorderColor: ui3
            }
        }

        Rectangle {
            anchors.centerIn: parent
            implicitWidth: clockText.implicitWidth + 12
            implicitHeight: 28
            radius: 3
            color: bg

            Text {
                id: clockText
                anchors.centerIn: parent
                text: Qt.formatDateTime(bar.currentDate, "ddd, dd MMM  ·  HH:mm:ss")
                color: bar.text
                font.family: "IosevkaTerm Nerd Font Propo"
                font.pixelSize: 14
                font.weight: Font.Medium
                renderType: Text.NativeRendering
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: ui3
            }
        }

        RowLayout {
            id: rightSection
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            StatusItem {
                text: " " + bar.cpuUsage + "%"
                foreground: bar.text
                background: bg
                hoverBackground: bg2
                bottomBorderColor: ui3
                tooltipTitle: "  CPU"
                tooltipText: "Использование: " + bar.cpuUsage + "%"
                    + "\nLoad average: " + bar.loadOne.toFixed(2)
                    + " · " + bar.loadFive.toFixed(2)
                    + " · " + bar.loadFifteen.toFixed(2)
                tooltipBackground: bg
                tooltipBorderColor: tx3
                tooltipTextColor: bar.text
                onPressed: button => {
                    if (button === Qt.LeftButton)
                        Quickshell.execDetached(["kitty", "--start-as=fullscreen", "btop"])
                }
            }

            StatusItem {
                text: " " + bar.memoryUsage + "%"
                foreground: bar.text
                background: bg
                hoverBackground: bg2
                bottomBorderColor: ui3
                tooltipTitle: "  RAM"
                tooltipText: "Использовано: " + bar.formatGiB(bar.memoryUsedKiB)
                    + " / " + bar.formatGiB(bar.memoryTotalKiB) + " GiB"
                    + "\nДоступно: "
                    + bar.formatGiB(bar.memoryTotalKiB - bar.memoryUsedKiB) + " GiB"
                tooltipBackground: bg
                tooltipBorderColor: tx3
                tooltipTextColor: bar.text
                onPressed: button => {
                    if (button === Qt.LeftButton)
                        Quickshell.execDetached(["kitty", "--start-as=fullscreen", "btop"])
                }
            }

            StatusItem {
                text: "󰌌 " + bar.keyboardLayout
                foreground: bar.keyboardLayoutColor()
                background: bg
                hoverBackground: bg2
                bottomBorderColor: ui3
                onPressed: button => {
                    if (button === Qt.LeftButton)
                        Quickshell.execDetached(["niri", "msg", "action", "switch-layout", "next"])
                    else if (button === Qt.RightButton)
                        Quickshell.execDetached(["niri", "msg", "action", "switch-layout", "prev"])
                }
            }

            VolumeItem {
                audioNode: Pipewire.defaultAudioSink
                outputType: bar.audioOutputType
                backgroundColor: bg
                hoverColor: bg2
                textColor: bar.text
                mutedColor: red
                trackColor: ui3
                popupBorderColor: tx3
                bottomBorderColor: ui3
            }

            VolumeItem {
                audioNode: Pipewire.defaultAudioSource
                microphoneMode: true
                backgroundColor: bg
                hoverColor: bg2
                textColor: bar.text
                mutedColor: red
                trackColor: ui3
                popupBorderColor: tx3
                bottomBorderColor: ui3
            }

            StatusItem {
                text: bar.networkIcon()
                foreground: bar.networkConnected ? bar.text : bg
                background: bar.networkConnected ? bg : red
                hoverBackground: bar.networkConnected ? bg2 : red
                bottomBorderColor: ui3
                onPressed: button => {
                    if (button === Qt.LeftButton)
                        Quickshell.execDetached(["kitty", "nmtui"])
                }
            }

            StatusItem {
                readonly property var adapter: Bluetooth.defaultAdapter
                readonly property int connectedCount: adapter && adapter.devices ? adapter.devices.values.filter(device => device.connected).length : 0
                text: adapter && adapter.enabled ? ("" + (connectedCount > 0 ? " " + connectedCount : "")) : "󰂲"
                foreground: adapter && adapter.enabled ? blue : muted
                background: bg
                hoverBackground: bg2
                bottomBorderColor: ui3
                onPressed: button => {
                    if (button === Qt.LeftButton)
                        Quickshell.execDetached(["kitty", "bluetui"])
                    else if (button === Qt.MiddleButton && adapter)
                        adapter.enabled = !adapter.enabled
                }
            }

            StatusItem {
                text: bar.powerProfileIcon()
                foreground: bar.powerProfileColor()
                background: bg
                hoverBackground: bg2
                bottomBorderColor: ui3
                onPressed: button => {
                    if (button === Qt.LeftButton)
                        bar.cyclePowerProfile()
                }
            }

            RowLayout {
                spacing: 1

                Repeater {
                    model: SystemTray.items

                    delegate: TrayItem {
                        required property var modelData
                        trayItem: modelData
                        parentWindow: bar
                        backgroundColor: bg
                        hoverColor: bg2
                        bottomBorderColor: ui3
                    }
                }
            }

            StatusItem {
                id: batteryItem
                readonly property bool ready: UPower.displayDevice
                    && UPower.displayDevice.ready
                readonly property bool warning: ready && !bar.batteryCharging()
                    && bar.batteryPercent() > 15
                    && bar.batteryPercent() <= 30
                readonly property bool critical: ready && !bar.batteryCharging()
                    && bar.batteryPercent() >= 0
                    && bar.batteryPercent() <= 15
                readonly property bool alertActive: warning || critical
                readonly property color alertColor: critical ? red : orange
                property bool alertInverted: false
                text: bar.batteryPercent() + "% " + bar.batteryIcon()
                foreground: alertActive ? (alertInverted ? alertColor : "#100f0f")
                    : (bar.batteryCharging() ? bg : bar.batteryColor())
                background: bar.batteryCharging() ? green
                    : (alertActive ? (alertInverted ? "#100f0f" : alertColor) : bg)
                hoverBackground: background
                bottomBorderColor: ui3
                horizontalPadding: 6

                onAlertActiveChanged: {
                    if (!alertActive)
                        alertInverted = false
                }

                Timer {
                    interval: batteryItem.critical ? 380 : 500
                    repeat: true
                    running: batteryItem.alertActive
                    onTriggered: batteryItem.alertInverted = !batteryItem.alertInverted
                }
            }
        }
    }
}
