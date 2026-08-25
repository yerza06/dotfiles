#!/usr/bin/env python3
"""Собирает data/glyphs.json из того, что уже установлено в системе.

Пакета с готовой базой эмодзи в Arch нет, а тянуть её из сети ради шелла не
хочется. Зато есть два оффлайн-источника, покрывающих всё нужное:

  * `unicodedata` из stdlib — официальные имена символов (UCD 16.0 в py3.14);
  * `fontTools` — таблица cmap шрифта Symbols Nerd Font, где имена глифов
    осмысленные (`md-folder_star`, `fa-github`, `dev-python`).

Результат детерминирован: ни таймстампов, ни путей — повторный запуск даёт
побайтово тот же файл, чтобы диффы в git оставались читаемыми.

Запуск:  python3 scripts/gen-glyphs.py
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
import unicodedata
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "data" / "glyphs.json"

# --- диапазоны ---------------------------------------------------------------

# Группы эмодзи по официальному emoji-test.txt (UTS #51, Emoji 17.0).
# Таблица вшита в скрипт намеренно: исходник лежит в кеше cargo и может
# исчезнуть, а генератор обязан оставаться самодостаточным и детерминированным.
EMOJI_GROUPS = {
    "smileys": [
        (0x2620, 0x2620), (0x2639, 0x263A), (0x2763, 0x2764), (0x1F479, 0x1F47B), (0x1F47D, 0x1F480),
        (0x1F48B, 0x1F48C), (0x1F493, 0x1F49F), (0x1F4A2, 0x1F4A2), (0x1F4A4, 0x1F4A6), (0x1F4A8, 0x1F4A9),
        (0x1F4AB, 0x1F4AD), (0x1F4AF, 0x1F4AF), (0x1F573, 0x1F573), (0x1F5A4, 0x1F5A4), (0x1F5E8, 0x1F5E8),
        (0x1F5EF, 0x1F5EF), (0x1F600, 0x1F644), (0x1F648, 0x1F64A), (0x1F90D, 0x1F90E), (0x1F910, 0x1F917),
        (0x1F920, 0x1F925), (0x1F927, 0x1F92F), (0x1F970, 0x1F976), (0x1F978, 0x1F97A), (0x1F9D0, 0x1F9D0),
        (0x1F9E1, 0x1F9E1), (0x1FA75, 0x1FA77), (0x1FAE0, 0x1FAE5), (0x1FAE8, 0x1FAEA), (0x1FAEF, 0x1FAEF),
    ],
    "people": [
        (0x261D, 0x261D), (0x26F7, 0x26F7), (0x26F9, 0x26F9), (0x270A, 0x270D), (0x1F385, 0x1F385),
        (0x1F3C2, 0x1F3C4), (0x1F3C7, 0x1F3C7), (0x1F3CA, 0x1F3CC), (0x1F440, 0x1F450), (0x1F463, 0x1F478),
        (0x1F47C, 0x1F47C), (0x1F481, 0x1F483), (0x1F485, 0x1F487), (0x1F48F, 0x1F48F), (0x1F491, 0x1F491),
        (0x1F4AA, 0x1F4AA), (0x1F574, 0x1F575), (0x1F57A, 0x1F57A), (0x1F590, 0x1F590), (0x1F595, 0x1F596),
        (0x1F5E3, 0x1F5E3), (0x1F645, 0x1F647), (0x1F64B, 0x1F64F), (0x1F6A3, 0x1F6A3), (0x1F6B4, 0x1F6B6),
        (0x1F6C0, 0x1F6C0), (0x1F6CC, 0x1F6CC), (0x1F90C, 0x1F90C), (0x1F90F, 0x1F90F), (0x1F918, 0x1F91F),
        (0x1F926, 0x1F926), (0x1F930, 0x1F93A), (0x1F93C, 0x1F93E), (0x1F977, 0x1F977), (0x1F9B4, 0x1F9B9),
        (0x1F9BB, 0x1F9BB), (0x1F9BE, 0x1F9BF), (0x1F9CC, 0x1F9CF), (0x1F9D1, 0x1F9E0), (0x1FAC0, 0x1FAC6),
        (0x1FAC8, 0x1FAC8), (0x1FAE6, 0x1FAE6), (0x1FAF0, 0x1FAF8),
    ],
    "nature": [
        (0x2618, 0x2618), (0x1F331, 0x1F335), (0x1F337, 0x1F33C), (0x1F33E, 0x1F344), (0x1F3F5, 0x1F3F5),
        (0x1F400, 0x1F43F), (0x1F490, 0x1F490), (0x1F4AE, 0x1F4AE), (0x1F54A, 0x1F54A), (0x1F577, 0x1F578),
        (0x1F940, 0x1F940), (0x1F980, 0x1F9AE), (0x1FAB0, 0x1FAB4), (0x1FAB6, 0x1FABF), (0x1FACD, 0x1FACF),
    ],
    "food": [
        (0x2615, 0x2615), (0x1F32D, 0x1F330), (0x1F336, 0x1F336), (0x1F33D, 0x1F33D), (0x1F345, 0x1F37F),
        (0x1F382, 0x1F382), (0x1F3FA, 0x1F3FA), (0x1F52A, 0x1F52A), (0x1F942, 0x1F944), (0x1F950, 0x1F96F),
        (0x1F9C0, 0x1F9CB), (0x1FAD0, 0x1FADC),
    ],
    "travel": [
        (0x231A, 0x231B), (0x23F0, 0x23F3), (0x2600, 0x2604), (0x2614, 0x2614), (0x2668, 0x2668),
        (0x2693, 0x2693), (0x26A1, 0x26A1), (0x26C4, 0x26C5), (0x26C8, 0x26C8), (0x26E9, 0x26EA),
        (0x26F0, 0x26F2), (0x26F4, 0x26F5), (0x26FA, 0x26FA), (0x26FD, 0x26FD), (0x2708, 0x2708),
        (0x2744, 0x2744), (0x2B50, 0x2B50), (0x1F300, 0x1F321), (0x1F324, 0x1F32C), (0x1F3A0, 0x1F3A2),
        (0x1F3AA, 0x1F3AA), (0x1F3CD, 0x1F3CE), (0x1F3D4, 0x1F3E6), (0x1F3E8, 0x1F3ED), (0x1F3EF, 0x1F3F0),
        (0x1F488, 0x1F488), (0x1F492, 0x1F492), (0x1F4A7, 0x1F4A7), (0x1F4BA, 0x1F4BA), (0x1F525, 0x1F525),
        (0x1F54B, 0x1F54D), (0x1F550, 0x1F567), (0x1F570, 0x1F570), (0x1F5FA, 0x1F5FE), (0x1F680, 0x1F6A2),
        (0x1F6A4, 0x1F6A8), (0x1F6B2, 0x1F6B2), (0x1F6CE, 0x1F6CE), (0x1F6D1, 0x1F6D1), (0x1F6D5, 0x1F6D6),
        (0x1F6D8, 0x1F6D8), (0x1F6DD, 0x1F6DF), (0x1F6E2, 0x1F6E5), (0x1F6E9, 0x1F6E9), (0x1F6EB, 0x1F6EC),
        (0x1F6F0, 0x1F6F0), (0x1F6F3, 0x1F6F6), (0x1F6F8, 0x1F6FC), (0x1F9BC, 0x1F9BD), (0x1F9ED, 0x1F9ED),
        (0x1F9F1, 0x1F9F1), (0x1F9F3, 0x1F9F3), (0x1FA82, 0x1FA82), (0x1FA90, 0x1FA90), (0x1FAA8, 0x1FAA8),
        (0x1FAB5, 0x1FAB5),
    ],
    "activities": [
        (0x265F, 0x2660), (0x2663, 0x2663), (0x2665, 0x2666), (0x26BD, 0x26BE), (0x26F3, 0x26F3),
        (0x26F8, 0x26F8), (0x2728, 0x2728), (0x1F004, 0x1F004), (0x1F0CF, 0x1F0CF), (0x1F380, 0x1F381),
        (0x1F383, 0x1F384), (0x1F386, 0x1F38B), (0x1F38D, 0x1F391), (0x1F396, 0x1F397), (0x1F39F, 0x1F39F),
        (0x1F3A3, 0x1F3A3), (0x1F3A8, 0x1F3A8), (0x1F3AB, 0x1F3AB), (0x1F3AD, 0x1F3B4), (0x1F3BD, 0x1F3C0),
        (0x1F3C5, 0x1F3C6), (0x1F3C8, 0x1F3C9), (0x1F3CF, 0x1F3D3), (0x1F3F8, 0x1F3F8), (0x1F52B, 0x1F52B),
        (0x1F52E, 0x1F52E), (0x1F579, 0x1F579), (0x1F5BC, 0x1F5BC), (0x1F6F7, 0x1F6F7), (0x1F93F, 0x1F93F),
        (0x1F945, 0x1F945), (0x1F947, 0x1F94F), (0x1F9E7, 0x1F9E9), (0x1F9F5, 0x1F9F6), (0x1F9F8, 0x1F9F8),
        (0x1FA80, 0x1FA81), (0x1FA84, 0x1FA86), (0x1FAA1, 0x1FAA2), (0x1FAA9, 0x1FAA9),
    ],
    "objects": [
        (0x2328, 0x2328), (0x260E, 0x260E), (0x2692, 0x2692), (0x2694, 0x2694), (0x2696, 0x2697),
        (0x2699, 0x2699), (0x26B0, 0x26B1), (0x26CF, 0x26CF), (0x26D1, 0x26D1), (0x26D3, 0x26D3),
        (0x2702, 0x2702), (0x2709, 0x2709), (0x270F, 0x270F), (0x2712, 0x2712), (0x1F392, 0x1F393),
        (0x1F399, 0x1F39B), (0x1F39E, 0x1F39E), (0x1F3A4, 0x1F3A5), (0x1F3A7, 0x1F3A7), (0x1F3A9, 0x1F3A9),
        (0x1F3AC, 0x1F3AC), (0x1F3B5, 0x1F3BC), (0x1F3EE, 0x1F3EE), (0x1F3F7, 0x1F3F7), (0x1F3F9, 0x1F3F9),
        (0x1F451, 0x1F462), (0x1F484, 0x1F484), (0x1F489, 0x1F48A), (0x1F48D, 0x1F48E), (0x1F4A1, 0x1F4A1),
        (0x1F4A3, 0x1F4A3), (0x1F4B0, 0x1F4B0), (0x1F4B3, 0x1F4B9), (0x1F4BB, 0x1F4DA), (0x1F4DC, 0x1F4F2),
        (0x1F4F7, 0x1F4FD), (0x1F4FF, 0x1F4FF), (0x1F507, 0x1F517), (0x1F526, 0x1F529), (0x1F52C, 0x1F52D),
        (0x1F56F, 0x1F56F), (0x1F576, 0x1F576), (0x1F587, 0x1F587), (0x1F58A, 0x1F58D), (0x1F5A5, 0x1F5A5),
        (0x1F5A8, 0x1F5A8), (0x1F5B1, 0x1F5B2), (0x1F5C2, 0x1F5C4), (0x1F5D1, 0x1F5D3), (0x1F5DC, 0x1F5DE),
        (0x1F5E1, 0x1F5E1), (0x1F5F3, 0x1F5F3), (0x1F5FF, 0x1F5FF), (0x1F6AA, 0x1F6AA), (0x1F6AC, 0x1F6AC),
        (0x1F6BD, 0x1F6BD), (0x1F6BF, 0x1F6BF), (0x1F6C1, 0x1F6C1), (0x1F6CB, 0x1F6CB), (0x1F6CD, 0x1F6CD),
        (0x1F6CF, 0x1F6CF), (0x1F6D2, 0x1F6D2), (0x1F6D7, 0x1F6D7), (0x1F6E0, 0x1F6E1), (0x1F941, 0x1F941),
        (0x1F97B, 0x1F97F), (0x1F9AF, 0x1F9AF), (0x1F9BA, 0x1F9BA), (0x1F9E2, 0x1F9E6), (0x1F9EA, 0x1F9EC),
        (0x1F9EE, 0x1F9F0), (0x1F9F2, 0x1F9F2), (0x1F9F4, 0x1F9F4), (0x1F9F7, 0x1F9F7), (0x1F9F9, 0x1F9FF),
        (0x1FA70, 0x1FA74), (0x1FA78, 0x1FA7C), (0x1FA83, 0x1FA83), (0x1FA87, 0x1FA8A), (0x1FA8E, 0x1FA8F),
        (0x1FA91, 0x1FAA0), (0x1FAA3, 0x1FAA7), (0x1FAAA, 0x1FAAE), (0x1FAE7, 0x1FAE7),
    ],
    "signs": [
        (0x00A9, 0x00A9), (0x00AE, 0x00AE), (0x203C, 0x203C), (0x2049, 0x2049), (0x2122, 0x2122),
        (0x2139, 0x2139), (0x2194, 0x2199), (0x21A9, 0x21AA), (0x23CF, 0x23CF), (0x23E9, 0x23EF),
        (0x23F8, 0x23FA), (0x24C2, 0x24C2), (0x25AA, 0x25AB), (0x25B6, 0x25B6), (0x25C0, 0x25C0),
        (0x25FB, 0x25FE), (0x2611, 0x2611), (0x2622, 0x2623), (0x2626, 0x2626), (0x262A, 0x262A),
        (0x262E, 0x262F), (0x2638, 0x2638), (0x2640, 0x2640), (0x2642, 0x2642), (0x2648, 0x2653),
        (0x267B, 0x267B), (0x267E, 0x267F), (0x2695, 0x2695), (0x269B, 0x269C), (0x26A0, 0x26A0),
        (0x26A7, 0x26A7), (0x26AA, 0x26AB), (0x26CE, 0x26CE), (0x26D4, 0x26D4), (0x2705, 0x2705),
        (0x2714, 0x2714), (0x2716, 0x2716), (0x271D, 0x271D), (0x2721, 0x2721), (0x2733, 0x2734),
        (0x2747, 0x2747), (0x274C, 0x274C), (0x274E, 0x274E), (0x2753, 0x2755), (0x2757, 0x2757),
        (0x2795, 0x2797), (0x27A1, 0x27A1), (0x27B0, 0x27B0), (0x27BF, 0x27BF), (0x2934, 0x2935),
        (0x2B05, 0x2B07), (0x2B1B, 0x2B1C), (0x2B55, 0x2B55), (0x3030, 0x3030), (0x303D, 0x303D),
        (0x3297, 0x3297), (0x3299, 0x3299), (0x1F170, 0x1F171), (0x1F17E, 0x1F17F), (0x1F18E, 0x1F18E),
        (0x1F191, 0x1F19A), (0x1F201, 0x1F202), (0x1F21A, 0x1F21A), (0x1F22F, 0x1F22F), (0x1F232, 0x1F23A),
        (0x1F250, 0x1F251), (0x1F3A6, 0x1F3A6), (0x1F3E7, 0x1F3E7), (0x1F4A0, 0x1F4A0), (0x1F4B1, 0x1F4B2),
        (0x1F4DB, 0x1F4DB), (0x1F4F3, 0x1F4F6), (0x1F500, 0x1F506), (0x1F518, 0x1F524), (0x1F52F, 0x1F53D),
        (0x1F549, 0x1F549), (0x1F54E, 0x1F54E), (0x1F6AB, 0x1F6AB), (0x1F6AD, 0x1F6B1), (0x1F6B3, 0x1F6B3),
        (0x1F6B7, 0x1F6BC), (0x1F6BE, 0x1F6BE), (0x1F6C2, 0x1F6C5), (0x1F6D0, 0x1F6D0), (0x1F6DC, 0x1F6DC),
        (0x1F7E0, 0x1F7EB), (0x1F7F0, 0x1F7F0), (0x1FAAF, 0x1FAAF), (0x1FADF, 0x1FADF),
    ],
    "flags": [
        (0x1F38C, 0x1F38C), (0x1F3C1, 0x1F3C1), (0x1F3F3, 0x1F3F4), (0x1F6A9, 0x1F6A9),
    ],
}

# Пиктограммы, которые лежат в «эмодзи-блоках», но эмодзи не являются: маджонг,
# игральные карты, дингбаты, часть Misc Symbols. Раньше они попадали в раздел
# «Эмодзи» и засоряли его почти тысячей записей — теперь проваливаются в
# «Символы», куда и относятся по смыслу.
PICTOGRAPH_RANGES = [
    (0x1F000, 0x1F0FF),  # игральные карты, маджонг, домино
    (0x1F300, 0x1F5FF),  # природа, погода, объекты
    (0x1F600, 0x1F64F),  # смайлы и жесты
    (0x1F680, 0x1F6FF),  # транспорт и карты
    (0x1F900, 0x1F9FF),  # дополнение: лица, люди, предметы
    (0x1FA70, 0x1FAFF),  # расширение 12.0+
    (0x2600, 0x27BF),    # разное + дингбаты
    (0x2B00, 0x2BFF),    # разные стрелки-символы
]

SYMBOL_RANGES = [
    (0x00A0, 0x00FF),  # latin-1: © ± × ÷ ¶ §
    (0x0370, 0x03FF),  # греческий
    (0x2000, 0x206F),  # пунктуация: — … • ‰ „ “
    (0x20A0, 0x20BF),  # валюты
    (0x2100, 0x214F),  # ™ № ℃ ℉ ℹ
    (0x2150, 0x218F),  # дроби и римские цифры
    (0x2190, 0x21FF),  # стрелки
    (0x2200, 0x22FF),  # математические операторы
    (0x2300, 0x23FF),  # технические знаки
    (0x2500, 0x259F),  # рамки и блоки
    (0x25A0, 0x25FF),  # геометрические фигуры
    (0x27F0, 0x27FF),  # дополнительные стрелки
    (0x2A00, 0x2AFF),  # дополнительная математика
]

# Всё это либо невидимо само по себе, либо осмысленно только в составе
# последовательности, поэтому отдельной строкой в списке быть не должно.
EXCLUDED_RANGES = [
    (0x1F3FB, 0x1F3FF),  # модификаторы тона кожи
    (0x1F1E6, 0x1F1FF),  # regional indicators (флаги собираются парами)
    (0xFE00, 0xFE0F),    # селекторы начертания
    (0xE0000, 0xE007F),  # теги
]


# Подгруппы раздела «Символы». Диапазоны те же, что в SYMBOL_RANGES, плюс то,
# что не прошло отбор в эмодзи и провалилось сюда.
SYMBOL_GROUPS = [
    ((0x00A0, 0x00FF), "latin"),
    ((0x0370, 0x03FF), "greek"),
    ((0x2000, 0x206F), "punct"),
    ((0x20A0, 0x20BF), "currency"),
    ((0x2100, 0x214F), "letterlike"),
    ((0x2150, 0x218F), "numbers"),
    ((0x2190, 0x21FF), "arrows"),
    ((0x27F0, 0x27FF), "arrows"),
    ((0x2B00, 0x2BFF), "arrows"),
    ((0x2200, 0x22FF), "math"),
    ((0x2A00, 0x2AFF), "math"),
    ((0x2300, 0x23FF), "technical"),
    ((0x2500, 0x259F), "box"),
    ((0x25A0, 0x25FF), "shapes"),
    ((0x1F000, 0x1F0FF), "games"),
]

SKIP_CATEGORIES = {"Cc", "Cf", "Cn", "Co", "Cs", "Zl", "Zp", "Zs"}

# Официальные имена Unicode местами далеки от того, что человек набирает в
# поиске: ❤ называется «heavy black heart», 👍 — «thumbs up sign». Здесь только
# то, что действительно ищут по-другому; остальное имя покрывает само.
ALIASES = {
    0x2764: "heart love red",
    0x1F494: "broken heart",
    0x1F44D: "thumbsup like ok yes +1",
    0x1F44E: "thumbsdown dislike no -1",
    0x1F44C: "ok perfect",
    0x1F64F: "please thanks pray",
    0x1F525: "fire lit hot",
    0x1F680: "rocket launch ship deploy",
    0x1F41B: "bug issue",
    0x2705: "check done ok green",
    0x274C: "cross no fail red",
    0x2714: "check tick done",
    0x2716: "cross multiply",
    0x26A0: "warning caution attention",
    0x1F389: "party tada celebrate release",
    0x1F4A9: "poop shit",
    0x1F602: "lol laugh cry funny",
    0x1F914: "thinking hmm",
    0x1F440: "eyes look watch review",
    0x1F44F: "clap applause",
    0x1F4A1: "idea bulb light",
    0x1F512: "lock secure closed",
    0x1F513: "unlock open",
    0x1F4E6: "package box release npm",
    0x1F527: "wrench fix tool",
    0x1F6A7: "construction wip work in progress",
    0x1F971: "yawn tired sleepy",
    0x1F9E0: "brain smart ai",
    0x1F440 + 0: "eyes",
    0x2B50: "star favourite favorite",
    0x1F4CC: "pin pinned",
    0x1F4DD: "memo note write docs",
    0x1F4CA: "chart graph stats",
    0x23F0: "alarm clock timer",
    0x1F3AF: "target goal dart",
    0x1F195: "new",
    0x00A9: "copyright",
    0x00AE: "registered",
    0x2122: "trademark tm",
    0x00B0: "degree",
    0x20AC: "euro",
    0x00A3: "pound gbp",
    0x00A5: "yen",
    0x20BD: "ruble rouble",
    0x2026: "ellipsis dots",
    0x2014: "em dash",
    0x2013: "en dash",
    0x00B1: "plus minus",
    0x00D7: "multiply times",
    0x00F7: "divide",
    0x2260: "not equal",
    0x2264: "less or equal",
    0x2265: "greater or equal",
    0x221E: "infinity",
    0x2211: "sum sigma",
    0x221A: "sqrt root",
    0x2192: "right arrow",
    0x2190: "left arrow",
    0x2191: "up arrow",
    0x2193: "down arrow",
    0x21B5: "return enter newline",
    0x2318: "command cmd mac",
    0x2325: "option alt mac",
    0x21E7: "shift",
    0x232B: "backspace delete",
    0x2423: "space",
    0x2116: "numero number",
}

# Каомодзи Unicode не знает — только ручной список. Отобраны те, что реально
# уходят в переписку; имя пишется так, как их ищут словами.
KAOMOJI = [
    ("¯\\_(ツ)_/¯", "shrug", "dunno whatever idk неважно пожатие плеч"),
    ("(╯°□°）╯︵ ┻━┻", "table flip", "rage angry flip злость стол"),
    ("┬─┬ ノ( ゜-゜ノ)", "table unflip", "calm put back спокойствие"),
    ("(ノಠ益ಠ)ノ彡┻━┻", "rage flip", "furious angry ярость"),
    ("ಠ_ಠ", "disapproval", "look stare judging осуждение взгляд"),
    ("ಠ益ಠ", "angry stare", "rage furious"),
    ("(╬ಠ益ಠ)", "very angry", "rage mad"),
    ("(◕‿◕)", "happy", "smile cute радость"),
    ("(｡◕‿◕｡)", "cute smile", "kawaii adorable"),
    ("(✿◠‿◠)", "flower smile", "cute happy"),
    ("(⌐■_■)", "deal with it", "cool sunglasses круто"),
    ("(•_•)", "blank stare", "what confused"),
    ("( •_•)>⌐■-■", "putting on glasses", "cool deal with it"),
    ("(っ◔◡◔)っ", "hug", "love offering обнимашки"),
    ("(づ｡◕‿‿◕｡)づ", "big hug", "love cuddle"),
    ("(つ﹏⊂)", "crying", "sad tears плач"),
    ("(ಥ﹏ಥ)", "sobbing", "sad crying tears"),
    ("(T_T)", "crying", "sad tears"),
    ("(ノ_<。)", "sad", "crying upset"),
    ("(・_・;)", "nervous", "sweat awkward неловко"),
    ("(-_-;)", "annoyed", "tired sigh"),
    ("(￣ー￣)", "smug", "smirk"),
    ("(¬‿¬)", "smirk", "sly mischief"),
    ("(^_^)", "smile", "happy"),
    ("(^_^)/", "waving", "hi hello bye привет"),
    ("(*^▽^*)", "excited", "joy happy"),
    ("\\(^o^)/", "cheering", "yay hooray ура"),
    ("(>_<)", "frustrated", "ouch pain"),
    ("(°ロ°)", "shocked", "surprised omg шок"),
    ("(⊙_⊙)", "surprised", "wide eyes shock"),
    ("(◔_◔)", "side eye", "doubt skeptical"),
    ("(¬_¬)", "unimpressed", "annoyed side eye"),
    ("(=^･ω･^=)", "cat", "kitty meow кот"),
    ("(=^‥^=)", "cat face", "kitty кот"),
    ("ʕ•ᴥ•ʔ", "bear", "cute медведь"),
    ("(づ￣ ³￣)づ", "kiss", "love smooch поцелуй"),
    ("(~_~;)", "confused", "unsure puzzled"),
    ("(￣▽￣)ノ", "casual wave", "hey bye"),
    ("＼(°o°)／", "panic", "shock scream"),
    ("(ง'̀-'́)ง", "fight me", "ready fists драка"),
    ("ᕕ( ᐛ )ᕗ", "running", "happy go leaving"),
    ("(҂◡_◡)", "beaten", "defeated tired"),
    ("(๑•̀ㅂ•́)و✧", "determined", "lets go motivated вперёд"),
    ("(｡•̀ᴗ-)✧", "wink", "confident подмигивание"),
    ("( ͡° ͜ʖ ͡°)", "lenny", "lewd smirk ленни"),
    ("┌(・。・)┘♪", "dancing", "music happy танец"),
    ("♪~ ᕕ(ᐛ)ᕗ", "walking to music", "happy dance"),
    ("(=￣ω￣=)", "content cat", "smug cat"),
    ("(＃￣0￣)", "grumpy", "annoyed angry"),
    ("(´･_･`)", "worried", "concerned unsure"),
    ("(￣～￣;)", "unsure", "hmm thinking"),
    ("(°ω°)", "blank", "dazed"),
    ("(￢_￢)", "suspicious", "side eye doubt"),
    ("〒▽〒", "bawling", "crying rivers"),
    ("(ﾉ◕ヮ◕)ﾉ*:･ﾟ✧", "sparkle throw", "magic yay волшебство"),
    ("✧･ﾟ: *✧･ﾟ:*", "sparkles", "magic shiny блеск"),
    ("(ᵔᴥᵔ)", "happy dog", "puppy cute собака"),
    ("૮ ˶ᵔ ᵕ ᵔ˶ ა", "soft cat", "cozy cute"),
    ("(っ˘̩╭╮˘̩)っ", "sad hug", "comfort crying"),
    ("(⑅˘꒳˘)", "content", "cozy soft happy"),
    ("(ㆆ_ㆆ)", "suspicious stare", "doubt"),
    ("(•̀ᴗ•́)و", "you got this", "encourage motivated"),
    ("♥‿♥", "in love", "hearts eyes влюблён"),
    ("(◍•ᴗ•◍)", "warm smile", "cute happy"),
    ("(ᗒᗣᗕ)՞", "distressed", "upset crying"),
    ("凸(￣ヘ￣)", "middle finger", "rude fuck off"),
    ("(￣^￣)ゞ", "salute", "yes sir честь"),
    ("m(_ _)m", "bow apology", "sorry извинение"),
    ("(＾▽＾)", "big smile", "joy happy"),
    ("(・・;)", "sweatdrop", "awkward nervous"),
    ("(°益°)", "outraged", "furious"),
    ("(¤_¤)", "dizzy", "confused stunned"),
    ("(=_=)", "exhausted", "tired sleepy устал"),
    ("(-_-)zzz", "sleeping", "asleep tired сон"),
    ("(o_O)", "wat", "confused what"),
    ("(⚆_⚆)", "startled", "surprised"),
    ("¯\\(°_o)/¯", "confused shrug", "dunno what"),
]


def in_ranges(cp: int, ranges: list[tuple[int, int]]) -> bool:
    return any(low <= cp <= high for low, high in ranges)


def usable(ch: str) -> bool:
    return unicodedata.category(ch) not in SKIP_CATEGORIES and not unicodedata.category(ch).startswith("M")


def symbol_group(cp: int) -> str:
    for (low, high), group in SYMBOL_GROUPS:
        if low <= cp <= high:
            return group
    return "pictographs"


def make(cp: int, group: str, subgroup: str) -> dict | None:
    if in_ranges(cp, EXCLUDED_RANGES):
        return None
    ch = chr(cp)
    try:
        name = unicodedata.name(ch).lower()
    except ValueError:
        return None
    if not usable(ch):
        return None

    keywords = f"{name} {subgroup}" if subgroup else name
    alias = ALIASES.get(cp)
    if alias:
        keywords += " " + alias
    return {
        "c": ch,
        "n": name,
        "k": keywords,
        "g": group,
        "s": subgroup,
        "u": f"U+{cp:04X}",
    }


def collect_emoji(seen: set[int]) -> list[dict]:
    """Только то, что Unicode считает эмодзи, — с официальной группой каждого."""
    items = []
    for subgroup, ranges in EMOJI_GROUPS.items():
        for low, high in ranges:
            for cp in range(low, high + 1):
                if cp in seen:
                    continue
                entry = make(cp, "emoji", subgroup)
                if entry is None:
                    continue
                seen.add(cp)
                items.append(entry)
    items.sort(key=lambda item: item["u"])
    return items


def collect_symbols(seen: set[int]) -> list[dict]:
    """Символы плюс всё, что не прошло отбор в эмодзи."""
    items = []
    for low, high in SYMBOL_RANGES + PICTOGRAPH_RANGES:
        for cp in range(low, high + 1):
            if cp in seen:
                continue
            entry = make(cp, "symbol", symbol_group(cp))
            if entry is None:
                continue
            seen.add(cp)
            items.append(entry)
    items.sort(key=lambda item: item["u"])
    return items


# Ниже этого размера набор иконок не получает собственную вкладку.
NERD_MIN_SUBGROUP = 10

PLACEHOLDER = re.compile(r"^u(ni)?[0-9a-fA-F]{4,6}$")


def nerd_font_path() -> str | None:
    try:
        out = subprocess.run(
            ["fc-match", "-f", "%{file}", "Symbols Nerd Font"],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return None
    return out or None


def collect_nerd() -> list[dict]:
    path = nerd_font_path()
    if not path:
        print("  Symbols Nerd Font не найден — раздел пропущен", file=sys.stderr)
        return []
    try:
        from fontTools.ttLib import TTFont
    except ImportError:
        print("  fontTools не установлен — раздел пропущен", file=sys.stderr)
        return []

    cmap = TTFont(path, lazy=True).getBestCmap()

    def split(glyph: str) -> tuple[str, str]:
        prefix, _, rest = glyph.partition("-")
        if not rest:
            return "other", glyph
        return prefix, rest

    # Префиксы имён глифов дают набор иконок (md, fa, dev…), но у хвоста из
    # одиночных глифов набора по сути нет — отдельная вкладка под одну иконку
    # только засоряет полосу подразделов, поэтому мелочь сводится в «прочее».
    sizes: dict[str, int] = {}
    for glyph in cmap.values():
        if PLACEHOLDER.match(glyph):
            continue
        sizes[split(glyph)[0]] = sizes.get(split(glyph)[0], 0) + 1

    items = []
    for cp, glyph in cmap.items():
        if PLACEHOLDER.match(glyph):
            continue
        prefix, rest = split(glyph)
        name = rest.replace("_", " ").replace("-", " ").strip().lower()
        if not name:
            continue
        subgroup = prefix if sizes.get(prefix, 0) >= NERD_MIN_SUBGROUP else "other"
        items.append({
            "c": chr(cp),
            "n": name,
            "k": f"{name} {prefix} nerd icon",
            "g": "nerd",
            "s": subgroup,
            "u": f"U+{cp:04X}",
        })
    items.sort(key=lambda item: (item["n"], item["u"]))
    return items


def main() -> int:
    seen: set[int] = set()
    # Порядок важен: эмодзи забирают свои кодпоинты первыми, символы подбирают
    # всё остальное, включая пиктограммы, не попавшие в официальный список.
    emoji = collect_emoji(seen)
    symbols = collect_symbols(seen)
    kaomoji = [
        {"c": text, "n": name, "k": f"{name} {keywords} kaomoji ascii",
         "g": "kaomoji", "s": "", "u": ""}
        for text, name, keywords in KAOMOJI
    ]
    nerd = collect_nerd()

    items = emoji + symbols + kaomoji + nerd
    payload = {
        "unicode": unicodedata.unidata_version,
        "counts": {
            "emoji": len(emoji),
            "symbol": len(symbols),
            "kaomoji": len(kaomoji),
            "nerd": len(nerd),
        },
        "items": items,
    }

    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, ensure_ascii=False, separators=(",", ":"))
        handle.write("\n")

    size = OUT.stat().st_size
    print(f"UCD {payload['unicode']}")
    for group, count in payload["counts"].items():
        print(f"  {group:8} {count:6}")
        subs = {}
        for item in items:
            if item["g"] == group and item["s"]:
                subs[item["s"]] = subs.get(item["s"], 0) + 1
        for sub, n in sorted(subs.items(), key=lambda pair: -pair[1])[:12]:
            print(f"      {sub:14} {n:5}")
    print(f"  {'итого':8} {len(items):6}   {size / 1024:.0f} КБ → {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
