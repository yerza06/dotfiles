#!/bin/bash

# Скрипт для управления WiFi через nmcli

show_usage() {
    echo "Использование: $0 {on|off|toggle|status}"
    echo ""
    echo "Команды:"
    echo "  on      - Включить WiFi"
    echo "  off     - Выключить WiFi"
    echo "  toggle  - Переключить состояние WiFi"
    echo "  status  - Показать текущее состояние WiFi"
    exit 1
}

check_wifi_status() {
    # Проверяем текущее состояние WiFi
    status=$(nmcli radio wifi)
    echo "$status"
}

wifi_on() {
    echo "Включение WiFi..."
    nmcli radio wifi on
    sleep 1
    if [ "$(check_wifi_status)" = "enabled" ]; then
        echo "✓ WiFi успешно включен"
    else
        echo "✗ Ошибка при включении WiFi"
        exit 1
    fi
}

wifi_off() {
    echo "Выключение WiFi..."
    nmcli radio wifi off
    sleep 1
    if [ "$(check_wifi_status)" = "disabled" ]; then
        echo "✓ WiFi успешно выключен"
    else
        echo "✗ Ошибка при выключении WiFi"
        exit 1
    fi
}

wifi_toggle() {
    current_status=$(check_wifi_status)
    if [ "$current_status" = "enabled" ]; then
        wifi_off
    else
        wifi_on
    fi
}

wifi_status() {
    current_status=$(check_wifi_status)
    if [ "$current_status" = "enabled" ]; then
        echo "WiFi: Включен"
        # Показываем подключенную сеть, если есть
        connected=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2)
        if [ -n "$connected" ]; then
            echo "Подключено к: $connected"
        fi
    else
        echo "WiFi: Выключен"
    fi
}

# Проверяем наличие nmcli
if ! command -v nmcli &> /dev/null; then
    echo "Ошибка: nmcli не найден"
    echo "Установите NetworkManager (например: sudo apt install network-manager)"
    exit 1
fi

# Обработка аргументов
case "${1:-}" in
    on)
        wifi_on
        ;;
    off)
        wifi_off
        ;;
    toggle)
        wifi_toggle
        ;;
    status)
        wifi_status
        ;;
    *)
        show_usage
        ;;
esac
