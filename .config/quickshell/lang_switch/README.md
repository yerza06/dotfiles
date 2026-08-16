# Quickshell Language Switch Toast

Небольшой Quickshell-проект для Niri. После переключения раскладки показывает внизу по центру каждого подключённого экрана уведомление с названием нового языка.

Поддерживаемые подписи:

- English → EN
- Russian → RU
- Kazakh → KZ

## Запуск

```bash
qs -c lang_switch
```

Для автоматического запуска добавьте `qs -c lang_switch` в `spawn-at-startup` конфигурации Niri или создайте пользовательский systemd-сервис.

Проект использует поток событий Niri, поэтому не опрашивает раскладку по таймеру. Цвета автоматически переключаются между Flexoki Light и Dark согласно `org.gnome.desktop.interface color-scheme`.
