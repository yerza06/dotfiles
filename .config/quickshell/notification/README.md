# Quickshell Notification

Демон уведомлений для Quickshell 0.3, заменяющий Mako.

## Возможности

- стандартный D-Bus интерфейс `org.freedesktop.Notifications`;
- уведомления в правом верхнем углу;
- Flexoki Light/Dark с автоматическим отслеживанием
  `org.gnome.desktop.interface color-scheme`;
- уровни важности, иконки/изображения и кнопки действий;
- автоматическое закрытие; таймер приостанавливается при наведении;
- ручное закрытие кнопкой `󰅖`.

## Ручной запуск

```bash
qs -p ~/.config/quickshell/notification/shell.qml
```

## Systemd

Исходный unit лежит здесь:

```text
~/.config/quickshell/services/quickshell_notification.service
```

Рабочая пользовательская копия устанавливается в:

```text
~/.config/systemd/user/quickshell_notification.service
```

Проверка:

```bash
systemctl --user status quickshell_notification.service --no-pager
journalctl --user -u quickshell_notification.service -b --no-pager
```

Тестовые уведомления:

```bash
notify-send "Обычное уведомление" "Flexoki и Quickshell работают"
notify-send -u critical "Критическое уведомление" "Проверка красного акцента"
```
