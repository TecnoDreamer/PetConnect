# Segurança — Memorial do Pet

Complementa `docs/seguranca.md` e `docs/features/memorial-pet.md`.

## Autorização

| Ação | Onde é garantida | Situação |
|---|---|---|
| Registrar falecimento / corrigir marcação | Regra deployada `Pets/{petId}`: `allow update: if request.auth.uid == resource.data.userId`. A transação falha inteira para outra conta. | ✅ Em vigor |
| Ver memorial ou lista do Memorial | Consulta por `userId` + `PetSituacaoGuard` confere o dono | ✅ App. ⚠️ As regras permitem **leitura** de `Pets` a qualquer usuário logado (situação anterior, ver `firestore.rules`). |
| Criar vacina, consulta, histórico ou localização para pet falecido | Rotas bloqueadas pelo `PetSituacaoGuard` | ✅ App. ⛔ Servidor pendente (abaixo). |
| Gravar evento de auditoria | Subcoleção sob o catch-all (`write` para logado) | ⚠️ Pendente de restrição |
| Modo API | `PetService.ownedOr404` no backend | Memorial desligado no app (exposição pública) |

## Proposta de regras (NÃO deployada; depende de aprovação)

```text
match /Pets/{petId} {
  // (regras atuais de Pets mantidas)

  function donoDoPet() {
    return request.auth != null
      && get(/databases/$(database)/documents/Pets/$(petId)).data.userId
         == request.auth.uid;
  }
  function petAtivo() {
    return get(/databases/$(database)/documents/Pets/$(petId))
      .data.get('situacao', 'ATIVO') != 'FALECIDO';
  }

  match /vacinas/{id}         { allow read: if donoDoPet(); allow write: if donoDoPet() && petAtivo(); }
  match /consultas/{id}       { allow read: if donoDoPet(); allow write: if donoDoPet() && petAtivo(); }
  match /historicoMedico/{id} { allow read: if donoDoPet(); allow write: if donoDoPet() && petAtivo(); }
  match /localizacoes/{id}    { allow read: if donoDoPet(); allow write: if donoDoPet() && petAtivo(); }

  match /eventosSituacao/{id} {
    allow read, create: if donoDoPet();
    allow update, delete: if false;   // auditoria imutável
  }
}
```

Atenção à observação já registrada em `firestore.rules`: blocos `match`
se somam por **OR**. O catch-all `/{document=**}` precisaria **excluir**
as subcoleções de `Pets`, senão continua liberando escrita por cima destas
regras. Antes do deploy, a proposta precisa ser validada no Firestore
Emulator (que não roda nesta máquina) ou num projeto de staging.

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
