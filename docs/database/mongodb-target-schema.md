# Schema alvo — MongoDB (via API Spring Boot)

> Etapa obrigatória 03. Modelo **proposto** para o novo banco primário. Nada aqui está implementado.
> Princípios: Flutter **nunca** acessa o Mongo direto — só via `/api/v1`. A API expõe **DTOs**, nunca documentos Mongo crus. Firebase Auth continua sendo a fonte de identidade (`firebaseUid`); o Mongo é a fonte de autorização e dados de domínio.

## Convenções globais

- **Nomes de coleção:** `snake_case` plural em inglês (`users`, `pets`, `vaccines`, `appointments`, `medical_records`, `locations`, `sharing_requests`, `sharing_consents`, `notifications`, `organizations`).
- **`_id`:** `ObjectId` gerado pelo Mongo. O Flutter **nunca** inventa id.
- **IDs de referência:** guardados como `ObjectId` (ex.: `pets.tutorId` → `users._id`). Nos DTOs da API, expostos como string hex.
- **IDs públicos:** campo `publicId` = `UUID v4` aleatório (não sequencial), com índice único, para tudo que aparece em URL pública (QR de pet).
- **Datas:** sempre `Date` (BSON) / ISO 8601 na API. **Nunca** `dd/MM/yyyy` no banco. O Flutter converte para exibição.
- **Timestamps:** toda collection tem `createdAt` e `updatedAt` (`Date`), preenchidos pela API (`@CreatedDate` / `@LastModifiedDate`).
- **Soft delete:** onde fizer sentido (`users`, `pets`), campo `deletedAt: Date | null` em vez de remoção física, para permitir rollback e auditoria durante a migração.
- **Enums:** persistidos como string maiúscula (`ACTIVE`, `LOST`, …).
- **Validação:** Bean Validation nos DTOs de entrada + JSON Schema validator no Mongo (`$jsonSchema`) como segunda barreira.

---

## `users`

Origem: `Usuarios` do Firestore. 1 doc por conta do Firebase Auth.

| Campo | Tipo | Obrig. | Notas |
|---|---|---|---|
| `_id` | ObjectId | sim | |
| `firebaseUid` | string | sim | **único**; chave de ligação com o Firebase Auth; vem do ID Token verificado |
| `email` | string | sim | único; espelha o Auth, atualizado no login |
| `firstName` | string | sim | ← `nome` |
| `lastName` | string | não | ← `sobrenome` (`''` → `null`) |
| `phone` | string | não | ← `telefone`, normalizado (só dígitos + DDI opcional) |
| `birthDate` | Date | não | ← `dataNascimento` parseado; inválido/vazio → `null` + flag em relatório |
| `gender` | string enum | não | `MALE` / `FEMALE` / `OTHER` / `UNDISCLOSED` ← `genero` mapeado |
| `photoUrl` | string | não | ← `foto` (Cloudinary) |
| `legacyUsuarioId` | string | não | ← `usuarioID` preservado até confirmação de descarte (ambiguidade B) |
| `roles` | array\<string\> | sim | default `["TUTOR"]`; base para autorização server-side |
| `createdAt` / `updatedAt` | Date | sim | |
| `deletedAt` | Date | não | soft delete (RF09) |

Índices: `{ firebaseUid: 1 }` único · `{ email: 1 }` único · `{ deletedAt: 1 }`.

---

## `pets`

Origem: `Pets` do Firestore.

| Campo | Tipo | Obrig. | Notas |
|---|---|---|---|
| `_id` | ObjectId | sim | |
| `publicId` | string (UUID v4) | sim | **único**; usado no QR → `https://<dominio>/p/{publicId}`. Pets migrados usam o UUID determinístico de `"pet:" + legacyFirestoreId` até o tutor regenerar |
| `publicIdRotatedAt` | Date | não | última regeneração do QR (RF19); a migração preserva o `publicId` de quem tem este campo |
| `publicIdRotations` | int | não | quantas regenerações; ids antigos não são guardados |
| `tutorId` | ObjectId | sim | → `users._id` ← resolvido a partir de `userId` (firebaseUid) |
| `name` | string | sim | ← `nome` |
| `species` | string enum | sim | `DOG` / `CAT` / `OTHER` ← `especie` |
| `breed` | string | não | ← `raca` |
| `color` | string | não | ← `cor` |
| `gender` | string enum | não | `MALE` / `FEMALE` / `UNKNOWN` ← `genero` |
| `size` | string enum | não | `SMALL` / `MEDIUM` / `LARGE` ← `porte` |
| `weightKg` | number (double) | não | ← `peso` — extrai número de `"12kg"`; unidade descartada (sempre kg) |
| `birthDate` | Date | não | ← `dataNascimento` |
| `status` | string enum | sim | `ACTIVE` / `LOST` / `FOUND` / `DECEASED` / `ARCHIVED`; default `ACTIVE`. **Novo** — não existe no Firestore |
| `vaccinatedFlag` | bool | não | ← `vacinado` (resumo informado pelo tutor; não é derivado da carteira) |
| `publicContactPhone` | string | não | ← `telefone` (contato exibido na página pública do QR) |
| `photoUrl` | string | não | ← `foto` |
| `legacyQrCodeId` | string | não | ← `qrCodeId` (histórico; QR novo usa `publicId`) |
| `legacyDono` | string | não | ← `dono` se não-nulo e ≠ `userId` (senão descartar) — ambiguidade C |
| `createdAt` / `updatedAt` | Date | sim | |
| `deletedAt` | Date | não | |

