#!/usr/bin/env bash
# SDK oficial fixado pelo global.json do alertasp-csharp, Linux x86_64.
set -Eeuo pipefail
[[ $# == 1 && $1 == /* && $1 != / ]] || { echo 'Uso: install-dotnet.sh /diretorio/absoluto' >&2; exit 1; }
[[ $(uname -m) == x86_64 ]] || { echo 'Este instalador foi validado para Linux x86_64.' >&2; exit 1; }
destination=$1
version=10.0.100
sha=f78dbac30c9af2230d67ff5c224de3a5dbf63f8a78d1c206594dedb80e6909d2cc8a9d865d5105c72c2fd2aa266fc0c6c77dedac60408cbccf272b116bd11b07
export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1
if [[ -x $destination/dotnet && -f $destination/.alertasp-sha512 ]] && [[ $(cat "$destination/.alertasp-sha512") == "$sha" ]] && [[ $("$destination/dotnet" --version) == "$version" ]]; then
    printf '.NET SDK %s já instalado em %s\n' "$version" "$destination"
    exit 0
fi
[[ ! -e $destination ]] || { echo 'Destino existente não reconhecido; preserve e revise antes de instalar.' >&2; exit 1; }
mkdir -p -- "$(dirname -- "$destination")"
stage=$(mktemp -d "${destination}.stage.XXXXXX")
trap 'rm -rf -- "$stage"' EXIT
curl --fail --show-error --silent --location --retry 3 "https://builds.dotnet.microsoft.com/dotnet/Sdk/$version/dotnet-sdk-$version-linux-x64.tar.gz" -o "$stage/sdk.tar.gz"
printf '%s  %s\n' "$sha" "$stage/sdk.tar.gz" | sha512sum -c -
mkdir "$stage/sdk"
tar -xzf "$stage/sdk.tar.gz" -C "$stage/sdk"
printf '%s\n' "$sha" > "$stage/sdk/.alertasp-sha512"
"$stage/sdk/dotnet" --list-sdks
chmod -R a+rX "$stage/sdk"
mv -- "$stage/sdk" "$destination"
