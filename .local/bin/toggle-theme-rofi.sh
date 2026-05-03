#!/bin/bash
options="Dark\nLight"
choice=$(echo -e "$options" | rofi -dmenu -p "Выбери режим:")

case "$choice" in
    Dark)
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
        notify-send "Тёмная тема активирована"
        ;;
    Light)
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
        notify-send "Светлая тема активирована"
        ;;
esac
