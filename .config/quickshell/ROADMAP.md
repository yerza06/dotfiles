# Quickshell — что ещё можно добавить

Документ описывает нереализованные возможности текущей конфигурации.

**Окружение:** Quickshell 0.3.1 (Arch), композитор **Niri**, 7 независимых конфигов
(`status_bars`, `menu_applications`, `buffermenu`, `emojimenu`, `powermenu`, `notification`,
`lang_switch`).

**Уже задействовано:** `Quickshell.Io`, `Quickshell.Wayland` (только `WlrLayershell`),
`Quickshell.Widgets`, `Quickshell.Networking`, `Quickshell.Bluetooth`,
`Quickshell.WindowManager`, `Services.{Pipewire,Mpris,SystemTray,UPower,Notifications}`.

**Не задействовано вообще:** `WlSessionLock`, `IdleMonitor`, `IdleInhibitor`,
`ScreencopyView`, `ToplevelManager`, `BackgroundEffect`, `ShortcutInhibitor`,
`ColorQuantizer`, `PersistentProperties`, `LazyLoader`, `PopupWindow`, `Region`,
`DesktopEntries`, `SocketServer`, `Services.{Pam,Polkit,Greetd}`,
`QtQuick.Effects`, `QtQuick.Shapes`.

---

## Приоритет 1 — заменить внешние демоны на QML

Наибольший выигрыш: минус зависимость, плюс единый стиль Flexoki.

### 1.1 Экран блокировки

* **API:** `Quickshell.Wayland.WlSessionLock` + `WlSessionLockSurface` + `Quickshell.Services.Pam`
* **Заменяет:** `swaylock -f -c 000000` (хардкод в `powermenu/Actions.qml:~60`)
* **Почему стоит:** `WlSessionLock` — правильный протокол сессии: при падении процесса
  экран не «протекает». `Pam` даёт настоящую аутентификацию без внешнего бинарника.
* **Что нарисовать:** часы, поле пароля, индикатор раскладки, текущий трек (Mpris),
  батарея, уведомления поверх лока.
* **Новый конфиг:** `lockscreen/` (`shell.qml`, `Lock.qml`, `PasswordField.qml`, `Theme.qml`).
* **Интеграция:** `powermenu/Actions.qml` → `qs -c lockscreen ipc call lock activate`
  вместо `execDetached(["swaylock", ...])`.

### 1.2 Idle-демон

* **API:** `Quickshell.Wayland.IdleMonitor` (таймауты бездействия) + `IdleInhibitor` (запрет сна)
* **Заменяет:** `hypridle` / `swayidle`
* **Схема:** 5 мин → притушить экран, 10 мин → вызвать локскрин (п. 1.1), 15 мин → `systemctl suspend`.
* **Бонус:** тумблер «не гасить экран» в `status_bars` — один `IdleInhibitor { enabled: ... }`
  плюс иконка рядом с power-profiles.

### 1.3 Polkit-агент

* **API:** `Quickshell.Services.Polkit`
* **Заменяет:** `hyprpolkitagent` / `polkit-gnome`
* **Что нарисовать:** модальное окно с именем действия, приложения-инициатора и полем пароля.
* **Новый конфиг:** `polkit/`.

### 1.4 Обои

* **API:** обычный `PanelWindow` с `WlrLayershell.layer: WlrLayer.Background`,
  `Variants { model: Quickshell.screens }`
* **Заменяет:** `awww` / `awww-daemon` (сейчас запускается из `niri/includes/startup.kdl`)
* **Плюсы:** анимация перехода средствами QML, разные обои на разные мониторы,
  переключение по IPC вместо внешнего скрипта.
* **Связка:** `~/.local/bin/toggle-theme-script.sh` перестаёт дёргать `awww` —
  оставляет за собой только `gsettings set ... color-scheme`.

### 1.5 Greeter (опционально)

* **API:** `Quickshell.Services.Greetd`
* **Заменяет:** `tuigreet` и аналоги
* **Оговорка:** делать после локскрина — 80% разметки переиспользуется.

