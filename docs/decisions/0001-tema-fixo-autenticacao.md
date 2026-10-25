# ADR 0001 — Tema fixo nas telas de autenticação

- **Status:** proposta (PR `fix/auth-tema-identidade-original`, aguardando
  aceite)
- **Data:** 2026-10-25

## Contexto

O app tem três modos de aparência (Padrão, Claro, Escuro) escolhidos pelo
tutor e aplicados por um único `theme:` dinâmico no `MaterialApp`. As
telas de autenticação (Login, Cadastro, Esqueci senha) foram desenhadas
com a identidade original e parte delas lê cores fixas (`AppColors`), mas
os campos, botões e textos herdam o tema global. No Escuro, isso deixava
os campos do Login pretos. O caso mais visível era logo após o logout,
quando a preferência continua em Escuro.

## Decisão

As telas de autenticação usam **sempre o tema do modo Padrão**
(`AppTheme.autenticacao()`), aplicado só à subárvore delas pelo
`AuthThemeScope`, nas rotas declaradas em `lib/routing/auth_routes.dart`.

## Alternativas descartadas

- **Resetar a preferência para Padrão no logout:** apaga uma escolha do
  usuário para contornar um problema visual, e o próximo login abriria no
  tema errado.
- **Fixar cores literais em cada campo das telas de autenticação:**
  espalha cores e é frágil, porque qualquer widget novo voltaria a herdar
  o tema global.
- **Criar uma paleta exclusiva de autenticação:** duplicaria a paleta
  Padrão, que já é a identidade original.

## Consequências

- Antes do login, a identidade visual é sempre a mesma, em qualquer
  preferência.
- O tutor que prefere o Escuro vê as telas de autenticação claras. Isso é
  intencional: a autenticação é o "cartão de visita" da marca e acontece
  antes de qualquer contexto de usuário.
- Se um dia houver uma versão escura aprovada das telas de autenticação,
  basta mudar `AppTheme.autenticacao()`.
