# Segurança — Memorial do Pet

Complementa `docs/seguranca.md` e `docs/features/memorial-pet.md`.

## Autorização

| Ação | Onde é garantida | Situação |
|---|---|---|
| Registrar falecimento / corrigir marcação | App: só o dono chega à tela (`PetSituacaoGuard`). Regras deployadas: o catch-all `/{document=**}` (`allow write` para logado) também casa `Pets/{id}` e anula a condição de dono. | ⛔ Servidor não garante até o deploy da Fase 1 |
| Ver memorial ou lista do Memorial | Consulta por `userId` + `PetSituacaoGuard` confere o dono | ✅ App. ⛔ Regras deployadas liberam leitura de `Pets` a qualquer logado |
| Criar vacina, consulta, histórico ou localização para pet falecido | Rotas bloqueadas pelo `PetSituacaoGuard` | ✅ App. ⛔ Servidor só após o deploy |
| Gravar evento de auditoria | Subcoleção sob o catch-all (`write` para logado) | ⛔ Servidor só após o deploy |
| Modo API | `PetService.ownedOr404` no backend | Memorial desligado no app (exposição pública) |

## Regras propostas (NÃO deployadas; dependem de aprovação)

Ficam em `firestore.rules`, com testes no emulador. Detalhes, limites e
plano de deploy em [`firestore-isolamento-por-dono.md`](firestore-isolamento-por-dono.md).
Em resumo, para o Memorial:

- Sem catch-all; só o dono lê e escreve o pet e as subcoleções.
- Pet `FALECIDO`: criar ou alterar vacina, consulta, histórico ou
  localização é negado; ler e apagar continua permitido.
- `eventosSituacao`: só criação pelo dono, na mesma escrita que muda a
  situação do pet e descrevendo essa mudança; nunca alterado nem apagado.

## Exposição pública

- O falecimento **não** aparece na página pública do QR no modo Firestore,
  porque a situação não é enviada à API.
- No modo API, o Memorial fica desligado porque
  `PublicPetSummaryResponse.status` exibiria "Falecido".
- O memorial em si é privado: não há link público.

## Auditoria

Evento por transição efetiva (`eventosSituacao`) com ator, estado
anterior e novo, motivo técnico, resultado, origem e horário do servidor.
Não grava data de falecimento, homenagem nem dados do tutor além do uid.
Repetições não geram evento.

## LGPD e retenção

- Dados do pet falecido continuam sob a mesma finalidade e base de
  tratamento (conta do tutor), sem exclusão automática.
- Planejamento de retenção, exportação, anonimização e exclusão futura:
  `docs/privacy/retencao-pets-falecidos.md`.
