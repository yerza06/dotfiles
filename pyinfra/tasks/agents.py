"""ИИ-агенты в терминале: claude code, pi с плагинами и herdr.

Пакетов в репозиториях у них нет, ставятся официальными установщиками.
codex и gemini-cli приезжают из pacman, их здесь нет.
"""

import shlex

from pyinfra.operations import files, server

from config import HOME
from packages import NPM

CLAUDE_INSTALLER = "https://claude.ai/install.sh"
HERDR_INSTALLER = "https://herdr.dev/install.sh"
LOCAL_BIN = HOME / ".local/bin"
# npm без prefix ставит глобальные пакеты в /usr/lib от root; этот каталог
# .zshrc уже добавляет в PATH.
NPM_PREFIX = HOME / ".npm-global"
NPM_MODULES = NPM_PREFIX / "lib/node_modules"
# Ставятся не здесь: bun и nodejs (даёт npx) есть в pacman-списке. Задача
# только проверяет, что они доехали, — агенты без них бесполезны.
REQUIRED = {"bun": ["/usr/bin/bun", HOME / ".bun/bin/bun"], "npx": ["/usr/bin/npx"]}


def setup() -> None:
    """Ставит агентов по очереди и проверяет bun с npx.

    Проверки «уже установлено» живут внутри самих команд, а не в фактах
    pyinfra: факты собираются до того, как pacman поставит nodejs и curl,
    поэтому на чистой машине они показали бы пустоту.
    """
    _install_claude()
    _install_npm_packages()
    _install_herdr()
    _require_tools()


def _install_claude() -> None:
    server.shell(
        name="Установить claude code",
        commands=[_unless_present("claude", f"curl -fsSL {CLAUDE_INSTALLER} | bash")],
    )


def _install_herdr() -> None:
    server.shell(
        name="Установить herdr",
        commands=[_unless_present("herdr", f"curl -fsSL {HERDR_INSTALLER} | sh")],
    )


def _install_npm_packages() -> None:
    files.line(
        name="Прописать prefix в ~/.npmrc",
        path=str(HOME / ".npmrc"),
        line=r"^prefix=",
        replace=f"prefix={NPM_PREFIX}",
    )

    targets = " ".join(shlex.quote(pkg) for pkg in NPM)
    server.shell(
        name="Установить pi и его плагины",
        commands=[
            "missing=''; "
            f"for pkg in {targets}; do "
            f'  [ -e {shlex.quote(str(NPM_MODULES))}/"$pkg" ] || missing="$missing $pkg"; '
            "done; "
            '[ -z "$missing" ] || npm install -g $missing'
        ],
    )


def _require_tools() -> None:
    checks = [
        f"{_present(cmd, *paths)} || "
        f'{{ echo "Нет {cmd}: проверь, что pacman отработал" >&2; exit 1; }}'
        for cmd, paths in REQUIRED.items()
    ]
    server.shell(name="Проверить bun и npx", commands=["; ".join(checks)])


def _present(command: str, *paths) -> str:
    """Команда есть в PATH или лежит по одному из известных путей."""
    # PATH у pyinfra неинтерактивный, ~/.local/bin и ~/.bun/bin в него не входят.
    tests = [f"command -v {shlex.quote(command)} >/dev/null 2>&1"]
    tests += [f"[ -x {shlex.quote(str(path))} ]" for path in (*paths, LOCAL_BIN / command)]
    return " || ".join(tests)


def _unless_present(command: str, install: str) -> str:
    """Ставит, только если команды ещё нет: падение установщика не глушим."""
    return f"if {_present(command)}; then :; else {install}; fi"
