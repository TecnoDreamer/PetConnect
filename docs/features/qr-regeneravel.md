# QR code regenerável (RF19, issue #29)

Status em 2026-10-27: implementado no app e na API, **sem merge e sem
deploy**. Desligado por padrão no app (`USE_API_QR`), então nada muda para
quem usa o app hoje até a API nova estar no ar e a flag ser ligada.

## Problema

O tutor não tinha como invalidar o QR code de um pet (coleira perdida,
etiqueta fotografada por estranhos, suspeita de uso indevido).

E não dava para resolver só no app:

- No modo Firestore (o padrão), o app **calcula** o id do QR a partir do id
  do documento do pet: `UUID.nameUUIDFromBytes("pet:" + id)`, o mesmo valor
  que a migração grava no Mongo (`docs/fixes/qr-public-pet-not-found.md`).
  É fixo: não existe "outro" QR para o mesmo pet.
- Quem resolve o QR é a API Spring (Render + MongoDB Atlas):
  `GET /api/v1/public/pets/{publicId}`, chamado pela página pública
  (`public/index.html`). O Firestore não participa.
- A migração Firestore → Mongo **apaga e recria** os pets importados a cada
  execução, com o mesmo id fixo. Uma troca feita só no Mongo seria desfeita
  na próxima migração.

## Decisão

A API é a dona do QR (ADR 0004). Regenerar é uma operação da API; o app
só guarda o resultado para exibir sem depender do servidor.

| Onde | O quê |
|---|---|
| Mongo `pets.publicId` | id atual do QR — o único que a página pública aceita |
| Mongo `pets.publicIdRotatedAt` / `publicIdRotations` | quando e quantas vezes o tutor regenerou (sem guardar ids antigos) |
| Firestore `Pets/{id}.qrPublicId` | cópia do id atual, gravada pelo app depois da troca; ausente = nunca regenerado |
| Firestore `Pets/{id}.qrRegeneradoEm` | `serverTimestamp` da última cópia |

O campo antigo `qrCodeId` do Firestore continua sendo lido e regravado (para
não perder o valor de documentos legados), mas não é mais usado no QR: a API
nunca reconheceu esse valor.

## Contrato da API

Todas autenticadas com o ID token do Firebase; pet de outro tutor (ou ainda
não migrado) responde 404, sem revelar se existe.

| Método e rota | Uso |
|---|---|
| `GET /api/v1/legacy-pets/{firestoreId}/qr` | QR atual de um pet do app em modo Firestore |
| `POST /api/v1/legacy-pets/{firestoreId}/qr/rotation` | regenera |
| `GET /api/v1/pets/{id}/qr` | QR atual (pets criados pela API) |
| `POST /api/v1/pets/{id}/qr/rotation` | regenera |

Corpo do `POST`: `{"expectedPublicId": "<QR que o app está mostrando>"}`.
Resposta: `{"publicId": "...", "rotatedAt": "..."}`.

| Resposta | Quando |
|---|---|
| 200 | trocado; o novo id é um UUID v4 aleatório |
| 400 | sem `expectedPublicId` |
| 401 | sem token válido |
| 404 | pet não existe, é de outro tutor, ou ainda não chegou ao Mongo |
| 409 | `expectedPublicId` não é mais o atual (trocado em outro aparelho, toque duplo) — nada muda |
| 429 | mais de 5 regenerações do mesmo pet em 24 h |

**Atomicidade:** a troca é um único `findAndModify` condicionado a
`_id` **e** `publicId == expectedPublicId`. Pedidos simultâneos geram um só
QR ativo; os outros recebem 409. O QR antigo para de funcionar no mesmo
instante (a página pública não tem cache: cada leitura vai ao Mongo).

**QR revogado:** responde 404 como qualquer id desconhecido. A página pública
já diz "O QR code pode ter sido desativado pelo tutor". Não guardamos os ids
antigos, então não dá para distinguir "revogado" de "inexistente" — e isso é
de propósito: confirmar que um id já pertenceu a um pet seria vazamento.

**Migração:** antes de apagar o import anterior, a migração lê os pets com
`publicIdRotatedAt` e devolve o id regenerado ao pet recriado. Pet nunca
regenerado continua com o id determinístico.

**Auditoria:** log `QR code do pet {_id} regenerado (Nª vez)`, sem nenhum
`publicId` (quem tem o id tem acesso à página pública) e sem dado do tutor.

## Fluxo no app

1. O tutor abre "QR Code do Pet". Em segundo plano o app chama
   `GET .../qr` e, se o id da API for diferente do salvo, atualiza o pet
   (corrige troca feita em outro aparelho). Isso também acorda o servidor
   gratuito, que pode levar até ~2 min na primeira chamada.
2. "Gerar novo QR code" abre uma confirmação: o QR atual deixa de funcionar
   na hora, inclusive em coleiras e etiquetas já impressas.
3. Confirmado, o app chama `POST .../qr/rotation` com o QR que está
   mostrando e grava `qrPublicId` no Firestore. O sheet troca o QR exibido.

