# Firestore Security Rules — histórico (R-02)

> Projeto `pet-connect-c53f1`. A partir de 2026-09-11 as regras **vivem em
> `firestore.rules`** na raiz do repo (referenciado por `firebase.json`) —
> este arquivo passa a ser só o histórico/análise, não a fonte da verdade.
>
> **Atenção (2026-10-26):** `firestore.rules` no repositório passou a conter
> as regras de isolamento por dono, **ainda não deployadas**
> ([`firestore-isolamento-por-dono.md`](firestore-isolamento-por-dono.md)).
> Até o deploy, o que vale em produção é o último estado registrado abaixo
> (FASE 11, passo 2).

## ✅ 2026-09-11 — FASE 11, passo 1: leitura/escrita anônima fechada

Deploy feito (`firebase deploy --only firestore:rules`) e **verificado**:
`GET Pets`/`Localizacoes` sem token → `403 PERMISSION_DENIED` (antes: 200,
aberto); com um ID Token real → `200` continua normal (não quebrou nada que
já exigia login). Nada que já dependia de `request.auth != null` mudou de
comportamento — só o acesso **sem login nenhum** deixou de funcionar.

Confirmado com o usuário antes do deploy: não existe mais nenhum fluxo
público real (página/Cloud Function) escrevendo em `Localizacoes` — os 95
registros eram só histórico de scans de QR de uma versão antiga, já
migrados pro MongoDB. Por isso a escrita pública dessa coleção também foi
fechada, não só a leitura (rollback: `git revert` no commit que mudou
`firestore.rules` + re-deploy).

O texto exato de antes e depois está no histórico do git de `firestore.rules`
(e reproduzido nas seções abaixo, para quem não tiver acesso ao repo).

## ✅ 2026-09-11 — FASE 11, passo 2: `Localizacoes` write fechado de vez

Deploy feito e **verificado por REST direto** (não só o exit code do CLI):
POST autenticado em `Localizacoes` → `403 PERMISSION_DENIED` (antes: `200`,
qualquer usuário logado conseguia escrever); `GET` autenticado continua
`200` (histórico ainda legível); POST anônimo continua `403` (sem mudança).

**Pegadinha encontrada e corrigida durante a verificação** (documentada em
comentário no próprio `firestore.rules`): blocos `match` do Firestore não
se sobrepõem por especificidade — eles se somam por OR. Um
`allow write: if false` no bloco de `Localizacoes` **não bloqueava nada
sozinho**, porque o catch-all `/{document=**}` também casa com
`Localizacoes/{docId}` e concedia `write: if request.auth != null`, que
"vazava" por cima. A primeira tentativa de correção (excluir `Localizacoes`
comparando `document.size()`, onde `document` é a variável do wildcard
`{document=**}`) também falhou: `document` é do tipo `path`, que não tem
`.size()` — erro de tipo silencioso que o Firestore trata como condição
`false`, o que **derrubaria a escrita de todas as coleções**, não só
`Localizacoes` (pego no teste real antes de virar um problema em produção:
um POST autenticado numa coleção qualquer não-relacionada voltou `403`
inesperado). Correção final: indexar `request.path` (sempre
`/databases/{db}/documents/<colecao>/...`) em vez da variável do wildcard —
`request.path[3] != 'Localizacoes'`, sem warning de tipo, testado e
confirmado (catch-all volta a liberar escrita em coleções não-relacionadas,
e a subcoleção real `Pets/{petId}/localizacoes` usada pelo app antigo
continua 100% funcional).

Todos os documentos de teste criados durante a verificação foram apagados
logo em seguida (Admin SDK, que ignora as regras).

