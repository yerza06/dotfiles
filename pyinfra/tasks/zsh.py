"""oh-my-zsh с плагинами и zsh как оболочка по умолчанию."""

from getpass import getuser

from pyinfra.operations import git, server

from config import HOME

ZSH_DIR = HOME / ".oh-my-zsh"
ZSH_REPOS = {
    ZSH_DIR: "https://github.com/ohmyzsh/ohmyzsh.git",
    ZSH_DIR / "custom/themes/powerlevel10k": "https://github.com/romkatv/powerlevel10k.git",
    ZSH_DIR / "custom/plugins/zsh-autosuggestions": "https://github.com/zsh-users/zsh-autosuggestions",
    ZSH_DIR / "custom/plugins/zsh-syntax-highlighting": "https://github.com/zsh-users/zsh-syntax-highlighting.git",
    ZSH_DIR / "custom/plugins/fzf-tab": "https://github.com/Aloxaf/fzf-tab",
}


def setup(sudo: dict) -> None:
    # oh-my-zsh первым: плагины и тема клонируются внутрь его каталога.
    for dest, src in ZSH_REPOS.items():
        git.repo(name=f"Клонировать {dest.name}", src=src, dest=str(dest), pull=False)

    server.user(
        name="zsh — оболочка по умолчанию",
        user=getuser(),
        shell="/usr/bin/zsh",
        **sudo,
    )
