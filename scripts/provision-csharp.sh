#!/usr/bin/env bash
# Fluxo da VM: infraestrutura + build não privilegiado + aplicação + monitor.
set -Eeuo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$HERE/lib/common.sh"
require_vm
[[ $# == 3 && $3 == --apply-network && -f $1 && -f $2 ]] || fail 'Uso no console: provision-csharp.sh infra.local monitor.local --apply-network'
"$HERE/01-infra.sh" "$1" --apply-network
# Não manter lock de auditoria durante chamadas dos outros provisionadores.
(
    audit_start build-csharp
    id alertasp-build >/dev/null 2>&1 || useradd --system --user-group --create-home --home-dir /var/lib/alertasp-build --shell /usr/sbin/nologin alertasp-build
    install -d -m 0750 -o alertasp-build -g alertasp-build /var/lib/alertasp-build
    install -d -m 0755 /usr/local/lib/alertasp-build
    for script in install-dotnet.sh prepare-csharp.sh start-csharp.sh; do
        install -m 0755 "$HERE/$script" "/usr/local/lib/alertasp-build/$script"
    done
    step build runuser -u alertasp-build -- /usr/local/lib/alertasp-build/prepare-csharp.sh /var/lib/alertasp-build/source /var/lib/alertasp-build/bundle /var/lib/alertasp-build/dotnet
)
config=$(mktemp)
trap 'rm -f "$config"' EXIT
printf 'ARTIFACT_DIR=/var/lib/alertasp-build/bundle\nRUNTIME=dotnet\nPORT=8080\nHEALTH_PATH=/health\n' > "$config"
"$HERE/02-app.sh" "$config"
"$HERE/03-monitor.sh" "$2"
