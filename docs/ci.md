# Validação automatizada em VM no GitHub

O workflow `Ubuntu VM validation` roda em push para `main` ou manualmente pela aba Actions. Primeiro executa testes locais e ShellCheck. Depois instala QEMU no runner Ubuntu, baixa uma imagem Ubuntu Server 24.04 oficial, verifica a assinatura GPG dos checksums e o SHA-256 da imagem, e inicia uma VM x86_64 descartável.

A rede alterada pelos provisionadores é apenas a da VM convidada. O runner mantém sua configuração. O harness cria uma chave SSH temporária, não usa senha nem segredo do aluno, e encaminha portas somente no loopback do runner. Ao terminar, encerra sua VM e remove o disco/chave temporários.

Dentro da VM, o teste configura IP estático, gateway e DNS a partir dos valores efetivamente fornecidos pela rede QEMU; provisiona aplicação e monitor duas vezes; cria registro sintético; testa SIGKILL/restart dos dois serviços; verifica os três alertas simulados; reinicia a VM e confirma serviços, journal persistente e preservação do registro SQLite. Também verifica HTTP do lado de fora da VM.

Saídas ficam no artifact `ubuntu-vm-evidence` e na branch `validation-results`, sob `runs/<run_id>/`. `STATUS.txt` identifica o commit testado, run e resultado; `raw/RESULT.txt` só aparece após o fluxo completo passar. Uma execução falha não é evidência de funcionamento. O relatório é gerado com GITHUB_TOKEN temporário e permissão contents:write; não é necessário cadastrar PAT.

Não substituir o vídeo por logs de CI. O aluno ainda precisa demonstrar/explicar o provisionamento no vídeo <=7 minutos e confirmar com o professor a aceitação da API. Se Actions estiver desabilitado, a conta sem minutos disponíveis ou a política impedir escrita da branch de evidências, habilitar/ajustar nas configurações do GitHub. Não fornecer tokens em chat.
