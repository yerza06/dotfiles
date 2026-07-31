#!/usr/bin/env bash
# Waybar custom module: Claude Code subscription usage.
# Reads the Claude Code OAuth credential locally; never prints it.
set -euo pipefail

readonly AUTH_FILE="$HOME/.claude/.credentials.json"
readonly CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/waybar-limits"
readonly CACHE_FILE="$CACHE_DIR/claude.json"
readonly CACHE_TTL=120

emit_error() {
  local message="$1"
  jq -cn --arg text '󰚩 Claude —' --arg tooltip "$message" \
    '{text: $text, tooltip: $tooltip, class: "error"}'
}

format_reset() {
  local iso_time="$1"
  local reset_epoch now seconds
  reset_epoch=$(date -d "$iso_time" +%s 2>/dev/null || printf '0')
  now=$(date +%s)
  seconds=$(( reset_epoch - now ))

  if (( seconds <= 0 )); then
    printf 'скоро'
  elif (( seconds < 3600 )); then
    printf 'через %dм' "$(( (seconds + 59) / 60 ))"
  elif (( seconds < 86400 )); then
    printf 'через %dч %dм' "$(( seconds / 3600 ))" "$(( (seconds % 3600 + 59) / 60 ))"
  else
    printf 'через %dд %dч' "$(( seconds / 86400 ))" "$(( (seconds % 86400) / 3600 ))"
  fi
}

mkdir -p "$CACHE_DIR"

use_cache=false
if [[ -s "$CACHE_FILE" ]]; then
  cache_age=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE") ))
  (( cache_age < CACHE_TTL )) && use_cache=true
fi

if ! $use_cache; then
  [[ -r "$AUTH_FILE" ]] || { emit_error 'Claude: не найден файл авторизации'; exit 0; }
  token=$(jq -r '.claudeAiOauth.accessToken // empty' "$AUTH_FILE" 2>/dev/null || true)
  [[ -n "$token" ]] || { emit_error 'Claude: OAuth-токен не найден'; exit 0; }

  tmp_file=$(mktemp "$CACHE_DIR/claude.XXXXXX")
  if curl --silent --show-error --fail --max-time 12 \
      -H "Authorization: Bearer $token" \
      -H 'anthropic-version: 2023-06-01' \
      -H 'anthropic-beta: oauth-2025-04-20' \
      'https://api.anthropic.com/api/oauth/usage' >"$tmp_file" \
      && jq -e '.five_hour.utilization != null and .seven_day.utilization != null' "$tmp_file" >/dev/null 2>&1; then
    chmod 600 "$tmp_file"
    mv "$tmp_file" "$CACHE_FILE"
  else
    rm -f "$tmp_file"
  fi
fi

[[ -s "$CACHE_FILE" ]] || { emit_error 'Claude: не удалось получить лимиты'; exit 0; }

five_used=$(jq -r '.five_hour.utilization // empty' "$CACHE_FILE")
five_reset=$(jq -r '.five_hour.resets_at // empty' "$CACHE_FILE")
week_used=$(jq -r '.seven_day.utilization // empty' "$CACHE_FILE")
week_reset=$(jq -r '.seven_day.resets_at // empty' "$CACHE_FILE")

[[ "$five_used" =~ ^[0-9]+([.][0-9]+)?$ && "$week_used" =~ ^[0-9]+([.][0-9]+)?$ ]] || { emit_error 'Claude: ответ содержит неизвестный формат лимитов'; exit 0; }
five_display=$(LC_NUMERIC=C printf '%.0f' "$five_used")
week_display=$(LC_NUMERIC=C printf '%.0f' "$week_used")
five_left=$(( 100 - five_display ))
week_left=$(( 100 - week_display ))

text="󰚩 ${five_display}/${five_left}% · ${week_display}/${week_left}%"
tooltip="Claude Code\n5 часов: ${five_display}% использовано, ${five_left}% осталось, сброс $(format_reset "$five_reset")\n7 дней: ${week_display}% использовано, ${week_left}% осталось, сброс $(format_reset "$week_reset")"

if (( five_display >= week_display )); then highest="$five_display"; else highest="$week_display"; fi
if (( highest >= 90 )); then class='critical'
elif (( highest >= 75 )); then class='warning'
else class='good'; fi

jq -cn --arg text "$text" --arg tooltip "$tooltip" --arg class "$class" \
  '{text: $text, tooltip: $tooltip, class: $class}'
