#!/usr/bin/env bash
set -Eeuo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$HERE/lib/common.sh"
require_vm
audit_start monitor
[[ $# == 1 && -f $1 ]] || fail 'Uso: 03-monitor.sh monitor.local'
# Validação antes de substituir configuração ou reiniciar serviço.
MONITOR_CONFIG=$1 bash "$HERE/monitor.sh" --simulate 0 0 0 >/dev/null
install -d -m 0755 /usr/local/lib/alertasp/lib /etc/alertasp-monitor /etc/systemd/journald.conf.d
install -m 0755 "$HERE/monitor.sh" /usr/local/lib/alertasp/monitor.sh
install -m 0644 "$HERE/lib/common.sh" /usr/local/lib/alertasp/lib/common.sh
install -m 0644 "$1" /etc/alertasp-monitor/monitor.conf
install -m 0644 "$HERE/../systemd/alertasp-monitor.service" /etc/systemd/system/alertasp-monitor.service
# Limita espaço e mantém logs após reboot; journald já faz rotação.
printf '[Journal]\nStorage=persistent\nSystemMaxUse=200M\nMaxRetentionSec=14day\n' > /etc/systemd/journald.conf.d/alertasp.conf
step journal-restart systemctl restart systemd-journald
step journal-flush journalctl --flush
step reload systemctl daemon-reload
step enable systemctl enable alertasp-monitor
step restart systemctl restart alertasp-monitor
sleep 3
step status systemctl is-active alertasp-monitor
# Uma amostra concluída é necessária, além do processo ativo.
journalctl -u alertasp-monitor --since '-5 seconds' --no-pager -o cat | grep -q 'source=real.*metric=disk' || fail 'Monitor iniciou, mas não completou amostra.'
audit INFO primeira_amostra_ok
