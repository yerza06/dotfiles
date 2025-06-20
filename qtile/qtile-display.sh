#!/bin/sh

echo "[1] 165.04"
echo "[2] 60.03"
read i

if [ "$i" -eq "1" ]; then
    xrandr --output eDP-1 --mode 2560x1600 --rate 165.04
elif [ "$i" -eq "2" ]; then
    xrandr --output eDP-1 --mode 2560x1600 --rate 60.03
elif [ "$1" -eq "1" ]; then
    xrandr --output eDP-1 --mode 2560x1600 --rate 165.04
elif [ "$1" -eq "2" ]; then
    xrandr --output eDP-1 --mode 2560x1600 --rate 60.03
else
    echo "ERROR!!!"
fi
