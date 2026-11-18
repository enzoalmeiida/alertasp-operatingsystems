#!/usr/bin/env bash
set -Eeuo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
[[ $# == 4 && $4 == --apply-network ]] || { echo 'Uso (console da VM): provision.sh infra.local app.local monitor.local --apply-network' >&2; exit 1; }
# Falhar antes de mexer na rede se uma configuração estiver ausente.
for file in "$1" "$2" "$3"; do [[ -f $file ]] || { echo "Ausente: $file" >&2; exit 1; }; done
"$HERE/01-infra.sh" "$1" --apply-network
"$HERE/02-app.sh" "$2"
"$HERE/03-monitor.sh" "$3"
