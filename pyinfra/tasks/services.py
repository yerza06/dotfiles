"""User-юниты systemd: quickshell и syncthing."""

from pyinfra import host
from pyinfra.facts.files import File
from pyinfra.operations import files, systemd
from pyinfra.operations.util import any_changed

from config import HOME, REPO

QUICKSHELL_UNITS = sorted((REPO / ".config/quickshell/services").glob("*.service"))
USER_UNIT_DIR = HOME / ".config/systemd/user"
# Старый юнит lang_switch, созданный вручную до переезда в репо.
LEGACY_UNITS = ["quickshell-lang-switch.service"]


def setup() -> None:
    # Операции, меняющие файлы юнитов: после них нужен daemon-reload.
    unit_file_changes = _remove_legacy()

    links = _link_units()
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


def _remove_legacy() -> list:
    changes = []
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
            changes.append(
                files.file(
                    name=f"Удалить {legacy}",
                    path=str(legacy_path),
                    present=False,
                )
            )
    return changes


def _link_units() -> dict:
    links = {}
    for unit in QUICKSHELL_UNITS:
        links[unit.name] = files.link(
            name=f"Симлинк {unit.name}",
            path=str(USER_UNIT_DIR / unit.name),
            target=str(unit),
            force=True,
            force_backup=False,
        )
    return links
