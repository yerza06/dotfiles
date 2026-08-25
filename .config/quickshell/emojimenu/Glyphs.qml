pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Модель палитры символов. В отличие от Clips, источник здесь статический:
// `data/glyphs.json` собирается офлайн скриптом `scripts/gen-glyphs.py` и лежит
// рядом с конфигом, так что в рантайме нет ни внешних процессов, ни сети.
// Синглтон только читает набор, ранжирует его и копирует выбранное.
Singleton {
    id: root

    readonly property var categories: [
        { id: "freq", label: "Частые", icon: "" },
        { id: "pinned", label: "Закреплённые", icon: "" },
        { id: "all", label: "Всё", icon: "" },
        { id: "emoji", label: "Эмодзи", icon: "" },
        { id: "symbol", label: "Символы", icon: "" },
        { id: "kaomoji", label: "Каомодзи", icon: "" },
        { id: "nerd", label: "Иконки", icon: "" }
    ]

    // Ниже этой длины подпоследовательность совпадает почти со всем набором,
    // а набор здесь — четырнадцать тысяч строк.
    readonly property int fuzzyMinLength: 3

    // Ярлыки подразделов. Порядок внутри раздела задаётся здесь же: у эмодзи он
    // канонический (как в UTS #51), у иконок — по размеру набора.
    readonly property var subLabels: ({
        "smileys": "Смайлы", "people": "Люди", "nature": "Природа", "food": "Еда",
        "travel": "Места", "activities": "Занятия", "objects": "Предметы",
        "signs": "Знаки", "flags": "Флаги",

        "arrows": "Стрелки", "math": "Математика", "currency": "Валюты",
        "punct": "Пунктуация", "greek": "Греческий", "letterlike": "Буквенные",
        "numbers": "Числа", "technical": "Технические", "box": "Рамки",
        "shapes": "Фигуры", "games": "Игральные", "latin": "Латиница",
        "pictographs": "Пиктограммы",

        "md": "Material", "fa": "Font Awesome", "dev": "Devicons",
        "cod": "Codicons", "oct": "Octicons", "weather": "Погода",
        "fae": "FA Extension", "seti": "Seti", "linux": "Linux",
        "ple": "Powerline", "pl": "Powerline", "custom": "Custom",
        "extra": "Extra", "pom": "Pomicons", "iec": "IEC", "alpha": "Alpha",
        "other": "Прочее"
    })

    readonly property var subOrder: ({
        "emoji": ["smileys", "people", "nature", "food", "travel",
                  "activities", "objects", "signs", "flags"],
        "symbol": ["arrows", "math", "technical", "shapes", "box", "currency",
                   "punct", "letterlike", "numbers", "greek", "latin",
                   "games", "pictographs"],
        "nerd": ["md", "fa", "dev", "cod", "oct", "weather", "fae", "seti", "linux"]
    })

    property string query: ""
    property string category: "freq"
    // Пустая строка — «все подразделы».
    property string subcategory: ""

    // Весь набор, как он лежит в JSON: { c, n, k, g, u }.
    property var items: []
    // Раскладка по разделам, чтобы не фильтровать 14 000 записей на каждый клик.
    property var byGroup: ({})
    property var groupCounts: ({})
    // "раздел/подраздел" -> массив записей. Готовится один раз при загрузке,
    // чтобы переключение вкладки не фильтровало четырнадцать тысяч записей.
    property var bySub: ({})
    property var subCounts: ({})
    // символ -> true. Нужен, чтобы «Частые» не считали символы, исчезнувшие
    // из набора после перегенерации glyphs.json.
    property var itemIndex: ({})

    // Закреплённые записи. Каждая несёт свою копию полей, поэтому переживает
    // перегенерацию набора — ровно по той же причине, что и пины в буфере.
    property var pins: []
    // символ -> true, перестраивается при каждом изменении `pins`.
    property var pinIndex: ({})
    // символ -> сколько раз вставлен.
    property var usage: ({})

    property var results: []
    property bool loading: true

    readonly property var subcategories: root.subcategoriesFor(root.category)

    onQueryChanged: root.refresh()
    // Подраздел принадлежит разделу, поэтому при смене раздела сбрасывается.
    // Присваивание само вызовет refresh(), если значение действительно менялось.
    onCategoryChanged: {
        if (subcategory.length > 0)
            subcategory = ""
        else
            root.refresh()
    }
    onSubcategoryChanged: root.refresh()
    onItemsChanged: root.refresh()
    onUsageChanged: root.refresh()

    onPinsChanged: {
        const index = {}
        for (let i = 0; i < pins.length; i++)
            index[pins[i].c] = true
        pinIndex = index
        refresh()
    }

    // --- загрузка ----------------------------------------------------------

    function ingest(payload) {
        const list = Array.isArray(payload.items) ? payload.items : []
        const groups = {}
        const counts = {}
        const index = {}
        const subs = {}
        const subTotals = {}

        for (let i = 0; i < list.length; i++) {
            const entry = list[i]
            const group = entry.g
            if (groups[group] === undefined) {
                groups[group] = []
                counts[group] = 0
            }
            groups[group].push(entry)
            counts[group] = counts[group] + 1
            index[entry.c] = true

            if (entry.s.length > 0) {
                const key = group + "/" + entry.s
                if (subs[key] === undefined) {
                    subs[key] = []
                    subTotals[key] = 0
                }
                subs[key].push(entry)
                subTotals[key] = subTotals[key] + 1
            }
        }

        byGroup = groups
        groupCounts = counts
        itemIndex = index
        bySub = subs
        subCounts = subTotals
        items = list
        loading = false
    }

    // --- поиск -------------------------------------------------------------

    // Поле `k` в JSON уже приведено к нижнему регистру на этапе генерации, так
    // что здесь нет ни одного toLowerCase() на горячем пути.
    function fieldScore(hay, needle, fuzzy) {
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

        // Подпоследовательность, как в лаунчере: «arrw» всё ещё находит
        // «rightwards arrow». Разрозненные буквы стоят дешевле плотных.
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

    // Iosevka не рисует цветные эмодзи, а Noto Color Emoji не знает приватную
    // зону Nerd Font — семейство приходится выбирать по разделу записи.
    function fontFor(group) {
        if (group === "emoji")
            return "Noto Color Emoji"
        if (group === "nerd")
            return "Symbols Nerd Font"
        return Theme.fontFamily
    }

    function isPinned(entry) {
        return entry !== null && entry !== undefined && pinIndex[entry.c] === true
    }

    function useCount(entry) {
        if (!entry)
            return 0
        const count = usage[entry.c]
        return count === undefined ? 0 : count
    }

    function frequentEntries() {
        const list = []
        for (let i = 0; i < items.length; i++) {
            if (usage[items[i].c] !== undefined)
                list.push(items[i])
        }
        list.sort((left, right) => {
            const delta = usage[right.c] - usage[left.c]
            return delta !== 0 ? delta : (left.n < right.n ? -1 : 1)
        })
        return list
    }

    function source() {
        if (category === "pinned")
            return pins
        if (category === "freq")
            return frequentEntries()
        if (category === "all")
            return items
        if (subcategory.length > 0) {
            const bucket = bySub[category + "/" + subcategory]
            return bucket === undefined ? [] : bucket
        }
        const group = byGroup[category]
        return group === undefined ? [] : group
    }

    // Подразделы текущего раздела: сначала в каноническом порядке из subOrder,
    // затем всё, чего там не оказалось, — по убыванию размера. Так новый набор
    // иконок не потеряется молча, если его забудут прописать в subOrder.
    function subcategoriesFor(id) {
        const prefix = id + "/"
        const known = subOrder[id]
        const listed = {}
        const list = []

        if (known !== undefined) {
            for (let i = 0; i < known.length; i++) {
                const count = subCounts[prefix + known[i]]
                if (count === undefined)
                    continue
                listed[known[i]] = true
                list.push({ id: known[i], label: labelOf(known[i]), count: count })
            }
        }

        const rest = []
        for (const key in subCounts) {
            if (key.indexOf(prefix) !== 0)
                continue
            const sub = key.substring(prefix.length)
            if (listed[sub] === true)
                continue
            rest.push({ id: sub, label: labelOf(sub), count: subCounts[key] })
        }
        rest.sort((left, right) => right.count - left.count)

        return list.concat(rest)
    }

    function labelOf(sub) {
        const label = subLabels[sub]
        return label === undefined ? sub : label
    }

    function cycleSubcategory(delta) {
        const subs = subcategories
        if (subs.length === 0)
            return
        // Нулевая позиция — «Все», поэтому список длиннее на единицу.
        let index = 0
        for (let i = 0; i < subs.length; i++) {
            if (subs[i].id === subcategory)
                index = i + 1
        }
        const next = (index + delta + subs.length + 1) % (subs.length + 1)
        subcategory = next === 0 ? "" : subs[next - 1].id
    }

    function refresh() {
        const visible = source()
        const needle = query.trim().toLowerCase()

        if (needle.length === 0) {
            results = visible
            return
        }

        const fuzzy = needle.length >= fuzzyMinLength
        const scored = []
        for (let i = 0; i < visible.length; i++) {
            const entry = visible[i]
            let score = fieldScore(entry.k, needle, fuzzy)
            if (score <= 0)
                continue
            if (pinIndex[entry.c] === true)
                score += 40
            const used = usage[entry.c]
            if (used !== undefined)
                score += 5 * Math.min(used, 20)
            scored.push({ entry: entry, order: i, score: score })
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

    function countOf(id) {
        if (id === "pinned")
            return pins.length
        if (id === "all")
            return items.length
        if (id === "freq") {
            let count = 0
            for (const key in usage) {
                if (itemIndex[key] === true)
                    count++
            }
            return count
        }
        const count = groupCounts[id]
        return count === undefined ? 0 : count
    }

    // --- действия ----------------------------------------------------------

    // Никаких процессов: символ — это просто текст, и Quickshell умеет класть
    // текст в буфер сам.
    function copy(entry) {
        if (!entry)
            return
        Quickshell.clipboardText = entry.c
        bump(entry)
    }

    function bump(entry) {
        const counts = {}
        for (const key in usage)
            counts[key] = usage[key]
        counts[entry.c] = (counts[entry.c] || 0) + 1
        usage = counts
        usageWrite.restart()
    }

    function forget(entry) {
        if (!entry || usage[entry.c] === undefined)
            return
        const counts = {}
        for (const key in usage) {
            if (key !== entry.c)
                counts[key] = usage[key]
        }
        usage = counts
        usageWrite.restart()
    }

    function clearUsage() {
        usage = ({})
        usageWrite.restart()
    }

    function togglePin(entry) {
        if (!entry)
            return

        const list = []
        let removed = false
        for (let i = 0; i < pins.length; i++) {
            if (pins[i].c === entry.c)
                removed = true
            else
                list.push(pins[i])
        }

        if (!removed) {
            // Пин хранит собственную копию полей, чтобы пережить перегенерацию
            // набора: символ останется рабочим, даже если исчезнет из JSON.
            list.unshift({
                c: entry.c,
                n: entry.n,
                k: entry.k,
                g: entry.g,
                u: entry.u
            })
        }

        pins = list
        pinsFile.setText(JSON.stringify(list))
    }

    // Серия вставок подряд не должна бить по диску на каждое нажатие.
    Timer {
        id: usageWrite
        interval: 400
        onTriggered: usageFile.setText(JSON.stringify(root.usage))
    }

    // --- хранение ----------------------------------------------------------

    FileView {
        id: dataFile

        path: Quickshell.shellDir + "/data/glyphs.json"
        printErrors: false

        onLoaded: {
            try {
                root.ingest(JSON.parse(text()))
            } catch (error) {
                root.items = []
                root.loading = false
            }
        }

        onLoadFailed: {
            root.items = []
            root.loading = false
        }
    }

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
        // FileView не создаёт каталог состояния сам.
        const path = usageFile.path
        const separator = path.lastIndexOf("/")
        if (separator > 0)
            Quickshell.execDetached(["mkdir", "-p", path.substring(0, separator)])
    }
}
