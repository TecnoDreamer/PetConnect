# Roteiro de validação: avisos do QR por push (issue #36)

Use um pet de teste. Precisa de dois aparelhos (ou um aparelho e um
computador): o do tutor, com o app, e outro para abrir a página do QR.

**Pré-requisitos:**
- API com as fases 3 e 4 no Render;
- página publicada;
- APK com `USE_API_QR=true` e `API_BASE_URL` do Render.

| # | Passo | Esperado |
|---|---|---|
| 1 | Instalar o APK, entrar na conta | Android 13 ou mais novo pede permissão de notificação uma vez |
| 2 | Permitir | Nada visível; o aparelho fica registrado |
| 3 | Pet > Configurações > Compartilhamento via QR Code | Seção "Avisos no celular" com os dois avisos ligados |
| 4 | Fechar o app (voltar para a tela inicial) e abrir a página do QR no outro aparelho | Notificação "O QR Code de [pet] foi acessado" em alguns segundos, com a pata como ícone |
| 5 | Recarregar a página 3 vezes | Nenhuma notificação nova (limite de 15 minutos) |
| 6 | Enviar um relato com localização pela página | Notificação "Novo avistamento de [pet]" |
| 7 | Tocar na notificação | App abre direto (sessão guardada) e vai para a aba Localização do pet com o relato |
| 8 | Com o app aberto na Home, enviar outro relato | Faixa no rodapé com "Ver"; tocar abre a aba Localização |
| 9 | Desligar "Quando a página do QR for aberta" e esperar 15 min; abrir a página | Sem notificação de acesso |
| 10 | Enviar relato | Notificação de avistamento continua |
| 11 | Configurações do Android > PetConnect > Notificações: desativar e voltar à tela do passo 3 | Aviso de notificações desativadas |
| 12 | Sair da conta e enviar outro relato | Nenhuma notificação neste aparelho |
| 13 | Tela bloqueada com "ocultar conteúdo sensível" | Notificação sem o texto, conforme o Android |

## Resultados

| Data | Aparelho / Android | Passos | Resultado | Quem testou |
|---|---|---|---|---|
| — | — | — | Pendente | — |
