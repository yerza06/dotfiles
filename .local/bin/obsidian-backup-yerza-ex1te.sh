#!/bin/sh

set -e

DATE=$(date +%d.%m.%YT%H:%M:%S)
MSG="User: $(whoami) | Date: $DATE"

# echo $MSG

cd "/home/yerza/.obsidian-vaults/yerza-ex1te-vault-md"
git add .
git commit -m "$MSG"
git push origin main
