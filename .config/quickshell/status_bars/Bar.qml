import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Wayland
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
    property string keyboardLayout: "--"
    property var keyboardLayoutNames: []
    property string pinnedMprisPlayerId: ""
    readonly property var mprisPlayers: Mpris.players ? Mpris.players.values : []
    // Закреплённый плеер ищется по dbusName в живом списке, поэтому его выход
    // сам собой возвращает автовыбор.
    property var activeMprisPlayer: {
        const players = mprisPlayers
        if (!players || players.length === 0)
            return null
        if (pinnedMprisPlayerId.length > 0) {
            for (let i = 0; i < players.length; i++) {
                if (players[i].dbusName === pinnedMprisPlayerId)
                    return players[i]
            }
        }
        for (let i = 0; i < players.length; i++) {
            if (players[i].isPlaying)
                return players[i]
        }
        return players[0]
    }
    property date currentDate: new Date()

    signal pinPlayerRequested(string playerId)

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

    screen: targetScreen
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 28
    color: bg

    // Клавиатура нужна панели, только пока открыто «липкое» окно — календарь,
    // плеер или батарея: без фокуса до них не доходит Esc. OnDemand, а не
    // Exclusive — панель не должна перехватывать ввод у окон.
    WlrLayershell.keyboardFocus: clock.calendarVisible
        || mprisItem.popupVisible
        || batteryItem.popupVisible
        ? WlrKeyboardFocus.OnDemand
        : WlrKeyboardFocus.None

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
        id: keyboardLayoutProcess
        command: ["niri", "msg", "--json", "event-stream"]
        running: true
        stdout: SplitParser {
            onRead: data => bar.updateKeyboardLayout(data)
        }
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
                id: mprisItem

                player: bar.activeMprisPlayer
                players: bar.mprisPlayers
                pinnedPlayerId: bar.pinnedMprisPlayerId
                backgroundColor: bg
                hoverColor: bg2
                textColor: bar.text
                mutedTextColor: muted
                mutedBorderColor: tx3
                spotifyColor: green
                browserColor: orange
                chromiumColor: blue
                bottomBorderColor: ui3
                menuHoverColor: ui
                menuBorderColor: tx3
                menuSeparatorColor: ui3
                popupTrackColor: ui
                popupSeparatorColor: ui3
                onPinRequested: playerId => bar.pinPlayerRequested(playerId)
            }
        }

        ClockItem {
            id: clock

            anchors.centerIn: parent
            currentDate: bar.currentDate
            backgroundColor: bg
            hoverColor: bg2
            textColor: bar.text
            mutedTextColor: muted
            borderColor: tx3
            separatorColor: ui3
            bottomBorderColor: ui3
            menuHoverColor: ui
            accentColor: blue
            weekendColor: red
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
                tooltipMutedColor: bar.muted
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
                tooltipMutedColor: bar.muted
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
                mutedTextColor: bar.muted
                menuHoverColor: ui
                menuBorderColor: tx3
                menuSeparatorColor: ui3
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
                mutedTextColor: bar.muted
                menuHoverColor: ui
                menuBorderColor: tx3
                menuSeparatorColor: ui3
            }

            NetworkItem {
                backgroundColor: bg
                tooltipBorderColor: tx3
                hoverColor: bg2
                textColor: bar.text
                mutedTextColor: bar.muted
                offlineColor: red
                bottomBorderColor: ui3
                menuHoverColor: ui
                menuBorderColor: tx3
                menuSeparatorColor: ui3
            }

            BluetoothItem {
                backgroundColor: bg
                tooltipBorderColor: tx3
                hoverColor: bg2
                textColor: bar.text
                mutedTextColor: bar.muted
                activeColor: blue
                bottomBorderColor: ui3
                menuHoverColor: ui
                menuBorderColor: tx3
                menuSeparatorColor: ui3
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
                        menuTextColor: bar.text
                        menuHoverColor: ui
                        menuDisabledColor: tx3
                        menuBorderColor: tx3
                        menuSeparatorColor: ui3
                    }
                }
            }

            BatteryItem {
                id: batteryItem
                baseBackground: bg
                baseHoverBackground: bg2
                textColor: bar.text
                mutedTextColor: bar.muted
                popupHoverColor: ui
                popupBorderColor: tx3
                popupSeparatorColor: ui3
                popupTrackColor: ui
                greenColor: green
                orangeColor: orange
                redColor: red
                bottomBorderColor: ui3
                tooltipBackground: bg
                tooltipBorderColor: tx3
                tooltipTextColor: bar.text
                tooltipMutedColor: bar.muted
            }
        }
    }
}
