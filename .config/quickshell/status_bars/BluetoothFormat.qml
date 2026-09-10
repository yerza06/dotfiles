pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Общие форматтеры Bluetooth: одними и теми же значениями пользуются пилюля
// в панели и окно с устройствами — раньше BluetoothItem дёргал их у BluetoothMenu,
// что связывало виджет с меню без всякой на то нужды.
Singleton {
    id: root

    // Алиас (name) идёт первым: именно его переписывает переименование,
    // а deviceName только для чтения — с обратным порядком новое имя не было бы видно.
    function deviceLabel(device) {
        if (!device)
            return ""
        return device.name || device.deviceName || device.address || ""
    }

    // Percentage у org.bluez.Battery1 — байт 0..100. Долю принимаем на случай
    // другого бэкенда, но строго меньше единицы: иначе реальный 1 % стал бы 100 %.
    function batteryPercent(device) {
        if (!device)
            return 0
        const value = device.battery
        return Math.round(value > 0 && value < 1 ? value * 100 : value)
    }

    function hasBattery(device) {
        return device !== null && device !== undefined && device.batteryAvailable
    }

    function batteryText(device) {
        return hasBattery(device) ? batteryPercent(device) + "%" : ""
    }

    function deviceBusy(device) {
        if (!device)
            return false
        return device.pairing
            || device.state === BluetoothDeviceState.Connecting
            || device.state === BluetoothDeviceState.Disconnecting
    }

    function deviceStateLabel(device) {
        if (!device)
            return ""
        switch (device.state) {
        case BluetoothDeviceState.Connected:
            return "Подключено"
        case BluetoothDeviceState.Connecting:
            return "Подключение…"
        case BluetoothDeviceState.Disconnecting:
            return "Отключение…"
        default:
            return "Сопряжено"
        }
    }

    // Правая приписка в свёрнутой строке: заряд, если BlueZ его отдаёт,
    // иначе состояние — пустой правый край смотрится недоделанным.
    function deviceDetail(device) {
        if (!device)
            return ""
        if (deviceBusy(device))
            return deviceStateLabel(device)
        return hasBattery(device) ? batteryText(device) : deviceStateLabel(device)
    }

    // BlueZ отдаёт имя иконки freedesktop — по нему и выбираем глиф.
    // На этой машине встречаются audio-headset, input-gaming и input-keyboard.
    function deviceGlyph(device) {
        const icon = device && device.icon ? String(device.icon) : ""
        switch (icon) {
        case "audio-headset":
            return "󰋎"
        case "audio-headphones":
            return "󰋋"
        case "audio-card":
        case "multimedia-player":
            return "󰓃"
        case "input-gaming":
            return "󰊴"
        case "input-keyboard":
            return "󰌌"
        case "input-mouse":
            return "󰍽"
        case "input-tablet":
            return "󰓷"
        case "phone":
            return "󰄜"
        case "computer":
            return "󰟀"
        case "printer":
            return "󰐪"
        case "camera-photo":
        case "camera-video":
            return "󰄀"
        default:
            return "󰂯"
        }
    }

    function adapterStateLabel(adapter) {
        if (!adapter)
            return "Адаптер не найден"
        switch (adapter.state) {
        case BluetoothAdapterState.Enabled:
            return "Включён"
        case BluetoothAdapterState.Enabling:
            return "Включается…"
        case BluetoothAdapterState.Disabling:
            return "Выключается…"
        case BluetoothAdapterState.Blocked:
            return "Заблокирован"
        default:
            return "Выключен"
        }
    }

    // Сопряжённым считается и bonded, и уже подключённое устройство:
    // у части устройств paired и bonded расходятся.
    function filterPaired(devices) {
        if (!devices)
            return []
        const result = []
        for (let i = 0; i < devices.length; i++) {
            const device = devices[i]
            if (device.connected || device.paired || device.bonded)
                result.push(device)
        }
        return result
    }

    // Подключённые сверху, дальше по алфавиту: без второго ключа
    // порядок скакал бы при любом обновлении модели.
    function sortDevices(devices) {
        const result = devices.slice()
        result.sort((left, right) => {
            if (left.connected !== right.connected)
                return left.connected ? -1 : 1
            return deviceLabel(left).localeCompare(deviceLabel(right))
        })
        return result
    }
}
