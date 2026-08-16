import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

// Меню выбора аудиоустройства в стиле Flexoki.
// Показывает только выходы или только входы — в зависимости от виджета.
PopupWindow {
    id: menuRoot

    property bool microphoneMode: false
    property color backgroundColor: "#100f0f"
    property color hoverColor: "#282726"
    property color textColor: "#cecdc3"
    property color mutedTextColor: "#878580"
    property color borderColor: "#575653"
    property color separatorColor: "#403e3c"
    property string fontFamily: "IosevkaTerm Nerd Font Propo"

    signal closeRequested()

    readonly property bool chainHovered: frameHover.hovered

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
            const node = all[i]
            if ((node.type & PwNodeType.Stream) !== 0)
                continue
            if ((node.type & wanted) !== wanted)
                continue
            result.push(node)
        }
        return result
    }

    function deviceName(node) {
        if (!node)
            return ""
        return node.description || node.nickname || node.name || ""
    }

    function selectDevice(node) {
        if (!node)
            return
        if (microphoneMode)
            Pipewire.preferredDefaultAudioSource = node
        else
            Pipewire.preferredDefaultAudioSink = node
        menuRoot.closeRequested()
    }

    implicitWidth: frame.implicitWidth
    implicitHeight: frame.implicitHeight
    color: "transparent"
    grabFocus: false

    PwObjectTracker {
        objects: menuRoot.deviceNodes
    }

    Rectangle {
        id: frame

        anchors.fill: parent
        implicitWidth: Math.max(200, Math.min(400, content.implicitWidth + 24))
        implicitHeight: content.implicitHeight + 12
        color: menuRoot.backgroundColor
        border.width: 1
        border.color: menuRoot.borderColor
        radius: 5

        HoverHandler {
            id: frameHover
        }

        ColumnLayout {
            id: content

            anchors.fill: parent
            anchors.topMargin: 6
            anchors.bottomMargin: 6
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 0

            Text {
                Layout.fillWidth: true
                Layout.bottomMargin: 2
                text: menuRoot.microphoneMode ? "Устройство ввода" : "Устройство вывода"
                color: menuRoot.mutedTextColor
                font.family: menuRoot.fontFamily
                font.pixelSize: 11
                font.weight: Font.Medium
                renderType: Text.NativeRendering
            }

            Repeater {
                model: menuRoot.deviceNodes

                delegate: DeviceRow {
                    required property var modelData

                    node: modelData
                    current: modelData === menuRoot.currentNode
                    label: menuRoot.deviceName(modelData)
                    hoverColor: menuRoot.hoverColor
                    textColor: menuRoot.textColor
                    mutedTextColor: menuRoot.mutedTextColor
                    markColor: menuRoot.separatorColor
                    fontFamily: menuRoot.fontFamily
                    onActivated: menuRoot.selectDevice(modelData)
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                verticalAlignment: Text.AlignVCenter
                visible: menuRoot.deviceNodes.length === 0
                text: "Устройств не найдено"
                color: menuRoot.mutedTextColor
                font.family: menuRoot.fontFamily
                font.pixelSize: 12
                renderType: Text.NativeRendering
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 5
                Layout.bottomMargin: 5
                implicitHeight: 1
                color: menuRoot.separatorColor
            }

            DeviceRow {
                showMark: false
                label: "Настройки звука…"
                labelColor: menuRoot.textColor
                hoverColor: menuRoot.hoverColor
                textColor: menuRoot.textColor
                mutedTextColor: menuRoot.mutedTextColor
                markColor: menuRoot.separatorColor
                fontFamily: menuRoot.fontFamily
                onActivated: {
                    Quickshell.execDetached(["pavucontrol"])
                    menuRoot.closeRequested()
                }
            }
        }
    }
}
