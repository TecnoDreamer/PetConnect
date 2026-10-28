# Validação manual — Login com Google

> Branch: `feat/login-social-google-facebook`. Detalhes em
> `docs/features/login-social.md`. O Facebook saiu do escopo (2026-10-27).
>
> Pré-requisitos (feitos em 2026-10-27):
> - provedor Google ativado no Firebase;
> - SHA-1 e SHA-256 de debug e upload cadastradas;
> - `google-services.json` novo em `android/app/`.
>
> Testar com as duas assinaturas:
> - debug: `flutter run`;
> - upload: APK de release.

## Identificação

```text
Aparelho / Android:
Assinatura (debug / upload):
Build (commit):
Data:
Testado por:
```

## Casos

| ID | Caso | Resultado |
|---|---|---|
| LS01 | "Entrar com Google", primeira vez: escolher a conta → Home; Editar perfil mostra nome e e-mail do Google, telefone vazio | |
| LS02 | Sair → "Entrar com Google" de novo: o app pergunta a conta; entra na mesma conta, com os mesmos pets | |
| LS03 | Fechar o seletor de conta → volta ao Login sem mensagem | |
| LS04 | Conta Google com outro e-mail → outra conta PetConnect, sem os pets da primeira | |
| LS05 | Conta por e-mail e senha existente + Google com o **mesmo e-mail**: entra na mesma conta (os mesmos pets), direto ou pelo diálogo "Você já tem uma conta" com a senha certa | |
| LS06 | Mesmo caso do LS05, se aparecer o diálogo: senha errada → "E-mail ou senha inválidos."; nada é vinculado | |
| LS07 | Depois do LS05: sair e entrar só com o Google → mesma conta e mesmos pets; entrar por e-mail e senha também funciona, se a senha foi mantida | |
| LS08 | Modo avião → "Entrar com Google" → mensagem de conexão; o app não trava | |
| LS09 | Tocar várias vezes rápido no botão: um único seletor | |
| LS10 | Enquanto o Google carrega, ENTRAR fica desabilitado | |
| LS11 | Tema do tutor Escuro → sair → o Login continua na identidade original | |
| LS12 | Segundo plano durante o seletor (Home do Android) e volta: dá para continuar ou tentar de novo | |
| LS13 | APK de release (chave de upload) também entra com Google | |

Marcar `OK`, `FALHOU: <o que aconteceu>` ou `BLOQUEADO: <motivo>`.
