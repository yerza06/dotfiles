"""Раскладка конфигов: stow, жёсткие ссылки, XDG-каталоги."""

import re
import shlex

from pyinfra import host
from pyinfra.facts.server import Command
from pyinfra.operations import files, server

from config import HOME, REPO

# Исключены из stow (.stow-local-ignore): вместо симлинков — жёсткие ссылки.
HARDLINKS = [".config/mimeapps.list", ".config/user-dirs.dirs", ".config/user-dirs.locale"]


def setup() -> None:
    _stow()
    _hardlinks()
    _xdg_dirs()


def _stow() -> None:
    plan = host.get_fact(
        Command,
        command=f"cd {shlex.quote(str(REPO))} && stow -n -v -t {shlex.quote(str(HOME))} . 2>&1 || true",
    )
    # stow сам выводит LINK: для недостающих ссылок и падает на конфликтах —
    # запускаем его, только если есть что делать, чтобы увидеть ошибку.
    if "LINK:" in (plan or "") or "conflict" in (plan or ""):
        server.shell(
            name="stow .",
            commands=[f"cd {shlex.quote(str(REPO))} && stow -v -t {shlex.quote(str(HOME))} ."],
        )


def _hardlinks() -> None:
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


def _xdg_dirs() -> None:
    # xdg-user-dirs-update при входе заменяет несуществующие каталоги на $HOME
    # и тем самым рвёт жёсткую ссылку на user-dirs.dirs — создаём их заранее.
    for line in (REPO / ".config/user-dirs.dirs").read_text().splitlines():
        match = re.fullmatch(r'XDG_\w+_DIR="\$HOME/(.+)"', line)
        if match:
            files.directory(name=f"Каталог ~/{match[1]}", path=str(HOME / match[1]))
