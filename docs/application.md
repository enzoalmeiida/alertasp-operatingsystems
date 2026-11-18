# Aplicação selecionada: AlertaSP C#

Repositório: https://github.com/enzoalmeiida/alertasp-csharp

Commit validado: `cffd7a757982642824f7acba1ace1af8c4c0e18e` (sem alterações no código da aplicação).

| Item | Configuração |
|---|---|
| SDK | .NET 10.0.100, conforme global.json com rollForward desativado |
| Aplicação | `src/Alertasp.Api/Alertasp.Api.csproj`, net10.0 |
| Publicação | Release, framework-dependent, executada por `dotnet Alertasp.Api.dll` |
| Porta / bind na VM | 8080 / 0.0.0.0, rede de laboratório |
| Saúde | `GET /health` |
| Fluxo | `POST/GET /api/reports`, `PATCH /api/reports/{id}/status` |
| Banco | SQLite via EF Core; migrations automáticas no startup |
| Persistência | `/var/lib/alertasp/alertasp.db`, propriedade do usuário alertasp |
| Ambiente padrão | Production; Swagger só existe em Development |
| Credenciais externas | Nenhuma necessária para esta versão |

A API não tem autenticação e não possui interface cidadã. Use rede de laboratório restrita; o professor ainda precisa confirmar se API isolada atende “aplicação WEB”. Não apresentar Swagger como dashboard de outra disciplina.

## Provisionamento automatizado na VM

Use o comando do README: `provision-csharp.sh`. O build executa sob `alertasp-build`, separado do usuário `alertasp` do serviço. Arquivos gerados e caches ficam em `/var/lib/alertasp-build`; o bundle é copiado para `/opt/alertasp/app`, somente leitura pelo serviço. O SDK de execução fica em `/opt/alertasp/dotnet`. As bibliotecas nativas Ubuntu (`libicu74`, `libssl3t64`, zlib, libgcc e libstdc++) são instaladas automaticamente.

O instalador baixa o SDK somente da Microsoft e verifica SHA-512 publicado em:
`https://builds.dotnet.microsoft.com/dotnet/release-metadata/10.0/releases.json`.

O pin é intencional para corresponder ao projeto. Atualizações de SDK/runtime exigem rever versão, checksum, build e testes. Não desabilitar assinatura de pacotes ou TLS. O projeto não fornece lockfile NuGet: referências diretas são fixadas, mas o primeiro restore resolve transitivas. O bundle preparado inclui `SHA256SUMS`, commit e resultado TRX para rastreabilidade; não se afirma build bit a bit idêntico em datas diferentes.

## Build independente e validação na nuvem

Pré-requisitos: Linux x86_64, bash, git, curl, Python 3 e bibliotecas nativas .NET. Neste ambiente já estão disponíveis. Não execute scripts privilegiados da VM aqui.

```bash
cd /workspace/alertasp-operatingsystems
./scripts/prepare-csharp.sh /workspace/alertasp-csharp /workspace/alertasp-runtime/bundle /workspace/alertasp-tools/dotnet
python3 tests/test-csharp-smoke.py /workspace/alertasp-runtime/bundle /workspace/alertasp-tools/dotnet
```

O helper pode clonar o checkout caso ainda não exista. Preserva checkout existente e exige o commit revisado, sem alterações. Instala SDK, roda testes, publica em staging e move o bundle pronto. Em nova execução verifica checksums e reaproveita. Se mudar a aplicação ou o launcher, revise o pin e use um diretório novo para o bundle; não sobrescreva trabalho existente. Para rodar novamente a suíte C# com dependências já instaladas:

```bash
cd /workspace/alertasp-csharp
DOTNET_CLI_HOME=/workspace/alertasp-tools/dotnet-cli NUGET_PACKAGES=/workspace/alertasp-tools/nuget /workspace/alertasp-tools/dotnet/dotnet test Alertasp.sln -c Release
```

O smoke test inicia a aplicação publicada em porta local temporária e SQLite temporário, cadastra dado sintético, filtra, atualiza, verifica 400/404 e reinicia o processo para consultar o mesmo ID. Encerra apenas processos que criou e remove o banco temporário. Não testa o restart automático do systemd; isso deve ser demonstrado na VM com `04-failure-test.sh`.

## Variáveis e inicialização

`start-csharp.sh` é copiado para `bin/start` do bundle e usa `exec`, permitindo que systemd acompanhe o processo .NET diretamente:

- `HOST`/`PORT`: gerenciados por `02-app.sh` no arquivo root-only `app-runtime.env`.
- `DOTNET_ROOT`: padrão `/opt/alertasp/dotnet`.
- `ASPNETCORE_ENVIRONMENT`: Production por padrão.
- `ConnectionStrings__Alertasp`: padrão `Data Source=/var/lib/alertasp/alertasp.db`.

Para demonstrar Swagger em rede de laboratório, edite `/etc/alertasp/app.env` com `sudoedit`, acrescente `ASPNETCORE_ENVIRONMENT=Development` e reinicie `alertasp-app`. A rota passa a ser `/swagger`. Isso não adiciona autenticação. Não habilite Development para exposição pública.

O arquivo `app.env` é root:root 0600, preservado nas reexecuções. Não é necessário preencher segredos para SQLite. Não inclua bancos ou arquivos .env no bundle. Migrations precisam escrever no diretório de dados, incluindo arquivos WAL/SHM. Antes de atualizar schema/commit, faça backup consistente do SQLite com a aplicação parada e valide a restauração; rollback de binário não desfaz migration.

## Resultado obtido e próximo passo

Build Release, 6 testes existentes e 7 verificações HTTP do artefato publicado passaram na nuvem. Persistência após reinício manual comprovada. Código fonte C# permaneceu intacto. O próximo passo é executar o fluxo completo no Ubuntu com systemd, verificar reexecução, boot, falha controlada, acesso do host e gravar o vídeo.