| Situação | O que o tutor vê | QR exibido |
|---|---|---|
| Sucesso | "Novo QR code ativo. O anterior não funciona mais…" | o novo |
| 409 | "Este QR code já tinha sido trocado… Agora aparece o QR code atual." | o atual da API |
| 429 | "…muitos QR codes novos para este pet hoje. Tente novamente amanhã." | o mesmo |
| 404 | "Este pet ainda não está disponível no serviço do QR code…" | o mesmo |
| Sem resposta | "Não conseguimos confirmar com o servidor…" + **Verificar de novo** | o mesmo |
| API trocou, Firestore falhou | "O novo QR code foi criado, mas não conseguimos salvá-lo…" + **Verificar de novo** | o anterior até verificar |

"Sem resposta" pode acontecer com a API acordando (o app espera 15 s): o
servidor pode ter feito a troca mesmo assim. "Verificar de novo" busca o QR
atual e resolve.

Sem nenhuma flag de API, o sheet mostra o QR como antes, sem o botão.

## O que não muda

- A página pública mostra os mesmos dados de antes (nome, espécie, status,
  foto, telefone de contato). Nada de WhatsApp, localização ou dados médicos
  — isso depende da issue #35 (privacidade e contato público).
- Pet falecido pode ter o QR regenerado (o motivo — uso indevido — continua
  valendo); o QR em si não muda de comportamento.
- Pets criados no app depois da última migração **ainda não existem no
  Mongo**: o QR deles não abre a página pública e a regeneração responde
  404. Isso já era assim (`docs/fixes/qr-public-pet-not-found.md`, "Riscos")
  e não é resolvido aqui.

## Limites conhecidos

- O limite de 5/24 h fica em memória na API: reinício do servidor zera a
  contagem. Suficiente para uma instância; com mais de uma, precisa de
  contador compartilhado (mesma nota do `RateLimiter`).
- Reexecutar a migração ainda recria os pets com outro `_id` no Mongo; os
  avistamentos feitos pela página pública (`locations` com
  `source=PUBLIC_QR`) apontam para o `_id` antigo e ficam órfãos. Já era
  assim; registrado como pendência à parte.

## Testes

- API (`PetQrControllerTest`, 10 testes): QR original funciona antes; o novo
  funciona depois; o antigo responde 404 (leitura e avistamento); tutor B
  não consulta nem regenera o pet de A (nas duas rotas); 409 com QR
  desatualizado; 4 pedidos simultâneos → 1 sucesso e 3 conflitos, um só QR
  ativo; limite de 5 → 429 sem trocar; sem token → 401; pet não migrado →
  404; `expectedPublicId` obrigatório.
- Migração (`LegacyMigrationServiceTest`): reexecutar mantém o QR
  regenerado e o determinístico antigo não volta.
- App:
  - `api_pet_qr_repository_test.dart`: rotas, corpo e token; grava
    `qrPublicId`; 409 sincroniza; 404/429/500/sem rede mapeados sem mexer
    no pet; falha parcial (API trocou, Firestore não) recuperada por
    `sincronizar`; modo API não toca no Firestore.
  - `pet_qr_sheet_test.dart`: botão some sem API; confirmação obrigatória
    (cancelar não troca); QR exibido muda depois da troca; mensagens de
    cada falha; "Verificar de novo"; sem overflow em 360x800 com fonte 1.3
    nos três temas.
  - `pet_qr_code_test.dart`: `qrPublicId` tem prioridade, `qrCodeId`
    legado é ignorado, `toMap` não grava `qrPublicId`.
- Prova de mutação (feita e revertida): sem a condição
  `publicId == expectedPublicId`, os testes de 409 e de concorrência falham;
  sem a preservação na migração, o teste da migração falha; com o app
  gravando o campo errado no Firestore, 3 testes do repositório falham; com
  `qrPublicId` no `toMap`, o teste do modelo falha.

Não testado no aparelho: depende do deploy da API (abaixo).

## Como ligar (com aprovação)

1. Mesclar a PR da API (`AleksGustavo/PetConnect-API`) e publicar no Render.
   Conferir `GET /api/v1/legacy-pets/{id}/qr` com um token de teste.
2. Rodar o app com a API publicada:
   ```
   flutter run --dart-define=API_BASE_URL=https://petconnect-api-rxr9.onrender.com --dart-define=USE_API_QR=true
   ```
3. No aparelho: abrir o QR de um pet migrado, escanear (abre a página),
   regenerar, escanear o novo (abre) e o antigo (pet não encontrado).

## Rollback

- App: desligar `USE_API_QR` (build sem a flag) — o botão some e o QR volta
  a ser lido de `qrPublicId` se existir, ou do id determinístico. Se um pet
  já foi regenerado, **não** apagar `qrPublicId`: o QR determinístico já foi
  revogado na API.
- API: reverter a PR. Os campos novos no Mongo são ignorados pelo código
  antigo; os QRs regenerados continuam valendo até a próxima migração, que
  (com o código antigo) volta todos ao id determinístico — nesse caso, o
  `qrPublicId` salvo no app fica inválido e precisa ser removido.
