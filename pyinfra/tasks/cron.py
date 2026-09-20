"""Задачи по расписанию: демон cronie и записи в crontab пользователя."""

from pyinfra.operations import crontab, systemd

from config import HOME

# Скрипты раскладывает stow из .local/bin/; cron не разворачивает ~,
# поэтому путь собираем абсолютным.
BATTERY_NOTIFY = f"bash {HOME}/.local/bin/battery-notify.sh"


def setup(sudo: dict) -> None:
    systemd.service(
        name="Включить и запустить cronie",
        service="cronie.service",
        running=True,
        enabled=True,
        **sudo,
    )

    # Без user= правится crontab того пользователя, под которым идёт деплой.
    # Запись опознаётся по тексту команды, так что менять её нужно здесь,
    # иначе старая строка останется в crontab отдельной записью.
    crontab.crontab(
        name="Уведомления о заряде батареи раз в минуту",
        command=BATTERY_NOTIFY,
        minute="*/1",
    )