---

## Приоритет 2 — динамическая палитра из обоев

* **API:** `ColorQuantizer` (входит в ядро Quickshell, внешние утилиты не нужны)
* **Проблема сейчас:** палитра Flexoki захардкожена **в 5 местах**:
  `status_bars/Bar.qml` (инлайн-блок `readonly property color`),
  `powermenu/Theme.qml`, `menu_applications/Theme.qml`, `buffermenu/Theme.qml`,
  `notification/shell.qml`. `lang_switch` вообще без `Theme.qml`.
* **Решение:**
  1. Вынести палитру в один общий синглтон (см. п. 4.1).
  2. `ColorQuantizer` читает текущие обои → отдаёт доминирующие цвета.
  3. Результат кэшируется в `~/.local/state/quickshell/colors.json` через `FileView` + `JsonAdapter`.
* **Итог:** свой matugen внутри шелла, без `matugen` в зависимостях.

---

## Приоритет 3 — новые виджеты

### 3.1 OSD громкости / яркости / микрофона
* Overlay-слой (`WlrLayer.Overlay`), появляется при изменении, автоскрытие по `Timer`.
* Сейчас громкость видна **только при наведении** на бар — при смене хоткеем обратной связи нет.
* Источник: `Services.Pipewire` (уже подключён в `status_bars/Bar.qml`).

### 3.2 Управление яркостью
* Сейчас **отсутствует полностью**.
* Реализация: `FileView` на `/sys/class/backlight/*/brightness` (чтение без задержки)
  + `Process` с `brightnessctl` на запись.
* Место: слайдер в баре рядом с `VolumeItem.qml` + OSD из п. 3.1.

### 3.3 Календарь по клику на часах — ✅ сделано
* Реализовано в `status_bars/`: `ClockItem.qml` (часы переехали из `Bar.qml`),
  `CalendarPopup.qml`, `CalendarDay.qml`, `CalendarButton.qml`.
* Первое применение `PopupWindow` с `grabFocus`: захват отдаёт окну клавиатуру
  и заставляет композитор закрыть его по клику мимо. Отсюда «липкое» поведение —
  календарь не закрывается по уходу курсора, в отличие от меню по ПКМ.
* Сетка месяца с понедельника (`Qt.locale("ru_RU")`), всегда шесть строк,
  подсветка сегодня, выходные красным, листание стрелками, колесом и клавишами.
* Агенда из `khal`/`ical` не делалась: `khal` в системе нет, новую зависимость
  не вводили.

### 3.4 Центр уведомлений (история)
* Сейчас `notification/shell.qml` объявляет `persistenceSupported: false` — история теряется.
* **API:** `Retainable` + `ObjectModel` дают хранение почти бесплатно.
* Панель со списком, «очистить всё», группировка по приложению, режим «не беспокоить».
* Заодно включить `bodyMarkupSupported` и `inlineReplySupported` (сейчас оба `false`).

### 3.5 Control center
* Одна выдвижная панель: Wi-Fi, Bluetooth, звук + устройства, яркость, power-profile,
  медиа, тумблеры (idle-inhibit, DND).
* **Всё уже написано по отдельности:** `NetworkMenu.qml`, `BluetoothMenu.qml`,
  `AudioDeviceMenu.qml`, `MprisMenu.qml` — задача сборочная, не с нуля.

### 3.6 Таскбар / Alt-Tab с миниатюрами
* **API:** `Wayland.ToplevelManager` + `Toplevel` (список окон) и `Wayland.ScreencopyView`
  (живое превью окна или экрана).
* Ни один из двух не используется сейчас.

### 3.7 Скриншоты и запись экрана
* `ScreencopyView` для превью, overlay с выделением области (`Region` для маски ввода),
  `Process` → `wl-screenrec` / `wf-recorder` для записи.

### 3.8 Полноценный медиаплеер
* `Services.Mpris` уже подключён, но выводится только строкой в баре.
* Отдельное окно: обложка, прогресс-бар с перемоткой, очередь, переключение плееров.

