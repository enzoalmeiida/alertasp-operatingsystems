# Critérios, evidências e vídeo

Não atribuir nota de funcionamento a código não executado na VM. A tabela é uma avaliação de cobertura, não nota garantida.

| Critério | Peso | Evidência técnica obtida | Pendência de entrega |
|---|---:|---|---|
| Infra: rede, DNS, IP | 2 | VM limpa com Netplan estático aplicado, DNS/hostname e reexecução aprovados | Mostrar no vídeo |
| Aplicação | 2 | Build/testes C#, dependências, variáveis, serviço, HTTP e SQLite aprovados | Aceite de API isolada pelo professor |
| CPU/disco/memória e alertas | 2 | Amostras reais e três alertas simulados identificados, em logs da VM | Explicar limiares no vídeo |
| Monitor tolerante a falhas | 1 | SIGKILL, PID novo, NRestarts incrementado e amostra recuperada | Mostrar/explicar a recuperação |
| Auditoria/execução | 1 | Logs de execução, journal persistente e leitura do boot anterior aprovados | Mostrar no vídeo |
| Funcionamento completo | 2 | Dois provisionamentos, API, falhas, reboot e relato SQLite preservado aprovados | Vídeo <=7 min e aceite acadêmico da aplicação |

Os seis critérios têm implementação e evidência técnica, cobrindo os pesos 2+2+2+1+1+2. A nota é atribuída pelo professor; não equivale a garantia de 10/10. [Resultado completo da VM](../evidence/ubuntu-vm/README.md).

## Checklist final em VM limpa

- Registrar distribuição, recursos, snapshot inicial, commit dos scripts e commit da aplicação.
- Confirmar aceitação da aplicação pelo professor; Expo não equivale automaticamente à aplicação web.
- Preparar configurações reais e bundle; executar provisionamento completo, sem instalações manuais ocultas.
- Reexecutar os scripts; verificar sucesso sem usuários duplicados, arquivos corrompidos ou segredos sobrescritos.
- Validar endereço/gateway, resolução DNS e hostname. Acesso HTTP local e a partir do host.
- Executar um fluxo funcional da aplicação e persistência, se houver banco.
- Monitor real registra CPU/memória/disco. Simular 100/100/100 e registrar três ALERT com origem simulation.
- Rodar `04-failure-test.sh` para monitor e aplicação; salvar PIDs anterior/novo, reinícios e saúde recuperada.
- Reiniciar VM; verificar `is-enabled`, `is-active`, HTTP e journal preservado.
- Coletar `05-evidence.sh`, revisar/redigir dados e adicionar evidências ao GitHub.
- Gravar vídeo <=7 min, conferir áudio/legibilidade/link acessível e enviar o link conforme orientação da disciplina.

## Roteiro sugerido — 6min50s

| Tempo | Demonstração |
|---|---|
| 0:00–0:35 | AlertaSP, aplicação de outra disciplina e VM limpa |
| 0:35–1:10 | Scripts, configurações sem segredos, rede e limiares |
| 1:10–2:45 | Provisionamento automático no console, logs e resultado; acelerar espera se necessário e identificar cortes |
| 2:45–3:25 | IP/DNS/hostname e aplicação hospedada com operação funcional |
| 3:25–4:05 | Serviços, usuário, Restart, boot e permissões |
| 4:05–4:55 | Amostras reais e simulação identificada de três alertas |
| 4:55–5:50 | Falha controlada e recuperação: PID, NRestarts e HTTP/amostra |
| 5:50–6:30 | Segunda execução, reboot validado, logs persistentes |
| 6:30–6:50 | Repositório, evidências, resultado e limitações |

Não apresentar simulação de recurso como saturação real. Não afirmar que código foi validado apenas por mostrar arquivos de configuração. A gravação é um entregável pendente; nenhum vídeo foi produzido nesta sessão.

Roteiro com falas e comandos: [docs/video.md](video.md). A gravação continua pendente; esse roteiro não constitui vídeo entregue.
