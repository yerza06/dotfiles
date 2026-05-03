#!/bin/sh

VAULT=$(ls ~/.obsidian-vaults -1 | rofi -dmenu)

tmux new-session -c ~/.obsidian-vaults/$VAULT -d -s Obsidian-CLI nvim
tmux new-window -c ~/.obsidian-vaults/$VAULT -t Obsidian-CLI:2 "claude"

kitty tmux attach -t Obsidian-CLI
