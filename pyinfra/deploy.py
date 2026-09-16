"""Установка пакетов, dotfiles, zsh/tmux и user-сервисов на локальную Arch-машину.

Запуск (из графической сессии — юниты quickshell требуют Wayland):

    pyinfra @local ~/.dotfiles/pyinfra/deploy.py

Деплой рассчитан только на @local: пути до репо и домашней директории
берутся с машины, где запущен pyinfra.
"""

import os
import re
import shlex
import subprocess
import sys
from getpass import getpass, getuser
from io import StringIO
from pathlib import Path

from pyinfra import host
from pyinfra.facts.files import Directory, File, FindInFile
from pyinfra.facts.pacman import PacmanPackages
from pyinfra.facts.server import Command, Which
from pyinfra.operations import files, flatpak, git, pacman, server, systemd
from pyinfra.operations.util import any_changed

sys.path.insert(0, str(Path(__file__).resolve().parent))
from packages import AUR, FLATPAK, PACMAN  # noqa: E402

REPO = Path(__file__).resolve().parents[1]
HOME = Path.home()
QUICKSHELL_UNITS = sorted((REPO / ".config/quickshell/services").glob("*.service"))
USER_UNIT_DIR = HOME / ".config/systemd/user"
AUR_CACHE = HOME / ".cache/pyinfra-aur"
# Старый юнит lang_switch, созданный вручную до переезда в репо.
LEGACY_UNITS = ["quickshell-lang-switch.service"]
# Исключены из stow (.stow-local-ignore): вместо симлинков — жёсткие ссылки.
HARDLINKS = [".config/mimeapps.list", ".config/user-dirs.dirs", ".config/user-dirs.locale"]
ZSH_DIR = HOME / ".oh-my-zsh"
ZSH_REPOS = {
    ZSH_DIR: "https://github.com/ohmyzsh/ohmyzsh.git",
    ZSH_DIR / "custom/themes/powerlevel10k": "https://github.com/romkatv/powerlevel10k.git",
    ZSH_DIR / "custom/plugins/zsh-autosuggestions": "https://github.com/zsh-users/zsh-autosuggestions",
    ZSH_DIR / "custom/plugins/zsh-syntax-highlighting": "https://github.com/zsh-users/zsh-syntax-highlighting.git",
    ZSH_DIR / "custom/plugins/fzf-tab": "https://github.com/Aloxaf/fzf-tab",
}
# ~/.config/tmux — симлинк stow на репо, плагины там в .gitignore.
TMUX_PLUGIN_DIR = HOME / ".config/tmux/plugins"
TPM_REPO = "https://github.com/tmux-plugins/tpm"

# --- sudo -----------------------------------------------------------------

PASSWORD = getpass("[pyinfra] sudo password: ")
check = subprocess.run(
    ["sudo", "-S", "-k", "-v", "-p", ""],
    input=f"{PASSWORD}\n",
    text=True,
    capture_output=True,
)
if check.returncode != 0:
    sys.exit("Неверный пароль sudo")

SUDO = {"_sudo": True, "_sudo_password": PASSWORD}

# --- pacman ---------------------------------------------------------------

if not host.get_fact(FindInFile, path="/etc/pacman.conf", pattern=r"^\[multilib\]"):
    files.block(
        name="Включить репозиторий multilib",
        path="/etc/pacman.conf",
        content="[multilib]\nInclude = /etc/pacman.d/mirrorlist",
        **SUDO,
    )

pacman.packages(
    name="Установить пакеты pacman (с полным -Syu)",
    packages=PACMAN,
    update=True,
    upgrade=True,
    **SUDO,
)

# --- Flatpak --------------------------------------------------------------

server.shell(
    name="Добавить remote flathub",
    commands=[
        "flatpak remote-add --if-not-exists flathub "
        "https://dl.flathub.org/repo/flathub.flatpakrepo",
    ],
    **SUDO,
)

flatpak.packages(
    name="Установить пакеты Flatpak",
    packages=FLATPAK,
    remote="flathub",
    **SUDO,
)

# --- AUR ------------------------------------------------------------------

if not host.get_fact(Which, command="yay"):
    yay_dir = AUR_CACHE / "yay-bin"
    git.repo(
        name="Скачать PKGBUILD yay-bin",
        src="https://aur.archlinux.org/yay-bin.git",
        dest=str(yay_dir),
    )
    server.shell(
        name="Собрать yay-bin",
        commands=[f"cd {shlex.quote(str(yay_dir))} && makepkg --noconfirm -f"],
    )
    server.shell(
        name="Установить yay-bin",
        commands=[
            f"pacman -U --noconfirm --needed {shlex.quote(str(yay_dir))}/yay-bin-[0-9]*.pkg.tar.zst"
        ],
        **SUDO,
    )

installed = host.get_fact(PacmanPackages)
missing_aur = [pkg for pkg in AUR if pkg not in installed]

if missing_aur:
    # yay нельзя запускать от root, а его внутренний `sudo pacman` без tty
    # не может спросить пароль. Отдаём пароль через SUDO_ASKPASS-скрипт в
    # tmpfs, чтобы он не попадал в argv и лог pyinfra.
    askpass = Path(f"/run/user/{os.getuid()}/pyinfra-askpass.sh")
    files.put(
        name="Создать временный askpass",
        src=StringIO(f"#!/bin/sh\nprintf '%s\\n' {shlex.quote(PASSWORD)}\n"),
        dest=str(askpass),
        mode="700",
    )
    server.shell(
        name="Установить пакеты AUR",
        commands=[
            "yay -S --needed --noconfirm --answerclean None --answerdiff None "
            f"--sudoflags=-A {' '.join(missing_aur)}"
        ],
        _env={"SUDO_ASKPASS": str(askpass)},
    )
    files.file(
        name="Удалить временный askpass",
        path=str(askpass),
        present=False,
    )

