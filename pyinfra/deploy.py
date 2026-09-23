"""Установка пакетов, dotfiles, zsh/tmux, правил udev, cron и user-сервисов на локальную Arch-машину.

Запуск (из графической сессии — юниты quickshell требуют Wayland):

    pyinfra @local ~/.dotfiles/pyinfra/deploy.py

Деплой рассчитан только на @local: пути до репо и домашней директории
берутся с машины, где запущен pyinfra.

Сам файл — только порядок задач; их реализация лежит в пакете tasks/.
"""

import sys
from pathlib import Path

# pyinfra исполняет deploy-файл через exec(), а не импортирует как модуль,
# поэтому его каталог приходится добавлять в sys.path вручную.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from tasks import (  # noqa: E402
    agents,
    aur,
    cron,
    dotfiles,
    flatpak,
    pacman,
    services,
    sudo,
    tmux,
    udev,
    zsh,
)

SUDO = sudo.prompt()

# Порядок важен: pacman ставит flatpak, git, stow и base-devel для остальных задач.
pacman.install(SUDO)
flatpak.install(SUDO)
aur.install(SUDO)
dotfiles.setup()
zsh.setup(SUDO)
tmux.setup()
agents.setup()
udev.setup(SUDO)
cron.setup(SUDO)
services.setup()
