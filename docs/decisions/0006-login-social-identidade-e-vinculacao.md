# 0006 — Login social: identidade e vinculação de contas

- **Data:** 2026-10-27
- **Status:** aceita (implementada em `feat/login-social-google-facebook`)
- **Contexto:** RF04-A, `docs/features/login-social.md`

## Contexto

O tutor pode entrar com e-mail e senha ou com o Google. Os pets são ligados
ao tutor pelo `userId`, que é o UID do Firebase Auth. Um login por outro
método não pode criar um segundo tutor, nem juntar contas de pessoas
diferentes que tenham o mesmo e-mail.

## Decisões

1. **Só o Google como login social.** O Facebook (RF04-B) saiu do escopo
   por decisão do proprietário. A estrutura aceita um novo provedor sem
   mudar o fluxo.
2. **O UID do Firebase Auth continua sendo a identidade canônica.**
   - O perfil (`Usuarios/{uid}` ou `GET /me`) é criado só se ainda não
     existir.
   - Um login repetido nunca altera o perfil.
3. **Sem união automática pelo e-mail feita pelo app.**
   - Quando o Firebase responde `account-exists-with-different-credential`,
     o app pede a senha da conta existente.
   - Só depois disso o Google é vinculado (`linkWithCredential`).
   - A credencial pendente fica só em memória, durante o diálogo.
4. **Nenhuma migração de pets entre UIDs.** Se algum dia for necessária,
   será um procedimento próprio, transacional e auditado, com aprovação.
5. **Perfil social mínimo.**
   - Do Google, o app usa só o nome e o e-mail. A foto não é copiada.
   - Os campos que faltam ficam vazios e o tutor completa em Editar perfil.
6. **Sair encerra o Firebase e o Google Sign-In**, para o próximo login
   perguntar a conta.
7. **Configuração fora do código.** O cliente OAuth vem do
   `google-services.json` (fora do Git) ou de
   `--dart-define=GOOGLE_SERVER_CLIENT_ID`. A chave secreta do cliente web
   não é usada pelo app.

## Consequências

- Mais seguro contra tomada de conta, ao custo de um passo a mais no
  conflito.
- **Comportamento do Firebase com o Google:** o Google é um provedor
  confiável. Com "uma conta por e-mail" e conta por senha **não
  verificada**, o Firebase mantém o UID e troca o método pelo Google, sem
  conflito.
  - Os dados continuam com o tutor.
  - Fica registrado para não ser confundido com união feita pelo app.
- Sem o cliente OAuth no build, o botão avisa que o login não está
  disponível, em vez de quebrar.
