import QtQuick
import Quickshell
import Quickshell.Io

// Right-hand pane with the full content of the selected entry. cliphist's own
// preview stops at 100 characters, so anything multi-line is invisible without
// this.
Item {
    id: pane

    property var entry: null

    property string body: ""
    property bool truncated: false

    readonly property bool isImage: entry !== null && entry.kind === "image"

    onEntryChanged: {
        body = ""
        truncated = false
        decodeDelay.restart()
    }

    function load() {
        const target = pane.entry
        if (!target)
            return

        if (target.kind === "image") {
            Clips.requestThumb(target)
            return
        }

        // A pinned entry already carries its own copy of the text.
        if (target.pinned) {
            pane.truncated = target.text.length > Clips.previewLimit
            pane.body = target.text.substring(0, Clips.previewLimit)
            return
        }

        // Capped in the pipe rather than after the fact — single clippings in
        // this database run into megabytes, and rendering one would stall the UI.
        decodeProbe.running = false
        decodeProbe.command = ["sh", "-c",
            "cliphist decode " + Clips.shellQuote(target.id) + " | head -c " + Clips.previewLimit]
        decodeProbe.running = true
    }

    // Keeps a held-down arrow key from spawning a decode per row.
    Timer {
        id: decodeDelay
        interval: 80
        onTriggered: pane.load()
    }

    Process {
        id: decodeProbe

        stdout: StdioCollector {
            onStreamFinished: {
                pane.truncated = text.length >= Clips.previewLimit
                pane.body = text
            }
        }
    }

    Item {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        anchors.bottomMargin: 0
        height: 18
        visible: pane.entry !== null

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pane.isImage ? "" : ""
                color: Theme.tx3
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    if (!pane.entry)
                        return ""
                    if (pane.isImage)
                        return String(pane.entry.ext || "image").toUpperCase()
                            + (pane.entry.dims.length > 0 ? "  " + pane.entry.dims : "")
                    return "Текст" + (pane.body.length > 0 ? "  " + pane.body.length + " симв." : "")
                }
                color: Theme.tx3
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: pane.entry !== null && pane.entry.pinned
                text: "  закреплено"
                color: Theme.yellow
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
        }
    }

    Rectangle {
        id: headerLine

        anchors.top: header.bottom
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        height: 1
        color: Theme.ui
        visible: header.visible
    }

    Text {
        id: note

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        anchors.topMargin: 0
        height: visible ? 14 : 0
        visible: pane.truncated
        text: "… показаны первые " + Clips.previewLimit + " символов"
        color: Theme.tx3
        font.family: Theme.fontFamily
        font.pixelSize: 11
        elide: Text.ElideRight
    }

    Item {
        anchors.top: headerLine.bottom
        anchors.topMargin: 12
        anchors.bottom: note.top
        anchors.bottomMargin: pane.truncated ? 8 : 16
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        visible: pane.entry !== null

        Image {
            anchors.fill: parent
            visible: pane.isImage
            asynchronous: true
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            source: pane.isImage ? Clips.thumbSource(pane.entry) : ""
        }

        Flickable {
            id: flick

            anchors.fill: parent
            visible: !pane.isImage
            clip: true
            contentWidth: width
            contentHeight: content.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Text {
                id: content

                width: flick.width
                text: pane.body
                color: Theme.tx2
                font.family: Theme.fontFamily
                font.pixelSize: 12
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: pane.entry === null
        text: "Нет записи"
        color: Theme.tx3
        font.family: Theme.fontFamily
        font.pixelSize: 13
    }
}
