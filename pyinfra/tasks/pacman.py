"""Репозиторий multilib и пакеты pacman."""

from pyinfra import host
from pyinfra.facts.files import FindInFile
from pyinfra.operations import files, pacman

from packages import PACMAN


def install(sudo: dict) -> None:
    if not host.get_fact(FindInFile, path="/etc/pacman.conf", pattern=r"^\[multilib\]"):
        files.block(
            name="Включить репозиторий multilib",
            path="/etc/pacman.conf",
            content="[multilib]\nInclude = /etc/pacman.d/mirrorlist",
            **sudo,
        )

    pacman.packages(
        name="Установить пакеты pacman (с полным -Syu)",
        packages=PACMAN,
        update=True,
        upgrade=True,
        **sudo,
    )