Índices: `{ publicId: 1 }` único · `{ tutorId: 1, deletedAt: 1 }` · `{ status: 1 }`.

Relacionamento: **referência** (não embed) para vacinas/consultas/histórico/localizações — coleções filhas separadas, porque crescem sem limite e são consultadas por conta própria.

---

## `vaccines`

Origem: subcoleção `Pets/{petId}/vacinas`.

| Campo | Tipo | Obrig. | Notas |
|---|---|---|---|
| `_id` | ObjectId | sim | |
| `petId` | ObjectId | sim | → `pets._id` |
| `name` | string | sim | ← `nome` |
| `appliedAt` | Date | sim | ← `dataAplicacao` |
| `nextDoseAt` | Date | não | ← `proximaDose`; alimenta alerta (regra fica na API e/ou no app) |
| `veterinarian` | string | não | ← `veterinario` |
| `notes` | string | não | ← `observacoes` |
| `manufacturer` / `batch` / `dose` / `clinic` / `proofUrl` | string | não | **novos** campos do modelo-alvo; nulos na migração inicial |
| `createdAt` / `updatedAt` | Date | sim | |

Índices: `{ petId: 1, appliedAt: -1 }` · `{ petId: 1, nextDoseAt: 1 }`.

---

## `appointments`

Origem: subcoleção `Pets/{petId}/consultas`.

| Campo | Tipo | Obrig. | Notas |
|---|---|---|---|
| `_id` | ObjectId | sim | |
| `petId` | ObjectId | sim | → `pets._id` |
| `scheduledAt` | Date | sim | ← `data` + `horario` combinados num único instante (se `horario` nulo, 00:00 local) |
| `veterinarian` | string | sim | ← `veterinario` |
| `reason` | string | sim | ← `motivo` |
| `status` | string enum | sim | ver mapeamento abaixo |
| `requestedBy` / `resolvedBy` | ObjectId | não | preparação p/ fluxo clínica↔tutor (futuro) |
| `createdAt` / `updatedAt` | Date | sim | |

Mapeamento de status (Firestore → alvo):

| Firestore | Alvo |
|---|---|
| `agendada` | `CONFIRMED` |
| `realizada` | `COMPLETED` |
| `cancelada` | `CANCELLED` |

Enum-alvo completo (para uso futuro, não gerado pela migração): `REQUESTED`, `PENDING`, `CONFIRMED`, `COMPLETED`, `CANCELLATION_REQUESTED`, `CANCELLED`, `REJECTED`.

Índices: `{ petId: 1, scheduledAt: -1 }` · `{ status: 1 }`.

---

## `medical_records`

Origem: subcoleção `Pets/{petId}/historicoMedico`.

| Campo | Tipo | Obrig. | Notas |
|---|---|---|---|
| `_id` | ObjectId | sim | (novo ObjectId; id antigo do client guardado em `legacyId`) |
| `legacyId` | string | não | id gerado no client no Firestore |
| `petId` | ObjectId | sim | → `pets._id` |
| `recordedAt` | Date | sim | ← `data` |
| `description` | string | sim | ← `descricao` |
| `veterinarian` | string | não | ← `veterinario` |
| `attachments` | array\<string\> (URLs) | não | ← `anexos` (Cloudinary) |
| `origin` | string enum | sim | `TUTOR` / `CLINIC` / `VETERINARIAN` / `IMPORT`; migração seta `TUTOR`. **Novo** |
| `createdAt` / `updatedAt` | Date | sim | |

Índices: `{ petId: 1, recordedAt: -1 }`.

---

## `locations`

