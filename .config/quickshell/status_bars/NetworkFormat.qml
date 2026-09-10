pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

// Общие форматтеры сети: одними и теми же значениями пользуются пилюля в панели,
// меню выбора сети и окно с подробностями — раньше NetworkItem дёргал их
// у NetworkMenu, что связывало виджет с меню без всякой на то нужды.
Singleton {
    id: root

    // signalStrength приходит то долей, то процентом — зависит от бэкенда.
    function signalPercent(network) {
        if (!network)
            return 0
        const value = network.signalStrength
        return Math.round(value > 1 ? value : value * 100)
    }

    function isSecured(network) {
        if (!network)
            return false
        return network.security !== WifiSecurityType.Open
            && network.security !== WifiSecurityType.Owe
    }

    function securityLabel(network) {
        if (!network)
            return ""
        switch (network.security) {
        case WifiSecurityType.Wpa3SuiteB192:
        case WifiSecurityType.Sae:
            return "WPA3"
        case WifiSecurityType.Wpa2Eap:
        case WifiSecurityType.Wpa2Psk:
            return "WPA2"
        case WifiSecurityType.WpaEap:
        case WifiSecurityType.WpaPsk:
            return "WPA"
        case WifiSecurityType.StaticWep:
        case WifiSecurityType.DynamicWep:
            return "WEP"
        case WifiSecurityType.Leap:
            return "LEAP"
        case WifiSecurityType.Owe:
            return "OWE"
        case WifiSecurityType.Open:
            return "Открытая"
        default:
            return ""
        }
    }

    // linkSpeed приходит в Мбит/с.
    function speedLabel(device) {
        if (!device || !device.linkSpeed)
            return ""
        return device.linkSpeed + " Мбит/с"
    }

    function wifiGlyph(percent) {
        if (percent >= 75) return "󰤨"
        if (percent >= 50) return "󰤥"
        if (percent >= 25) return "󰤢"
        if (percent > 0) return "󰤟"
        return "󰤯"
    }

    // Подключённая сверху, затем известные, затем по убыванию сигнала.
    function sortNetworks(networks) {
        const result = networks.slice()
        result.sort((left, right) => {
            if (left.connected !== right.connected)
                return left.connected ? -1 : 1
            if (left.known !== right.known)
                return left.known ? -1 : 1
            return signalPercent(right) - signalPercent(left)
        })
        return result
    }

    // `ip -j -4 addr show <iface>`
    function parseIp(rawText) {
        try {
            const data = JSON.parse(rawText)
            if (data.length > 0 && data[0].addr_info && data[0].addr_info.length > 0)
                return data[0].addr_info[0].local || ""
        } catch (error) {
            return ""
        }
        return ""
    }

    // `ip -j route show default dev <iface>`
    function parseGateway(rawText) {
        try {
            const data = JSON.parse(rawText)
            for (let i = 0; i < data.length; i++) {
                if (data[i].gateway)
                    return data[i].gateway
            }
        } catch (error) {
            return ""
        }
        return ""
    }

    function formatRate(bytesPerSecond) {
        if (!(bytesPerSecond > 0))
            return "0 Б/с"
        return formatBytes(bytesPerSecond) + "/с"
    }

    function formatBytes(value) {
        if (!(value > 0))
            return "0 Б"
        if (value < 1024)
            return Math.round(value) + " Б"
        if (value < 1024 * 1024)
            return (value / 1024).toFixed(1) + " КБ"
        if (value < 1024 * 1024 * 1024)
            return (value / (1024 * 1024)).toFixed(1) + " МБ"
        return (value / (1024 * 1024 * 1024)).toFixed(2) + " ГБ"
    }
}
