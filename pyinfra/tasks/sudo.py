"""Запрос и проверка sudo-пароля."""

import subprocess
import sys
from getpass import getpass


def prompt() -> dict:
    """Спрашивает пароль, проверяет его и возвращает kwargs для операций pyinfra.

    Результат раскрывается как ``**sudo`` в операциях, которым нужен root.
    Сырой пароль доступен по ключу ``_sudo_password`` (нужен tasks.aur).
    """
    password = getpass("[pyinfra] sudo password: ")
    check = subprocess.run(
        ["sudo", "-S", "-k", "-v", "-p", ""],
        input=f"{password}\n",
        text=True,
        capture_output=True,
    )
    if check.returncode != 0:
        # Без stderr от sudo не отличить опечатку в пароле от отсутствия
        # пользователя в wheel, requiretty и прочих настроек sudoers.
        reason = check.stderr.strip() or f"sudo завершился с кодом {check.returncode}"
        sys.exit(f"Проверка sudo не прошла:\n{reason}")

    return {"_sudo": True, "_sudo_password": password}
