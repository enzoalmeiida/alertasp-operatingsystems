#!/usr/bin/env bash
set -Eeuo pipefail
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
umask 027
AUDIT_LOG=/var/log/alertasp/provision.log
fail() { printf 'ERRO: %s\n' "$*" >&2; exit 1; }
require_root() { [[ $EUID -eq 0 ]] || fail 'Execute com sudo na VM Ubuntu.'; }
require_vm() {
    require_root
    [[ $(ps -p 1 -o comm=) == systemd ]] || fail 'É necessário systemd como PID 1.'
    # shellcheck disable=SC1091
    . /etc/os-release
    [[ $ID == ubuntu && $VERSION_ID == 24.04 ]] || fail 'Alvo suportado: Ubuntu Server 24.04 LTS.'
}
# Configuração declarativa, nunca executada com source/eval.
load_config() {
    local file=$1 allowed=$2 key value line
    [[ -f $file ]] || fail "Configuração ausente: $file"
    while IFS= read -r line || [[ -n $line ]]; do
        [[ -z $line || $line == \#* ]] && continue
        [[ $line == *=* ]] || fail 'Use CHAVE=valor sem aspas nem espaços em torno de =.'
        key=${line%%=*}; value=${line#*=}
        [[ " $allowed " == *" $key "* && $key =~ ^[A-Z_]+$ ]] || fail "Chave inválida: $key"
        [[ $value != *$'\r'* ]] || fail 'Converta o arquivo para linhas Unix (LF).'
        printf -v "$key" '%s' "$value"
    done < "$file"
}
audit_start() {
    install -d -m 0750 /var/log/alertasp
    exec 9>/run/lock/alertasp-provision.lock
    flock -n 9 || fail 'Outro provisionamento está em execução.'
    AUDIT_TASK=$1
    audit INFO inicio
    trap 'rc=$?; trap - EXIT; if ((rc == 0)); then audit INFO sucesso; else audit ERROR "falha exit=$rc linha=$LINENO"; fi; exit "$rc"' EXIT
}
audit() {
    printf '%s task=%s level=%s event=%s\n' "$(date -u +%FT%TZ)" "${AUDIT_TASK:-manual}" "$1" "$2" | tee -a "$AUDIT_LOG"
}
step() {
    local label=$1; shift
    audit INFO "$label:inicio"
    # Apenas operações sem segredos passam por esta função.
    local rc=0
    # Compiler servers may outlive this command; never pass the lock to children.
    "$@" 9>&- >> "$AUDIT_LOG" 2>&1 || rc=$?
    if ((rc)); then audit ERROR "$label:exit=$rc"; return "$rc"; fi
    audit INFO "$label:sucesso"
}
