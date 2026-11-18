#!/usr/bin/env bash
set -Eeuo pipefail
cd -- "$(dirname -- "$0")/.."
[[ $EUID == 0 && -f /etc/alertasp-ci-vm ]] || exit 1
exec > >(tee evidence/raw/reboot-validation.log) 2>&1
for unit in alertasp-app alertasp-monitor; do
    systemctl is-enabled "$unit"
    systemctl is-active "$unit"
done
python3 - <<'PY'
import json,urllib.request
report_id=open('evidence/raw/report-id').read().strip()
with urllib.request.urlopen('http://127.0.0.1:8080/api/reports/'+report_id,timeout=5) as r:
 data=json.load(r)
 assert r.status==200 and data['roadName']=='Teste VM OS'
print('PASS report-survives-reprovision-failure-and-vm-reboot')
PY
journalctl -u alertasp-monitor -b --no-pager -o cat | grep 'source=real.*metric=disk'
journalctl -u alertasp-monitor -b -1 --no-pager -o cat | grep 'source=real.*metric=disk'
[[ -s /var/log/alertasp/provision.log ]]
printf 'PASS boot-services-and-persistent-journal\n'
