#!/usr/bin/env bash
set -Eeuo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$HERE/lib/common.sh"
require_vm
audit_start infra
[[ $# -ge 1 && $# -le 2 ]] || fail 'Uso: 01-infra.sh infra.local [--apply-network]'
[[ ${2:-} == '' || ${2:-} == --apply-network ]] || fail 'Opção desconhecida.'
HOSTNAME=alertasp INTERFACE='' MODE=dhcp ADDRESS='' GATEWAY='' DNS=''
load_config "$1" 'HOSTNAME INTERFACE MODE ADDRESS GATEWAY DNS'
[[ $HOSTNAME =~ ^[a-z][a-z0-9-]{0,61}[a-z0-9]$ ]] || fail 'Hostname inválido (2 a 63 caracteres).'
[[ $INTERFACE =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]{0,14}$ && -d /sys/class/net/$INTERFACE ]] || fail 'Interface inexistente/inválida.'
[[ $MODE == dhcp || $MODE == static ]] || fail 'MODE deve ser dhcp ou static.'
python3 "$HERE/validate-network.py" "$MODE" "$ADDRESS" "$GATEWAY" "$DNS"
# Evita conflito com arquivos do instalador/cloud-init: exigimos uma VM dedicada.
shopt -s nullglob
for file in /etc/netplan/*.yaml /etc/netplan/*.yml; do
    [[ $file == /etc/netplan/90-alertasp.yaml ]] || fail "Netplan existente: $file. Leia docs/vm.md para migração e backup."
done
export DEBIAN_FRONTEND=noninteractive
step apt-update apt-get update
step apt-upgrade apt-get -y -o Dpkg::Options::=--force-confold upgrade
step packages apt-get install -y netplan.io curl ca-certificates python3 rsync logrotate git libicu74 libssl3t64 zlib1g libgcc-s1 libstdc++6
step hostname hostnamectl set-hostname "$HOSTNAME"
python3 - "$HOSTNAME" <<'PY'
from pathlib import Path
import sys
p=Path('/etc/hosts')
lines=[s for s in p.read_text().splitlines() if not s.startswith('127.0.1.1')]
p.write_text('\n'.join(lines)+f'\n127.0.1.1 {sys.argv[1]}\n')
PY
install -d -m 0755 /etc/netplan
stage=$(mktemp /etc/netplan/.alertasp.XXXXXX)
{
    printf 'network:\n  version: 2\n  renderer: networkd\n  ethernets:\n    %s:\n' "$INTERFACE"
    if [[ $MODE == dhcp ]]; then
        printf '      dhcp4: true\n'
    else
        printf '      dhcp4: false\n      addresses: [%s]\n      routes:\n        - to: default\n          via: %s\n' "$ADDRESS" "$GATEWAY"
    fi
    if [[ -n $DNS ]]; then
        [[ $MODE != dhcp ]] || printf '      dhcp4-overrides:\n        use-dns: false\n'
        printf '      nameservers:\n        addresses: [%s]\n' "$DNS"
    fi
} > "$stage"
chmod 600 "$stage"
mv "$stage" /etc/netplan/90-alertasp.yaml
step netplan-generate netplan generate
if [[ ${2:-} == --apply-network ]]; then
    step netplan-apply netplan apply
else
    audit INFO 'rede_preparada_nao_aplicada:execute_no_console_com_--apply-network'
fi
install -m 0644 "$HERE/../config/logrotate" /etc/logrotate.d/alertasp
step network-address ip -brief address show "$INTERFACE"
step network-route ip route show
step network-dns resolvectl status "$INTERFACE"
