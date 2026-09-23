"""Списки пакетов для задач из tasks/."""

PACMAN = [
    # Разработка
    "git",
    "stow",
    "tmux",
    "openssh",
    "openssl",
    "gnupg",
    "github-cli",
    "glab",
    "lazygit",
    "lua",
    "neovim",
    "nodejs",
    "bun",
    "rust",
    "uv",
    "zed",
    "openai-codex",
    "gemini-cli",
    # Терминалы
    "alacritty",
    "kitty",
    # Контейнеры и сеть
    "docker",
    "docker-compose",
    "lazydocker",
    "nginx",
    "syncthing",
    "flatpak",
    # Системные утилиты
    "baobab",  # анализатор занятого места на диске
    "btop",
    "cliphist",  # история буфера обмена для quickshell buffermenu
    "cronie",  # демон cron для tasks/cron.py
    "cups",
    "curl",
    "htop",
    "tar",
    "unzip",
    "wget",
    "wl-clipboard",  # даёт wl-copy / wl-paste
    "yazi",
    "zip",
    "zstd",
    "zsh",
    "eza",  # замена exa, которого больше нет в репозиториях
    "bat",
    "fzf",
    "zoxide",
    # Пароли
    "pass",
    "qtpass",  # GUI поверх pass
    # Файловые менеджеры
    "pcmanfm",
    # Браузер
    "firefox",
    # Графика/творчество
    "blender",
    "freecad",
    "inkscape",
    "kdenlive",
    "krita",
    "obs-studio",
    # Игры и развлечения
    "discord",
    "modrinth-app",
    "spotify-launcher",
    "steam",  # из [multilib]
    # Служебные
    "quickshell",  # нужен user-сервисам quickshell_*
    "bluetui",  # открывается из панели quickshell по СКМ
    "pulsemixer",  # открывается из панели quickshell по СКМ
    "awww",  # обои, переключаются в toggle-theme-script.sh
    "nwg-look",  # настройки GTK-темы для wlroots
    "base-devel",  # сборка AUR-пакетов
]

FLATPAK = [
    "cc.arduino.IDE2",
    "md.obsidian.Obsidian",
    "com.github.tchx84.Flatseal",
    "org.telegram.desktop",
    "org.pgadmin.pgadmin4",
    "io.httpie.Httpie",
    "com.bitwarden.desktop",
    "it.mijorus.gearlever",
    "app.xmcl.voxelum",
]

AUR = [
    "helium-browser-bin",
    "android-studio",
]

# Глобальные npm-пакеты: агент pi и его плагины. Префикс — ~/.npm-global,
# его задаёт tasks/agents.py.
NPM = [
    "@earendil-works/pi-coding-agent",
    "@artale/pi-skills",
    "@artale/pi-memory",
    "@aliou/pi-guardrails",
    "@tintinweb/pi-subagents",
    "@narumitw/pi-chrome-devtools",
    "@llblab/pi-codex-usage",
    "@0xkobold/pi-ollama",
    "@juicesharp/rpiv-todo",
    "@juicesharp/rpiv-ask-user-question",
    "@vkundapur/context-inspector",
    "pi-web-access",
]
