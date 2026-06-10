#!/bin/bash

# Получаем текущий профиль
current=$(powerprofilesctl get)

if [ "$current" == "power-saver" ]; then
    powerprofilesctl set balanced
    notify-send "Профиль питания" "Сбалансированный (Balanced)"
elif [ "$current" == "balanced" ]; then
    powerprofilesctl set performance
    notify-send "Профиль питания" "Производительность (Performance)"
else
    powerprofilesctl set power-saver
    notify-send "Профиль питания" "Энергосбережение (Power-saver)"
fi
