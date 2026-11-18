# VM Ubuntu: validação completa aprovada

Execução: [GitHub Actions 44311927366](https://github.com/enzoalmeiida/alertasp-operatingsystems/actions/runs/44311927366).

Código testado: `60a54af7125916226b6119ce37edf1b9c2408984`. Aplicação C#: `cffd7a757982642824f7acba1ace1af8c4c0e18e`. As atualizações posteriores de documentação não alteram os scripts, units ou testes dessa execução.

**Resultado real: success / PASS full-ubuntu-vm-validation.**

| Verificação | Resultado |
|---|---|
| Ubuntu 24.04 em VM QEMU isolada, imagem verificada por assinatura e SHA-256 | Passou |
| IP estático, gateway, DNS e hostname configurados por scripts | Passou |
| Build e 6 testes C# executados na VM, deploy e HTTP | Passou |
| Provisionamento completo repetido na mesma VM | Passou |
| Cadastro de relato sintético | Passou |
| Monitor real de CPU/memória/disco e três alertas simulados identificados | Passou |
| SIGKILL do monitor: novo PID 11318, NRestarts=1 e nova amostra | Passou |
| SIGKILL da API: novo PID 11386, NRestarts=1 e HTTP recuperado | Passou |
| Reboot real, com mudança do boot ID do kernel | Passou |
| API e monitor ativos/habilitados após reboot | Passou |
| Mesmo relato preservado no SQLite após reexecução, falhas e reboot | Passou |
| Journal do boot anterior disponível após reboot | Passou |
| HTTP da API acessível pelo host via encaminhamento de porta | Passou |

Boot ID antes: `28b14e00-8659-4452-8770-a3f3070014fd`; depois: `f07c669c-db3b-46c2-af20-014795f81f0a`.

Os arquivos de texto deste diretório são cópias sem edição do relatório gerado pelo workflow. `SHA256SUMS` permite conferir sua integridade. [Relatório completo, incluindo console da VM e log do host](https://github.com/enzoalmeiida/alertasp-operatingsystems/tree/validation-results/runs/44311927366). O artifact do Actions também contém as saídas.

A VM de CI é descartável e foi encerrada após a validação; não é um servidor de produção mantido ligado. Os endereços/PIDs/horários são daquela execução. Os alertas com `source=simulation` não representam saturação real dos recursos. Nenhuma etapa foi apresentada como aprovada apenas por existir código.

Pendências de entrega: confirmação do professor sobre API isolada e gravação/publicação do vídeo de até 7 minutos. Uma execução de CI aprovada não substitui esses entregáveis nem garante a nota.
