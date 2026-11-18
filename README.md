# AlertaSP — Operating Systems / FIAP

Automação Bash para hospedar a **aplicação web de outra disciplina** em Ubuntu Server 24.04 LTS com systemd. O app React Native/Expo não é tratado como essa aplicação. Base elaborada a partir das páginas 35–37 do PDF CitizenTech fornecido pelo aluno.

**Situação:** integração com [alertasp-csharp](https://github.com/enzoalmeiida/alertasp-csharp), API ASP.NET Core .NET 10 com SQLite, implementada. Os 10 testes de scripts, 6 testes da API e 7 verificações HTTP passaram nesta nuvem. Provisionamento completo, idempotência na VM, boot, recuperação systemd e vídeo ainda não comprovados. A aceitação de API isolada pelo professor continua pendente. Não é uma entrega validada para 10/10.

## Plataforma escolhida

VM dedicada Ubuntu Server 24.04 LTS **x86_64**, sugestão inicial: 2 vCPU, 4 GB RAM e 25 GB disco. Pode ser VirtualBox, VMware ou VM equivalente. Esses recursos são uma sugestão, não uma exigência extraída do PDF. Console da VM e sudo são necessários. Não executar os provisionadores no host pessoal, em container ou na máquina de produção.

A máquina de desenvolvimento na nuvem usa Debian 13 com `tail` no PID 1. Permite editar e executar testes locais; não substitui a demonstração da VM. [Resultado real dos testes](evidence/local-tests.txt).

## Fluxo da aplicação C# selecionada

A API vem da disciplina C# Software Development, commit `cffd7a757982642824f7acba1ace1af8c4c0e18e`. SDK 10.0.100, SQLite incorporado, porta 8080 e `/health`; migrations aplicadas no startup. Sem servidor de banco, senha ou serviço externo. Confirme com o professor a aceitação de API isolada: Swagger não é um dashboard cidadão.

1. Preparar VM e rede conforme [guia da VM](docs/vm.md).
2. Copiar configurações e preencher a interface/IP/DNS reais:

```bash
cp config/infra.conf.example config/infra.local
cp config/monitor.conf.example config/monitor.local
# Edite os arquivos. Formato CHAVE=valor, sem aspas.
```

3. No console da VM dedicada, executar:

```bash
sudo ./scripts/00-adopt-network.sh --console-confirmed
sudo ./scripts/provision-csharp.sh config/infra.local config/monitor.local --apply-network
```

O segundo script configura a infra, instala SDK com verificação SHA-512, baixa o commit fixado, executa os 6 testes e publica a API usando usuário de build sem privilégios. Instala o serviço web e o monitor; aguarda HTTP e primeira amostra. O SDK é usado também para hospedar a aplicação nesta base didática (ocupa mais disco que instalar apenas runtime).

Execute o segundo comando duas vezes na VM para comprovar idempotência. O bundle existente é reutilizado após checksums; usuário, diretórios e serviços convergem. Há reinício deliberado da API a cada deploy e pacotes podem receber novas atualizações. O banco em `/var/lib/alertasp/alertasp.db` não é substituído pelo deploy. Não é atualização sem indisponibilidade.

[Integração, build independente, variáveis e smoke test](docs/application.md). O fluxo genérico `provision.sh` permanece disponível para outros bundles, com `config/app.local` explícito.

## Scripts e serviços

| Arquivo | Responsabilidade |
|---|---|
| `00-adopt-network.sh` | Backup verificado e transferência do Netplan da VM dedicada |
| `01-infra.sh` | apt update/upgrade, pacotes, hostname, hosts, Netplan IPv4 DHCP/estático, DNS e logrotate |
| `install-dotnet.sh` / `prepare-csharp.sh` | SDK verificado, checkout fixado, testes e publicação sem alterar código C# |
| `provision-csharp.sh` | Infra + build sem root + deploy da API + monitor |
| `02-app.sh` | Runtime selecionado, usuário sem login, artefato, variáveis, serviço e healthcheck HTTP |
| `03-monitor.sh` | Instala monitor, configuração, journal persistente limitado e serviço |
| `monitor.sh` | Mede CPU, memória disponível e ocupação de disco; gera amostras e alertas |
| `04-failure-test.sh` | Mata o processo principal, exige novo PID, aumento de NRestarts e recuperação funcional |
| `05-evidence.sh` | Coleta estado, HTTP, monitoramento e log dos scripts sem ler arquivos de segredos |

`alertasp-app`: `Restart=on-failure`, atraso de 5s, dependência de `network-online.target`. Isso ordena a inicialização de rede, não comprova disponibilidade de banco ou Internet. O launcher precisa usar `exec` e ficar em primeiro plano. Usuário `alertasp`, sem privilégios; código somente leitura; escrita em `/var/lib/alertasp`. Recursos extras devem ser liberados somente quando a aplicação real exigir.

`alertasp-monitor`: `Restart=always`, atraso de 5s, usuário dinâmico, sem escrita no sistema. Falhas repetidas são limitadas a 10 inicializações em 60s para impedir loops descontrolados. Depois de corrigir a causa: `sudo systemctl reset-failed NOME` e `sudo systemctl start NOME`. `enable` inicia no boot. Uma parada administrativa via `systemctl stop` não aciona reinício automático.

## Monitoramento, variáveis e alertas

Limiares padrão documentados: CPU >=85%, memória >=85%, disco >=90%; amostra de CPU em 1s; espera de 30s entre ciclos. São valores iniciais para laboratório, ajustáveis em `config/monitor.local`. Memória usa `(MemTotal-MemAvailable)/MemTotal`; CPU usa diferenças de `/proc/stat` descontando idle/iowait e sem duplicar guest; disco usa `df -P` sobre `DISK_PATH`. Não exige atingir esses limites consumindo recursos de verdade.

Cada métrica gera timestamp UTC, origem, nível, evento, consumo e limiar. `level=ALERT` significa limiar atingido; entrega do alerta é o journal local, sem email/Slack. O monitor avisa em cada amostra acima do limite, sem deduplicação. Comandos:

```bash
./scripts/monitor.sh --once
./scripts/monitor.sh --simulate 100 100 100
sudo journalctl -u alertasp-monitor --since '-10 minutes' --no-pager
```

Simulação é marcada `source=simulation`, não representa carga real. Para registrar simulação no journal sem alterar o serviço:

```bash
sudo /usr/local/lib/alertasp/monitor.sh --simulate 100 100 100 | systemd-cat -t alertasp-simulation
journalctl -t alertasp-simulation --no-pager
```

Scripts privilegiados registram início, etapas, sucesso/erro e código de saída em `/var/log/alertasp/provision.log`; execução concorrente é bloqueada com flock. Não usam `set -x`, `eval` nem executam configuração como shell. Saídas de operações sem segredos são registradas. Logrotate mantém oito arquivos semanais comprimidos. Journal: persistente, até 200 MB e 14 dias. São logs operacionais, não uma trilha inviolável de segurança.

Segredos ficam somente em `/etc/alertasp/app.env`, root:root 0600, nunca no Git, vídeo ou linha de comando. `PORT` e `HOST` são gerenciados separadamente. A aplicação precisa respeitar essas variáveis ou adaptar seu launcher. Não registrar tokens no stdout da aplicação. Não há domínio público, certificado TLS nem firewall imposto: usar rede de laboratório; exposição pública requer configuração adicional.

## Testes e evidências

```bash
./tests/test-local.sh
sudo ./scripts/04-failure-test.sh alertasp-monitor
sudo ./scripts/04-failure-test.sh alertasp-app
sudo ./scripts/05-evidence.sh /tmp/alertasp-evidence-01.txt
```

O primeiro comando funciona sem root e testa comportamento real do monitor, simulação e validações. Os demais exigem VM e aplicação funcionais. A API já passou também nos testes descritos em [evidence/csharp-validation.md](evidence/csharp-validation.md). Revise dados e copie evidências aprovadas para `evidence/`; nunca publique arquivos de segredos. Valide reinício da VM, acesso HTTP de outra máquina e uma operação representativa da aplicação (consultar um alerta, por exemplo): HTTP 200 sozinho não comprova a solução inteira.

[Rubrica, pendências e roteiro de vídeo de 6min50s](docs/delivery.md). [Troubleshooting e recuperação da rede](docs/vm.md).

## Validação em VM pelo GitHub Actions

O workflow [Ubuntu VM validation](.github/workflows/validate.yml) cria uma VM QEMU Ubuntu isolada para testar provisionamento duas vezes, rede, serviços, falha, alertas e reboot. Consulte [docs/ci.md](docs/ci.md) e o resultado da execução correspondente ao commit: presença do workflow não significa que passou.