# --- dotfiles -------------------------------------------------------------

stow_plan = host.get_fact(
    Command,
    command=f"cd {shlex.quote(str(REPO))} && stow -n -v -t {shlex.quote(str(HOME))} . 2>&1 || true",
)
# stow сам выводит LINK: для недостающих ссылок и падает на конфликтах —
# запускаем его, только если есть что делать, чтобы увидеть ошибку.
if "LINK:" in (stow_plan or "") or "conflict" in (stow_plan or ""):
    server.shell(
        name="stow .",
        commands=[f"cd {shlex.quote(str(REPO))} && stow -v -t {shlex.quote(str(HOME))} ."],
    )

for rel in HARDLINKS:
    src, dest = REPO / rel, HOME / rel
    inodes = host.get_fact(
        Command,
        command=f"stat -c %i {shlex.quote(str(src))} {shlex.quote(str(dest))} 2>/dev/null || true",
    )
    inodes = (inodes or "").split()
    if len(inodes) == 2 and inodes[0] == inodes[1]:
        continue
    q_src, q_dest = shlex.quote(str(src)), shlex.quote(str(dest))
    server.shell(
        name=f"Жёсткая ссылка {rel}",
        commands=[
            f"mkdir -p {shlex.quote(str(dest.parent))}",
            # Источник истины — репо; отличающуюся копию из $HOME сохраняем рядом.
            f"if [ -e {q_dest} ] && ! cmp -s {q_src} {q_dest}; then "
            f"cp -a {q_dest} {q_dest}.pyinfra-bak.$(date +%Y%m%d-%H%M%S); fi",
            f"ln -f {q_src} {q_dest}",
        ],
    )

# xdg-user-dirs-update при входе заменяет несуществующие каталоги на $HOME
# и тем самым рвёт жёсткую ссылку на user-dirs.dirs — создаём их заранее.
for line in (REPO / ".config/user-dirs.dirs").read_text().splitlines():
    match = re.fullmatch(r'XDG_\w+_DIR="\$HOME/(.+)"', line)
    if match:
        files.directory(name=f"Каталог ~/{match[1]}", path=str(HOME / match[1]))

# --- zsh ------------------------------------------------------------------

# oh-my-zsh первым: плагины и тема клонируются внутрь его каталога.
for dest, src in ZSH_REPOS.items():
    git.repo(name=f"Клонировать {dest.name}", src=src, dest=str(dest), pull=False)

server.user(
    name="zsh — оболочка по умолчанию",
    user=getuser(),
    shell="/usr/bin/zsh",
    **SUDO,
)

# --- tmux -----------------------------------------------------------------

git.repo(name="Клонировать tpm", src=TPM_REPO, dest=str(TMUX_PLUGIN_DIR / "tpm"), pull=False)

tmux_plugins = re.findall(
    r"^set -g @plugin '([^']+)'",
    (REPO / ".config/tmux/core/plugins.conf").read_text(),
    flags=re.MULTILINE,
)
missing_tmux = [
    plugin
    for plugin in tmux_plugins
    if not host.get_fact(Directory, path=str(TMUX_PLUGIN_DIR / plugin.split("/")[-1]))
]
if missing_tmux:
    server.shell(
        name=f"Установить плагины tmux: {', '.join(missing_tmux)}",
        commands=[shlex.quote(str(TMUX_PLUGIN_DIR / "tpm/bin/install_plugins"))],
    )

# --- user-сервисы ---------------------------------------------------------

# Операции, меняющие файлы юнитов: после них нужен daemon-reload.
unit_file_changes = []

for legacy in LEGACY_UNITS:
    legacy_path = USER_UNIT_DIR / legacy
    if host.get_fact(File, path=str(legacy_path)):
        systemd.service(
            name=f"Остановить и отключить {legacy}",
            service=legacy,
            running=False,
            enabled=False,
            user_mode=True,
        )
        unit_file_changes.append(
            files.file(
                name=f"Удалить {legacy}",
                path=str(legacy_path),
                present=False,
            )
        )

links = {}
for unit in QUICKSHELL_UNITS:
    links[unit.name] = files.link(
        name=f"Симлинк {unit.name}",
        path=str(USER_UNIT_DIR / unit.name),
        target=str(unit),
        force=True,
        force_backup=False,
    )
unit_file_changes.extend(links.values())

systemd.daemon_reload(
    name="systemctl --user daemon-reload",
    user_mode=True,
    _if=any_changed(*unit_file_changes),
)

for unit_name, link in links.items():
    systemd.service(
        name=f"Включить и запустить {unit_name}",
        service=unit_name,
        running=True,
        enabled=True,
        user_mode=True,
    )
    systemd.service(
        name=f"Перезапустить {unit_name} после смены юнита",
        service=unit_name,
        restarted=True,
        user_mode=True,
        _if=link.did_change,
    )

systemd.service(
    name="Включить и запустить syncthing",
    service="syncthing.service",
    running=True,
    enabled=True,
    user_mode=True,
)
