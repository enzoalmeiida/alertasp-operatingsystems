# AlertaSP — Operating Systems

Infraestrutura Linux automatizada para hospedar a aplicação web do AlertaSP, desenvolvida na disciplina de C# Software Development. O projeto usa scripts Bash para provisionar uma VM Ubuntu Server 24.04 LTS, configurar rede e serviços, executar a API ASP.NET Core e monitorar CPU, memória e disco.

O aplicativo React Native/Expo do AlertaSP é um projeto separado. A aplicação hospedada nesta entrega é a API web do repositório [alertasp-csharp](https://github.com/enzoalmeiida/alertasp-csharp).

## Integrantes

- Enzo Almeida — RM556900
- Gabriel Mello — RM554421
- Guilherme Moreira — RM557290

## Vídeo demonstrativo

[Assista à demonstração do AlertaSP](https://youtu.be/TDRk2UIh-TM)

## Ambiente

- Ubuntu Server 24.04 LTS x86_64
- Bash e systemd
- .NET SDK 10.0.100
- ASP.NET Core na porta `8080`
- SQLite em `/var/lib/alertasp/alertasp.db`
- Netplan para configuração de rede
- Journal do systemd e `/var/log/alertasp/provision.log` para registros

Uma VM com 2 vCPU, 4 GB de RAM e 25 GB de disco é suficiente como configuração inicial de laboratório. Os scripts de provisionamento exigem acesso ao console da VM e privilégios de `sudo`.

## Aplicação hospedada

O provisionamento usa o commit `cffd7a757982642824f7acba1ace1af8c4c0e18e` do repositório [alertasp-csharp](https://github.com/enzoalmeiida/alertasp-csharp). O script instala o SDK .NET com verificação SHA-512, obtém o código, executa os testes, publica a API e configura sua execução como serviço Linux.

A API responde em `http://IP_DA_VM:8080/health`. As migrations do SQLite são aplicadas na inicialização. O banco permanece em `/var/lib/alertasp/` durante novos provisionamentos.

## Provisionamento

No console de uma VM Ubuntu Server 24.04 LTS dedicada:

```bash
git clone https://github.com/enzoalmeiida/alertasp-operatingsystems.git
cd alertasp-operatingsystems

cp config/infra.conf.example config/infra.local
cp config/monitor.conf.example config/monitor.local
```

Preencha `config/infra.local` com a interface de rede, o endereçamento e os servidores DNS da VM. As configurações de monitoramento podem ser ajustadas em `config/monitor.local`. Os arquivos usam o formato `CHAVE=valor`, sem aspas.

Execute:

```bash
sudo ./scripts/00-adopt-network.sh --console-confirmed
sudo ./scripts/provision-csharp.sh config/infra.local config/monitor.local --apply-network
```

O primeiro script prepara a adoção da configuração de rede e preserva um backup. O segundo provisiona a infraestrutura, instala e publica a aplicação, configura os serviços systemd e aguarda a resposta HTTP e a primeira amostra do monitor.

O comando de provisionamento pode ser executado novamente:

```bash
sudo ./scripts/provision-csharp.sh config/infra.local config/monitor.local --apply-network
```

A segunda execução reutiliza componentes já instalados e preserva o banco de dados. O serviço da API é reiniciado durante o deploy.

As etapas de configuração de rede e recuperação estão descritas em [docs/vm.md](docs/vm.md). A integração com a aplicação C# está documentada em [docs/application.md](docs/application.md).

## Scripts

| Script | Função |
|---|---|
| `scripts/00-adopt-network.sh` | Prepara a configuração de rede com backup |
| `scripts/01-infra.sh` | Configura pacotes, hostname, IP, DNS, Netplan e rotação de logs |
| `scripts/install-dotnet.sh` | Instala o SDK .NET com verificação SHA-512 |
| `scripts/prepare-csharp.sh` | Obtém o código C#, executa testes e publica a API |
| `scripts/provision-csharp.sh` | Orquestra o provisionamento completo |
| `scripts/02-app.sh` | Configura usuário, diretórios, variáveis e serviço da aplicação |
| `scripts/03-monitor.sh` | Instala o monitor e seu serviço systemd |
| `scripts/monitor.sh` | Mede CPU, memória e disco e gera alertas |
| `scripts/04-failure-test.sh` | Simula falha de processo e testa a recuperação |
| `scripts/05-evidence.sh` | Coleta estado dos serviços, HTTP, monitoramento e logs |

## Serviços systemd

A aplicação é executada pelo serviço `alertasp-app`, com usuário próprio sem privilégios. O serviço inicia com o sistema e usa `Restart=on-failure` para se recuperar de falhas de processo.

O monitor é executado pelo serviço `alertasp-monitor`. Ele inicia automaticamente, realiza medições periódicas e usa `Restart=always` para recuperar o processo após uma falha. Uma parada administrativa com `systemctl stop` não aciona reinício automático.

Comandos de administração:

```bash
sudo systemctl status alertasp-app
sudo systemctl status alertasp-monitor

sudo systemctl restart alertasp-app
sudo systemctl restart alertasp-monitor

sudo journalctl -u alertasp-app --since '-10 minutes' --no-pager
sudo journalctl -u alertasp-monitor --since '-10 minutes' --no-pager
```

Os arquivos de serviço estão em `systemd/`.

## Monitoramento e alertas

O monitor registra a utilização de CPU, memória RAM e disco. Os limites iniciais são:

| Recurso | Limite de alerta |
|---|---:|
| CPU | 85% |
| Memória | 85% |
| Disco | 90% |

Esses valores são configuráveis em `config/monitor.local`. O monitor aguarda 30 segundos entre ciclos e registra cada amostra no journal. Quando uma medição atinge o limite, registra um evento `level=ALERT`.

Para executar uma medição:

```bash
./scripts/monitor.sh --once
```

Para demonstrar os três alertas sem consumir recursos reais da VM:

```bash
./scripts/monitor.sh --simulate 100 100 100
```

A simulação é identificada nos registros por `source=simulation`. Para registrá-la no journal:

```bash
sudo /usr/local/lib/alertasp/monitor.sh --simulate 100 100 100 | systemd-cat -t alertasp-simulation
journalctl -t alertasp-simulation --no-pager
```

Os alertas são entregues pelo journal local. O projeto não configura envio por email ou mensageria.

## Logs e auditoria

Os scripts de provisionamento registram início, etapas executadas, resultado, erros e horário em:

```text
/var/log/alertasp/provision.log
```

O log tem rotação configurada pelo `logrotate`. As execuções dos serviços, as amostras e os alertas do monitor podem ser consultados com `journalctl`. O journal é configurado para persistir após reinicializações, com limite de armazenamento.

Arquivos de segredos não são publicados no repositório. As variáveis privadas da aplicação ficam em `/etc/alertasp/app.env`, com acesso restrito ao usuário `root`.

## Testes de falha e recuperação

Com os serviços ativos na VM, execute:

```bash
sudo ./scripts/04-failure-test.sh alertasp-monitor
sudo ./scripts/04-failure-test.sh alertasp-app
```

O teste interrompe o processo principal com `SIGKILL` e verifica se o systemd cria um novo processo, incrementa o contador de reinicializações e restaura o funcionamento do serviço.

Para coletar o estado do ambiente após os testes:

```bash
sudo ./scripts/05-evidence.sh /tmp/alertasp-evidence-01.txt
```

O teste local dos scripts pode ser executado sem `root`:

```bash
./tests/test-local.sh
```

## Evidências

As evidências técnicas da execução em VM Ubuntu estão organizadas em [evidence/ubuntu-vm/](evidence/ubuntu-vm/). As capturas de tela da demonstração ficam em `evidence/ubuntu-vm/prints/`.

O workflow [Ubuntu VM validation](.github/workflows/validate.yml) executou o provisionamento duas vezes em uma VM QEMU Ubuntu e verificou rede, aplicação, SQLite, monitoramento, alertas, recuperação dos serviços e persistência após reboot. [Consulte a execução do GitHub Actions](https://github.com/enzoalmeiida/alertasp-operatingsystems/actions/runs/44311927366).

Também foram executados 11 testes locais dos scripts, 6 testes da API e 7 verificações HTTP. Os resultados estão em [evidence/local-tests.txt](evidence/local-tests.txt), [evidence/csharp-validation.md](evidence/csharp-validation.md) e [evidence/ubuntu-vm/README.md](evidence/ubuntu-vm/README.md).

## Estrutura

```text
.
├── .github/workflows/       # Validação automatizada em VM Ubuntu
├── config/                  # Exemplos de configuração
├── docs/                    # Guias de VM, aplicação, CI e demonstração
├── evidence/                # Resultados e evidências técnicas
├── scripts/                 # Provisionamento, monitoramento e testes de falha
├── systemd/                 # Unidades dos serviços
└── tests/                   # Testes locais dos scripts
```

## Documentação complementar

- [Preparação da VM e recuperação de rede](docs/vm.md)
- [Integração da aplicação C#](docs/application.md)
- [Validação no GitHub Actions](docs/ci.md)
- [Roteiro da demonstração](docs/video.md)
- [Rubrica e entrega](docs/delivery.md)
