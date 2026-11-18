#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
export DOTNET_ROOT=${DOTNET_ROOT:-/opt/alertasp/dotnet}
export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1
export ASPNETCORE_ENVIRONMENT=${ASPNETCORE_ENVIRONMENT:-Production}
export ConnectionStrings__Alertasp=${ConnectionStrings__Alertasp:-Data Source=/var/lib/alertasp/alertasp.db}
exec "$DOTNET_ROOT/dotnet" "$ROOT/Alertasp.Api.dll" --urls "http://${HOST:-0.0.0.0}:${PORT:-8080}"
