# Quickshell Application Launcher

Замена rofi `-show drun` на Quickshell. Сеточный лаунчер приложений в теме Flexoki — той же, что у status bar и уведомлений: цвета переключаются между Flexoki Light и Dark по `org.gnome.desktop.interface color-scheme`.

## Возможности

- Сетка иконок по 5 колонок, поиск в верхней строке, подсказка `Comment` выбранного приложения в футере.
- Вкладки-категории под строкой поиска (см. ниже). Число справа в шапке — сколько приложений в текущей выборке.
- Нечёткий поиск: точное совпадение → префикс → начало слова → подстрока → подпоследовательность (`gimp` находит «GNU Image Manipulation Program»). Имя, `GenericName` и id ищутся нечётко; `Keywords`, `Exec` и `Comment` — только по подстроке, чтобы не засорять выдачу.
- Частота запусков запоминается в `~/.local/state/quickshell/by-shell/<id>/usage.json` — при пустом запросе сверху идут самые используемые приложения.
- `Terminal=true` в `.desktop` запускается через `kitty -e`.
- Приложения без иконки показывают плитку с первой буквой названия.
- Лаунчер открывается на том мониторе, который сейчас в фокусе (`niri msg focused-output`).

## Управление

| Клавиша | Действие |
| --- | --- |
| текст | фильтрация |
| `↑` `↓` | строка вверх/вниз |
| `←` `→` | соседнее приложение (когда курсор в конце/начале строки поиска) |
| `Tab` / `Shift+Tab` | следующее/предыдущее |
| `Ctrl+h` / `Ctrl+l` | предыдущая/следующая категория (по кругу) |
| `Ctrl+←` / `Ctrl+→` | то же самое стрелками |
| `PageUp` / `PageDown` | две строки |
| `Enter` | запуск |
| `Esc` или клик мимо окна | закрыть |

## Категории

Вкладки строятся из поля `Categories=` в `.desktop`. Приложение с `Utility;Development;` попадает сразу в две вкладки — так и задумано форматом. Всё, что не подошло ни под одну группу, уходит в «Прочее»; пустые вкладки не показываются.

| Вкладка | XDG-категории |
| --- | --- |
| Все | — |
| Разработка | `Development` |
| Интернет | `Network` |
| Графика | `Graphics` |
| Офис | `Office` |
| Медиа | `AudioVideo`, `Audio`, `Video` |
| Игры | `Game` |
| Наука | `Science`, `Education` |
| Утилиты | `Utility` |
| Система | `System` |
| Настройки | `Settings` |
| Прочее | всё остальное |

Поиск работает внутри выбранной вкладки. По умолчанию открывается «Все», так что обычный ввод ищет по всем приложениям. Список групп задаётся в `Apps.qml` — там же меняются названия, иконки и состав.

## Запуск

Лаунчер работает как демон и показывается по IPC — так открытие происходит мгновенно, без старта процесса на каждое нажатие.

```bash
qs -c menu_applications
```

Автозапуск через systemd:

```bash
ln -sf ~/.config/quickshell/services/quickshell_menu_applications.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now quickshell_menu_applications.service
```

## IPC

```bash
qs -c menu_applications ipc call launcher toggle          # показать/скрыть
qs -c menu_applications ipc call launcher open            # показать
qs -c menu_applications ipc call launcher close           # скрыть
qs -c menu_applications ipc call launcher search firefox  # показать с готовым запросом
qs -c menu_applications ipc call launcher group development  # показать на вкладке «Разработка»
```

Бинд в Niri (`~/.config/niri/includes/binds.kdl`):

```kdl
Mod+S hotkey-overlay-title="Run an Application: quickshell" { spawn "qs" "-c" "menu_applications" "ipc" "call" "launcher" "toggle"; }
```

## Структура

| Файл | Назначение |
| --- | --- |
| `shell.qml` | IPC-обработчик, определение активного монитора, корень |
| `Launcher.qml` | окно-оверлей: строка поиска, сетка, футер, клавиши |
| `AppTile.qml` | плитка приложения |
| `Apps.qml` | индекс `.desktop`, ранжирование, счётчик запусков |
| `Theme.qml` | палитра Flexoki и отслеживание светлой/тёмной темы |
