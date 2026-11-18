# VM, rede e diagnóstico

Use Ubuntu Server **24.04 LTS** com systemd como PID 1. Crie snapshot antes do provisionamento e mantenha o console aberto. Use x86_64 para o SDK fixado desta integração. Para demonstração, NAT com encaminhamento da porta da aplicação ou rede host-only + uma interface NAT para instalar pacotes. Uma interface em bridge exige autorização da rede local. Os scripts gerenciam **uma interface** IPv4; caso precise de duas, estenda e valide o Netplan antes da entrega.

Antes de editar `infra.local`, consulte `ip -br link`, `ip -4 address`, `ip route` e `resolvectl status`. Em DHCP, a rede entrega IP/gateway/DNS; preencher DNS substitui DNS do DHCP. Para IP estático, obter endereço livre/CIDR, gateway e DNS reais da rede. O validador exige gateway na mesma sub-rede; não oferece configuração on-link ou IPv6. `HOSTNAME=alertasp` cria resolução local em `/etc/hosts`; não registra DNS público ou resolução em outros computadores. Use o IP da VM no cliente ou uma entrada hosts local autorizada.

A configuração de rede do instalador/cloud-init conflita com Netplan adicional. `00-adopt-network.sh --console-confirmed` arquiva e verifica os arquivos existentes em um diretório privado `/var/backups/alertasp-netplan.*`, retira-os de `/etc/netplan` e desativa geração de rede pelo cloud-init. A rede em memória permanece até `netplan apply`/reboot. Execute `01-infra.sh` imediatamente, sem reiniciar entre essas etapas. Para a primeira execução use uma VM dedicada; não transfira essa automação para redes gerenciadas.

`01-infra.sh` sem `--apply-network` gera/valida configuração mas não altera rede ativa. Com a opção, aplica. Alterar rede pode interromper SSH; por isso a execução completa é pelo console. Em caso de erro, pelo console, remova apenas `/etc/netplan/90-alertasp.yaml`, restaure os `.yaml/.yml` do backup correto e execute `sudo netplan generate && sudo netplan apply`. Se voltar a usar cloud-init para rede, remova somente o arquivo `99-alertasp-disable-network-config.cfg` criado por estes scripts. Não apague backups. Configurações de hostname/hosts podem ser revertidas pelo snapshot.

O provisionamento exige acesso aos mirrors Ubuntu (`archive.ubuntu.com`, `security.ubuntu.com` ou o mirror configurado), DNS e GitHub para o checkout, `builds.dotnet.microsoft.com` para o SDK e `api.nuget.org` (e destinos oficiais de download NuGet) para restore. Nunca desligue TLS/assinaturas para contornar falhas. Atualizações de kernel podem solicitar reboot: verifique `/var/run/reboot-required`, reinicie após terminar e teste o boot dos serviços.

## Diagnóstico

| Sintoma | Investigar |
|---|---|
| Sem rede | console, `ip -br a`, `ip route`, `sudo netplan get`, YAML e backup |
| DNS falha | `resolvectl status`, `resolvectl query archive.ubuntu.com`, DNS real da rede |
| 203/EXEC | `bin/start` executável, shebang Unix e runtime instalado |
| Serviço reinicia repetidamente | `sudo journalctl -u alertasp-app`, variáveis, permissões e dependências |
| HTTP local funciona, cliente não | bind 0.0.0.0, porta, NAT/encaminhamento, firewall da VM e host |
| Monitor sem amostras | `journalctl -u alertasp-monitor`, config válida, acesso a `/proc` e caminho do disco |
| Start limit atingido | corrigir causa, `systemctl reset-failed NOME`, `systemctl start NOME` |

Não use `systemctl show ... -p Environment`, `env` ou `cat app.env` em gravações. Logs da aplicação podem conter dados pessoais; revise antes de anexar.