### 3.9 Overview воркспейсов
* `WindowManager.screenProjection(targetScreen)` уже вызывается в `status_bars/Bar.qml`
  ради номеров — он же отдаёт полноценную сетку окон.

### 3.10 Emoji / glyph picker — ✅ сделано
* Реализовано в `emojimenu/` на 14 412 символов: эмодзи, юникод-символы,
  каомодзи, иконки Nerd Font. Оформление от `buffermenu`, сетка плиток
  и навигация от `menu_applications`.
* Двухуровневые вкладки: раздел + подраздел (группы UTS #51 у эмодзи,
  типы у символов, наборы у иконок).
* Набор собирается офлайн (`scripts/gen-glyphs.py` на `unicodedata`,
  `emoji-test.txt` и `fontTools`), в рантайме зависимостей нет.
  Открывается по `Mod+Period`.

### 3.11 Dock
* `PanelWindow` снизу, `DesktopEntries` для иконок, `ToplevelManager` для индикаторов запуска.

---

## Приоритет 4 — архитектурный долг

### 4.1 Общий Theme-синглтон
* Палитра дублируется 5× (см. п. 2). `lang_switch` инлайнит цвета в `shell.qml`.
* Каждый `qs -c <name>` — отдельный процесс, поэтому нужен общий каталог с `qmldir`,
  подключаемый всеми конфигами, либо переход на один процесс (п. 4.3).

### 4.2 Убрать хардкод путей
* `/home/yerza/...` встречается в `status_bars/shell.qml` (2 места),
  `status_bars/Bar.qml` и **всех шести** `services/*.service`.
* Замена: `Quickshell.env(...)` / `Quickshell.shellDir`, в юнитах — `%h`.
* Для dotfiles-репо это блокер переносимости.

### 4.3 Свести 6 процессов в один
* `LazyLoader` + `Variants` + единый `IpcHandler`.
* Выигрыш: общий `Theme`, один монитор `gsettings` вместо **пяти**
  (`status_bars/shell.qml`, `notification/shell.qml`, три `Theme.qml`),
  заметно меньше RAM.

### 4.4 Унифицировать запуск
* Сейчас `status_bars` и `notification` стартуют через `-p <path>`, остальные — через `-c <name>`.
* Форма `-c` обязательна там, где есть синглтоны (регистрируются по имени конфига).
* Установка юнитов тоже расходится: `status_bars/README.md` предлагает
  `sudo install -Dm644 ... /usr/lib/systemd/user/`, остальные — симлинк в `~/.config/systemd/user/`.

### 4.5 Визуальные эффекты
* `QtQuick.Effects` (`MultiEffect`) не импортирован нигде — тени, скругления, размытие внутри окон.
* `Wayland.BackgroundEffect` (блюр **под** окном) на Niri, скорее всего, не сработает:
  Niri не поддерживает размытие слоёв. Рассчитывать только на `MultiEffect` / `ShaderEffect`.

### 4.6 Тесты
* `menu_applications/tests/key-navigation.test.js` существует, но нет ни раннера, ни `package.json`.
* Либо добавить `bun test` / `node --test`, либо удалить.

### 4.7 Сократить shell-out'ы
* `ip -j -4 addr show <dev>` в `NetworkItem.qml` — обход того, что `Networking` отдаёт MAC,
  а не IP. Проверить, появился ли IP в API 0.3.x.
* `scripts/audio-output.sh` тянет зависимости `jq` и `pactl` при уже подключённом `Services.Pipewire` —
  классификацию наушники/динамики/HDMI можно сделать по `PwNode` без внешних процессов.

---

## Что не подойдёт

* **`Quickshell.Hyprland`** целиком, включая `GlobalShortcut` и `HyprlandFocusGrab` —
  только для Hyprland. Глобальные хоткеи остаются на биндах Niri + IPC, как сейчас
  (`niri/includes/binds.kdl`: `Mod+S`, `Mod+V`, `Mod+Delete`).
* **`Quickshell.I3`**, **`Quickshell.X11`** — не тот композитор / не тот дисплейный сервер.
