#!/bin/bash
current=$(gsettings get org.gnome.desktop.interface color-scheme)

if [ "$current" = "'prefer-dark'" ]; then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
    notify-send "Тема изменена" "Включён светлый режим" -i weather-clear
else
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    notify-send "Тема изменена" "Включён тёмный режим" -i weather-clear-night
fi
