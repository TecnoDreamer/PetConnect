# Firestore — isolamento por dono (issue #31)

Fase 1 do plano de próximos passos. Regras em `firestore.rules`, testes em
`tool/firestore-rules/`. **Estado: proposta em PR, não deployada.** O que
está em produção continua sendo o descrito em
[`firestore-rules-deployed.md`](firestore-rules-deployed.md).

## Problema

As regras deployadas em 2026-09-11 têm um catch-all
`match /{document=**} { allow write: if request.auth != null && ... }`. Ele
também casa `Usuarios/{id}` e `Pets/{id}`, e blocos `match` somam por OR.
Resultado, pela leitura das regras (não testado contra produção):

| Quem | Pode hoje |
|---|---|
| Qualquer usuário logado | ler todos os perfis (`Usuarios`: nome, e-mail, telefone, data de nascimento) e todos os pets |
| Qualquer usuário logado | criar, alterar e apagar perfis e pets de outros tutores |
| Qualquer usuário logado | ler e escrever vacinas, consultas, histórico, localizações e eventos de qualquer pet |
| Qualquer usuário logado | criar documentos em qualquer coleção nova |

## Operações reais do app (modo Firestore, flags `USE_API_*` desligadas)

Levantadas em `lib/features/*/data/firebase_*_repository.dart`.

| Operação | Caminho e método | Regra nova |
|---|---|---|
| Cadastro | `set Usuarios/{uid}` com `usuarioID` (não `uid`) | ID do documento = UID |
| Ver/editar perfil | `get`/`update Usuarios/{uid}` | idem |
| Excluir conta | `delete` de `vacinas`, `consultas`, `historicoMedico`, `localizacoes` e `fotos` de cada pet; depois **um lote** com `eventosSituacao` de cada pet, os pets e `Usuarios/{uid}`; depois o usuário do Auth | dono; exclusão permitida mesmo com pet falecido; eventos só no lote que apaga o perfil |
| Listar pets | `Pets where userId == uid` | `userId == uid` (a consulta é aceita porque filtra pelo dono) |
| Abrir pet | `get Pets/{id}` | dono |
| Criar pet | `add Pets` com `userId` = UID | `userId == uid` |
| Editar/apagar pet | `update`/`delete Pets/{id}` (o `toMap` reenvia `userId`) | dono antes e depois (sem transferir) |
| Registrar falecimento / corrigir | transação: `update Pets/{id}` (`situacao`) + `set eventosSituacao/{novo}` | dono; evento descreve a mudança real |
| Vacinas, consultas, histórico, localizações | listar, `add`/`set`, `update`, `delete` em `Pets/{id}/<sub>` | dono do pet pai; criar/alterar bloqueado se `FALECIDO` |
| Galeria de fotos (`GALERIA_FOTOS`) | listar (`orderBy criadoEm`), `set`, `delete` em `Pets/{id}/fotos`; `deletePet` apaga a subcoleção antes do pet | dono do pet pai, também com pet `FALECIDO`; criação validada campo a campo; sem `update` |
| Página pública do QR | **não usa o Firestore**: `GET /api/v1/public/pets/{id}` na API (Render/MongoDB) | não afetada |

## Regras novas, em resumo

- Sem catch-all. Caminho sem regra própria é negado.
- `Usuarios/{userId}`: tudo só para `request.auth.uid == userId`. O ID do
  documento é o Auth UID em todos os 18 perfis reais
  (`docs/database/firestore-data-report.md`), então não depende dos campos
  `uid`/`usuarioID`, que variam entre gerações do app.
- `Pets/{petId}`: leitura, exclusão e alteração só pelo dono. O dono é
  `userId`; o único pet legado com `userID` (maiúsculo, pet de teste) também é
  reconhecido. Criar exige `userId` = UID. Alterar exige que o pet continue do
  mesmo tutor.
- Subcoleções clínicas: dono do pet pai (lido com `get`). **Escrita clínica**
  = criar ou alterar registro; bloqueada para pet `FALECIDO`. Leitura e
  exclusão continuam (o Memorial lê; a exclusão de conta apaga).
- `eventosSituacao`: leitura pelo dono; criação só pelo dono, na mesma escrita
  que muda `situacao` do pet (`get` antes × `getAfter` depois), com
  `atorId` = UID, `em` = horário do servidor e só os campos conhecidos;
  `update` sempre negado; `delete` só pelo dono do pet e só na escrita que
  apaga o próprio perfil (exclusão de conta, ver abaixo).
- `fotos` (galeria): dono do pet pai, inclusive pet `FALECIDO` (foto não é
  registro clínico). Criação só com os campos conhecidos, `petId` igual ao
  pai, `userId` = UID, URL de imagem do Cloudinary, `publicId`, legenda de
  até 300 caracteres e `criadoEm` = horário do servidor. `update` negado.
- `Localizacoes` (raiz, legado): igual a hoje — leitura para logado, escrita
  fechada.

### Limites conhecidos

- O dono ainda pode mudar `situacao` com um `update` direto, sem evento. Para
  auditoria à prova do próprio dono seria preciso escrever pelo servidor
  (Cloud Function ou API).
- Exclusão de conta: o lote final (eventos + pets + perfil) está sujeito aos
  limites de um lote do Firestore, 500 operações e 20 leituras de regra. Cada
  pet com eventos custa uma leitura (`get` do pet) e o perfil custa duas
  (`exists` e `existsAfter`), então cabem cerca de 18 pets com eventos. Acima
  disso a exclusão falha sem apagar pets nem perfil; as subcoleções clínicas
  já terão saído.
