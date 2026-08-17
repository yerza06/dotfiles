pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history model. The store itself stays cliphist — the same daemons
// (`wl-paste --watch cliphist store`) keep filling it, so the history is shared
// with anything else that reads it. This singleton only reads, ranks and acts.
Singleton {
    id: root

    readonly property var categories: [
        { id: "all", label: "Всё", icon: "" },
        { id: "text", label: "Текст", icon: "" },
        { id: "image", label: "Картинки", icon: "" },
        { id: "pinned", label: "Закреплённые", icon: "" }
    ]

    // Decoded image previews land here; pinned payloads live next to them so
    // they outlive both the 750-entry cap and `cliphist wipe`.
    readonly property string thumbDir: Quickshell.cachePath("thumbs")
    readonly property string pinDir: Quickshell.cachePath("pins")

    // Enough of an entry to fill the preview pane without ever rendering a
    // multi-megabyte clipping into a Text item.
    readonly property int previewLimit: 16384

    property string query: ""
    property string category: "all"

    // cliphist rows, newest first.
    property var entries: []
    // Pinned payloads, each carrying its own copy of the content.
    property var pins: []
    // pin key -> true, rebuilt whenever `pins` changes.
    property var pinIndex: ({})
    // cliphist id -> decoded image file on disk.
    property var thumbs: ({})

    property var results: []
    property bool loading: false

    onQueryChanged: root.refresh()
    onCategoryChanged: root.refresh()
    onEntriesChanged: root.refresh()

    onPinsChanged: {
        const index = {}
        for (let i = 0; i < pins.length; i++)
            index[pins[i].key] = true
        pinIndex = index
        refresh()
    }

    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'"
    }

    function mimeOf(entry) {
        switch (String(entry.ext || "").toLowerCase()) {
        case "jpeg":
        case "jpg":
            return "image/jpeg"
        case "gif":
            return "image/gif"
        case "webp":
            return "image/webp"
        case "bmp":
            return "image/bmp"
        default:
            return "image/png"
        }
    }

    // --- reading -----------------------------------------------------------

    // Re-reads cliphist. Called when the menu opens rather than continuously:
    // the list is ~75 KB of text against a 105 MB database.
    function reload() {
        loading = true
        listProbe.running = false
        listProbe.running = true
    }

    function parse(payload) {
        const lines = String(payload).split("\n")
        const list = []
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i]
            const tab = line.indexOf("\t")
            if (tab <= 0)
                continue

            const id = line.substring(0, tab)
            const preview = line.substring(tab + 1)
            // cliphist renders images as `[[ binary data 22 KiB png 496x221 ]]`.
            // Anything binary without dimensions is not an image we can show,
            // so it keeps travelling down the plain-text path.
            const binary = preview.match(/^\[\[ binary data .* ([a-z0-9]+) (\d+x\d+) \]\]$/)
            const kind = binary ? "image" : "text"

            list.push({
                id: id,
                preview: preview,
                kind: kind,
                ext: binary ? binary[1] : "",
                dims: binary ? binary[2] : "",
                key: kind + ":" + preview,
                pinned: false,
                text: "",
                file: ""
            })
        }
        entries = list
    }

    // --- filtering ---------------------------------------------------------

    function normalize(value) {
        return String(value === undefined || value === null ? "" : value).toLowerCase()
    }

    // Same ladder as the launcher's ranking, minus its subsequence pass — on
    // free-form clipboard text a subsequence match hits practically everything.
    function fieldScore(text, needle) {
        const hay = normalize(text)
        if (hay.length === 0)
            return 0

        if (hay === needle)
            return 1000
        if (hay.indexOf(needle) === 0)
            return 820 - Math.min(hay.length - needle.length, 60)

        const wordStart = hay.indexOf(" " + needle)
        if (wordStart !== -1)
            return 640 - Math.min(wordStart, 60)

        const anywhere = hay.indexOf(needle)
        if (anywhere !== -1)
            return 460 - Math.min(anywhere, 60)

        return 0
    }

    function isPinned(entry) {
        return entry !== null && entry !== undefined && pinIndex[entry.key] === true
    }

    // Pins as entry-shaped objects. They are self-contained, so a pin still
    // works after cliphist has forgotten the original row.
    function pinnedEntries() {
        const list = []
        for (let i = 0; i < pins.length; i++) {
            const pin = pins[i]
            list.push({
                id: String(pin.id || ""),
                preview: pin.preview,
                kind: pin.kind,
                ext: String(pin.ext || ""),
                dims: String(pin.dims || ""),
                key: pin.key,
                pinned: true,
                text: String(pin.text || ""),
                file: String(pin.file || "")
            })
        }
        return list
    }

    function matchesCategory(entry) {
        if (category === "all" || category === "pinned")
            return true
        return entry.kind === category
    }

    // Pinned first, then the live history with the pinned rows filtered out so
    // nothing shows up twice.
    function source() {
        const pinned = pinnedEntries()
        if (category === "pinned")
            return pinned

        const list = []
        for (let i = 0; i < pinned.length; i++) {
            if (matchesCategory(pinned[i]))
                list.push(pinned[i])
        }
        for (let i = 0; i < entries.length; i++) {
            if (!isPinned(entries[i]) && matchesCategory(entries[i]))
                list.push(entries[i])
        }
        return list
    }

    function refresh() {
        const visible = source()
        const needle = query.trim().toLowerCase()

        if (needle.length === 0) {
            results = visible
            return
        }

        const scored = []
        for (let i = 0; i < visible.length; i++) {
            const score = fieldScore(visible[i].preview, needle)
            if (score > 0)
                scored.push({ entry: visible[i], order: i, score: score + (visible[i].pinned ? 40 : 0) })
        }

        scored.sort((left, right) => {
            if (right.score !== left.score)
                return right.score - left.score
            return left.order - right.order
        })

        const ordered = []
        for (let i = 0; i < scored.length; i++)
            ordered.push(scored[i].entry)
        results = ordered
    }

    function categoryIndex() {
        for (let i = 0; i < categories.length; i++) {
            if (categories[i].id === category)
                return i
        }
        return 0
    }

    function cycleCategory(delta) {
        const next = (categoryIndex() + delta + categories.length) % categories.length
        category = categories[next].id
    }

    // Counts what the tab would actually list: pinned rows are shown once, at
    // the top, and skipped in the live history below them.
    function countOf(id) {
        if (id === "pinned")
            return pins.length

        let count = 0
        for (let i = 0; i < pins.length; i++) {
            if (id === "all" || pins[i].kind === id)
                count++
        }
        for (let i = 0; i < entries.length; i++) {
            if ((id === "all" || entries[i].kind === id) && !isPinned(entries[i]))
                count++
        }
        return count
    }

    // --- acting ------------------------------------------------------------

    // A pin carries its own payload, so it never has to reach back into
    // cliphist — which is the whole point of pinning something.
    function copy(entry) {
        if (!entry)
            return

        if (entry.pinned) {
            if (entry.kind === "image" && entry.file.length > 0)
                Quickshell.execDetached(["sh", "-c",
                    "wl-copy --type " + mimeOf(entry) + " < " + shellQuote(entry.file)])
            else
                Quickshell.clipboardText = entry.text
            return
        }

        // `--type` is what the old rofi pipe was missing: without it an image
        // was handed to wl-copy as text/plain and pasted as garbage.
        const type = entry.kind === "image" ? " --type " + mimeOf(entry) : ""
        Quickshell.execDetached(["sh", "-c",
            "cliphist decode " + shellQuote(entry.id) + " | wl-copy" + type])
    }

    // The live cliphist row behind an entry, if it still has one.
    function liveEntry(entry) {
        if (!entry)
            return null
        if (!entry.pinned)
            return entry
        for (let i = 0; i < entries.length; i++) {
            if (entries[i].key === entry.key)
                return entries[i]
        }
        return null
    }

    function remove(entry) {
        if (!entry)
            return

        if (entry.pinned)
            unpin(entry)

        const live = liveEntry(entry)
        if (!live) {
            refresh()
            return
        }

        // cliphist delete takes the whole `id<TAB>preview` line on stdin; it
        // has no id argument, unlike decode. Closing stdin afterwards is what
        // makes it stop reading and actually delete.
        deleteProbe.running = false
        deleteProbe.stdinEnabled = true
        deleteProbe.running = true
        deleteProbe.write(live.id + "\t" + live.preview + "\n")
        deleteProbe.stdinEnabled = false
    }

    function wipe() {
        wipeProbe.running = false
        wipeProbe.running = true
    }

    // --- pins --------------------------------------------------------------

    function writePins(list) {
        pins = list
        pinsFile.setText(JSON.stringify(list))
    }

    function unpin(entry) {
        const list = []
        for (let i = 0; i < pins.length; i++) {
            if (pins[i].key === entry.key) {
                // The private copy of a pinned image has nothing left to serve.
                const file = String(pins[i].file || "")
                if (file.length > 0)
                    Quickshell.execDetached(["rm", "-f", file])
                continue
            }
            list.push(pins[i])
        }
        writePins(list)
    }

    // Pinning has to grab a private copy of the content first, so the two
    // Process blocks below finish the job asynchronously.
    function pin(entry) {
        if (!entry || entry.pinned)
            return

        if (entry.kind === "image") {
            const file = pinDir + "/" + entry.id + "-" + entry.dims + "." + (entry.ext || "png")
            pinImageProbe.pending = entry
            pinImageProbe.pendingFile = file
            pinImageProbe.command = ["sh", "-c",
                "mkdir -p " + shellQuote(pinDir)
                + " && cliphist decode " + shellQuote(entry.id) + " > " + shellQuote(file)]
            pinImageProbe.running = false
            pinImageProbe.running = true
            return
        }

        pinTextProbe.pending = entry
        pinTextProbe.command = ["cliphist", "decode", entry.id]
        pinTextProbe.running = false
        pinTextProbe.running = true
    }

    function addPin(entry, text, file) {
        const list = []
        for (let i = 0; i < pins.length; i++)
            list.push(pins[i])
        list.unshift({
            key: entry.key,
            id: entry.id,
            kind: entry.kind,
            preview: entry.preview,
            ext: entry.ext,
            dims: entry.dims,
            text: text,
            file: file,
            added: Date.now()
        })
        writePins(list)
    }

    function togglePin(entry) {
        if (!entry)
            return
        if (entry.pinned || isPinned(entry))
            unpin(entry)
        else
            pin(entry)
    }

    // --- image thumbnails --------------------------------------------------

    // QML Image cannot read a process's stdout, so every image has to be
    // decoded to a file first. One decode at a time, on demand.
    property var thumbQueue: []
    property string thumbActive: ""

    function thumbSource(entry) {
        if (!entry || entry.kind !== "image")
            return ""
        if (entry.pinned && entry.file.length > 0)
            return "file://" + entry.file
        const ready = thumbs[entry.id]
        return ready === undefined ? "" : "file://" + ready
    }

    function requestThumb(entry) {
        if (!entry || entry.kind !== "image")
            return
        if (entry.pinned && entry.file.length > 0)
            return
        if (thumbs[entry.id] !== undefined || thumbActive === entry.id)
            return
        for (let i = 0; i < thumbQueue.length; i++) {
            if (thumbQueue[i].id === entry.id)
                return
        }
        thumbQueue.push(entry)
        pumpThumbs()
    }

    function pumpThumbs() {
        if (thumbActive.length > 0 || thumbQueue.length === 0)
            return

        const entry = thumbQueue.shift()
        // The dimensions in the name keep a stale thumbnail from being reused
        // after `cliphist wipe` restarts the id counter.
        const file = thumbDir + "/" + entry.id + "-" + entry.dims + "." + (entry.ext || "png")

        thumbActive = entry.id
        thumbProbe.pendingId = entry.id
        thumbProbe.pendingFile = file
        thumbProbe.command = ["sh", "-c",
            "mkdir -p " + shellQuote(thumbDir)
            + " && { [ -s " + shellQuote(file) + " ] || cliphist decode " + shellQuote(entry.id)
            + " > " + shellQuote(file) + "; }"]
        thumbProbe.running = true
    }

    // --- processes ---------------------------------------------------------

    Process {
        id: listProbe

        command: ["cliphist", "list"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.parse(text)
                root.loading = false
            }
        }

        onExited: root.loading = false
    }

    Process {
        id: deleteProbe

        command: ["cliphist", "delete"]
        stdinEnabled: true

        onExited: root.reload()
    }

    Process {
        id: wipeProbe

        command: ["sh", "-c", "cliphist wipe; rm -rf " + root.shellQuote(root.thumbDir)]

        onExited: {
            root.thumbs = ({})
            root.thumbQueue = []
            root.reload()
        }
    }

    Process {
        id: thumbProbe

        property string pendingId: ""
        property string pendingFile: ""

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && thumbProbe.pendingId.length > 0) {
                const next = {}
                for (const id in root.thumbs)
                    next[id] = root.thumbs[id]
                next[thumbProbe.pendingId] = thumbProbe.pendingFile
                root.thumbs = next
            }
            root.thumbActive = ""
            root.pumpThumbs()
        }
    }

    Process {
        id: pinTextProbe

        property var pending: null

        stdout: StdioCollector {
            onStreamFinished: {
                if (pinTextProbe.pending)
                    root.addPin(pinTextProbe.pending, text, "")
                pinTextProbe.pending = null
            }
        }
    }

    Process {
        id: pinImageProbe

        property var pending: null
        property string pendingFile: ""

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && pinImageProbe.pending)
                root.addPin(pinImageProbe.pending, "", pinImageProbe.pendingFile)
            pinImageProbe.pending = null
        }
    }

    // --- persistence -------------------------------------------------------

    FileView {
        id: pinsFile

        path: Quickshell.statePath("pins.json")
        printErrors: false

        onLoaded: {
            try {
                const parsed = JSON.parse(text())
                root.pins = Array.isArray(parsed) ? parsed : []
            } catch (error) {
                root.pins = []
            }
        }

        onLoadFailed: root.pins = []
    }

    Component.onCompleted: {
        // Neither FileView nor the decode redirections create their directories.
        const path = pinsFile.path
        const separator = path.lastIndexOf("/")
        if (separator > 0)
            Quickshell.execDetached(["mkdir", "-p", path.substring(0, separator)])
        Quickshell.execDetached(["mkdir", "-p", root.thumbDir, root.pinDir])
        root.reload()
    }
}
