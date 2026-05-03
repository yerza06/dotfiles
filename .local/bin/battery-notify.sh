#!/bin/bash

export DISPLAY=:0
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus

# Файл для хранения предыдущего статуса батареи
STATUS_FILE="/tmp/battery_status.txt"

# Получаем процент заряда батареи
battery_level=$(cat /sys/class/power_supply/BAT0/capacity)

# Получаем статус батареи (Charging/Discharging)
battery_status=$(cat /sys/class/power_supply/BAT0/status)

# Читаем предыдущий статус
if [ -f "$STATUS_FILE" ]; then
    previous_status=$(cat "$STATUS_FILE")
else
    previous_status=""
fi

# Сохраняем текущий статус для следующей проверки
echo "$battery_status" > "$STATUS_FILE"

# Проверяем, начала ли батарея заряжаться
if [ "$battery_status" = "Charging" ] && [ "$previous_status" = "Discharging" ]; then
    notify-send -u normal "Зарядка подключена" "Батарея заряжается. Текущий уровень: $battery_level%"
fi

# Проверяем, разряжается ли батарея
if [ "$battery_status" = "Discharging" ]; then
    if [ "$battery_level" -le 15 ]; then
        notify-send -u critical "Критически низкий заряд батареи!" "Осталось $battery_level%. Подключите зарядное устройство!"
    elif [ "$battery_level" -le 30 ]; then
        notify-send -u normal "Низкий заряд батареи" "Осталось $battery_level%. Рекомендуется подключить зарядное устройство."
    fi
fi
