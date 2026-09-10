import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets

// Окно медиаплеера по СКМ на MprisItem: обложка, название с исполнителем,
// прогресс-бар с перемоткой и три кнопки транспорта.
// Как и календарь, окно «липкое»: grabFocus отдаёт ему клавиатуру и заставляет
// композитор закрыть его по клику мимо, поэтому таймера автозакрытия по уходу
// курсора здесь нет — в отличие от меню панели.
PopupWindow {
    id: popupRoot

    property var player: null
    // Глиф плеера из MprisItem — подменяет обложку, когда её нет.
    property string fallbackIcon: ""
    property color backgroundColor: "#100f0f"
    property color hoverColor: "#282726"
    property color textColor: "#cecdc3"
    property color mutedTextColor: "#878580"
    property color borderColor: "#575653"
    property color separatorColor: "#403e3c"
    property color trackColor: "#282726"
    property color accentColor: "#4385be"
    property string fontFamily: "IosevkaTerm Nerd Font Propo"

    signal closeRequested()

    // Позиция под пальцем во время перетаскивания. Пока seeking истинно,
    // полоса рисуется от неё, иначе бар отскакивал бы назад в момент отпускания:
    // плеер сообщает новую позицию не мгновенно.
    property bool seeking: false
    property real seekPreview: 0

    readonly property real trackLength: player && player.lengthSupported
        ? Math.max(0, player.length) : 0
    readonly property real trackPosition: {
        if (seeking)
            return seekPreview
        return player ? Math.max(0, player.position) : 0
    }
    readonly property real progress: trackLength > 0
        ? Math.max(0, Math.min(1, trackPosition / trackLength)) : 0
    readonly property bool seekable: player !== null && player.canSeek && trackLength > 0

    readonly property bool shuffleOn: player !== null
        && player.shuffleSupported && player.shuffle
    readonly property int loopMode: player !== null && player.loopSupported
        ? player.loopState : MprisLoopState.None

    function toggleShuffle() {
        if (player && player.shuffleSupported)
            player.shuffle = !player.shuffle
    }

    // Повтор перебирается по кругу, как в Spotify: выключен → плейлист → трек.
    function cycleLoop() {
        if (!player || !player.loopSupported)
            return
        if (player.loopState === MprisLoopState.None)
            player.loopState = MprisLoopState.Playlist
        else if (player.loopState === MprisLoopState.Playlist)
            player.loopState = MprisLoopState.Track
        else
            player.loopState = MprisLoopState.None
    }

    function formatTime(seconds) {
        const total = Math.max(0, Math.floor(seconds))
        const hours = Math.floor(total / 3600)
        const minutes = Math.floor((total % 3600) / 60)
        const secs = total % 60
        const pad = value => value < 10 ? "0" + value : "" + value
        if (hours > 0)
            return hours + ":" + pad(minutes) + ":" + pad(secs)
        return minutes + ":" + pad(secs)
    }

    function seekPreviewFromX(x, width) {
        if (width <= 0)
            return 0
        return Math.max(0, Math.min(1, x / width)) * trackLength
    }

    function handleKey(event) {
        switch (event.key) {
        case Qt.Key_Escape:
            popupRoot.closeRequested()
            break
        case Qt.Key_Space:
            if (popupRoot.player && popupRoot.player.canTogglePlaying)
                popupRoot.player.togglePlaying()
            break
        case Qt.Key_Left:
            if (popupRoot.player && popupRoot.player.canGoPrevious)
                popupRoot.player.previous()
            break
        case Qt.Key_Right:
            if (popupRoot.player && popupRoot.player.canGoNext)
                popupRoot.player.next()
            break
        case Qt.Key_S:
            popupRoot.toggleShuffle()
            break
        case Qt.Key_R:
            popupRoot.cycleLoop()
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
        if (visible) {
            seeking = false
            frame.forceActiveFocus()
        }
    }

    // position вычисляется при чтении и сам сигнала не шлёт, поэтому его
    // приходится эмитить вручную — иначе полоса стоит на месте.
    // Таймер завязан на visible, чтобы не дёргать D-Bus при закрытом окне.
    Timer {
        interval: 1000
        repeat: true
        running: popupRoot.visible
            && popupRoot.player !== null
            && popupRoot.player.isPlaying
            && !popupRoot.seeking
        onTriggered: popupRoot.player.positionChanged()
    }

    Rectangle {
        id: frame

        anchors.fill: parent
        // Ширина фиксированная: иначе длинный заголовок с YouTube распирал бы
        // окно, и оно прыгало бы при каждой смене трека.
        implicitWidth: 340
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
                spacing: 12

                ClippingRectangle {
                    Layout.preferredWidth: 72
                    Layout.preferredHeight: 72
                    Layout.alignment: Qt.AlignTop
                    radius: 4
                    color: popupRoot.hoverColor

                    Image {
                        id: artImage

                        anchors.fill: parent
                        source: popupRoot.player && popupRoot.player.trackArtUrl
                            ? popupRoot.player.trackArtUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 144
                        sourceSize.height: 144
                        smooth: true
                        asynchronous: true
                        visible: status === Image.Ready
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !artImage.visible
                        text: popupRoot.fallbackIcon
                        color: popupRoot.mutedTextColor
                        font.family: popupRoot.fontFamily
                        font.pixelSize: 30
                        renderType: Text.NativeRendering
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 3

                    Text {
                        Layout.fillWidth: true
                        text: popupRoot.player && popupRoot.player.trackTitle
                            ? popupRoot.player.trackTitle : "Неизвестная композиция"
                        color: popupRoot.textColor
                        font.family: popupRoot.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }

                    Text {
                        Layout.fillWidth: true
                        text: popupRoot.player && popupRoot.player.trackArtist
                            ? popupRoot.player.trackArtist : "Неизвестный исполнитель"
                        color: popupRoot.mutedTextColor
                        font.family: popupRoot.fontFamily
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: text.length > 0
                        text: popupRoot.player && popupRoot.player.trackAlbum
                            ? popupRoot.player.trackAlbum : ""
                        color: popupRoot.mutedTextColor
                        font.family: popupRoot.fontFamily
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: popupRoot.trackLength > 0
                spacing: 2

                Item {
                    id: seekArea

                    Layout.fillWidth: true
                    Layout.preferredHeight: 18

                    Rectangle {
                        id: seekTrack

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
                            width: Math.max(0, Math.min(parent.width,
                                parent.width * popupRoot.progress))
                            radius: 3
                            color: popupRoot.accentColor
                        }

                        Rectangle {
                            width: 12
                            height: 12
                            radius: 6
                            visible: popupRoot.seekable
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(parent.width - width,
                                parent.width * popupRoot.progress - width / 2))
                            color: popupRoot.accentColor
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: popupRoot.seekable
                        acceptedButtons: Qt.LeftButton
                        cursorShape: Qt.PointingHandCursor

                        onPressed: mouse => {
                            popupRoot.seekPreview = popupRoot.seekPreviewFromX(mouse.x, width)
                            popupRoot.seeking = true
                        }
                        onPositionChanged: mouse => {
                            if (pressed)
                                popupRoot.seekPreview = popupRoot.seekPreviewFromX(mouse.x, width)
                        }
                        onReleased: {
                            if (popupRoot.player)
                                popupRoot.player.position = popupRoot.seekPreview
                            popupRoot.seeking = false
                        }
                        onCanceled: popupRoot.seeking = false
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: popupRoot.formatTime(popupRoot.trackPosition)
                        color: popupRoot.mutedTextColor
                        font.family: popupRoot.fontFamily
                        font.pixelSize: 11
                        renderType: Text.NativeRendering
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Text {
                        text: popupRoot.formatTime(popupRoot.trackLength)
                        color: popupRoot.mutedTextColor
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

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 10

                MprisControlButton {
                    text: "󰒝"
                    size: 26
                    pixelSize: 14
                    active: popupRoot.shuffleOn
                    available: popupRoot.player !== null && popupRoot.player.shuffleSupported
                    backgroundColor: popupRoot.backgroundColor
                    hoverColor: popupRoot.hoverColor
                    textColor: popupRoot.mutedTextColor
                    mutedTextColor: popupRoot.separatorColor
                    accentColor: popupRoot.accentColor
                    fontFamily: popupRoot.fontFamily
                    onActivated: popupRoot.toggleShuffle()
                }

                MprisControlButton {
                    text: ""
                    available: popupRoot.player !== null && popupRoot.player.canGoPrevious
                    backgroundColor: popupRoot.backgroundColor
                    hoverColor: popupRoot.hoverColor
                    textColor: popupRoot.textColor
                    mutedTextColor: popupRoot.separatorColor
                    accentColor: popupRoot.accentColor
                    fontFamily: popupRoot.fontFamily
                    onActivated: popupRoot.player.previous()
                }

                MprisControlButton {
                    text: popupRoot.player && popupRoot.player.isPlaying ? "" : ""
                    size: 38
                    pixelSize: 16
                    filled: true
                    available: popupRoot.player !== null && popupRoot.player.canTogglePlaying
                    backgroundColor: popupRoot.backgroundColor
                    hoverColor: popupRoot.hoverColor
                    textColor: popupRoot.textColor
                    mutedTextColor: popupRoot.separatorColor
                    accentColor: popupRoot.accentColor
                    fontFamily: popupRoot.fontFamily
                    onActivated: popupRoot.player.togglePlaying()
                }

                MprisControlButton {
                    text: ""
                    available: popupRoot.player !== null && popupRoot.player.canGoNext
                    backgroundColor: popupRoot.backgroundColor
                    hoverColor: popupRoot.hoverColor
                    textColor: popupRoot.textColor
                    mutedTextColor: popupRoot.separatorColor
                    accentColor: popupRoot.accentColor
                    fontFamily: popupRoot.fontFamily
                    onActivated: popupRoot.player.next()
                }

                MprisControlButton {
                    text: popupRoot.loopMode === MprisLoopState.Track
                        ? "󰑘" : "󰑖"
                    size: 26
                    pixelSize: 14
                    active: popupRoot.loopMode !== MprisLoopState.None
                    available: popupRoot.player !== null && popupRoot.player.loopSupported
                    backgroundColor: popupRoot.backgroundColor
                    hoverColor: popupRoot.hoverColor
                    textColor: popupRoot.mutedTextColor
                    mutedTextColor: popupRoot.separatorColor
                    accentColor: popupRoot.accentColor
                    fontFamily: popupRoot.fontFamily
                    onActivated: popupRoot.cycleLoop()
                }
            }
        }
    }
}
