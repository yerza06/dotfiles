#!/bin/bash

# Получаем информацию о текущем треке
track=$(playerctl -p spotify metadata --format "{{ artist }} - {{ title }}")

# Если Spotify не запущен или трек не играет, выводим сообщение
if [ -z "$track" ]; then
  echo ""
else
  echo "$track"
fi
