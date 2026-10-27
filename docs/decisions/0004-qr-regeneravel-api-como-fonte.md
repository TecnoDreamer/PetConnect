# ADR 0004 — QR code regenerável com a API como fonte do QR

- **Status:** proposta (PRs `feat/qr-regeneravel` no app e na API, aguardando aceite)
- **Data:** 2026-10-27

## Contexto

O tutor precisa invalidar o QR code de um pet e receber um novo (RF19,
issue #29). Hoje o app em modo Firestore calcula o id do QR a partir do id
do documento (determinístico, igual ao da migração), a página pública
resolve esse id pela API Spring (Mongo Atlas) e a migração recria os pets do
Mongo a cada execução com o mesmo id fixo. Detalhes em
`docs/features/qr-regeneravel.md`.

## Decisão

1. **A API é a dona do QR.** Regenerar é `POST .../qr/rotation` na API, que
   troca `pets.publicId` por um UUID v4 aleatório. É ela que resolve o QR,
   então é o único lugar onde a troca vale na hora.
2. **Troca condicionada ao QR que o app mostra** (`expectedPublicId`), num
   único `findAndModify`: sem dois QRs ativos, sem troca dupla; quem chega
   depois recebe 409.
3. **Sem histórico de ids antigos.** QR revogado responde 404 igual a um id
   que nunca existiu.
4. **A migração preserva QRs regenerados** (`publicIdRotatedAt`).
5. **O app guarda uma cópia** (`Pets/{id}.qrPublicId`) para exibir o QR sem
   depender do servidor (que pode levar ~2 min para acordar) e sincroniza
   com a API ao abrir o QR. `Pet.toMap()` não grava o campo, então editar o
   perfil nunca volta o QR para um id revogado.
6. **Rotas por id do Firestore** (`/legacy-pets/{firestoreId}/qr`) para o
   app no modo padrão, além de `/pets/{id}/qr` para o modo API.
7. **Desligado por padrão** no app (`USE_API_QR`), até a API nova estar
   publicada.

## Alternativas descartadas

- **Trocar o id só no Firestore** e esperar a migração: o QR novo não
  funcionaria até a próxima migração e o antigo continuaria valendo — o
  oposto do pedido.
- **Página pública lendo do Firestore** (coleção pública com dados
  mínimos): cria um segundo caminho de resolução do QR, contra a direção
  da migração para a API, e exigiria leitura anônima nas regras.
- **App gera o novo id e manda para a API**: deixaria a imprevisibilidade
  do QR por conta do cliente; o servidor gerar é mais simples de garantir.
- **Guardar ids antigos para mostrar "QR revogado"**: confirmaria a quem
  tem um QR antigo que aquele pet existe.

## Consequências

- O app passa a depender da API para regenerar (não para mostrar o QR).
- Regeneração só funciona para pets que já estão no Mongo; pets criados
  depois da última migração respondem 404 até a próxima.
- Rollback da API exige cuidado com pets já regenerados (ver a seção
  Rollback do documento da feature).
