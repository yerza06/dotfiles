#!/usr/bin/env bash

# ─────────────────────────────────────────────
#  Power Menu для niri + swaylock
#  Зависимости: rofi-wayland, swaylock,
#               systemd, power-profiles-daemon
# ─────────────────────────────────────────────

THEME="$HOME/.config/rofi/powermenu.rasi"

# ─── Команды ──────────────────────────────────
CMD_LOCK="swaylock -f -c 000000"
CMD_LOGOUT="niri msg action quit --skip-confirmation"
CMD_SUSPEND="systemctl suspend"
CMD_HIBERNATE="systemctl hibernate"
CMD_REBOOT="systemctl reboot"
CMD_SHUTDOWN="systemctl poweroff"

# ─── Опции меню (иконка + метка) ──────────────
#     Иконки — Nerd Font (IosevkaTermNerdFont)
OPT_SHUTDOWN="󰐥  Выключить"
OPT_REBOOT="󰜉  Перезагрузить"
OPT_SUSPEND="󰒲  Сон"
OPT_HIBERNATE="󰤄  Hibernate"
OPT_LOCK="󰌾  Заблокировать"
OPT_LOGOUT="󰍃  Выйти"

# ─── Uptime ────────────────────────────────────
get_uptime() {
    uptime -p | sed 's/up //'
}

# ─── Power profile ─────────────────────────────
get_profile() {
    powerprofilesctl get 2>/dev/null || echo "unknown"
}

get_profile_icon() {
    case "$(get_profile)" in
        performance)  echo "󱐋" ;;
        balanced)     echo "󱐌" ;;
        power-saver)  echo "󰌪" ;;
        *)            echo "󰁹" ;;
    esac
}

cycle_profile() {
    case "$(get_profile)" in
        performance)  powerprofilesctl set balanced    ;;
        balanced)     powerprofilesctl set power-saver ;;
        power-saver)  powerprofilesctl set performance ;;
    esac
}

# ─── Строка mesg: uptime + профиль ─────────────
build_mesg() {
    local uptime_val icon profile
    uptime_val=$(get_uptime)
    profile=$(get_profile)
    icon=$(get_profile_icon)
    echo "󰥔  uptime: ${uptime_val}     ${icon}  ${profile}  (Alt+P — сменить)"
}

# ─── Запуск rofi ───────────────────────────────
show_menu() {
    printf '%s\n' \
        "$OPT_SHUTDOWN" \
        "$OPT_REBOOT"   \
        "$OPT_SUSPEND"  \
        "$OPT_HIBERNATE"\
        "$OPT_LOCK"     \
        "$OPT_LOGOUT"   \
    | rofi \
        -dmenu \
        -p "" \
        -mesg "$(build_mesg)" \
        -theme "$THEME" \
        -kb-custom-1 "Alt+p" \
        -selected-row 0
}

# ─── Основной цикл ─────────────────────────────
while true; do
    chosen=$(show_menu)
    rofi_exit=$?

    # Alt+P (custom-1) — сменить профиль и перерисовать меню
    if [[ $rofi_exit -eq 10 ]]; then
        cycle_profile
        continue
    fi

    # Esc или пустой выбор — выход
    [[ -z "$chosen" ]] && exit 0

    break
done

# ─── Выполнение ────────────────────────────────
case "$chosen" in
    "$OPT_SHUTDOWN")  $CMD_SHUTDOWN  ;;
    "$OPT_REBOOT")    $CMD_REBOOT    ;;
    "$OPT_SUSPEND")   $CMD_SUSPEND   ;;
    "$OPT_HIBERNATE") $CMD_HIBERNATE ;;
    "$OPT_LOCK")      $CMD_LOCK      ;;
    "$OPT_LOGOUT")    $CMD_LOGOUT    ;;
esac