Origem: **coleção raiz `Localizacoes`** (95 docs reais com GPS — decisão D revista, migrar).
A subcoleção `Pets/{petId}/localizacoes` do app novo está vazia; quando passar a
gravar, escreve nesta mesma collection.

| Campo | Tipo | Obrig. | Notas |
|---|---|---|---|
| `_id` | ObjectId | sim | |
| `petId` | ObjectId \| null | não | → `pets._id`; **null** para os 30 registros cujo pet foi apagado |
| `legacyPetId` | string | não | `Localizacoes.petId` cru (preserva o vínculo mesmo órfão) |
| `legacyPetName` | string | não | ← `nomePet` (denormalizado no legado) |
| `legacyTutorName` | string | não | ← `nomeTutor` |
| `reportedAt` | Date | sim | ← `timestamp` (já ISO) / futuro: `data` |
| `latitude` | number | não | ← `latitude` (presente em 100% do legado) |
| `longitude` | number | não | ← `longitude` |
| `description` | string | não | vazio no legado; texto livre no app novo (`descricao`) |
| `reporterContact` | string | não | ← `telefone` (legado) / `contatoReportante` (app novo) |
| `source` | string enum | sim | `TUTOR` / `PUBLIC_QR`; migração seta `PUBLIC_QR` (cada registro legado = 1 scan do QR) |
| `legacyImport` | bool | não | `true` nos migrados |
| `migrationWarnings` | array\<string\> | não | ex.: `["orphan-pet","foreign-coordinate","duplicate-coordinate"]` |
| `createdAt` / `updatedAt` | Date | sim | |

Índices: `{ petId: 1, reportedAt: -1 }` · `{ legacyPetId: 1 }`.

---

## Coleções futuras (arquitetura preparada, **não** implementar agora)

Apenas registradas para o modelo não precisar de quebra estrutural depois (spec: integração ERP/SaaS).

- **`organizations`** — clínicas/ONGs: `name`, `type` (`CLINIC`/`NGO`/`PETSHOP`), `document` (CNPJ), `contact`, membros.
- **`sharing_requests`** — organização pede acesso ao pet de um tutor: `petId`, `organizationId`, `requestedBy`, `scope`, `status`.
- **`sharing_consents`** — consentimento do tutor: `petId`, `organizationId`, `grantedBy`, `scope`, `expiresAt`, `revokedAt`.
- **`notifications`** — fila de avisos (vacina vencendo, consulta próxima, avistamento): `userId`, `type`, `payload`, `readAt`.
- **`pet_photos`** — galeria de fotos (hoje só no Firestore, `Pets/{petId}/fotos`; ver `docs/features/galeria-fotos-pet.md`): `petId`, `tutorId`, `url`, `cloudinaryPublicId`, `width`, `height`, `caption`, `createdAt`; índice `{petId: 1, createdAt: -1, _id: -1}`. Curtidas e comentários, se vierem, ficam em coleções próprias apontando para a foto.

Nenhuma dessas é criada, escrita ou exposta pela API na migração inicial.

---

## Coleções técnicas da migração

- **`migration_audit`** — 1 doc por documento migrado: `{ sourceCollection, sourcePath, targetCollection, targetId, migratedAt, warnings: [...], rawSnapshot }`. Permite rollback e relatório de qualidade (etapa 50).
- **`migration_state`** — controle de fases: `{ phase, status, startedAt, finishedAt, counts }`.

---

## Diferenças estruturais em relação ao Firestore (resumo)

| Tema | Firestore hoje | MongoDB alvo |
|---|---|---|
| Hierarquia | subcoleções aninhadas em `Pets` | coleções irmãs com `petId` referência |
| Datas | string `dd/MM/yyyy` | `Date` / ISO 8601 |
| ID de usuário | `docId` (uid) + `usuarioID` (uuid) | `firebaseUid` único + `_id` interno; `legacyUsuarioId` preservado |
| ID público de pet | `qrCodeId` opcional / doc id | `publicId` UUID obrigatório e único |
| Status do pet | só `vacinado: bool` | enum `status` + `vaccinatedFlag` |
| Status de consulta | 3 estados | enum de 7 estados (migração usa 3) |
| Origem do histórico | inexistente | enum `origin` |
| Timestamps | nenhum | `createdAt` / `updatedAt` em tudo |
| Exclusão | física, cascata manual incompleta | soft delete + cascata na API |
| Autorização | Firestore Rules (desconhecidas) | Spring Security + `roles` + checagem de posse por `tutorId` |
| Peso | string `"12kg"` | `weightKg` numérico |
