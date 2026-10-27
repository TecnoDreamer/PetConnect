# Schema atual — Cloud Firestore (`pet-connect-c53f1`)

> Etapa obrigatória 02. Levantado a partir do código **e do export real** `firestore_backup.json` (2026-09-10).
> 📊 Volumes/valores reais e problemas de dados: ver [`firestore-data-report.md`](firestore-data-report.md).
> ⚠️ **Correção pós-export:** as subcoleções de `Pets` (`vacinas`, `historicoMedico`, `consultas`, `localizacoes`) **não existem no Firestore** — zero documentos. Foram desenhadas no app Feature-First atual mas nunca populadas em produção. Os dados reais (18 usuários, 24 pets, 95 avistamentos) são de uma **versão anterior** do app. A coleção raiz `Localizacoes` **tem dados reais com GPS** e será migrada.

Legenda de origem: **base** = já existia antes deste ciclo de desenvolvimento · **app** = criado/escrito pelo app Flutter atual.

---

## Coleção `Usuarios`

- **Doc ID:** `firebaseUid` (o mesmo UID do Firebase Auth). Escrito em `signUp` logo após `createUserWithEmailAndPassword`.
- **Repositório:** `FirebaseUsuarioRepository` (`watchUsuario`, `updateUsuario`, `deleteAccount`).
- **Telas:** cadastro, home (saudação "Olá, {nome}"), configurações, editar-perfil.

| Campo | Tipo | Obrigatório | Referência | Origem | Observações |
|---|---|---|---|---|---|
| *(doc id)* | string | sim | = Auth UID | app | chave canônica proposta: `firebaseUid` |
| `usuarioID` | string (uuid) | ? | — | base | 2º identificador, **uso não confirmado**; nunca lido como FK no código atual |
| `nome` | string | sim | — | base | primeiro nome / nome informado no cadastro |
| `sobrenome` | string | não (default `''`) | — | app | adicionado neste ciclo; docs antigos podem não ter |
| `email` | string | sim | espelha Auth | base | |
| `telefone` | string | não | — | base | livre, sem máscara persistida |
| `dataNascimento` | string `dd/MM/yyyy` | não (default `''`) | — | base | **não** é Timestamp; pode vir vazio |
| `genero` | string | não | — | base | valores livres ('Masculino'/'Feminino'/'Outro'/…) |
| `foto` | string (URL) \| null | não | Cloudinary | app | `secure_url` do Cloudinary; antes era Firebase Storage |

**Escritas:** `signUp` grava `{nome, sobrenome:'', email, telefone, dataNascimento, genero:'', foto:null, usuarioID?}`. `updateUsuario` faz `update` parcial de `{nome, sobrenome, telefone, dataNascimento, genero, foto?}`.

---

## Coleção `Pets`

- **Doc ID:** auto (`collection('Pets').add(...)`).
- **Repositório:** `FirebasePetRepository` — `watchPets` filtra `where('userId', isEqualTo: uid)`.
- **Telas:** home (lista), pet_detail, pet_form.

| Campo | Tipo | Obrigatório | Referência | Origem | Observações |
|---|---|---|---|---|---|
| *(doc id)* | string (auto) | sim | — | app | proposta: `petId` |
| `userId` | string | sim | → `Usuarios` (doc id) | base | dono do pet; usado no filtro da lista |
| `nome` | string | sim | — | base | |
| `especie` | string | sim | — | base | livre ('Cachorro'/'Gato'/…) |
| `raca` | string | não | — | base | |
| `cor` | string | não | — | base | |
| `genero` | string | não | — | base | |
| `porte` | string | não | — | base | ('Pequeno'/'Médio'/'Grande') |
| `peso` | string | não | — | base | ex.: `"12kg"` — número + unidade juntos |
| `dataNascimento` | string `dd/MM/yyyy` | não (pode `''`) | — | base | |
| `vacinado` | bool | não (default `false`) | — | app | adicionado neste ciclo |
| `dono` | string \| null | não | ? | base | **redundante com `userId`**, observado `null`; propósito não confirmado |
| `telefone` | string \| null | não | — | base | contato público de fallback no QR |
| `foto` | string (URL) \| null | não | Cloudinary | app | |
| `qrCodeId` | string \| null | não | — | app | legado do app antigo; preservado, mas **não** usado no QR (a API nunca reconheceu) |
| `qrPublicId` | string | não | — | app (2026-10) | cópia do `publicId` atual do QR depois que o tutor o regenera (RF19); ausente = QR determinístico. Só `PetQrRepository` grava. Ver `docs/features/qr-regeneravel.md` |
| `qrRegeneradoEm` | timestamp | não | — | app (2026-10) | `serverTimestamp` da última cópia de `qrPublicId` |

**Sem** `status`, `publicId`, `createdAt`, `updatedAt`, `especie/porte` como enum.

---

> ⚠️ **As 4 subcoleções abaixo têm ZERO documentos no Firestore real.** O schema
> aqui é o que o código do app *escreveria*, não o que existe. Na migração elas
> nascem vazias no MongoDB — não há dado a converter.

### Subcoleção `Pets/{petId}/vacinas` — *vazia em produção*

- **Doc ID:** auto (`.add`). **Repo:** `FirebaseVacinaRepository`.

| Campo | Tipo | Obrigatório | Origem | Observações |
|---|---|---|---|---|
| *(doc id)* | string (auto) | sim | app | |
| `nome` | string | sim | app | |
| `dataAplicacao` | string `dd/MM/yyyy` | sim | app | |
| `proximaDose` | string `dd/MM/yyyy` \| null | não | app | alimenta o alerta (janela 30 dias) |
| `veterinario` | string \| null | não | app | |
| `observacoes` | string \| null | não | app | |

