#!/bin/bash
current=$(gsettings get org.gnome.desktop.interface color-scheme)

if [ "$current" = "'prefer-dark'" ]; then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
    awww img --transition-step 15 ~/.config/wallpapers/secluded-grove-pixel-light.png
    notify-send "Тема изменена" "Включён светлый режим"
else
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    awww img --transition-step 15 ~/.config/wallpapers/secluded-grove-pixel-dark.png
    notify-send "Тема изменена" "Включён тёмный режим"
fi

# Quickshell отслеживает color-scheme через gsettings monitor и
# обновляет Flexoki Light/Dark реактивно, поэтому перезапуск не нужен.
