# Roteiro de validação: acessos e avistamentos do QR (issue #37)

Use um pet de teste e dados fictícios. Não use o telefone real de ninguém
no relato.

**Pré-requisitos:**
- API com a fase 3 no Render;
- página publicada no Hosting;
- APK com `USE_API_QR=true` e `API_BASE_URL` do Render.

## Página pública (celular de outra pessoa ou aba anônima)

| # | Passo | Esperado |
|---|---|---|
| 1 | Escanear o QR do pet | Página abre e **não** pede localização sozinha |
| 2 | Tocar em "Avisar o tutor" sem escrever nada | "Conte onde viu o pet ou compartilhe a localização." |
| 3 | Tocar em "Compartilhar local onde vi o pet" e **negar** | "Você não permitiu a localização…"; o relato em texto continua possível |
| 4 | Recarregar, tocar de novo e **permitir** | "Localização pronta para enviar, com precisão de cerca de X m" e o botão vira "Enviar relato com a localização" |
| 5 | Tocar em "Conferir no mapa" | Abre o mapa no ponto obtido |
| 6 | Tocar em "Não enviar a localização" | Volta o botão de compartilhar; envio sem coordenada |
| 7 | Compartilhar de novo, escrever um texto e enviar | "Obrigado! Seu relato foi registrado." e o formulário trava |
| 8 | GPS desligado | Mensagem de localização indisponível; relato em texto continua |

## App do tutor

| # | Passo | Esperado |
|---|---|---|
| 9 | Abrir o pet > Localização | Cartão "Página do QR aberta N vezes…" com o aviso de que acesso não é avistamento |
| 10 | Conferir o relato do passo 7 | "Avistamento pelo QR Code", data e hora certas, precisão, texto e "Abrir no mapa" |
| 11 | Tocar em "Abrir no mapa" | Abre o app de mapas no ponto do relato |
| 12 | Relato só com texto | "Sem localização: relato em texto, não verificado", sem botão de mapa |
| 13 | Puxar para baixo | Atualiza; novo relato aparece |
| 14 | Modo avião e puxar para baixo | Registros do tutor continuam; aviso de falha do QR com "Tentar de novo" |
| 15 | Entrar com outro tutor | O pet não aparece; os relatos dele não aparecem |

## Resultados

| Data | Aparelho / navegador | Passos | Resultado | Quem testou |
|---|---|---|---|---|
| — | — | — | Pendente | — |
