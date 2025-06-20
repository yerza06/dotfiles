#!/usr/bin/env python3

import datetime
import json
import sys

# Целевая дата и время
# Установите вашу целевую дату здесь: год, месяц, день, час, минута, секунда
# Например, до Нового года 2026:
target_date = datetime.datetime(2025, 6, 25)
# Если вы хотите указать часовой пояс, используйте pytz:
# import pytz
# target_timezone = pytz.timezone('Europe/Moscow')
# target_date = target_timezone.localize(datetime.datetime(2026, 1, 1, 0, 0, 0))

current_date = datetime.datetime.now() # Текущее локальное время

# Если целевая дата уже прошла, можно отобразить что-то другое
if current_date > target_date:
    time_left = datetime.timedelta(seconds=0) # Или можно сделать отрицательное значение
else:
    time_left = target_date - current_date

days = time_left.days
seconds = int(time_left.total_seconds())

hours = seconds // 3600 // 24
minutes = (seconds % 3600) // 60
remaining_seconds = seconds % 60

# Формат вывода для Waybar
# Waybar ожидает JSON-объект для более продвинутых функций (например, классов CSS, всплывающих подсказок)
# Или просто текстовую строку
output_text = ""
if days > 0:
    output_text += f"{days}:"
if hours > 0 or days > 0: # Показываем часы, если есть дни или если часы > 0
    output_text += f"{hours}:"
if minutes > 0 or hours > 0 or days > 0: # Показываем минуты, если есть дни/часы или если минуты > 0
    output_text += f"{minutes}:"
output_text += f"{remaining_seconds}"

# Создаем JSON-вывод для Waybar
waybar_output = {
    "text": output_text,
    "tooltip": f"До {target_date.strftime('%Y-%m-%d %H:%M:%S')}",
    "class": "countdown" # Можно использовать для CSS стилизации
}

print(json.dumps(waybar_output))

# Можно также вывести простой текст, если не нужны классы или тултипы:
# print(output_text)
