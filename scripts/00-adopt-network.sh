#!/usr/bin/env bash
# Só para VM dedicada: transfere a gestão do Netplan para os scripts AlertaSP.
set -Eeuo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$HERE/lib/common.sh"
require_vm
audit_start adopt-network
[[ ${1:-} == --console-confirmed && $# == 1 ]] || fail 'Execute no console da VM: 00-adopt-network.sh --console-confirmed'
shopt -s nullglob
files=()
for file in /etc/netplan/*.yaml /etc/netplan/*.yml; do
    [[ $file == /etc/netplan/90-alertasp.yaml ]] || files+=("$file")
done
if ((${#files[@]})); then
    backup=$(mktemp -d /var/backups/alertasp-netplan.XXXXXX)
    chmod 0700 "$backup"
    cp -a -- "${files[@]}" "$backup/"
    # Verifica backup antes de remover a configuração ativa do disco.
    for file in "${files[@]}"; do cmp -s -- "$file" "$backup/$(basename "$file")"; done
    rm -- "${files[@]}"
    audit INFO "backup=$backup;rede_em_memoria_preservada_execute_01_infra_sem_reiniciar"
fi
if [[ -d /etc/cloud/cloud.cfg.d ]]; then
    target=/etc/cloud/cloud.cfg.d/99-alertasp-disable-network-config.cfg
    if [[ -e $target ]]; then
        [[ $(cat "$target") == 'network: {config: disabled}' ]] || fail 'Configuração cloud-init preexistente diferente; preserve e revise.'
    else
        printf 'network: {config: disabled}\n' > "$target"
    fi
fi
