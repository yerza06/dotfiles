#!/bin/bash
# Скрипт для создания скриншота.
# Принимает аргумент "full" для скриншота всего экрана
# или "area" для выбора области.

# Директория для сохранения скриншотов
SCREENSHOT_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SCREENSHOT_DIR"

# Имя файла для скриншота
FILENAME="$SCREENSHOT_DIR/$(date +'%Y-%m-%d_%H-%M-%S').png"

if [ "$1" == "full" ]; then
    # Сделать скриншот всего экрана, сохранить в файл и скопировать в буфер обмена
    grim - | tee "$FILENAME" | wl-copy
    if [ ${PIPESTATUS[0]} -eq 0 ] && [ ${PIPESTATUS[1]} -eq 0 ] && [ ${PIPESTATUS[2]} -eq 0 ]; then
      notify-send "Скриншот сохранен и скопирован" "Весь экран сохранен в $FILENAME и скопирован в буфер обмена."
    else
      notify-send "Ошибка скриншота" "Не удалось сделать, сохранить или скопировать скриншот."
    fi
elif [ "$1" == "area" ]; then
    # Выбрать область с помощью slurp. Если пользователь отменяет выбор, выйти.
    GEOMETRY=$(slurp)
    if [ -z "$GEOMETRY" ]; then
        exit 1
    fi

    # Захватить выбранную область, сохранить и передать в wl-copy
    grim -g "$GEOMETRY" - | tee "$FILENAME" | wl-copy

    # Проверить, успешно ли выполнились grim, tee и wl-copy
    if [ ${PIPESTATUS[0]} -eq 0 ] && [ ${PIPESTATUS[1]} -eq 0 ] && [ ${PIPESTATUS[2]} -eq 0 ]; then
      notify-send "Скриншот сохранен и скопирован" "Выбранная область сохранена в $FILENAME и скопирована в буфер обмена."
    else
      notify-send "Ошибка скриншота" "Не удалось сделать, сохранить или скопировать скриншот."
    fi
else
    # Если аргумент не "full" или "area", вывести инструкцию
    echo "Использование: $0 [full|area]"
    exit 1
fi
