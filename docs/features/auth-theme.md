# Telas de autenticação imunes ao tema do tutor

> Branch: `fix/auth-tema-identidade-original`. Fonte:
> `prompt_claude_opus_tema_auth_memorial_pet.md` (Entrega A, 2026-10-24).
> Decisão registrada em `docs/decisions/0001-tema-fixo-autenticacao.md`.

## Defeito

Depois de ativar o tema **Escuro** e sair da conta, a tela de Login abria
com os campos pretos, quebrando a identidade da autenticação (cabeçalho
marrom, card branco, campos claros).

## Causa raiz

Fluxo: `tema escuro → logout → redirect para /login → rebuild`.

1. O app tem um único `theme:` dinâmico (`app.dart` →
   `AppTheme.build(modo)`), aplicado a **todas** as rotas, inclusive as de
   autenticação.
2. Os `TextField` do Login não definem `fillColor`/`filled` próprios. Eles
   herdam `inputDecorationTheme` (`filled: true`, `fillColor:
   palette.surface`), e no Escuro `palette.surface` é escuro. **O fundo
   preto vinha do `fillColor` herdado do tema global.**
3. O texto digitado herda `textTheme.bodyColor = palette.textPrimary`,
   que é claro no Escuro. Os botões sociais (`OutlinedButton`) herdam
   `palette.surface` como fundo, o "Esqueceu a senha?" herda o
   `textButtonTheme`, e o cursor e a seleção herdam o `colorScheme`
   escuro.
4. A status bar seguia o `AnnotatedRegion` global (ícones brancos no
   Escuro) sobre o fundo branco das telas de autenticação, o que deixava
   os ícones invisíveis.
5. O Cadastro e o Esqueci senha têm o mesmo problema em menor grau: o
   `CadastroTextField` fixa `fillColor` branco, mas o rótulo flutuante e
   outros elementos ainda herdam o tema.

O logout não tinha nada a ver com o problema. A preferência continua em
Escuro, como deve ser, e o Login simplesmente herdava o tema global.

## Correção

- **`AppTheme.autenticacao()`**: o tema completo do modo **Padrão**, que é
  a identidade original (o mesmo usado por `AppColors`, que as telas de
  autenticação já liam). Os tokens já existentes foram reaproveitados, sem
  paleta nova.
- **`AuthThemeScope`** (`lib/features/auth/presentation/widgets/`):
  aplica esse tema **só à subárvore** da tela de autenticação e fixa a
  status bar com ícones escuros.
- **`lib/routing/auth_routes.dart`**: as três rotas de autenticação
  (`/login`, `/cadastro`, `/esqueci-senha`) são declaradas num único lugar
  e envolvidas pelo `AuthThemeScope`. O `app_router.dart` passa a usar
  `buildAuthRoutes()` e `authRoutePaths`, então o redirect e as rotas
  continuam iguais.

**O que não mudou:**

- A preferência de tema não é apagada no logout. Ela continua salva
  (`shared_preferences`, chave `tema_app`) e volta a valer na área logada
  ao entrar de novo.
- O tema global, a Home e as demais telas autenticadas não foram tocados.
- Layout, textos, fluxo do Firebase Auth e `go_router` também continuam
  iguais. Nenhuma tela de autenticação foi editada, o que evita conflito
  com a PR #68 (layout do Cadastro).
- Dialogs abertos a partir dessas telas herdam o tema correto, porque
  `showDialog` captura o `Theme` do contexto que o abre.

## Testes (`test/features/auth/auth_theme_test.dart`)

Usam as **rotas reais** (`buildAuthRoutes()`) e o mesmo arranjo de
`app.dart` (um `theme:` dinâmico pelo `themeModeProvider`):

- Login, Cadastro e Esqueci senha com a preferência salva em Padrão,
  Claro e Escuro (9 casos): paleta Padrão, brilho claro, fundo do campo
  claro, texto digitado escuro e status bar com ícones escuros.
- Escuro → logout → login: a área logada usa a paleta Escuro, o login abre
  claro, a preferência continua `escuro` no `SharedPreferences` e no
  provider, e ao entrar de novo a área logada volta ao Escuro.
- Troca repetida de tema com o login aberto, sem efeito no login.
- Navegação login ↔ cadastro ↔ esqueci senha no Escuro.
- No Escuro, sem overflow em 320×568, 360×800, 390×844 e 412×915, com
  fonte 1.0 e 1.3, e com o teclado aberto e fechado. A exceção é o
  Cadastro com teclado: o cabeçalho compacto do layout atual estoura na
  horizontal com fonte ampliada, independentemente do tema, e esse layout
  é substituído pela PR #68.

Verificação de mutação: sem o `AuthThemeScope`, os casos de Login e
Esqueci senha no Escuro falham.

## Limitações

- Não foi validado em aparelho físico (ver
  `docs/validation/auth-theme.md`). Hot restart e cold start também não
  foram testados em dispositivo. O tema vem de `SharedPreferences` lido
  em `main()` e não há estado em memória específico desta correção, então
  o resultado deve ser o mesmo após reabrir o app.
- A splash (`/`) não faz parte desta correção: ela usa cores fixas
  (`AppColors.brandGradient`) e não herda campos do tema.

## Rollback

Reverter o merge. Volta a herdar o tema global, sem dados ou preferências
envolvidos.
