# Validação real da integração C#

Execução nesta sessão de desenvolvimento, em Debian 13 x86_64 (sem systemd no PID 1). SDK Microsoft .NET 10.0.100, SHA-512 verificado antes de extrair. Commit da aplicação: `cffd7a757982642824f7acba1ace1af8c4c0e18e`.

- `prepare-csharp.sh`: sucesso; build/teste Release e publish framework-dependent.
- Segunda execução do mesmo comando: SDK reutilizado, bundle validado por SHA-256 e reutilizado.
- `dotnet test`: 6 executados, 6 passaram, 0 falharam, 0 ignorados. Resultado original em `csharp-tests.trx`.
- `test-csharp-smoke.py`: 7 verificações passaram no artefato publicado: health, cadastro sintético, filtro, atualização, 404, validação 400 e persistência SQLite após reiniciar o processo.
- Nenhum arquivo versionado da aplicação C# foi alterado. bin/obj são saídas ignoradas pelo Git.

Não executados: apt/Netplan/hostname na VM, boot, reinício automático systemd, idempotência completa da VM, vídeo. Reinício manual no smoke test não é prova de recuperação automática.
