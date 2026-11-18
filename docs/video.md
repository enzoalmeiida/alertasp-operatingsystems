# Gravação da demonstração — até 6min50s

Grave a tela da sua VM Ubuntu 24.04 x86_64 e narre com suas palavras. O roteiro abaixo usa comandos reais. Não mostre `.env`, chaves SSH ou tokens. A gravação deve mostrar execução, não apenas ler scripts ou abrir o resultado do CI. Se acelerar downloads/esperas, identifique o trecho acelerado. A API isolada ainda depende da confirmação do professor.

## Antes da gravação

- Criar snapshot da VM limpa; conferir console, conectividade e dados reais da interface.
- Ter o repositório de OS clonado e `config/infra.local`/`config/monitor.local` preenchidos. Preparar esses arquivos não significa já provisionar a aplicação.
- Ajustar fonte do terminal para leitura, ocultar notificações e testar áudio.
- Usar somente registros `SyntheticDemo`. Guardar a gravação fora do Git; publicar link acessível ao professor.

## 0:00–0:35 — contexto e VM inicial

Fala sugerida: “O AlertaSP hospeda uma API da disciplina de C# que registra relatos de alagamento. Vou demonstrar o provisionamento Linux automatizado, monitoramento e recuperação. Os registros são sintéticos, sem informação oficial em tempo real.”

```bash
cat /etc/os-release
ps -p 1 -o comm=
git rev-parse --short HEAD
ip -br address
```

## 0:35–2:45 — provisionamento no console

Mostre configuração da interface, escolha DHCP/estático e limiares 85/85/90. Explique que os endereços são da rede real da VM e que não há domínio público inventado.

```bash
cat config/infra.local config/monitor.local
sudo ./scripts/00-adopt-network.sh --console-confirmed
sudo ./scripts/provision-csharp.sh config/infra.local config/monitor.local --apply-network
```

Fala sugerida: “Os scripts atualizam o sistema, configuram rede, DNS e hostname; verificam o SDK; compilam e testam como usuário sem privilégios; instalam a API e o monitor. As etapas registram início, resultado e erros.”

## 2:45–3:25 — API hospedada e persistência

```bash
curl -fsS http://127.0.0.1:8080/health
curl -fsS -X POST http://127.0.0.1:8080/api/reports \
  -H 'Content-Type: application/json' \
  -d '{"roadName":"Via de demonstracao OS","district":"Teste OS","latitude":-23.55,"longitude":-46.63,"observedAt":"2026-01-15T12:00:00Z","source":"SyntheticDemo"}'
curl -fsS 'http://127.0.0.1:8080/api/reports?district=Teste%20OS'
```

Mostre a mesma consulta pelo IP/porta encaminhada a partir do host da VM. Se optar por Swagger, configure Development apenas na rede de laboratório conforme `docs/application.md`; não mostre arquivos que contenham segredos. Explique que SQLite fica em `/var/lib/alertasp`, separado do deploy.

## 3:25–4:05 — administração e systemd

```bash
systemctl is-enabled alertasp-app alertasp-monitor
systemctl is-active alertasp-app alertasp-monitor
systemctl show alertasp-app -p User -p MainPID -p Restart -p NRestarts
systemctl show alertasp-monitor -p DynamicUser -p MainPID -p Restart -p NRestarts
```

Fala sugerida: “A API roda sem root e reinicia em falha. O monitor usa usuário dinâmico e Restart=always. Há atraso e limite de reinícios para evitar ciclos descontrolados. Network-online ordena a inicialização, mas não garante a saúde de dependências externas.”

## 4:05–4:55 — métricas e três alertas

```bash
sudo journalctl -u alertasp-monitor -n 9 --no-pager -o cat
sudo /usr/local/lib/alertasp/monitor.sh --simulate 100 100 100 | systemd-cat -t alertasp-simulation
journalctl -t alertasp-simulation -n 3 --no-pager -o cat
```

Explique CPU por diferença de `/proc/stat`, memória via `MemAvailable` e disco via `df`. Diga explicitamente: “As primeiras amostras são reais. Estes três alertas são simulados e identificados, para não danificar a VM consumindo recursos.”

## 4:55–5:50 — falha e recuperação

```bash
sudo ./scripts/04-failure-test.sh alertasp-monitor
sudo ./scripts/04-failure-test.sh alertasp-app
```

Mostre PID anterior/novo, aumento de NRestarts e saúde recuperada. Explique que SIGKILL simula uma falha; `systemctl stop` é parada administrativa e não serve para demonstrar Restart.

## 5:50–6:30 — reexecução e reboot

```bash
sudo ./scripts/provision-csharp.sh config/infra.local config/monitor.local --apply-network
sudo reboot
# Depois de reconectar:
systemctl is-active alertasp-app alertasp-monitor
curl -fsS 'http://127.0.0.1:8080/api/reports?district=Teste%20OS'
sudo journalctl -u alertasp-monitor -b -1 -n 3 --no-pager
```

Pode acelerar o intervalo de espera identificado. Mostre que os mesmos relatos continuam disponíveis e logs anteriores persistem.

## 6:30–6:50 — evidências e fechamento

```bash
sudo ./scripts/05-evidence.sh /tmp/alertasp-evidencia-video.txt
sudo tail -8 /var/log/alertasp/provision.log
```

Mostre o repositório, o resultado do workflow correspondente ao commit e a documentação. Diga as limitações reais: API sem autenticação, rede de laboratório e dados sintéticos. Pare a gravação antes de 7 minutos; confira áudio, legibilidade e acesso ao link antes de entregar.
