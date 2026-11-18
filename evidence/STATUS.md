# Escopo das evidências

`local-tests.txt` registra a suíte Bash/monitoramento executada na máquina Debian 13 da nuvem. Simulações são explicitamente identificadas e a última amostra usa `/proc` e `df` reais. `csharp-tests.trx` e `csharp-validation.md` registram testes e validação da API real publicada.

A aplicação C# foi identificada, compilada, publicada e exercitada por HTTP com SQLite temporário. Persistência após reinício manual comprovada. Não houve alterações no código fonte da API.

Não executados nesta máquina: apt/provisionamento privilegiado, alterações de rede, deploy em systemd, testes de boot ou recuperação automática systemd. PID 1 é `tail`. A tentativa anterior de `systemd-analyze verify --man=no` não foi concluída porque `/run/systemd` é somente leitura. Portanto não há alegação de validação das units por esse comando.

Não existe vídeo nesta entrega parcial. Execute o checklist `docs/delivery.md` na VM Ubuntu para produzir as evidências finais. Aceitação de API isolada pelo professor segue pendente.
