# dotfiles

## Install

```bash
git clone https://github.com/yerza06/dotfiles.git .dotfiles
cd .dotfiles
stow .
```

## Пакеты и сервисы

Скрипт на [pyinfra](https://pyinfra.com):

- ставит пакеты (pacman, Flathub, AUR через yay), списки — в `pyinfra/packages.py`;
- запускает `stow .`, а `mimeapps.list` и `user-dirs.*` ставит жёсткими ссылками
  (отличающаяся копия из `~/.config` сохраняется как `*.pyinfra-bak.<дата>`);
- ставит oh-my-zsh с плагинами и powerlevel10k, делает zsh оболочкой по умолчанию;
- ставит tpm и плагины tmux из `.config/tmux/core/plugins.conf`;
- раскладывает правила udev из `pyinfra/files/udev/` в `/etc/udev/rules.d/`
  (доступ к hidraw для настраиваемой периферии);
- включает `cronie` и ставит запись crontab для `.local/bin/battery-notify.sh`;
- линкует юниты из `.config/quickshell/services/` в `~/.config/systemd/user/`
  и запускает их вместе с `syncthing`.

```bash
uv tool install pyinfra
pyinfra @local ~/.dotfiles/pyinfra/deploy.py
```

Запускать из графической сессии: юниты quickshell требуют Wayland.
