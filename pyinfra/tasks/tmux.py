"""tpm и плагины tmux."""

import re
import shlex

from pyinfra import host
from pyinfra.facts.files import Directory
from pyinfra.operations import git, server

from config import HOME, REPO

# ~/.config/tmux — симлинк stow на репо, плагины там в .gitignore.
TMUX_PLUGIN_DIR = HOME / ".config/tmux/plugins"
TPM_REPO = "https://github.com/tmux-plugins/tpm"


def setup() -> None:
    git.repo(name="Клонировать tpm", src=TPM_REPO, dest=str(TMUX_PLUGIN_DIR / "tpm"), pull=False)

    plugins = re.findall(
        r"^set -g @plugin '([^']+)'",
        (REPO / ".config/tmux/core/plugins.conf").read_text(),
        flags=re.MULTILINE,
    )
    missing = [
        plugin
        for plugin in plugins
        if not host.get_fact(Directory, path=str(TMUX_PLUGIN_DIR / plugin.split("/")[-1]))
    ]
    if missing:
        server.shell(
            name=f"Установить плагины tmux: {', '.join(missing)}",
            commands=[shlex.quote(str(TMUX_PLUGIN_DIR / "tpm/bin/install_plugins"))],
        )
