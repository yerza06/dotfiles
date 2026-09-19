"""Правила udev: доступ к hidraw для настраиваемой периферии."""

from pathlib import Path

from pyinfra.operations import files, server
from pyinfra.operations.util import any_changed

from config import REPO

RULES_SRC = REPO / "pyinfra/files/udev"
RULES_DIR = Path("/etc/udev/rules.d")
# Те же правила под старыми именами (без NN-префикса) — иначе останутся дубли.
OBSOLETE = [
    "99-cidoo-qk61.rules",
    "compx-vxe-nordicmouse.rules",
    "rdmctmzt-wireless.rules",
]


def setup(sudo: dict) -> None:
    changes = []

    for rule in sorted(RULES_SRC.glob("*.rules")):
        changes.append(
            files.put(
                name=f"Правило udev {rule.name}",
                src=str(rule),
                dest=str(RULES_DIR / rule.name),
                user="root",
                group="root",
                mode="644",
                **sudo,
            )
        )

    for old in OBSOLETE:
        changes.append(
            files.file(
                name=f"Удалить старое правило {old}",
                path=str(RULES_DIR / old),
                present=False,
                **sudo,
            )
        )

    # Перечитать правила и переприменить их к уже подключённым устройствам:
    # без trigger новые MODE/TAG появятся только после переподключения.
    server.shell(
        name="Перезагрузить правила udev",
        commands=[
            "udevadm control --reload-rules",
            "udevadm trigger --subsystem-match=hidraw",
        ],
        _if=any_changed(*changes),
        **sudo,
    )
