# ADR 0009 — Cartão de Emergência privado, em documento próprio

- **Status:** proposta (PR `feat/41-cartao-emergencia-pet`, aguardando aceite)
- **Data:** 2026-11-09
- **Issue:** #41

## Contexto

O tutor precisa de um resumo de saúde do pet para uma urgência. São dados
sensíveis na prática: alergias, medicamentos, condições, contato do tutor e
do veterinário. O app guarda os pets no Firestore, e a API Spring lê o
documento do pet no Firestore para montar a página pública do QR (ADR 0008).

## Decisão

1. **Privado na versão 1.**
   - Nada no QR, na web, na API ou em links.
   - O cartão só abre dentro do app, com a sessão do dono.
2. **Documento próprio:** `Pets/{petId}/emergencia/cartao`, fora do
   documento do pet.
3. **Escrita só com o pet ativo, leitura também no Memorial.** É dado
   clínico, como as vacinas (ADR 0002).
4. **Revisão:** cada gravação sobe a revisão em 1, numa transação que
   confere a revisão com que o formulário abriu. As regras exigem o mesmo.
5. **Sem cache próprio.** O cartão usa só o cache padrão do Firestore no
   aparelho, sem banco local nem cópia extra.
6. **Flag `CARTAO_EMERGENCIA`**, desligado até o deploy das regras.

## Alternativas descartadas

- **Campos no documento do pet:** a API leria os dados de saúde a cada
  acesso à página pública, mesmo sem mostrá-los. Um erro no mapeamento da
  API poderia expô-los.
- **API Spring / MongoDB:** o app não guarda pets na API hoje (só no modo
  `USE_API_PETS`), então seria um segundo caminho de dados, sem ganho para um
  cartão privado.
- **Banco local (sqflite) com sincronização:** mais um lugar com dado
  sensível no aparelho, sem proteção extra. O cache do Firestore já cobre a
  leitura offline.
- **Última gravação vence:** perderia em silêncio uma edição feita em outro
  aparelho.

## Consequências

- **Deploy:** depende do deploy das regras (`firestore.rules`).
- **Exclusão:** a cascata da exclusão de pet e de conta apaga o cartão
  direto, sem listar a subcoleção. Com as regras antigas, a negação é
  ignorada.
- **Evolução:** compartilhar o cartão (com clínica, #42, ou na página do QR)
  exige consentimento por campo, como na ADR 0008, e uma nova ADR.
