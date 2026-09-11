#!/usr/bin/env bash
# Показатели для окна мониторинга системы: раз в секунду одна строка JSON.
# Скрипт запускает SystemMonitorPopup, только пока окно открыто.
set -u

# Номера hwmon при каждой загрузке свои, поэтому датчик CPU ищется по имени.
cpu_temp_file=""
for hwmon in /sys/class/hwmon/hwmon*; do
    read -r sensor < "$hwmon/name" 2>/dev/null || continue
    case "$sensor" in
        coretemp|k10temp|zenpower)
            [[ -r $hwmon/temp1_input ]] && cpu_temp_file=$hwmon/temp1_input
            break
            ;;
    esac
done

json_escape() {
    local value=${1//\\/\\\\}
    printf '%s' "${value//\"/\\\"}"
}

# Имя модели ищется в pci.ids по vendor/device из sysfs, а не через lspci:
# lspci читает конфигурационное пространство и этим будит спящую NVIDIA.
pci_ids=""
for candidate in /usr/share/hwdata/pci.ids /usr/share/misc/pci.ids; do
    [[ -r $candidate ]] && { pci_ids=$candidate; break; }
done

pci_name() {
    [[ -n $pci_ids ]] || return
    awk -v vendor="$1" -v device="$2" '
        /^[0-9a-f]/ { in_vendor = ($1 == vendor); next }
        in_vendor && /^\t[0-9a-f]/ && $1 == device {
            sub(/^\t[0-9a-f]+ +/, "")
            print
            exit
        }
    ' "$pci_ids"
}

# Карты сортируются по PCI-адресу: встроенная графика стоит на шине 00 и
# оказывается первой, дискретная — второй.
gpu_cards=()
gpu_addrs=()
gpu_drivers=()
gpu_names=()
while read -r addr card; do
    device=/sys/class/drm/$card/device
    driver=$(basename "$(readlink -f "$device/driver")")
    read -r vendor_id < "$device/vendor"
    read -r device_id < "$device/device"
    name=$(pci_name "${vendor_id#0x}" "${device_id#0x}")
    # «Alder Lake-P GT2 [Iris Xe Graphics]» — маркетинговое имя в скобках.
    [[ $name =~ \[(.*)\] ]] && name=${BASH_REMATCH[1]}
    [[ -n $name ]] || name=$driver
    gpu_cards+=("$card")
    gpu_addrs+=("$addr")
    gpu_drivers+=("$driver")
    gpu_names+=("$(json_escape "$name")")
done < <(
    for card in /sys/class/drm/card[0-9]*; do
        # card0-eDP-1 и подобные — коннекторы, а не сами карты.
        [[ ${card##*/} == *-* ]] && continue
        addr=$(readlink -f "$card/device")
        printf '%s %s\n' "${addr##*/}" "${card##*/}"
    done | sort
)

take_sample() {
    now=${EPOCHREALTIME//[!0-9]/}

    read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
    cpu_idle=$((idle + iowait))
    cpu_total=$((user + nice + system + idle + iowait + irq + softirq + steal))

    # Только физические интерфейсы: у lo, veth, мостов и туннелей нет device,
    # а их трафик и так проходит через физический — иначе он посчитался бы дважды.
    net_rx=0
    net_tx=0
    for net in /sys/class/net/*; do
        [[ -e $net/device ]] || continue
        read -r bytes < "$net/statistics/rx_bytes" && net_rx=$((net_rx + bytes))
        read -r bytes < "$net/statistics/tx_bytes" && net_tx=$((net_tx + bytes))
    done

    gpu_rc6=()
    for i in "${!gpu_cards[@]}"; do
        gpu_rc6[i]=0
        [[ ${gpu_drivers[i]} == i915 ]] || continue
        read -r gpu_rc6[i] < "/sys/class/drm/${gpu_cards[i]}/gt/gt0/rc6_residency_ms" 2>/dev/null
    done
}

remember_sample() {
    prev_now=$now
    prev_cpu_idle=$cpu_idle
    prev_cpu_total=$cpu_total
    prev_net_rx=$net_rx
    prev_net_tx=$net_tx
    prev_gpu_rc6=("${gpu_rc6[@]}")
}

gpu_json() {
    local i=$1 busy=-1 freq=-1 temp=-1 mem_used=-1 mem_total=-1 state=active

    case "${gpu_drivers[i]}" in
        i915)
            # Доля времени вне RC6 (сна) — то же, что показывает intel_gpu_top.
            local idle=$(((gpu_rc6[i] - prev_gpu_rc6[i]) * 100000 / elapsed))
            busy=$((100 - idle))
            ((busy < 0)) && busy=0
            ((busy > 100)) && busy=100
            read -r freq < "/sys/class/drm/${gpu_cards[i]}/gt_act_freq_mhz" 2>/dev/null
            ;;
        nvidia)
            # nvidia-smi будит карту из runtime suspend, и она потом долго не
            # засыпает. Спящую карту не трогаем — её загрузка и так ноль.
            local status=active
            read -r status < "/sys/bus/pci/devices/${gpu_addrs[i]}/power/runtime_status" 2>/dev/null
            if [[ $status == suspended ]]; then
                state=sleep
            else
                IFS=', ' read -r busy temp mem_used mem_total < <(
                    nvidia-smi --id="${gpu_addrs[i]}" \
                        --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total \
                        --format=csv,noheader,nounits 2>/dev/null
                )
                [[ $busy =~ ^[0-9]+$ ]] || { busy=-1; temp=-1; mem_used=-1; mem_total=-1; }
            fi
            ;;
        *)
            state=unknown
            ;;
    esac

    printf '{"name":"%s","driver":"%s","state":"%s","busy":%d,"freq":%d,"temp":%d,"memUsed":%d,"memTotal":%d}' \
        "${gpu_names[i]}" "${gpu_drivers[i]}" "$state" \
        "${busy:--1}" "${freq:--1}" "${temp:--1}" "${mem_used:--1}" "${mem_total:--1}"
}

# Затравочный замер: первая строка сразу выходит с настоящими дельтами, а не
# с нулями, — окно открыли, и цифры должны появиться без секундной паузы.
take_sample
remember_sample
sleep 0.3

while :; do
    take_sample
    elapsed=$((now - prev_now))
    ((elapsed > 0)) || elapsed=1

    cpu=0
    total_delta=$((cpu_total - prev_cpu_total))
    if ((total_delta > 0)); then
        idle_delta=$((cpu_idle - prev_cpu_idle))
        cpu=$(((100 * (total_delta - idle_delta) + total_delta / 2) / total_delta))
    fi

    cpu_temp=-1
    if [[ -n $cpu_temp_file ]] && read -r millidegrees < "$cpu_temp_file"; then
        cpu_temp=$(((millidegrees + 500) / 1000))
    fi

    mem_total=0
    mem_available=0
    while read -r key value _; do
        case "$key" in
            MemTotal:) mem_total=$value ;;
            MemAvailable:) mem_available=$value ;;
        esac
    done < /proc/meminfo

    { read -r _; read -r disk_size disk_used disk_avail; } < <(df -B1 --output=size,used,avail /)

    read -r load_one load_five load_fifteen _ < /proc/loadavg
    read -r uptime _ < /proc/uptime

    # Счётчики обнуляются, когда интерфейс переподнимают.
    rx_rate=$(((net_rx - prev_net_rx) * 1000000 / elapsed))
    tx_rate=$(((net_tx - prev_net_tx) * 1000000 / elapsed))
    ((rx_rate < 0)) && rx_rate=0
    ((tx_rate < 0)) && tx_rate=0

    gpus=""
    for i in "${!gpu_cards[@]}"; do
        [[ -n $gpus ]] && gpus+=","
        gpus+=$(gpu_json "$i")
    done

    printf '{"cpu":%d,"cpuTemp":%d,"memUsed":%d,"memTotal":%d,"diskSize":%d,"diskUsed":%d,"diskAvail":%d,"load":[%s,%s,%s],"uptime":%d,"rx":%d,"tx":%d,"gpus":[%s]}\n' \
        "$cpu" "$cpu_temp" "$((mem_total - mem_available))" "$mem_total" \
        "$disk_size" "$disk_used" "$disk_avail" \
        "$load_one" "$load_five" "$load_fifteen" "${uptime%.*}" \
        "$rx_rate" "$tx_rate" "$gpus"

    remember_sample
    sleep 1
done
