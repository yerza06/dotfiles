import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

// Окно звука по ПКМ на VolumeItem: шапка с текущим устройством по умолчанию
// и кнопкой mute, полоса громкости с процентом и список устройств для
// переключения. Один и тот же компонент обслуживает вывод и микрофон —
// разницу задаёт microphoneMode.
// Как окна плеера, батареи и сети, окно «липкое»: grabFocus отдаёт ему
// клавиатуру и заставляет композитор закрыть его по клику мимо, поэтому
// таймера автозакрытия по уходу курсора здесь нет — в отличие от меню панели.
PopupWindow {
    id: popupRoot

    // Узел PipeWire считает VolumeItem — панель и окно должны показывать
    // ровно одно и то же.
    property var node: null
    property bool microphoneMode: false
    // Глиф из VolumeItem: он учитывает тип выхода (наушники, HDMI) и mute.
    property string icon: ""
    property color backgroundColor: "#100f0f"
    property color hoverColor: "#282726"
    property color textColor: "#cecdc3"
    property color mutedTextColor: "#878580"
    property color borderColor: "#575653"
    property color separatorColor: "#403e3c"
    property color trackColor: "#282726"
    property color accentColor: "#4385be"
    property color mutedColor: "#d14d41"
    property string fontFamily: "IosevkaTerm Nerd Font Propo"

    signal closeRequested()

    readonly property bool audioReady: node !== null && node.audio !== null
    readonly property real volumeValue: audioReady ? node.audio.volume : 0
    readonly property bool muted: !audioReady || node.audio.muted

    readonly property var currentNode: microphoneMode
        ? Pipewire.defaultAudioSource
        : Pipewire.defaultAudioSink

    // Реальные устройства, без потоков приложений. Флаги проверяются побитово,
    // чтобы дуплексные карты попадали и в вывод, и в ввод.
    readonly property var deviceNodes: {
        const result = []
        const all = Pipewire.nodes ? Pipewire.nodes.values : []
        const wanted = microphoneMode ? PwNodeType.AudioSource : PwNodeType.AudioSink
        for (let i = 0; i < all.length; i++) {
            const item = all[i]
            if ((item.type & PwNodeType.Stream) !== 0)
                continue
            if ((item.type & wanted) !== wanted)
                continue
            result.push(item)
        }
        return result
    }

    function volumePercent() {
        return Math.round(volumeValue * 100)
    }

    function deviceName(target) {
        if (!target)
            return ""
        return target.description || target.nickname || target.name || ""
    }

    function selectDevice(target) {
        if (!target)
            return
        if (microphoneMode)
            Pipewire.preferredDefaultAudioSource = target
        else
            Pipewire.preferredDefaultAudioSink = target
    }

    function toggleMute() {
        if (audioReady)
            node.audio.muted = !node.audio.muted
    }

    function setVolumeFromPosition(position, availableWidth) {
        if (!audioReady || availableWidth <= 0)
            return
        node.audio.volume = Math.max(0, Math.min(1, position / availableWidth))
    }

    function nudgeVolume(step) {
        if (!audioReady)
            return
        node.audio.volume = Math.max(0, Math.min(1, node.audio.volume + step))
    }

    function handleKey(event) {
        switch (event.key) {
        case Qt.Key_Escape:
            popupRoot.closeRequested()
            break
        case Qt.Key_Space:
        case Qt.Key_M:
            popupRoot.toggleMute()
            break
        case Qt.Key_Left:
            popupRoot.nudgeVolume(-0.05)
            break
        case Qt.Key_Right:
            popupRoot.nudgeVolume(0.05)
            break
        default:
            return
        }

        event.accepted = true
    }

    implicitWidth: frame.implicitWidth
    implicitHeight: frame.implicitHeight
    color: "transparent"
    grabFocus: true

    onVisibleChanged: {
        if (visible)
            frame.forceActiveFocus()
    }

    PwObjectTracker {
        objects: popupRoot.deviceNodes
    }

    Rectangle {
        id: frame

        anchors.fill: parent
        // Ширина фиксированная: иначе окно прыгало бы при каждой смене
        // устройства — их названия сильно разной длины.
        implicitWidth: 320
        implicitHeight: content.implicitHeight + 24
        color: popupRoot.backgroundColor
        border.width: 1
        border.color: popupRoot.borderColor
        radius: 5
        focus: true

        Keys.onPressed: event => popupRoot.handleKey(event)

        ColumnLayout {
            id: content

            anchors.fill: parent
            anchors.topMargin: 12
            anchors.bottomMargin: 12
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: popupRoot.icon
                    color: popupRoot.muted ? popupRoot.mutedColor : popupRoot.textColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 26
                    renderType: Text.NativeRendering
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: popupRoot.deviceName(popupRoot.currentNode)
                            || "Устройство не выбрано"
                        color: popupRoot.textColor
                        font.family: popupRoot.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }

                    Text {
                        Layout.fillWidth: true
                        text: popupRoot.microphoneMode
                            ? "Устройство ввода" : "Устройство вывода"
                        color: popupRoot.mutedTextColor
                        font.family: popupRoot.fontFamily
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }
                }

                MprisControlButton {
                    text: {
                        if (popupRoot.microphoneMode)
                            return popupRoot.muted ? "" : ""
                        return popupRoot.muted ? "" : ""
                    }
                    size: 30
                    pixelSize: 15
                    active: popupRoot.muted
                    available: popupRoot.audioReady
                    backgroundColor: popupRoot.backgroundColor
                    hoverColor: popupRoot.hoverColor
                    textColor: popupRoot.textColor
                    mutedTextColor: popupRoot.separatorColor
                    accentColor: popupRoot.mutedColor
                    fontFamily: popupRoot.fontFamily
                    onActivated: popupRoot.toggleMute()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Item {
                    id: sliderArea

                    Layout.fillWidth: true
                    Layout.preferredHeight: 18

                    Rectangle {
                        id: volumeTrack

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 6
                        radius: 3
                        color: popupRoot.trackColor

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            // Колесо мыши пускает громкость выше 100%, поэтому
                            // заливка отдельно ограничена шириной дорожки.
                            width: Math.max(0, Math.min(parent.width,
                                parent.width * popupRoot.volumeValue))
                            radius: 3
                            color: popupRoot.muted
                                ? popupRoot.mutedColor : popupRoot.accentColor
                        }

                        Rectangle {
                            width: 12
                            height: 12
                            radius: 6
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(parent.width - width,
                                parent.width * popupRoot.volumeValue - width / 2))
                            color: popupRoot.muted
                                ? popupRoot.mutedColor : popupRoot.accentColor
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: popupRoot.audioReady
                        acceptedButtons: Qt.LeftButton
                        cursorShape: Qt.PointingHandCursor

                        onPressed: mouse => popupRoot.setVolumeFromPosition(mouse.x, width)
                        onPositionChanged: mouse => {
                            if (pressed)
                                popupRoot.setVolumeFromPosition(mouse.x, width)
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: popupRoot.microphoneMode ? "Микрофон" : "Громкость"
                        color: popupRoot.mutedTextColor
                        font.family: popupRoot.fontFamily
                        font.pixelSize: 11
                        renderType: Text.NativeRendering
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Text {
                        text: popupRoot.muted
                            ? "Выключен"
                            : popupRoot.volumePercent() + "%"
                        color: popupRoot.muted
                            ? popupRoot.mutedColor : popupRoot.mutedTextColor
                        font.family: popupRoot.fontFamily
                        font.pixelSize: 11
                        renderType: Text.NativeRendering
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: popupRoot.separatorColor
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    Layout.bottomMargin: 2
                    text: popupRoot.microphoneMode
                        ? "УСТРОЙСТВА ВВОДА" : "УСТРОЙСТВА ВЫВОДА"
                    color: popupRoot.mutedTextColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 10
                    font.letterSpacing: 1
                    renderType: Text.NativeRendering
                }

                Repeater {
                    model: popupRoot.deviceNodes

                    delegate: DeviceRow {
                        required property var modelData

                        node: modelData
                        current: modelData === popupRoot.currentNode
                        label: popupRoot.deviceName(modelData)
                        hoverColor: popupRoot.hoverColor
                        textColor: popupRoot.textColor
                        mutedTextColor: popupRoot.mutedTextColor
                        markColor: popupRoot.separatorColor
                        fontFamily: popupRoot.fontFamily
                        onActivated: popupRoot.selectDevice(modelData)
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 24
                    verticalAlignment: Text.AlignVCenter
                    visible: popupRoot.deviceNodes.length === 0
                    text: "Устройств не найдено"
                    color: popupRoot.mutedTextColor
                    font.family: popupRoot.fontFamily
                    font.pixelSize: 12
                    renderType: Text.NativeRendering
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: popupRoot.separatorColor
            }

            DeviceRow {
                showMark: false
                label: "Настройки звука…"
                labelColor: popupRoot.textColor
                hoverColor: popupRoot.hoverColor
                textColor: popupRoot.textColor
                mutedTextColor: popupRoot.mutedTextColor
                markColor: popupRoot.separatorColor
                fontFamily: popupRoot.fontFamily
                onActivated: {
                    Quickshell.execDetached(["pavucontrol"])
                    popupRoot.closeRequested()
                }
            }
        }
    }
}
