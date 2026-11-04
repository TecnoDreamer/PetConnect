# Validação manual — login obrigatório ao reabrir o app

> **Substituído em 2026-11-04.** A pedido do proprietário, a sessão volta a
> ficar guardada no aparelho e só termina em "Sair da conta"
> (`fix/sessao-persistente`). Este roteiro fica como histórico; o atual é
> o item DV05 de `docs/validation/device-validation-checklist.md`.

> Branch: `fix/login-inicial-obrigatorio`. Fonte:
> `petconnect_correcoes_pos_validacao_claude.md` (2026-09-12), Feature 1.
>
> O mecanismo (splash sempre aguarda o `signOut()` de bootstrap antes de
> decidir o destino) está coberto por teste automatizado
> (`test/features/auth/splash_screen_test.dart`). O que só dá pra provar
> num aparelho real é que o `FirebaseAuth` de fato esquece uma sessão
> persistida entre reaberturas — não é possível simular isso num teste de
> widget sem uma sessão real do SDK.

## Como testar

1. Fazer login normalmente no app.
2. Fechar o app **de verdade** (removê-lo da lista de apps recentes, não
   só minimizar) — em Android, isso encerra o processo.
3. Reabrir o app.

## Checklist

- [ ] App frio **com** sessão anterior → abre na tela de Login (não vai
      direto pra Home)
- [ ] App frio **sem** sessão (primeira instalação, ou depois de excluir
      dados do app) → abre na tela de Login
- [ ] Login com credenciais válidas → vai para a Home normalmente
- [ ] Login com credenciais inválidas → mensagem de erro, permanece no
      Login
- [ ] Sair da conta (Configurações → Sair da conta) → volta para o
      Login
- [ ] Depois de sair, reabrir o app → continua no Login (nunca volta
      pra Home sozinho)
- [ ] Cadastro de conta nova continua funcionando normalmente
- [ ] "Esqueci a senha" continua funcionando normalmente
- [ ] Nenhum "flash" da Home aparece por uma fração de segundo antes do
      Login, em nenhum dos casos acima

## Como reportar

Marcar `[x]` ou `FALHOU: <o que aconteceu>`. Se algo falhar, não mesclar
a PR até corrigir.
