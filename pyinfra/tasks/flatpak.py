"""Remote flathub и пакеты Flatpak."""

from pyinfra.operations import flatpak, server

from packages import FLATPAK


def install(sudo: dict) -> None:
    server.shell(
        name="Добавить remote flathub",
        commands=[
            "flatpak remote-add --if-not-exists flathub "
            "https://dl.flathub.org/repo/flathub.flatpakrepo",
        ],
        **sudo,
    )

    flatpak.packages(
        name="Установить пакеты Flatpak",
        packages=FLATPAK,
        remote="flathub",
        **sudo,
    )
