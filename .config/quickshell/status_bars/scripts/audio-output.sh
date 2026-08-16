#!/usr/bin/env bash
# Печатает тип текущего аудиовыхода: headphones | speaker | hdmi | unknown
set -u

export LC_ALL=C

previous=""

classify() {
    local sink
    sink=$(pactl get-default-sink 2>/dev/null) || return 1
    [[ -n $sink ]] || return 1

    pactl -f json list sinks 2>/dev/null | jq -r --arg sink "$sink" '
        map(select(.name == $sink))[0] // empty
        | (.active_port // "") as $active
        | ((.ports // []) | map(select(.name == $active))[0].type // "") as $port
        | (.properties["device.form_factor"] // "") as $form
        | (.properties["device.bus"] // "") as $bus
        | if $port == "Headphones" or $port == "Headset"
              or $form == "headphone" or $form == "headset" then "headphones"
          elif $port == "HDMI" or $port == "DisplayPort" then "hdmi"
          elif $port == "Speaker" or $form == "speaker" or $form == "internal" then "speaker"
          elif $bus == "bluetooth" then "headphones"
          else "unknown" end
    '
}

emit() {
    local current
    current=$(classify) || return
    [[ -n $current && $current != "$previous" ]] || return
    previous=$current
    printf '%s\n' "$current"
}

emit

pactl subscribe 2>/dev/null | while read -r event; do
    case "$event" in
        *"on sink"*|*"on card"*|*"on server"*)
            emit
            ;;
    esac
done
