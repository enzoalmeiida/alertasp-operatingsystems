#!/usr/bin/env bash
set -Eeuo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$HERE/lib/common.sh"
CPU_THRESHOLD=85 MEM_THRESHOLD=85 DISK_THRESHOLD=90 INTERVAL=30 DISK_PATH=/
config=${MONITOR_CONFIG:-/etc/alertasp/monitor.conf}
[[ ! -f $config ]] || load_config "$config" 'CPU_THRESHOLD MEM_THRESHOLD DISK_THRESHOLD INTERVAL DISK_PATH'
for key in CPU_THRESHOLD MEM_THRESHOLD DISK_THRESHOLD; do
    value=${!key}
    [[ $value =~ ^[1-9][0-9]?$|^100$ ]] || fail "$key deve ser de 1 a 100."
done
if [[ ! $INTERVAL =~ ^[1-9][0-9]{0,3}$ ]] || ((INTERVAL > 3600)); then fail 'INTERVAL deve ser de 1 a 3600 segundos.'; fi
[[ -d $DISK_PATH ]] || fail 'DISK_PATH deve existir.'
mode=${1:---loop}
[[ $mode == --loop || $mode == --once || $mode == --simulate ]] || fail 'Uso: monitor.sh [--once | --loop | --simulate CPU MEM DISCO]'
if [[ $mode == --simulate ]]; then
    [[ $# == 4 ]] || fail 'Simulação exige três percentuais.'
    for value in "${@:2}"; do [[ $value =~ ^[0-9]$|^[1-9][0-9]$|^100$ ]] || fail 'Amostra inválida.'; done
else
    [[ $# -le 1 ]] || fail 'Argumentos inesperados.'
fi
cpu_sample() {
    # guest/guest_nice já estão em user/nice; não contar duas vezes.
    awk '/^cpu / { idle=$5+$6; total=0; for(i=2;i<=9;i++) total+=$i; print total,idle; exit }' /proc/stat
}
report() {
    local metric=$1 usage=$2 threshold=$3 source=$4 level=INFO event=sample
    if ((usage >= threshold)); then level=ALERT; event=threshold_exceeded; fi
    printf '%s source=%s level=%s event=%s metric=%s usage_pct=%s threshold_pct=%s\n' "$(date -u +%FT%TZ)" "$source" "$level" "$event" "$metric" "$usage" "$threshold"
}
while :; do
    source_kind=real
    if [[ $mode == --simulate ]]; then
        cpu=$2; mem=$3; disk=$4; source_kind=simulation
    else
        read -r total_before idle_before < <(cpu_sample)
        sleep 1
        read -r total_after idle_after < <(cpu_sample)
        delta=$((total_after-total_before))
        ((delta > 0)) || fail 'Não foi possível medir CPU.'
        cpu=$((100*(delta-idle_after+idle_before)/delta))
        mem=$(awk '/^MemTotal:/ {t=$2} /^MemAvailable:/ {a=$2; found=1} END {if(t<=0 || !found) exit 1; printf "%d",100*(t-a)/t}' /proc/meminfo)
        disk=$(df -P -- "$DISK_PATH" | awk 'NR==2 {gsub(/%/,"",$5); print $5}')
        [[ $disk =~ ^[0-9]+$ ]] || fail 'Não foi possível medir disco.'
    fi
    report cpu "$cpu" "$CPU_THRESHOLD" "$source_kind"
    report memory "$mem" "$MEM_THRESHOLD" "$source_kind"
    report disk "$disk" "$DISK_THRESHOLD" "$source_kind"
    [[ $mode == --loop ]] || break
    sleep "$INTERVAL"
done
