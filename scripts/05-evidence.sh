#!/usr/bin/env bash
set -Eeuo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$HERE/lib/common.sh"
require_vm
[[ $# == 1 && ! -e $1 ]] || fail 'Uso: 05-evidence.sh /caminho/arquivo-novo.txt'
umask 077
# Não coleta Environment, app.env nem logs arbitrários da aplicação.
{
    date -u +%FT%TZ
    cat /etc/os-release
    hostnamectl
    ip -brief address
    ip route
    resolvectl status
    for unit in alertasp-app alertasp-monitor; do
        systemctl is-active "$unit"
        systemctl is-enabled "$unit"
        systemctl show "$unit" -p MainPID -p NRestarts -p Result -p User -p Restart
    done
    curl --noproxy '*' -fsS --max-time 5 -o /dev/null -w 'HTTP status=%{http_code}\n' "$(cat /etc/alertasp/health-url)"
    journalctl -u alertasp-monitor -n 30 --no-pager -o cat
    cat /var/log/alertasp/provision.log
} > "$1"
printf 'Evidência criada. Revise IPs, nomes e logs antes de publicar: %s\n' "$1"
