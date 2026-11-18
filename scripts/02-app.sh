#!/usr/bin/env bash
set -Eeuo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$HERE/lib/common.sh"
require_vm
audit_start app
[[ $# == 1 ]] || fail 'Uso: 02-app.sh app.local'
ARTIFACT_DIR='' RUNTIME=none PORT=8080 HEALTH_PATH=/
load_config "$1" 'ARTIFACT_DIR RUNTIME PORT HEALTH_PATH'
[[ $ARTIFACT_DIR == /* && -d $ARTIFACT_DIR && -x $ARTIFACT_DIR/bin/start ]] || fail 'Bundle absoluto deve conter bin/start executável.'
if [[ ! $PORT =~ ^[0-9]{2,5}$ ]] || ((10#$PORT < 1024 || 10#$PORT > 65535)); then fail 'Porta inválida (1024–65535).'; fi
[[ $HEALTH_PATH =~ ^/[a-zA-Z0-9/_-]*$ ]] || fail 'HEALTH_PATH deve ser um caminho simples, sem query string.'
case $RUNTIME in dotnet) packages=(libicu74 libssl3t64 zlib1g libgcc-s1 libstdc++6);; node) packages=(nodejs npm);; java) packages=(openjdk-21-jre-headless);; python) packages=(python3 python3-venv);; none) packages=();; *) fail 'Runtime não suportado; ajuste a integração após definir a aplicação.';; esac
ARTIFACT_DIR=$(realpath "$ARTIFACT_DIR")
[[ $ARTIFACT_DIR != / && $ARTIFACT_DIR != /opt && $ARTIFACT_DIR != /opt/alertasp* ]] || fail 'Origem do bundle inválida.'
# Não importar segredos, links ou arquivos especiais para o deploy.
[[ -z $(find "$ARTIFACT_DIR" ! -type d ! -type f -print -quit) ]] || fail 'Bundle deve conter somente arquivos regulares e diretórios.'
[[ -z $(find "$ARTIFACT_DIR" \( -name '.env' -o -name '*.key' -o -name '*.pem' \) -print -quit) ]] || fail 'Remova segredos do bundle.'
export DEBIAN_FRONTEND=noninteractive
step apt-update apt-get update
step packages apt-get install -y curl ca-certificates rsync "${packages[@]}"
id alertasp >/dev/null 2>&1 || useradd --system --user-group --home-dir /var/lib/alertasp --shell /usr/sbin/nologin alertasp
install -d -m 0755 /opt/alertasp
if [[ $RUNTIME == dotnet ]]; then step dotnet-sdk "$HERE/install-dotnet.sh" /opt/alertasp/dotnet; fi
install -d -m 0750 -o alertasp -g alertasp /var/lib/alertasp
install -d -m 0700 /etc/alertasp
# Mesmo conteúdo: não copia novamente; a janela de atualização interrompe o serviço.
if systemctl is-active --quiet alertasp-app; then step stop systemctl stop alertasp-app; fi
step bundle rsync -a --delete --chown=root:root --exclude=.git/ "$ARTIFACT_DIR/" /opt/alertasp/app/
find /opt/alertasp/app -type d -exec chmod 0755 {} +
find /opt/alertasp/app -type f -exec chmod u+rw,go+r,go-w,a-s {} +
chmod 0755 /opt/alertasp/app/bin/start
# Variáveis secretas existentes são preservadas; systemd lê este arquivo como root.
if [[ ! -e /etc/alertasp/app.env ]]; then install -m 0600 /dev/null /etc/alertasp/app.env; fi
chown root:root /etc/alertasp/app.env
chmod 0600 /etc/alertasp/app.env
printf 'PORT=%s\nHOST=0.0.0.0\n' "$PORT" > /etc/alertasp/app-runtime.env
chmod 0600 /etc/alertasp/app-runtime.env
printf 'http://127.0.0.1:%s%s\n' "$PORT" "$HEALTH_PATH" > /etc/alertasp/health-url
install -m 0644 "$HERE/../systemd/alertasp-app.service" /etc/systemd/system/alertasp-app.service
step reload systemctl daemon-reload
step enable systemctl enable alertasp-app
step restart systemctl restart alertasp-app
ready=0
for ((i=0;i<30;i++)); do
    if curl --noproxy '*' -fsS --max-time 2 -o /dev/null "http://127.0.0.1:$PORT$HEALTH_PATH" 2>/dev/null; then ready=1; break; fi
    sleep 2
done
((ready)) || fail 'Healthcheck falhou; examine journalctl -u alertasp-app na VM.'
audit INFO http_healthcheck_ok
