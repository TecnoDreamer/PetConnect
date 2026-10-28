# Validação manual — Login com Google e Facebook

> Branch: `feat/login-social-google-facebook`. Detalhes em
> `docs/features/login-social.md`.
>
> **Bloqueado até a configuração do Console** (checklist na mesma página).
>
> Testar com as duas assinaturas:
> - debug: `flutter run`;
> - upload: APK de release.
>
> Usar contas de teste do Google e do Facebook. Contas pessoais só se o
> proprietário quiser.

## Identificação

```text
Aparelho / Android:
Assinatura (debug / upload):
Build (commit):
App do Facebook instalado? (sim / não):
Data:
Testado por:
```

## Casos

| ID | Caso | Resultado |
|---|---|---|
| LS00 | **Antes da configuração:** tocar em Google e em Facebook mostra "ainda não está disponível nesta versão", sem fechar o app | |
| LS01 | Google, primeira vez: escolher a conta → Home; Editar perfil mostra nome e e-mail do Google, telefone vazio | |
| LS02 | Sair → Google de novo: o app pergunta a conta; entra na mesma conta, com os mesmos pets | |
| LS03 | Google: fechar o seletor de conta → volta ao Login sem mensagem | |
| LS04 | Facebook com o app do Facebook instalado → autorizar → Home | |
| LS05 | Facebook **sem** o app instalado → abre o navegador → autorizar → volta ao app → Home | |
| LS06 | Facebook: cancelar na tela de autorização → Login sem mensagem | |
| LS07 | Conta por e-mail existente + Facebook com o **mesmo e-mail** → diálogo "Você já tem uma conta" → senha certa → Home com os pets da conta de e-mail | |
| LS08 | Mesmo caso do LS07 com senha errada → "E-mail ou senha inválidos."; nada é vinculado | |
| LS09 | Depois do LS07: sair e entrar só com o Facebook → mesma conta e mesmos pets | |
| LS10 | Modo avião → tocar em Google → mensagem de conexão; o app não trava | |
| LS11 | Tocar várias vezes rápido no botão: um único seletor ou login | |
| LS12 | Enquanto o Google carrega, Facebook e ENTRAR ficam desabilitados | |
| LS13 | Tema do tutor Escuro → sair → Login continua na identidade original | |
| LS14 | Segundo plano durante o login (Home do Android) e volta: o login continua ou dá para tentar de novo | |
| LS15 | Outra conta (Google diferente) não vê os pets da primeira | |
| LS16 | APK de release (chave de upload) também entra com Google e Facebook (SHA de upload cadastrado) | |

Marcar `OK`, `FALHOU: <o que aconteceu>` ou `BLOQUEADO: <motivo>`.
