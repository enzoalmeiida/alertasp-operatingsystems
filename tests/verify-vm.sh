#!/usr/bin/env bash
# Somente em VM Ubuntu descartável criada pelo harness: altera a rede da VM.
set -Eeuo pipefail
cd -- "$(dirname -- "$0")/.."
[[ $EUID == 0 && -f /etc/alertasp-ci-vm ]] || { echo 'Requer VM descartável marcada pelo cloud-init.' >&2; exit 1; }
mkdir -p evidence/raw
exec > >(tee evidence/raw/vm-validation.log) 2>&1
rc=0
trap 'rc=$?; if ((rc)); then tail -100 /var/log/alertasp/provision.log 2>/dev/null || true; journalctl -u alertasp-app -u alertasp-monitor -n 100 --no-pager || true; fi; exit "$rc"' EXIT
iface=$(ip -4 route show default | awk 'NR==1 {print $5}')
address=$(ip -4 -o address show dev "$iface" scope global | awk 'NR==1 {print $4}')
gateway=$(ip -4 route show default | awk 'NR==1 {print $3}')
dns=$(resolvectl dns "$iface" | awk '{print $NF}')
# Endereços obtidos da rede virtual efetiva, não inventados para a VM do aluno.
printf 'HOSTNAME=alertasp\nINTERFACE=%s\nMODE=static\nADDRESS=%s\nGATEWAY=%s\nDNS=%s\n' "$iface" "$address" "$gateway" "$dns" > config/infra.local
cp config/monitor.conf.example config/monitor.local
./scripts/00-adopt-network.sh --console-confirmed
./scripts/provision-csharp.sh config/infra.local config/monitor.local --apply-network
printf '\nPASS first-provision\n'
systemd-analyze verify systemd/alertasp-app.service systemd/alertasp-monitor.service
resolvectl query github.com
getent hosts alertasp
python3 - <<'PY'
import urllib.request,json
req=urllib.request.Request('http://127.0.0.1:8080/api/reports',data=json.dumps(dict(roadName='Teste VM OS',district='Synthetic VM',latitude=-23.55,longitude=-46.63,observedAt='2026-01-15T12:00:00Z',source='SyntheticDemo')).encode(),headers={'Content-Type':'application/json'})
with urllib.request.urlopen(req) as r:
 assert r.status==201
 report=json.load(r)
 open('evidence/raw/report-id','w').write(report['id'])
print('PASS create-synthetic-report')
PY
./scripts/provision-csharp.sh config/infra.local config/monitor.local --apply-network
printf '\nPASS second-provision\n'
./scripts/04-failure-test.sh alertasp-monitor
./scripts/04-failure-test.sh alertasp-app
./scripts/monitor.sh --simulate 100 100 100 | tee evidence/raw/alerts.log | systemd-cat -t alertasp-simulation
[[ $(grep -c 'level=ALERT' evidence/raw/alerts.log) == 3 ]]
[[ $(grep -c 'source=simulation' evidence/raw/alerts.log) == 3 ]]
journalctl -t alertasp-simulation --no-pager
./scripts/05-evidence.sh /tmp/alertasp-vm-evidence.txt
cp /tmp/alertasp-vm-evidence.txt evidence/raw/vm-evidence.txt
printf '\nPASS pre-reboot-validation\n'
