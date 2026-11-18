# Escopo das evidências

- `local-tests.txt`: 11 testes locais Bash/monitoramento, incluindo métricas reais e regressão do lock herdado por processos filhos.
- `csharp-tests.trx` e `csharp-validation.md`: 6 testes C# e 7 verificações HTTP do artefato publicado, com SQLite temporário e reinício manual.
- `ubuntu-vm/`: validação completa aprovada em VM Ubuntu 24.04 com systemd, a partir de imagem oficial verificada. Inclui dois provisionamentos, rede, aplicação, SIGKILL/recuperação, alertas, reboot, SQLite e journal persistentes. Consulte o README desse diretório para commit e run exatos.

A máquina de desenvolvimento na nuvem continua sendo Debian 13 com `tail` no PID 1. Os testes systemd foram executados na VM do GitHub Actions, não nesta máquina. As tentativas anteriores que falharam ficam preservadas na branch `validation-results`; não são contabilizadas como sucesso.

Código fonte C# preservado. A VM de CI é descartada ao terminar. Ainda faltam o aceite da API pelo professor e o vídeo. Não há gravação de vídeo produzida nesta sessão.
