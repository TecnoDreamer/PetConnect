# 0006 — Login social: identidade e vinculação de contas

- **Data:** 2026-10-27
- **Status:** aceita (implementada em `feat/login-social-google-facebook`)
- **Contexto:** RF04-A e RF04-B, `docs/features/login-social.md`

## Contexto

O tutor pode entrar com e-mail e senha, Google ou Facebook. Os pets são
ligados ao tutor pelo `userId`, que é o UID do Firebase Auth. Um login por
outro provedor não pode criar um segundo tutor, nem juntar contas de
pessoas diferentes que tenham o mesmo e-mail.

## Decisões

1. **O UID do Firebase Auth continua sendo a identidade canônica.**
   - O perfil (`Usuarios/{uid}` ou `GET /me`) é criado só se ainda não
     existir.
   - Um login repetido nunca altera o perfil.
2. **Sem união automática pelo e-mail.**
   - Quando o Firebase responde `account-exists-with-different-credential`,
     o app pede que o tutor entre pelo método que já usa, com senha ou
     outro provedor.
   - Só depois disso o provedor novo é vinculado (`linkWithCredential`).
   - A credencial pendente fica só em memória, durante o diálogo.
3. **Nenhuma migração de pets entre UIDs.** Se algum dia for necessária,
   será um procedimento próprio, transacional e auditado, com aprovação.
4. **Perfil social mínimo.**
   - Do provedor, o app usa só o nome e o e-mail. A foto não é copiada.
   - Os campos que faltam ficam vazios, como nas contas antigas, e o tutor
     completa em Editar perfil, sem tela nova.
5. **Sair encerra o Firebase e os SDKs dos provedores**, para o próximo login
   perguntar a conta de novo.
6. **Configuração fora do código:**
   - o App ID e o Client Token do Facebook ficam em
     `android/facebook.properties`, fora do Git;
   - o App Secret fica só no Firebase Console;
   - o cliente OAuth do Google vem do `google-services.json`, ou do
     `--dart-define=GOOGLE_SERVER_CLIENT_ID`.

## Consequências

- Mais seguro contra tomada de conta, ao custo de um passo a mais para quem
  já tinha conta e entra pela primeira vez com outro provedor.
- **Comportamento do Firebase:** com "uma conta por e-mail" e conta por
  senha **não verificada**, entrar com Google faz o Firebase manter o UID e
  substituir o método.
  - Os dados continuam com o tutor.
  - Fica registrado para não ser confundido com união automática feita
    pelo app.
- Sem configuração no Console, os botões avisam que o login não está
  disponível, em vez de quebrar.
