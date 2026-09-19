"""Бутстрап yay и установка пакетов AUR."""

import os
import shlex
from io import StringIO
from pathlib import Path

from pyinfra import host
from pyinfra.facts.pacman import PacmanPackages
from pyinfra.facts.server import Which
from pyinfra.operations import files, git, server

from config import HOME
from packages import AUR

AUR_CACHE = HOME / ".cache/pyinfra-aur"


def install(sudo: dict) -> None:
    """Ставит пакеты AUR, при необходимости собрав yay.

    Ожидает kwargs из ``tasks.sudo.prompt()``: помимо ``**sudo`` для операций
    от root, отсюда берётся сырой пароль для SUDO_ASKPASS-скрипта.
    """
    _bootstrap_yay(sudo)
    _install_packages(sudo["_sudo_password"])


def _bootstrap_yay(sudo: dict) -> None:
    if host.get_fact(Which, command="yay"):
        return

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
        **sudo,
    )


def _install_packages(password: str) -> None:
    installed = host.get_fact(PacmanPackages)
    missing = [pkg for pkg in AUR if pkg not in installed]
    if not missing:
        return

    # yay нельзя запускать от root, а его внутренний `sudo pacman` без tty
    # не может спросить пароль. Отдаём пароль через SUDO_ASKPASS-скрипт в
    # tmpfs, чтобы он не попадал в argv и лог pyinfra.
    askpass = Path(f"/run/user/{os.getuid()}/pyinfra-askpass.sh")
    files.put(
        name="Создать временный askpass",
        src=StringIO(f"#!/bin/sh\nprintf '%s\\n' {shlex.quote(password)}\n"),
        dest=str(askpass),
        mode="700",
    )
    server.shell(
        name="Установить пакеты AUR",
        commands=[
            "yay -S --needed --noconfirm --answerclean None --answerdiff None "
            f"--sudoflags=-A {' '.join(missing)}"
        ],
        _env={"SUDO_ASKPASS": str(askpass)},
    )
    files.file(
        name="Удалить временный askpass",
        path=str(askpass),
        present=False,
    )
