#!/bin/bash

# Скрипт для управления Bluetooth через bluetoothctl

show_usage() {
    echo "Использование: $0 {on|off|toggle|status}"
    echo ""
    echo "Команды:"
    echo "  on      - Включить Bluetooth"
    echo "  off     - Выключить Bluetooth"
    echo "  toggle  - Переключить состояние Bluetooth"
    echo "  status  - Показать текущее состояние Bluetooth"
    exit 1
}

check_bluetooth_status() {
    # Проверяем текущее состояние Bluetooth
    status=$(bluetoothctl show | grep "Powered:" | awk '{print $2}')
    echo "$status"
}

bluetooth_on() {
    echo "Включение Bluetooth..."
    echo "power on" | bluetoothctl > /dev/null 2>&1
    sleep 1
    if [ "$(check_bluetooth_status)" = "yes" ]; then
        echo "✓ Bluetooth успешно включен"
    else
        echo "✗ Ошибка при включении Bluetooth"
        exit 1
    fi
}

bluetooth_off() {
    echo "Выключение Bluetooth..."
    echo "power off" | bluetoothctl > /dev/null 2>&1
    sleep 1
    if [ "$(check_bluetooth_status)" = "no" ]; then
        echo "✓ Bluetooth успешно выключен"
    else
        echo "✗ Ошибка при выключении Bluetooth"
        exit 1
    fi
}

bluetooth_toggle() {
    current_status=$(check_bluetooth_status)
    if [ "$current_status" = "yes" ]; then
        bluetooth_off
    else
        bluetooth_on
    fi
}

bluetooth_status() {
    current_status=$(check_bluetooth_status)
    if [ "$current_status" = "yes" ]; then
        echo "Bluetooth: Включен"
    else
        echo "Bluetooth: Выключен"
    fi
}

# Проверяем наличие bluetoothctl
if ! command -v bluetoothctl &> /dev/null; then
    echo "Ошибка: bluetoothctl не найден"
    echo "Установите bluez пакет (например: sudo apt install bluez)"
    exit 1
fi

# Обработка аргументов
case "${1:-}" in
    on)
        bluetooth_on
        ;;
    off)
        bluetooth_off
        ;;
    toggle)
        bluetooth_toggle
        ;;
    status)
        bluetooth_status
        ;;
    *)
        show_usage
        ;;
esac
