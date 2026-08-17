pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The six power actions, their commands, and the uptime shown in the header.
// Commands mirror the ones the old rofi script used.
Singleton {
    id: root

    // `accent` names a Theme property; tiles resolve it as Theme[entry.accent].
    // `confirm` marks the destructive actions that go through ConfirmDialog.
    readonly property var items: [
        {
            id: "shutdown",
            icon: "󰐥",
            label: "Выключить",
            question: "Выключить компьютер?",
            accent: "red",
            confirm: true,
            command: ["systemctl", "poweroff"]
        },
        {
            id: "reboot",
            icon: "󰜉",
            label: "Перезагрузить",
            question: "Перезагрузить компьютер?",
            accent: "yellow",
            confirm: true,
            command: ["systemctl", "reboot"]
        },
        {
            id: "suspend",
            icon: "󰒲",
            label: "Сон",
            question: "Уйти в сон?",
            accent: "cyan",
            confirm: false,
            command: ["systemctl", "suspend"]
        },
        {
            id: "hibernate",
            icon: "󰤄",
            label: "Hibernate",
            question: "Уйти в гибернацию?",
            accent: "blue",
            confirm: true,
            command: ["systemctl", "hibernate"]
        },
        {
            id: "lock",
            icon: "󰌾",
            label: "Заблокировать",
            question: "Заблокировать экран?",
            accent: "green",
            confirm: false,
            command: ["swaylock", "-f", "-c", "000000"]
        },
        {
            id: "logout",
            icon: "󰍃",
            label: "Выйти",
            question: "Завершить сеанс?",
            accent: "purple",
            confirm: false,
            command: ["niri", "msg", "action", "quit", "--skip-confirmation"]
        }
    ]

    property string uptime: ""

    // Detached so the command survives this process going away with the session.
    function run(entry) {
        if (!entry)
            return
        Quickshell.execDetached(entry.command)
    }

    function refresh() {
        uptimeProbe.running = false
        uptimeProbe.running = true
    }

    // /proc/uptime instead of `uptime -p`, so the wording stays Russian
    // regardless of the locale the daemon was started with.
    function format(seconds) {
        const total = Math.floor(seconds)
        if (!(total > 0))
            return "меньше минуты"

        const days = Math.floor(total / 86400)
        const hours = Math.floor((total % 86400) / 3600)
        const minutes = Math.floor((total % 3600) / 60)

        const parts = []
        if (days > 0)
            parts.push(days + " дн")
        if (hours > 0)
            parts.push(hours + " ч")
        if (minutes > 0 && days === 0)
            parts.push(minutes + " мин")

        return parts.length > 0 ? parts.join(" ") : "меньше минуты"
    }

    Process {
        id: uptimeProbe

        command: ["cat", "/proc/uptime"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.uptime = root.format(parseFloat(String(text).trim().split(/\s+/)[0]))
        }
    }
}
