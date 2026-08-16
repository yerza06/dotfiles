# Quickshell status bar

Панель автоматически переключается между Flexoki Dark и Flexoki Light по значению `org.gnome.desktop.interface color-scheme`. Изменение применяется реактивно на обоих мониторах без перезапуска Quickshell.

Нативный `SystemTray` отображается перед батареей на обоих мониторах: ЛКМ активирует приложение, ПКМ открывает его меню, СКМ вызывает secondary action, колесо передаётся приложению.

Базовая панель для Niri на Quickshell 0.3.x.

## Запуск

```bash
qs -p ~/.config/quickshell/status_bars/shell.qml
```

## Пользовательский сервис systemd

Готовый unit-файл находится в общей директории сервисов Quickshell:

```text
~/.config/quickshell/services/quickshell_status_bars.service
```

Установка в системный каталог пользовательских unit-файлов:

```bash
sudo install -Dm644 \
  ~/.config/quickshell/services/quickshell_status_bars.service \
  /usr/lib/systemd/user/quickshell_status_bars.service
```

Перед первым запуском сервиса завершите вручную запущенную панель, чтобы не получить два экземпляра:

```bash
qs kill -p ~/.config/quickshell/status_bars/shell.qml
systemctl --user daemon-reload
systemctl --user enable --now quickshell_status_bars.service
```

Проверка:

```bash
systemctl --user status quickshell_status_bars.service --no-pager
journalctl --user -u quickshell_status_bars.service -b --no-pager
```

В `~/.config/niri/includes/startup.kdl` закомментируйте или удалите старую строку запуска status bar:

```kdl
// spawn-sh-at-startup "qs -p ~/.config/quickshell/status_bars/shell.qml"
```

Строку запуска `lang_switch` оставьте без изменений — это отдельная конфигурация Quickshell.

## Модули

- слева: Arch launcher (`fuzzel`), workspaces Niri и MPRIS;
- по центру: текущие дата и время;
- справа: CPU, RAM, раскладка Niri, PipeWire (звук и микрофон), NetworkManager, Bluetooth, power-profiles-daemon, SystemTray и батарея UPower.

При наведении CPU показывает текущую загрузку и load average за 1/5/15 минут. RAM показывает использованную, общую и доступную память в GiB. ЛКМ по CPU или RAM открывает `btop` в полноэкранном окне Kitty.

MPRIS показывает активный плеер и текущий трек. ЛКМ переключает play/pause, ПКМ включает следующий трек, средняя кнопка — предыдущий.

ЛКМ по звуку или микрофону открывает `pulsemixer` в Kitty, СКМ включает/выключает mute, ПКМ открывает `pavucontrol`, а колесо меняет громкость. При наведении на любой из этих модулей открывается соответствующий интерактивный ползунок: можно нажать на шкалу или перетаскивать бегунок. Сеть открывает `nmtui` в Kitty, Bluetooth — `bluetui`, профиль питания переключается по кругу.

При заряде 16–30% аккумулятор каждые 500 мс переключается между оранжевым фоном с тёмным текстом и тёмным фоном с оранжевым текстом. При критическом заряде 0–15% он каждые 380 мс переключается между красным фоном с тёмным текстом и тёмным фоном с красным текстом. Во время зарядки и выше 30% мигание отключено.
