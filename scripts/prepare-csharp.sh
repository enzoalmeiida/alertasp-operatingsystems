#!/usr/bin/env bash
# Executar sem root. Instala SDK verificado, testa e publica o commit inspecionado.
set -Eeuo pipefail
[[ $# == 3 ]] || { echo 'Uso: prepare-csharp.sh /checkout /bundle /sdk' >&2; exit 1; }
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source_dir=$1 bundle=$2 sdk=$3
for path in "$source_dir" "$bundle" "$sdk"; do [[ $path == /* && $path != / ]] || exit 1; done
export DOTNET_ROOT=$sdk DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1
export DOTNET_CLI_HOME=${DOTNET_CLI_HOME:-$(dirname "$sdk")/dotnet-cli}
export NUGET_PACKAGES=${NUGET_PACKAGES:-$(dirname "$sdk")/nuget}
commit=cffd7a757982642824f7acba1ace1af8c4c0e18e
"$HERE/install-dotnet.sh" "$sdk"
if [[ ! -e $source_dir ]]; then
    git clone https://github.com/enzoalmeiida/alertasp-csharp.git "$source_dir"
    git -C "$source_dir" checkout --detach "$commit"
fi
[[ $(git -C "$source_dir" rev-parse HEAD) == "$commit" ]] || { echo 'Commit da aplicação difere do revisado; revise antes de atualizar o pin.' >&2; exit 1; }
[[ -z $(git -C "$source_dir" status --porcelain) ]] || { echo 'Checkout contém alterações; preserve-as e use uma cópia limpa.' >&2; exit 1; }
if [[ -e $bundle ]]; then
    [[ -f $bundle/source-commit && $(cat "$bundle/source-commit") == "$commit" && -f $bundle/SHA256SUMS ]] || { echo 'Bundle existente não reconhecido.' >&2; exit 1; }
    (cd "$bundle" && sha256sum --check --quiet SHA256SUMS)
    cmp -s "$HERE/start-csharp.sh" "$bundle/bin/start" || { echo 'Launcher mudou: gere um bundle em novo diretório.' >&2; exit 1; }
    echo 'Bundle já preparado e checksums válidos.'
    exit 0
fi
mkdir -p "$(dirname "$bundle")"
stage=$(mktemp -d "${bundle}.stage.XXXXXX")
trap 'rm -rf -- "$stage"' EXIT
cd "$source_dir"
"$sdk/dotnet" test Alertasp.sln -c Release --logger 'trx;LogFileName=api-tests.trx' --results-directory "$stage/tests"
"$sdk/dotnet" publish src/Alertasp.Api/Alertasp.Api.csproj -c Release --no-restore --no-build -o "$stage/bundle" --self-contained false
mkdir "$stage/bundle/bin"
install -m 0755 "$HERE/start-csharp.sh" "$stage/bundle/bin/start"
printf '%s\n' "$commit" > "$stage/bundle/source-commit"
cp "$stage/tests/api-tests.trx" "$stage/bundle/build-tests.trx"
# SHA256SUMS is explicitly excluded from input.
# shellcheck disable=SC2094
(cd "$stage/bundle" && find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
mv "$stage/bundle" "$bundle"
printf 'Bundle publicado: %s\n' "$bundle"
