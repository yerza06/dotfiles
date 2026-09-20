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
    "btop",
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
    # Игры и развлечения
    "discord",
    "modrinth-app",
    "spotify-launcher",
    "steam",  # из [multilib]
    # Служебные
    "quickshell",  # нужен user-сервисам quickshell_*
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
]

AUR = [
    "helium-browser-bin",
    "t3code-bin",
    "android-studio",
]
