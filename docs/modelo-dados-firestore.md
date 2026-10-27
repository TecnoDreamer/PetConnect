# Modelo de Dados — Firestore

Reconciliado com a estrutura real já existente no projeto Firebase (`pet-connect-c53f1`), a partir do console compartilhado. Nomes de coleção e campo seguem o que já está em produção — **em português**, como no banco original.

## Coleções existentes

### `Usuarios/{docId}`

`docId` é o **UID do Firebase Auth** do usuário (ex: `4nMLz8EC9aeF0rEMJWykDvloOq92`).

| Campo | Tipo (real) | Observação |
|---|---|---|
| `nome` | string | |
| `sobrenome` | string | **novo campo, adicionado nesta fase** (edição de perfil, RF08) — contas criadas antes dele simplesmente não têm o valor até o tutor editar o perfil |
| `email` | string | |
| `telefone` | string | sem formatação (ex: `"19991562584"`) |
| `dataNascimento` | string | formato `"dd/MM/yyyy"` — **não** é Timestamp do Firestore |
| `genero` | string | ex: `"Homem"`, `"Mulher"` |
| `foto` | string | URL do Cloudinary (antes era Firebase Storage — trocado por exigir plano pago) |
| `usuarioID` | string (UUID) | identificador interno, **diferente** do `docId`/UID do Auth |

> ⚠️ **A confirmar com o usuário**: existem dois identificadores para o mesmo usuário — o `docId` da coleção (= UID do Firebase Auth) e o campo `usuarioID` (UUID gerado separadamente). Nos documentos de `Pets` já existentes, o campo `userId` parece referenciar o **`docId`/UID do Auth**, não o `usuarioID`. Precisamos confirmar se `usuarioID` tem algum uso específico (ex: em `Localizacoes`?) antes de decidir se ele é mantido, depreciado, ou se é a chave que deveria estar sendo usada em `Pets.userId`.

### `Pets/{docId}`

`docId` gerado automaticamente pelo Firestore (ex: `3RzQeA1w8KrAVfcCZjMi`).

| Campo | Tipo (real) | Observação |
|---|---|---|
| `nome` | string | |
| `especie` | string | |
| `raca` | string | |
| `cor` | string | |
| `genero` | string | ex: `"Fêmea"`, `"Macho"` |
| `porte` | string | ex: pequeno/médio/grande |
| `peso` | string | ⚠️ armazenado como string no exemplo visto, não número |
| `dataNascimento` | string | formato `"dd/MM/yyyy"`, pode ser vazio |
| `dono` | string \| null | campo visto como `null` no exemplo — função ainda não confirmada (ver nota abaixo) |
| `telefone` | string \| null | contato a exibir na página pública do QR code; se nulo, cai no `telefone` do usuário dono |
| `userId` | string | referencia o `docId`/UID do usuário dono (ver nota acima) |
| **`vacinado`** | boolean | **novo campo, adicionado nesta fase** — indica se o pet está vacinado (RF20-A) |
| `situacao` | string \| ausente | Memorial do Pet: `"ATIVO"` ou `"FALECIDO"`; **ausente = ATIVO** (pets legados). Só muda por `PetRepository.alterarSituacao`. |
| `dataFalecimento` | string \| ausente | `"dd/MM/yyyy"`, opcional (nunca inventada) |
| `homenagem` | string \| ausente | texto opcional do tutor exibido no memorial |
| `situacaoAtualizadaEm` | timestamp \| ausente | horário (servidor) da última mudança de situação |

> ⚠️ **A confirmar**: o campo `dono` parece redundante com `userId` (ambos apontariam para o tutor). Pode ser um campo legado, ou guardar o **nome** do dono de forma denormalizada (para exibir sem precisar buscar `Usuarios`) em vez do ID. Precisa confirmação antes de decidirmos se ele é usado, ignorado, ou removido.

> **`vacinado`**: adicionado como um campo simples e direto no documento do pet, conforme solicitado. Documentos de `Pets` já existentes no banco **não** terão esse campo automaticamente — ele passa a ser preenchido para pets novos a partir de agora; para os já existentes, precisa de uma atualização manual ou um script de migração (podemos fazer isso quando formos tratar dados de teste/produção). Ainda cabe, no futuro, uma subcoleção `Pets/{petId}/vacinas` para o histórico detalhado de doses (nome da vacina, data, próxima dose) — este campo booleano é só o indicador rápido "vacinado: sim/não" pedido agora.

