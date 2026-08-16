#!/usr/bin/env bash
set -u

previous_total=0
previous_idle=0

while :; do
    read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat

    idle_all=$((idle + iowait))
    total=$((user + nice + system + idle + iowait + irq + softirq + steal))
    cpu_usage=0

    if (( previous_total > 0 )); then
        total_delta=$((total - previous_total))
        idle_delta=$((idle_all - previous_idle))
        if (( total_delta > 0 )); then
            cpu_usage=$(((100 * (total_delta - idle_delta) + total_delta / 2) / total_delta))
        fi
    fi

    mem_total=0
    mem_available=0
    while read -r key value _; do
        case "$key" in
            MemTotal:)
                mem_total=$value
                ;;
            MemAvailable:)
                mem_available=$value
                ;;
        esac
    done < /proc/meminfo

    memory_usage=0
    if (( mem_total > 0 )); then
        memory_usage=$(((100 * (mem_total - mem_available) + mem_total / 2) / mem_total))
    fi

    mem_used=$((mem_total - mem_available))
    read -r load_one load_five load_fifteen _ < /proc/loadavg

    printf '%d %d %s %s %s %d %d\n' \
        "$cpu_usage" "$memory_usage" \
        "$load_one" "$load_five" "$load_fifteen" \
        "$mem_used" "$mem_total"

    previous_total=$total
    previous_idle=$idle_all
    sleep 1
done