## Conteúdo anterior ao endurecimento (deployado até 2026-09-11)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /Usuarios/{userId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && request.auth.uid == request.resource.data.uid;
      allow update: if request.auth != null && request.auth.uid == resource.data.uid;
      allow delete: if request.auth != null && request.auth.uid == resource.data.uid;
    }

    match /Pets/{petId} {
      allow read: if true;
      allow create: if request.auth != null;
      allow update: if request.auth != null && request.auth.uid == resource.data.userId;
      allow delete: if request.auth != null && request.auth.uid == resource.data.userId;
    }

    match /Localizacoes/{docId} {
      allow read, write: if true;
    }

    match /{document=**} {
      allow read;
      allow write: if request.auth != null;
    }
  }
}
```

## Análise

| Regra | Efeito real | Risco |
|---|---|---|
| Catch-all `/{document=**}` → `allow read;` | **Todo documento do banco é legível sem autenticação.** Inclui `Usuarios` (e-mail, telefone, foto, data de nascimento de todos). O bloco `Usuarios` tenta exigir `auth`, mas o catch-all concede leitura antes disso — no Firestore, **basta uma regra conceder**. | 🔴 Vazamento de PII de 18 usuários |
| `Pets` → `allow read: if true;` | Qualquer pessoa na internet lê **todos** os pets, incluindo o `userId` (Auth UID) do dono. | 🟠 Exposição de dados + UIDs |
| `Localizacoes` → `allow read, write: if true;` | Qualquer pessoa lê, **cria, altera e apaga** os 95 registros de GPS. Explica o lixo na coleção (coordenada na Irlanda, duplicatas). | 🔴 Escrita pública irrestrita |
| `Usuarios` create/update/delete → `... == data.uid` | Só o doc da "Gabrielly" tem campo `uid`. Nos outros 17, `resource.data.uid` é `undefined` → condição falsa → **update/delete negados**. Perfis antigos provavelmente só eram alterados por caminho administrativo/versão antiga. | 🟡 Inconsistência (fail-closed) |
| `Pets` update/delete → `... == resource.data.userId` | Correto para os docs que têm `userId` (23 de 24). O pet com `userID` (maiúsculo) fica sem dono válido. | 🟡 |

> **Correção de 2026-10-26 — as duas últimas linhas da tabela acima estão
> erradas.** Elas avaliam os blocos `Usuarios` e `Pets` isoladamente. Mas o
> catch-all `/{document=**}` tinha (e ainda tem, com exceção só de
> `Localizacoes`) `allow write: if request.auth != null`, e ele também casa
> `Usuarios/{id}` e `Pets/{id}`. Como os blocos somam por OR, **qualquer
> usuário logado consegue criar, alterar e apagar perfis e pets de outros
> tutores**, além das subcoleções; as condições de dono não têm efeito. Não é
> fail-closed. Conclusão tirada da leitura das regras com a mesma semântica
> que o passo 2 confirmou na prática em `Localizacoes`; não foi testado contra
> produção. Correção planejada na Fase 1 do plano de próximos passos (#31),
> sem deploy sem aprovação.

## Recomendação (situação após o passo 2 — FASE 11 fechada)

1. ~~Endurecimento de baixo risco~~ ✅ feito em 2026-09-11 (catch-all + `Pets` + `Localizacoes` exigem login agora).
2. ~~Versionar as regras~~ ✅ `firestore.rules` no repo, referenciado em `firebase.json`.
3. ~~`Localizacoes` → `write: if false` de vez~~ ✅ feito em 2026-09-11 (ver seção "passo 2" acima).
4. ~~Rate limiting nos endpoints públicos da API~~ ✅ feito em 2026-09-11 (`/api/v1/public/**`, 30 leituras/min e 10 escritas/min por IP — ver `PetConnect-API/src/main/java/com/petconnect/api/shared/web/`).
5. **Endurecimento final — deliberadamente NÃO feito ainda:** `allow read, write: if false` em `Usuarios`/`Pets` (as coleções que já têm equivalente 100% funcional na API). Está gated em uso real validado das FASES 4–10 (não só e2e) — hoje os 18 usuários reais ainda rodam o app antigo, que lê essas coleções direto do Firestore com as flags `USE_API_*` desligadas por padrão. Fechar agora quebraria o app pra eles. Só fazer depois que o app novo (com as flags ligadas) estiver em uso real validado, ou na FASE 13 (remoção total do Firestore).