---

### Subcoleção `Pets/{petId}/historicoMedico` — *vazia em produção*

- **Doc ID:** **gerado no client** (`novoId` → `.doc(id).set(...)`), porque os anexos sobem antes do doc existir.
- **Repo:** `FirebaseHistoricoMedicoRepository`.

| Campo | Tipo | Obrigatório | Referência | Origem | Observações |
|---|---|---|---|---|---|
| *(doc id)* | string (client) | sim | — | app | |
| `data` | string `dd/MM/yyyy` | sim | — | app | |
| `descricao` | string | sim | — | app | |
| `veterinario` | string \| null | não | — | app | |
| `anexos` | array\<string\> (URLs) | não (default `[]`) | Cloudinary | app | comentário no código diz "Firebase Storage" — **desatualizado** |

---

### Subcoleção `Pets/{petId}/consultas` — *vazia em produção*

- **Doc ID:** auto (`.add`). **Repo:** `FirebaseConsultaRepository` (sem delete — cancelar = mudar `status`).

| Campo | Tipo | Obrigatório | Origem | Observações |
|---|---|---|---|---|
| *(doc id)* | string (auto) | sim | app | |
| `data` | string `dd/MM/yyyy` | sim | app | |
| `horario` | string `HH:mm` \| null | não | app | |
| `veterinario` | string | sim | app | |
| `motivo` | string | sim | app | |
| `status` | string enum | sim | app | `agendada` \| `realizada` \| `cancelada` (via `ConsultaStatus.fromValue`) |

---

### Subcoleção `Pets/{petId}/localizacoes` — *vazia em produção*

- **Doc ID:** auto (`.add`). **Repo:** `FirebaseLocalizacaoRepository` (só `watch` + `create`).
- ⚠️ Não confundir com a coleção **raiz** `Localizacoes` (95 docs reais, GPS) — ver abaixo.

| Campo | Tipo | Obrigatório | Origem | Observações |
|---|---|---|---|---|
| *(doc id)* | string (auto) | sim | app | |
| `data` | string `dd/MM/yyyy` | sim | app | |
| `descricao` | string | sim | app | texto livre — **sem** lat/long |
| `contatoReportante` | string \| null | não | app | quem relatou o avistamento |

---

## Coleção raiz `Localizacoes` — **95 docs reais, com GPS**

O app Feature-First atual não usa esta coleção (usa a subcoleção, que está vazia).
Mas ela contém o **histórico real da funcionalidade "pet perdido"** de uma versão anterior.
Schema uniforme nos 95 docs:

| Campo | Tipo | Observações |
|---|---|---|
| *(doc id)* | string (auto) | |
| `latitude` | number | GPS real |
| `longitude` | number | GPS real |
| `telefone` | string | contato de quem avistou (alguns com espaço) |
| `petId` | string → `Pets` | 65 registros apontam para pet existente; **30 apontam para pet apagado** (`9CUlOu8…`) |
| `nomePet` | string | denormalizado |
| `nomeTutor` | string | denormalizado |
| `timestamp` | string ISO 8601 | 2024-12-04 → 2025-08-14 |

**Migração (decisão D revista): SIM, migrar.** Vira a collection `locations` no MongoDB
(que já prevê `latitude`/`longitude`). Registros órfãos entram com `petId: null` +
`legacyPetId`/`legacyPetName`/`legacyTutorName`. Detalhes e ruído de teste em
[`firestore-data-report.md`](firestore-data-report.md).

---

## Regras de segurança (Firestore Rules)

**Não versionadas neste repositório.** `firebase.json` não referencia `firestore.rules`. O conteúdo real deployado é desconhecido — e o export confirma o risco: a coleção `Localizacoes` foi escrita por uma versão antiga sem controle de dono, o que sugere regras permissivas. **Risco R-02.** Necessário o usuário colar as regras atuais do console.

---

## Resumo de problemas de dados a tratar na migração

Números e regras de conversão detalhadas em [`firestore-data-report.md`](firestore-data-report.md).

| # | Problema | Coleções afetadas |
|---|---|---|
| 1 | Datas em string: `dd/MM/yyyy`, ISO `yyyy-MM-dd`, vazias, e **inválidas** (`1/1/1`, `13/32/321`) | `Usuarios`, `Pets` |
| 2 | `peso` heterogêneo: string, número, com unidade (`"10 KG"`), lixo (`"byi"`), vazio, null | `Pets` |
| 3 | `dono` redundante — **nunca** difere de `userId` → descartar | `Pets` |
| 4 | `usuarioID` (UUID) sem uso como FK → `legacyUsuarioId` | `Usuarios` |
| 5 | Ausência de `createdAt`/`updatedAt` (exceto 3 pets e 1 usuário) | quase todas |
| 6 | Schema drift: `datadenascimento`, `imagemUrl`/`photoURL`, `userID`, `uid`, docs "Marcola"/"Gabrielly" antigos; só 2 usuários têm `sobrenome` | `Usuarios`, `Pets` |
| 7 | `genero` (`Homem`/`Mulher`/`Outro`), `especie` (ausente em 10/24, lixo), `porte` (case/lixo) → enums | `Usuarios`, `Pets` |
| 8 | **~28 imagens no Firebase Storage** — verificar se ainda resolvem; se sim, re-upload p/ Cloudinary | `Usuarios`, `Pets` |
| 9 | 2 pets órfãos + ~7 contas de teste + ruído em `Localizacoes` (30 órfãs, 1 na Irlanda, 13 duplicadas) | todas |
| 10 | `Localizacoes` raiz: 95 docs GPS a migrar para `locations` (30 com `petId` órfão) | `Localizacoes` |