### `Localizacoes/{docId}` (coleção existente no banco, não usada pelo app)

Coleção identificada no console, mas **os campos nunca foram compartilhados**. RF31/RF32 foram implementados sem tentar reconciliar com ela — em vez disso, criamos `Pets/{petId}/localizacoes/{id}` (ver abaixo), estrutura nova definida do zero, decisão consciente do usuário. Se um dia confirmarmos os campos desta coleção `Localizacoes` de nível raiz e ela tiver um propósito diferente/complementar, revisamos.

## Subcoleções criadas pelo app (não faziam parte do banco original)

As subcoleções abaixo não existiam na estrutura compartilhada original — foram criadas pelo próprio app conforme cada feature foi implementada (carteira de vacina detalhada, histórico médico, consultas). Documentos só passam a existir a partir do primeiro registro feito pelo tutor em cada pet.

### `Pets/{petId}/vacinas/{vacinaId}` (detalhe, além do campo `vacinado`)
```json
{
  "nome": "string",
  "dataAplicacao": "string (dd/MM/yyyy)",
  "proximaDose": "string (dd/MM/yyyy) | null",
  "veterinario": "string | null",
  "observacoes": "string | null"
}
```

### `Pets/{petId}/historicoMedico/{registroId}`
```json
{
  "data": "string (dd/MM/yyyy)",
  "descricao": "string",
  "veterinario": "string | null",
  "anexos": ["string (URL)"]
}
```

### `Pets/{petId}/consultas/{consultaId}`
```json
{
  "data": "string (dd/MM/yyyy)",
  "horario": "string | null",
  "veterinario": "string",
  "motivo": "string",
  "status": "agendada | realizada | cancelada"
}
```

### `Pets/{petId}/localizacoes/{localizacaoId}`
```json
{
  "data": "string (dd/MM/yyyy)",
  "descricao": "string",
  "contatoReportante": "string | null"
}
```
Sem latitude/longitude nesta fase — texto livre, para não introduzir uma dependência nova de mapas/geolocalização. RF31 (relato direto por quem encontrou o pet, sem login, a partir da página pública do QR code) segue bloqueado por RF17-19 — por ora, só o próprio tutor consegue registrar um avistamento pelo app.

### `Pets/{petId}/eventosSituacao/{eventoId}`

Auditoria das transições de situação (Memorial do Pet, ver
`docs/features/memorial-pet.md`). Um documento por transição efetiva,
gravado na mesma transação da mudança no pet.

| Campo | Tipo | Observação |
|---|---|---|
| `atorId` | string | uid de quem fez a alteração |
| `situacaoAnterior` | string | `"ATIVO"` / `"FALECIDO"` |
| `situacaoNova` | string | `"ATIVO"` / `"FALECIDO"` |
| `motivo` | string | `"registro_falecimento"` / `"correcao_marcacao"` |
| `resultado` | string | `"aplicado"` |
| `origem` | string | `"app"` |
| `em` | timestamp | horário do servidor |

### `Pets/{petId}/fotos/{fotoId}`

Galeria de fotos do pet (ver `docs/features/galeria-fotos-pet.md`). O
arquivo fica no Cloudinary; aqui só os metadados. Sem edição.

| Campo | Tipo | Observação |
|---|---|---|
| `petId` | string | igual ao id do pet pai |
| `userId` | string | uid de quem publicou |
| `url` | string | URL original do Cloudinary |
| `publicId` | string | `public_id` do Cloudinary |
| `largura`, `altura` | int (opcional) | dimensões |
| `legenda` | string (opcional) | até 300 caracteres |
| `criadoEm` | timestamp | horário do servidor — exceção à convenção de datas abaixo, porque ordena e pagina a galeria |

## Convenção de datas

O banco existente usa **strings no formato `dd/MM/yyyy`** para datas, não `Timestamp` do Firestore. Mantemos essa convenção nos novos campos/coleções para consistência, em vez de introduzir um formato diferente no meio do mesmo banco.

## Armazenamento de fotos

`foto` em `Usuarios` e em `Pets`, além dos `anexos` do histórico médico e da galeria (`Pets/{petId}/fotos`), apontam para URLs do **Cloudinary** (ver `lib/core/config/cloudinary_config.dart`). Não é Firebase Storage — o Storage passou a exigir o plano pago (Blaze) no projeto Firebase real, então o upload foi trocado para um serviço com tier gratuito sem cartão.

## Índices sugeridos

- `Pets`: índice em `userId` (listar os pets de um usuário é a query mais comum do app).
