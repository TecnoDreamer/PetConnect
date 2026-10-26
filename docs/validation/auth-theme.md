# Validação manual — autenticação imune ao tema do tutor

> Branch: `fix/auth-tema-identidade-original`. Detalhes em
> `docs/features/auth-theme.md`.

## Identificação

```text
Aparelho / Android:
Build (commit):
Data:
Testado por:
```

## Roteiro

1. Entrar na conta → Configurações → Tema → **Escuro**.
2. Sair da conta.
3. Conferir o Login, abrir Cadastro e Esqueci senha, e voltar.
4. Fechar o app por completo e abrir de novo (cold start).
5. Entrar na conta e conferir que a área logada voltou ao Escuro.
6. Repetir com **Claro** e **Padrão**.

## Checklist

```text
[ ] Login após logout no Escuro: campos claros, texto escuro legível
[ ] Card branco, cabeçalho marrom, botão ENTRAR marrom
[ ] "Esqueceu a senha?", Google/Facebook e "Cadastre-se" legíveis
[ ] Ícones da status bar visíveis (escuros) nas telas de autenticação
[ ] Cadastro e Esqueci senha com a mesma identidade
[ ] Senha visível/oculta funciona; foco e teclado não mudam as cores
[ ] Erro de login e loading com cores corretas
[ ] Depois de fechar e reabrir o app, o Login continua claro
[ ] Ao entrar de novo, a área logada respeita o tema escolhido
[ ] O tema escolhido continua marcado em Configurações → Tema
```

Marcar `[x]` ou `FALHOU: <o que aconteceu>`.
