#!/usr/bin/env bash
# Waybar custom module: Codex subscription usage.
# Reads the Codex CLI OAuth credential locally; never prints it.
set -euo pipefail

readonly AUTH_FILE="${CODEX_HOME:-$HOME/.codex}/auth.json"
readonly CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/waybar-limits"
readonly CACHE_FILE="$CACHE_DIR/codex.json"
readonly CACHE_TTL=120

emit_error() {
  local message="$1"
  jq -cn --arg text '󰚩 Codex —' --arg tooltip "$message" \
    '{text: $text, tooltip: $tooltip, class: "error"}'
}

format_reset() {
  local seconds="${1:-0}"
  if [[ ! "$seconds" =~ ^[0-9]+$ ]] || (( seconds <= 0 )); then
    printf 'неизвестно'
  elif (( seconds < 3600 )); then
    printf 'через %dм' "$(( (seconds + 59) / 60 ))"
  elif (( seconds < 86400 )); then
    printf 'через %dч %dм' "$(( seconds / 3600 ))" "$(( (seconds % 3600 + 59) / 60 ))"
  else
    printf 'через %dд %dч' "$(( seconds / 86400 ))" "$(( (seconds % 86400) / 3600 ))"
  fi
}

mkdir -p "$CACHE_DIR"

# Refresh no more than once per TTL. A stale successful cache is preferable to
# replacing the panel with a transient network failure.
use_cache=false
if [[ -s "$CACHE_FILE" ]]; then
  cache_age=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE") ))
  (( cache_age < CACHE_TTL )) && use_cache=true
fi

if ! $use_cache; then
  [[ -r "$AUTH_FILE" ]] || { emit_error 'Codex: не найден файл авторизации'; exit 0; }
  token=$(jq -r '.tokens.access_token // empty' "$AUTH_FILE" 2>/dev/null || true)
  [[ -n "$token" ]] || { emit_error 'Codex: OAuth-токен не найден'; exit 0; }

  tmp_file=$(mktemp "$CACHE_DIR/codex.XXXXXX")
  if curl --silent --show-error --fail --max-time 12 \
      -H "Authorization: Bearer $token" \
      'https://chatgpt.com/backend-api/wham/usage' >"$tmp_file" \
      && jq -e '.rate_limit.primary_window.used_percent != null' "$tmp_file" >/dev/null 2>&1; then
    chmod 600 "$tmp_file"
    mv "$tmp_file" "$CACHE_FILE"
  else
    rm -f "$tmp_file"
  fi
fi

[[ -s "$CACHE_FILE" ]] || { emit_error 'Codex: не удалось получить лимиты'; exit 0; }

primary_used=$(jq -r '.rate_limit.primary_window.used_percent // empty' "$CACHE_FILE")
primary_reset=$(jq -r '.rate_limit.primary_window.reset_after_seconds // 0' "$CACHE_FILE")
secondary_used=$(jq -r '.rate_limit.secondary_window.used_percent // empty' "$CACHE_FILE")
secondary_reset=$(jq -r '.rate_limit.secondary_window.reset_after_seconds // 0' "$CACHE_FILE")
plan=$(jq -r '.plan_type // ""' "$CACHE_FILE")

[[ "$primary_used" =~ ^[0-9]+([.][0-9]+)?$ ]] || { emit_error 'Codex: ответ содержит неизвестный формат лимитов'; exit 0; }
primary_display=$(LC_NUMERIC=C printf '%.0f' "$primary_used")
primary_left=$(( 100 - primary_display ))
primary_reset_text=$(format_reset "$primary_reset")

if [[ "$secondary_used" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  secondary_display=$(LC_NUMERIC=C printf '%.0f' "$secondary_used")
  secondary_left=$(( 100 - secondary_display ))
  text="󰚩 ${primary_display}/${primary_left}% · ${secondary_display}/${secondary_left}%"
  tooltip="Codex${plan:+ ($plan)}\nОсновной лимит: ${primary_display}% использовано, ${primary_left}% осталось, сброс $primary_reset_text\nДополнительный лимит: ${secondary_display}% использовано, ${secondary_left}% осталось, сброс $(format_reset "$secondary_reset")"
  highest="$secondary_display"
  (( primary_display > highest )) && highest="$primary_display"
else
  text="󰚩 ${primary_display}/${primary_left}%"
  tooltip="Codex${plan:+ ($plan)}\nЛимит: ${primary_display}% использовано, ${primary_left}% осталось, сброс $primary_reset_text"
  highest="$primary_display"
fi

if (( highest >= 90 )); then class='critical'
elif (( highest >= 75 )); then class='warning'
else class='good'; fi

jq -cn --arg text "$text" --arg tooltip "$tooltip" --arg class "$class" \
  '{text: $text, tooltip: $tooltip, class: $class}'
