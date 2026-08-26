.pragma library

function uniqueStrings(values) {
    const seen = Object.create(null)
    const result = []
    for (let i = 0; i < values.length; i++) {
        const value = String(values[i] || "").trim()
        if (value.length === 0 || seen[value])
            continue
        seen[value] = true
        result.push(value)
    }
    return result
}

function restorePins(text, defaults) {
    try {
        const parsed = JSON.parse(String(text || ""))
        if (!parsed || parsed.version !== 1 || !Array.isArray(parsed.pins))
            return uniqueStrings(defaults)
        return uniqueStrings(parsed.pins)
    } catch (error) {
        return uniqueStrings(defaults)
    }
}

function windowOnScreen(window, targetScreen) {
    if (!window || !targetScreen || !window.screens)
        return false

    for (let i = 0; i < window.screens.length; i++) {
        const screen = window.screens[i]
        if (screen === targetScreen)
            return true
        if (screen && screen.name && targetScreen.name && screen.name === targetScreen.name)
            return true
    }
    return false
}

function itemForGroup(group, pinned) {
    let active = false
    for (let i = 0; i < group.windows.length; i++) {
        if (group.windows[i].activated) {
            active = true
            break
        }
    }

    return {
        key: group.key,
        entryId: group.entry ? group.entry.id : "",
        entry: group.entry,
        appId: group.appId,
        name: group.entry ? (group.entry.name || group.entry.id) : group.appId,
        windows: group.windows,
        pinned: pinned,
        active: active
    }
}

function buildItems(pins, windows, targetScreen, entryById, entryForWindow) {
    const groups = Object.create(null)
    const groupOrder = []

    for (let i = 0; i < windows.length; i++) {
        const window = windows[i]
        if (!windowOnScreen(window, targetScreen))
            continue

        const entry = entryForWindow(window)
        const appId = String(window.appId || "unknown").trim() || "unknown"
        const key = entry ? entry.id : "app:" + appId.toLowerCase()
        if (!groups[key]) {
            groups[key] = { key: key, entry: entry, appId: appId, windows: [] }
            groupOrder.push(key)
        }
        groups[key].windows.push(window)
    }

    const pinnedItems = []
    const renderedPins = Object.create(null)
    for (let i = 0; i < pins.length; i++) {
        const id = pins[i]
        const entry = entryById(id)
        if (!entry)
            continue

        renderedPins[id] = true
        const group = groups[id] || { key: id, entry: entry, appId: id, windows: [] }
        pinnedItems.push(itemForGroup(group, true))
    }

    const runningItems = []
    for (let i = 0; i < groupOrder.length; i++) {
        const key = groupOrder[i]
        if (renderedPins[key])
            continue
        runningItems.push(itemForGroup(groups[key], false))
    }
    runningItems.sort((left, right) => {
        const a = left.name.toLowerCase()
        const b = right.name.toLowerCase()
        return a < b ? -1 : (a > b ? 1 : 0)
    })

    return { pinned: pinnedItems, running: runningItems }
}

function movePin(pins, fromIndex, toIndex) {
    const result = pins.slice()
    if (fromIndex < 0 || fromIndex >= result.length || toIndex < 0 || toIndex >= result.length)
        return result
    if (fromIndex === toIndex)
        return result

    const moved = result.splice(fromIndex, 1)[0]
    result.splice(toIndex, 0, moved)
    return result
}

function nextWindowIndex(windows, activeWindow) {
    if (!windows || windows.length === 0)
        return -1
    if (!activeWindow)
        return 0

    const index = windows.indexOf(activeWindow)
    return index === -1 ? 0 : (index + 1) % windows.length
}

function cleanCommand(command) {
    const result = []
    for (let i = 0; i < command.length; i++) {
        const argument = String(command[i])
        if (argument.indexOf("%") !== 0)
            result.push(argument)
    }
    return result
}

function shouldHide(interactionLocked, triggerHovered, cardHovered, hoveredIndex) {
    return !interactionLocked && !triggerHovered && !cardHovered && hoveredIndex < 0
}
