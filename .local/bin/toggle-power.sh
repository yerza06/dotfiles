#!/bin/bash

# Получаем текущий профиль
current=$(powerprofilesctl get)

if [ "$current" == "power-saver" ]; then
    powerprofilesctl set balanced
    # notify-send -a "Power" -i battery-good "Профиль питания" "Сбалансированный (Balanced)"
elif [ "$current" == "balanced" ]; then
    powerprofilesctl set performance
    # notify-send -a "Power" -i battery-full "Профиль питания" "Производительность (Performance)"
else
    powerprofilesctl set power-saver
    # notify-send -a "Power" -i battery-empty "Профиль питания" "Энергосбережение (Power-saver)"
fi