- Documentos que já ficaram órfãos (contas excluídas antes desta correção,
  com `consultas`, `localizacoes` ou `eventosSituacao` sem pet pai) não são
  limpos pelo app. Limpar exige o Admin SDK e uma decisão à parte.
- Um pet legado com `userID` não pode ser editado pelo app novo: o `toMap`
  grava `userId` vazio e a regra recusa (o pet deixaria de ter dono). Só afeta
  o pet de teste "teste2".

### Decisão: `eventosSituacao` é apagado na exclusão de conta

Cada evento guarda `atorId` (Auth UID do tutor), a mudança de situação do
pet, o motivo e o horário: é dado pessoal. O proprietário decidiu
(2026-10-27) **liberar o `delete` só para o dono durante a exclusão de
conta**, em vez de reter os eventos e documentar a retenção, para que nada
fique no banco depois do pedido de exclusão (RF09, RNF13).

Como a regra reconhece "durante a exclusão de conta":

- `delete` em `Pets/{petId}/eventosSituacao/{id}` exige `donoDoPet()` e
  `apagandoOProprioPerfil()`: `Usuarios/{uid}` existe antes da escrita
  (`exists`) e não existe depois (`existsAfter`). Na prática, o evento só sai
  no mesmo lote atômico que apaga o perfil do próprio usuário.
- A regra lê o pet para conferir o dono, então o pet precisa existir antes do
  lote. Por isso o app apaga eventos, pets e perfil juntos, nesse lote, e não
  o pet antes.
- Fora desse lote o dono não apaga evento nenhum: nem avulso, nem junto com o
  pet, nem depois de ter apagado o perfil numa escrita anterior. Apagar o
  próprio perfil não libera eventos de pet de outro tutor.

O que se perde: a trilha deixa de ser imutável para o dono no momento em que
ele exclui a conta. Como o próprio usuário pode recriar o perfil depois (o
cadastro faz `set Usuarios/{uid}`), um dono que use o SDK direto consegue
apagar os eventos apagando e recriando o perfil. Isso não piora o limite que
já existia (o dono já muda `situacao` sem evento com um `update` direto);
auditoria à prova do próprio dono continua exigindo servidor.

Testes: `test/features/usuario/firebase_usuario_repository_test.dart` (ordem
e conteúdo da cascata no app) e o bloco "exclusão de conta (mesma ordem do
app)" de `tool/firestore-rules/regras.test.js` (lote aceito; evento fora do
lote, com pet já apagado ou de outro tutor, negado).

**Depende do deploy das regras.** Com as regras antigas no ar, o lote final
é negado: a exclusão de conta para depois de apagar as subcoleções clínicas,
sem apagar eventos, pets, perfil nem o usuário do Auth.

## Testes

`tool/firestore-rules/regras.test.js` (Node `node:test` +
`@firebase/rules-unit-testing`) contra o Firestore Emulator, com projeto
`demo-petconnect` (nunca o Firebase real) e dados sintéticos de duas contas.
Cobre a matriz do plano: leitura, criação, alteração e exclusão do próprio
dado e do dado de outro tutor em `Usuarios`, `Pets` e cada subcoleção;
anônimo; pet falecido; eventos válidos, soltos, com autor falso, com campo
extra, e imutabilidade; transferência de dono; pet legado; exclusão de conta
(inclusive o `delete` de eventos só no lote do perfil); coleção e subcoleção
sem regra.

Os testes que tentam escrever em dado de outro tutor voltam a falhar se um
catch-all com `allow write` for reintroduzido.

Rodam no job **Firestore Rules (emulador)** do CI (Linux). Localmente:

```bash
cd tool/firestore-rules && npm ci && npm test
```

Precisa de Java 21. No Windows de desenvolvimento deste projeto o emulador
não sobe (`Unable to establish loopback connection`).

## Compatibilidade e riscos do deploy

| Risco | Situação |
|---|---|
| App atual (este repositório) | Todas as operações da tabela acima cobertas por teste. |
| **App antigo dos usuários reais** | O código dele não está neste repositório; não dá para verificar o que ele lê ou grava. Se ele ler perfil ou pet de outro tutor, gravar pet sem `userId`, ou usar outra coleção, essa parte para de funcionar. **Decisão do proprietário antes do deploy.** |
| Página pública do QR | Usa a API, não o Firestore. Sem impacto. |
| Modo API (flags ligadas) | Usa o MongoDB. Sem impacto. |

## Deploy (não executado — exige aprovação separada)

1. Confirmar com o proprietário quem ainda usa o app antigo.
2. CI verde, inclusive o job das regras.
3. Copiar as regras **em vigor** do console do Firebase (Firestore → Regras)
   para `firestore-rules-deployed.md`, como backup verificado. Não usar o
   arquivo do repositório como backup sem conferir.
4. `firebase deploy --only firestore:rules --project pet-connect-c53f1`.
5. Verificar no aparelho: login, lista de pets, abrir pet, criar e editar
   pet, vacina, consulta, histórico, localização, Memorial (registrar e
   corrigir), exclusão de conta com uma conta de teste. Verificar também que
   uma conta não abre o pet da outra.
6. Registrar o deploy em `firestore-rules-deployed.md`.

## Rollback

Voltar às regras anteriores **reabre a vulnerabilidade**: qualquer usuário
logado volta a poder alterar e apagar dados de outros. Não fazer isso
automaticamente. Se algum fluxo legítimo quebrar:

1. Preferir uma correção restritiva: liberar só a operação que quebrou, para
   o dono, e redeployar.
2. Só em último caso, redeployar o backup do passo 3 do deploy, com decisão
   explícita do proprietário, e reabrir a correção em seguida.

O console do Firebase também guarda o histórico de versões das regras e
permite voltar a uma versão anterior.
