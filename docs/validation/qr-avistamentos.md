# Roteiro de validação: acessos e avistamentos do QR (issue #37)

Use um pet de teste e dados fictícios. Não use o telefone real de ninguém
no relato.

**Pré-requisitos:**
- API com a fase 3 no Render;
- página publicada no Hosting;
- APK com `USE_API_QR=true` e `API_BASE_URL` do Render.

## Página pública (celular de outra pessoa ou aba anônima)

A localização é pedida assim que a página abre (2026-11-04).

| # | Passo | Esperado |
|---|---|---|
| 1 | Escanear o QR do pet | O pet aparece e o navegador pergunta se pode usar a localização, sem nenhum toque na página; o texto ao lado explica a finalidade |
| 2 | **Negar** | "Você não permitiu a localização…" e o botão "Tentar enviar a localização"; nada é enviado além do acesso |
| 3 | Tocar em "Avisar o tutor" sem escrever nada | "Conte onde viu o pet." |
| 4 | Liberar a localização do site no navegador, recarregar e **permitir** | "Localização enviada ao tutor, com precisão de cerca de X m", sem tocar em enviar |
| 5 | Tocar em "Conferir no mapa" | Abre o mapa no ponto obtido |
| 6 | Escrever um texto e tocar em "Avisar o tutor" | "Obrigado! Seu relato foi registrado." e o formulário trava |
| 7 | GPS desligado e recarregar | Mensagem de localização indisponível e "Tentar enviar a localização"; relato em texto continua |

## App do tutor

| # | Passo | Esperado |
|---|---|---|
| 8 | Abrir o pet > Localização | Cartão "Página do QR aberta N vezes…" com o aviso de que acesso não é avistamento |
| 9 | Conferir o envio do passo 4 | "Local onde o QR Code foi escaneado", data e hora certas, precisão e "Abrir no mapa" |
| 10 | Conferir o relato do passo 6 | "Avistamento pelo QR Code", com o texto, a precisão e "Abrir no mapa" |
| 11 | Tocar em "Abrir no mapa" | Abre o app de mapas no ponto |
| 12 | Relato só com texto (passo 2 sem permitir) | "Sem localização: relato em texto, não verificado", sem botão de mapa |
| 13 | Puxar para baixo | Atualiza; novo relato aparece |
| 14 | Modo avião e puxar para baixo | Registros do tutor continuam; aviso de falha do QR com "Tentar de novo" |
| 15 | Entrar com outro tutor | O pet não aparece; os relatos dele não aparecem |

## Resultados

| Data | Aparelho / navegador | Passos | Resultado | Quem testou |
|---|---|---|---|---|
| 2026-11-04 | Navegador do painel, API falsa local, GPS simulado | 1, 2, 3, 4, 6 | Passou: acesso e ponto enviados sozinhos; negado não envia ponto | Claude (simulado) |
