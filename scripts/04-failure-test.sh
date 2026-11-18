#!/usr/bin/env bash
set -Eeuo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$HERE/lib/common.sh"
require_vm
audit_start failure-test
[[ $# == 1 ]] || fail 'Uso: 04-failure-test.sh alertasp-monitor|alertasp-app'
unit=$1
[[ $unit == alertasp-monitor || $unit == alertasp-app ]] || fail 'Somente serviços AlertaSP podem ser testados.'
systemctl is-active --quiet "$unit" || fail 'Serviço precisa estar ativo antes do teste.'
old=$(systemctl show "$unit" -p MainPID --value)
restarts=$(systemctl show "$unit" -p NRestarts --value)
((old > 0)) || fail 'PID principal ausente.'
audit INFO "unit=$unit pid_anterior=$old reinicios_antes=$restarts"
# stop é uma parada administrativa e NÃO aciona Restart. SIGKILL simula falha.
step inject-failure systemctl kill --kill-whom=main --signal=SIGKILL "$unit"
recovered=0
for ((i=0;i<30;i++)); do
    new=$(systemctl show "$unit" -p MainPID --value)
    count=$(systemctl show "$unit" -p NRestarts --value)
    if ((new > 0 && new != old && count > restarts)) && systemctl is-active --quiet "$unit"; then recovered=1; break; fi
    sleep 1
done
((recovered)) || fail 'Serviço não se recuperou em 30s.'
if [[ $unit == alertasp-app ]]; then
    url=$(cat /etc/alertasp/health-url)
    ready=0
    for ((i=0;i<30;i++)); do
        if curl --noproxy '*' -fsS --max-time 2 -o /dev/null "$url" 2>/dev/null; then ready=1; break; fi
        sleep 1
    done
    ((ready)) || fail 'Processo reiniciou, mas HTTP não recuperou.'
else
    sleep 3
    journalctl -u "$unit" _PID="$new" --no-pager -o cat | grep -q 'source=real.*metric=disk' || fail 'Novo processo não completou uma amostra.'
fi
audit INFO "recuperado unit=$unit pid_novo=$new reinicios_depois=$count"
