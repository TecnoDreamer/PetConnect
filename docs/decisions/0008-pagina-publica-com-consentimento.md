# ADR 0008 — Página pública do QR com consentimento por campo

- **Status:** proposta (PRs `feat/qr-consentimento-publico` no app e na API, aguardando aceite)
- **Data:** 2026-11-02
- **Issue:** #35 (fase 1 do épico #102)

## Contexto

A página pública do QR mostrava nome, espécie, situação, foto e telefone
de qualquer pet, sem consentimento registrado. A especificação do épico
pede publicação desligada por padrão, escolha campo a campo, consentimento
explícito e revogação imediata. A API é quem resolve o QR (ADR 0004), mas
os pets do app de teste estão no Firestore, e pets novos só chegam ao
MongoDB pela migração manual.

## Decisão

1. **Sem consentimento, mínimo neutro** (decisão do proprietário): a
   resposta pública é `{"shared": false}` e a página mostra só "pet
   cadastrado" e o formulário de avistamento. O QR impresso continua
   abrindo.
2. **Allowlist de campos** (`PublicField`), um a um, e consentimento com a
   versão do texto (`CONSENT_VERSION`). Uma publicação em outra versão do
   texto deixa de valer até o tutor aceitar de novo.
3. **Coleção própria** (`pet_public_sharing`), fora de `pets`. A migração
   apaga e recria os pets importados; o consentimento não pode sumir junto.
4. **A API lê o pet no Firestore a cada acesso** (decisão do proprietário:
   ler o pet no Firestore). Isso vale para conferir o dono, para pets que
   ainda não estão no MongoDB e para os dados que a página mostra. Nenhum
   dado do pet é copiado; só ficam guardados o telefone e o nome de
   exibição, que existem só para a página.
5. **Histórico só de inclusão** (`public_sharing_consent_events`), com o
   escopo e sem os valores.
6. **Revogar apaga** o telefone e o nome de exibição. Excluir o pet ou a
   conta apaga a configuração.

## Alternativas descartadas

- **Copiar os dados do pet para o MongoDB ao salvar:** a cópia ficaria
  velha quando o tutor editasse o pet. Também continuaria aparecendo depois
  de o pet ser excluído no Firestore, porque o app não avisa a API.
- **Criar o pet no MongoDB ao salvar:** a próxima migração apagaria e
  recriaria o pet, e um pet criado fora dela colidiria com o `publicId`
  determinístico.
- **Página lendo direto do Firestore:** já descartada no ADR 0004. Seria um
  segundo caminho de resolução e exigiria leitura anônima nas regras.
- **Manter os dados de hoje até o tutor revisar:** continuaria expondo
  dados sem consentimento registrado.

## Consequências

- **Firestore no caminho da página:** cada acesso à página de um pet do
  Firestore faz uma leitura lá, o que cabe com folga na cota gratuita.
- **Firestore fora do ar:**
  - página publicada responde `503`;
  - página sem publicação continua neutra.
- **Credencial:** a conta de serviço da API precisa de leitura no
  Firestore.
- **Página antiga com a API nova:** o pet sem consentimento aparece como
  "Pet" até a página nova ser publicada.
