pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Application index: reads the XDG desktop entries, ranks them against the
// current query and remembers how often each one is launched.
Singleton {
    id: root

    // Terminal used for entries with `Terminal=true`.
    readonly property string terminal: "kitty"

    // Freedesktop menu categories folded into the groups worth having a tab for.
    // `match` lists the XDG categories that land in the group; "all" takes
    // everything and "other" takes whatever no other group claimed.
    readonly property var categories: [
        { id: "all", label: "Все", icon: "\uf00a", match: [] },
        { id: "development", label: "Разработка", icon: "\uf121", match: ["Development"] },
        { id: "network", label: "Интернет", icon: "\uf0ac", match: ["Network"] },
        { id: "graphics", label: "Графика", icon: "\uf03e", match: ["Graphics"] },
        { id: "office", label: "Офис", icon: "\uf0f6", match: ["Office"] },
        { id: "media", label: "Медиа", icon: "\uf001", match: ["AudioVideo", "Audio", "Video"] },
        { id: "game", label: "Игры", icon: "\uf11b", match: ["Game"] },
        { id: "science", label: "Наука", icon: "\uf19d", match: ["Science", "Education"] },
        { id: "utility", label: "Утилиты", icon: "\uf0ad", match: ["Utility"] },
        { id: "system", label: "Система", icon: "\uf085", match: ["System"] },
        { id: "settings", label: "Настройки", icon: "\uf013", match: ["Settings"] },
        { id: "other", label: "Прочее", icon: "\uf07b", match: [] }
    ]

    property string query: ""
    property string category: "all"
    // entry id -> launch count, persisted between sessions.
    property var usage: ({})
    property var results: []
    // Only the tabs that actually hold something, as { id, label, icon, count }.
    property var visibleCategories: []
    // Displayable entries and entry id -> group ids, both rebuilt with `entries`.
    property var indexed: []
    property var groupIndex: ({})

    readonly property var entries: DesktopEntries.applications.values

    onQueryChanged: root.refresh()
    onCategoryChanged: root.refresh()
    onEntriesChanged: root.rebuild()
    onUsageChanged: root.refresh()

    function normalize(value) {
        return String(value === undefined || value === null ? "" : value).toLowerCase()
    }

    // Ranks one field. 0 means "no match", higher is better. Fuzzy matching is
    // reserved for identifying fields — letting it loose on comments turns every
    // query into a hundred coincidental hits.
    function fieldScore(text, needle, fuzzy) {
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

        if (!fuzzy)
            return 0

        // Subsequence match, so "gimp" still finds "GNU Image Manipulation
        // Program". Scattered letters score lower than tight ones.
        let cursor = 0
        let previous = -1
        let gaps = 0
        for (let i = 0; i < needle.length; i++) {
            const found = hay.indexOf(needle[i], cursor)
            if (found === -1)
                return 0
            if (previous !== -1 && found !== previous + 1)
                gaps++
            previous = found
            cursor = found + 1
        }
        return Math.max(1, 260 - gaps * 18)
    }

    // Same as fieldScore, but demoted so that a name match always beats a
    // match hidden in the comment or the exec line.
    function weighted(text, needle, penalty, fuzzy) {
        const score = fieldScore(text, needle, fuzzy)
        return score === 0 ? 0 : Math.max(1, score - penalty)
    }

    function listScore(values, needle, penalty) {
        if (!values)
            return 0
        let best = 0
        for (let i = 0; i < values.length; i++)
            best = Math.max(best, weighted(values[i], needle, penalty, false))
        return best
    }

    function entryScore(entry, needle) {
        let best = weighted(entry.name, needle, 0, true)
        best = Math.max(best, weighted(entry.genericName, needle, 60, true))
        best = Math.max(best, weighted(entry.id, needle, 90, true))
        best = Math.max(best, listScore(entry.keywords, needle, 110))
        best = Math.max(best, weighted(entry.execString, needle, 140, false))
        best = Math.max(best, weighted(entry.comment, needle, 170, false))
        return best
    }

    function launchCount(entry) {
        const count = usage[entry.id]
        return count === undefined ? 0 : count
    }

    function byName(left, right) {
        return normalize(left.name) < normalize(right.name) ? -1 : 1
    }

    // Group ids an entry belongs to. An app with `Utility;Development;` shows up
    // under both tabs, which is what the desktop files intend.
    function groupsOf(entry) {
        const own = entry.categories || []
        const groups = []
        for (let i = 1; i < categories.length - 1; i++) {
            const group = categories[i]
            for (let j = 0; j < own.length; j++) {
                if (group.match.indexOf(own[j]) !== -1) {
                    groups.push(group.id)
                    break
                }
            }
        }
        if (groups.length === 0)
            groups.push("other")
        return groups
    }

    // Rebuilds the entry list and the tab strip. Only the desktop entries
    // changing warrants this; plain query or category changes do not.
    function rebuild() {
        const displayable = []
        const groups = {}
        const counts = {}
        for (let i = 0; i < entries.length; i++) {
            const entry = entries[i]
            if (entry.noDisplay)
                continue
            const own = groupsOf(entry)
            groups[entry.id] = own
            for (let j = 0; j < own.length; j++)
                counts[own[j]] = (counts[own[j]] || 0) + 1
            displayable.push(entry)
        }

        const tabs = []
        for (let i = 0; i < categories.length; i++) {
            const group = categories[i]
            const count = group.id === "all" ? displayable.length : (counts[group.id] || 0)
            if (count > 0)
                tabs.push({ id: group.id, label: group.label, icon: group.icon, count: count })
        }

        indexed = displayable
        groupIndex = groups
        visibleCategories = tabs
        refresh()
    }

    function inCategory(entry) {
        if (category === "all")
            return true
        const groups = groupIndex[entry.id]
        return groups !== undefined && groups.indexOf(category) !== -1
    }

    function refresh() {
        const visible = []
        for (let i = 0; i < indexed.length; i++) {
            if (inCategory(indexed[i]))
                visible.push(indexed[i])
        }

        const needle = query.trim().toLowerCase()
        if (needle.length === 0) {
            // Most used first, so the launcher opens on the apps actually used.
            visible.sort((left, right) => {
                const delta = root.launchCount(right) - root.launchCount(left)
                return delta !== 0 ? delta : root.byName(left, right)
            })
            results = visible
            return
        }

        const scored = []
        for (let i = 0; i < visible.length; i++) {
            const score = entryScore(visible[i], needle)
            if (score > 0)
                scored.push({ entry: visible[i], score: score + Math.min(launchCount(visible[i]), 25) * 6 })
        }

        scored.sort((left, right) => {
            if (right.score !== left.score)
                return right.score - left.score
            return root.byName(left.entry, right.entry)
        })

        const ordered = []
        for (let i = 0; i < scored.length; i++)
            ordered.push(scored[i].entry)
        results = ordered
    }

    function categoryIndex() {
        for (let i = 0; i < visibleCategories.length; i++) {
            if (visibleCategories[i].id === category)
                return i
        }
        return 0
    }

    function cycleCategory(delta) {
        const tabs = visibleCategories
        if (tabs.length === 0)
            return
        const next = (categoryIndex() + delta + tabs.length) % tabs.length
        category = tabs[next].id
    }

    function iconSource(entry) {
        const icon = String(entry.icon || "")
        if (icon.length === 0)
            return Quickshell.iconPath("application-x-executable")
        if (icon.indexOf("/") === 0)
            return "file://" + icon
        return Quickshell.iconPath(icon, "application-x-executable")
    }

    // Desktop entry field codes (%f, %U, ...) must not reach the process.
    function cleanCommand(command) {
        const result = []
        for (let i = 0; i < command.length; i++) {
            if (command[i].indexOf("%") !== 0)
                result.push(command[i])
        }
        return result
    }

    function remember(entry) {
        const counts = {}
        for (const id in usage)
            counts[id] = usage[id]
        counts[entry.id] = (counts[entry.id] || 0) + 1
        usage = counts
        usageFile.setText(JSON.stringify(counts))
    }

    function launch(entry) {
        if (!entry)
            return

        remember(entry)

        if (entry.runInTerminal) {
            const command = cleanCommand(entry.command)
            if (command.length > 0) {
                Quickshell.execDetached([root.terminal, "-e"].concat(command))
                return
            }
        }

        entry.execute()
    }

    FileView {
        id: usageFile

        path: Quickshell.statePath("usage.json")
        printErrors: false

        onLoaded: {
            try {
                const parsed = JSON.parse(text())
                root.usage = (parsed && typeof parsed === "object") ? parsed : ({})
            } catch (error) {
                root.usage = ({})
            }
        }

        onLoadFailed: root.usage = ({})
    }

    Component.onCompleted: {
        // FileView will not create the state directory for us.
        const path = usageFile.path
        const separator = path.lastIndexOf("/")
        if (separator > 0)
            Quickshell.execDetached(["mkdir", "-p", path.substring(0, separator)])
        root.rebuild()
    }
}
