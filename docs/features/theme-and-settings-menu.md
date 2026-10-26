# Temas globais (Padrão/Claro/Escuro) e padronização dos menus de configurações

> Branch: `feat/tema-e-menus-configuracoes`. Fonte:
> `prompt_tema_e_menus_configuracoes_petconnect.md` (2026-09-13). Referência
> de estrutura (só estrutura, não identidade visual): print do app Inter,
> "Explorar produtos" (ícone + título + chevron, sem subtítulo).

## Auditoria (antes de implementar)

1. **`ThemeData` hoje**: um único `AppTheme.light()`, com `ColorScheme.fromSeed`.
2. **Cores hoje**: `AppColors` (`static const`), sem `ColorScheme` dinâmico.
3. **`ColorScheme`?**: só o gerado por `fromSeed` dentro de `AppTheme.light()`.
4. **Persistência local?**: nenhuma (`shared_preferences`/`hive` não estavam
   no projeto) — adicionado `shared_preferences`.
5. **Telas de configurações**: `ConfiguracoesScreen` (tutor) e
   `PetSettingsScreen` (pet), ambas com `ListTile` cru e subtítulo.
6. **Componente de menu**: não existia.
7. **Descrições atuais**: sim, em ambas as telas — removidas dos itens de
   navegação (mantidas só na confirmação de exclusão, que já existia).
8. **Hardcodes**: `AppColors.` aparecia em 34 arquivos — praticamente toda
   a UI. Ver "Telas migradas" e "Hardcodes restantes" abaixo pro recorte
   desta etapa.
9. **`MaterialApp.router`**: só `theme:`, sem `darkTheme`/`themeMode`.
10. **Testes de tema/configurações existentes**: nenhum.

## Estratégia de tema

Três modos (`AppThemeMode`: `padrao`/`claro`/`escuro`) — "Padrão" é a
identidade visual oficial do PetConnect, não "seguir o sistema".

- `AppPalette` (`core/theme/app_palette.dart`) — um `ThemeExtension` com os
  tokens que variam por modo (`background`, `surface`, `cardBackground`,
  `textPrimary`, `textMuted`, `textOnBrand`, `brandDark/Medium/Light`,
  `error`, `success`, `divider`, `petCardBackgrounds`, `petCardAccents`).
  Acesso sempre via `context.colors` (extensão em `BuildContext`).
- `AppTheme.build(AppThemeMode)` monta um `ThemeData` completo por modo,
  registrando a paleta correspondente como `extensions: [...]` — telas
  migradas reagem sozinhas à troca de tema.
- `AppTheme.light()` continua existindo (usado em testes anteriores a esta
  etapa) — é só um alias de `build(AppThemeMode.padrao)`, com um `assert`
  em debug garantindo que `AppPalette.padrao` nunca se desalinhe de
  `AppColors` (a identidade visual atual não pode ser destruída por
  engano).
- `MaterialApp.router` recebe um único `theme:` dinâmico (não
  `theme`/`darkTheme`/`themeMode` do Flutter — são três modos, não dois).

## Padrão

Cópia literal dos valores de `AppColors` — o mesmo visual de sempre.

## Paleta Claro

Fundo neutro claro (`#F7F7F5`), cards brancos, texto quase-preto
(`#231A13`), cor de marca preservada como destaque (`brandDark`
inalterado). Cards de pet em tons pastel mais neutros que o Padrão.

## Paleta Escuro

Desenhada de verdade, não é uma inversão preto/branco automática: fundo
quase-preto com leve tom quente (`#15100C`), superfícies elevadas mais
claras que o fundo (`#241C15`), texto em tom creme (`#F3E9DF`, nunca preto
puro em fundo escuro), cor de marca clareada para `brandDark`/`brandMedium`
(`#A47854`/`#8A6245`) — a versão escura do marrom original ficaria quase
invisível num fundo quase-preto —, erro e sucesso mais saturados/claros
pra continuar legíveis, cards de pet em tons escuros próprios (não os
pastéis do Padrão/Claro escurecidos por instinto).

## Persistência

`shared_preferences`, chave `tema_app`, valor = `AppThemeMode.name`.
`ThemeModeController` (`StateNotifier`) lê na inicialização e grava a cada
troca. Sem preferência salva (todo usuário antes desta versão) começa
sempre em Padrão — nunca migra sozinho pra Claro/Escuro. Valor corrompido/
desconhecido também cai em Padrão (não quebra).

## Componente compartilhado de menu

`SettingsMenuTile` (`core/widgets/settings_menu_tile.dart`) — ícone,
título, chevron (ou `trailing` customizado), toda a linha clicável (altura
mínima 56, acima do mínimo de 48 exigido), suporte a `isDestructive`,
`isEnabled` e `semanticLabel` próprio. `SettingsSectionHeader` para
títulos de seção (PERFIL/APLICATIVO/CONTA). Usado em `ConfiguracoesScreen`,
`PetSettingsScreen` e `PetSecondaryActions` (as ações secundárias do
perfil do pet já seguiam esse padrão, agora usam o componente de verdade
em vez de uma versão própria quase idêntica).

> **Atualização (2026-10-25):** Login, Cadastro e Esqueci senha **não**
> respondem ao tema do tutor: usam sempre o tema Padrão via
> `AuthThemeScope` (ver `docs/features/auth-theme.md`).

> **Atualização (2026-10-27):** o tema **Claro** passa a ser o tema
> principal. Sem preferência salva (ou com valor inválido), o app abre no
> Claro, e quem já escolheu um modo continua nele. No Claro o fundo é
> sempre branco (`background` e `homeBackdrop`), com campos (`surface`
> `#F4F4F2`) e cartões (`cardBackground` `#F6F6F4`) em cinza bem claro para
> continuarem visíveis sobre o branco. As telas ainda não migradas
> (vacinas, consultas, histórico e localização, issue #56), que usavam
> `AppColors.background` (bege) fixo, passam a usar fundo branco.
> Login, Cadastro e Esqueci senha continuam com a identidade fixa (ADR
> 0001), já com fundo branco.

## Telas migradas (respondem ao tema)

Núcleo do tema + os dois menus de configurações + toda a stack do perfil
do pet (é o que este pedido toca de verdade) + Home + edição de perfil do
tutor:

`app_theme.dart`, `app_palette.dart`, `app_theme_mode.dart`,
`theme_providers.dart`, `tema_screen.dart`, `settings_menu_tile.dart`,
`configuracoes_screen.dart`, `pet_settings_screen.dart`,
`pet_detail_screen.dart`, `pet_profile_header.dart`, `pet_avatar.dart`,
`pet_cover_image.dart` (fundo/placeholder — o gradiente de fallback da
capa fica fixo em todo modo, é um momento de marca, não conteúdo),
`pet_feature_card.dart`, `pet_feature_grid.dart`,
`pet_secondary_actions.dart`, `pet_card.dart`, `pet_qr_code.dart` (o fundo
branco do próprio QR fica fixo — requisito técnico de contraste pra
leitura por câmera, não escolha de estilo), `cover_position_editor.dart`,
`home_screen.dart`, `editar_perfil_screen.dart`, `pet_form_screen.dart`,
`avatar_picker.dart`.

`fullscreen_image_viewer.dart` não precisou de mudança — já era
preto/branco fixo de propósito (convenção universal de visualizador de
imagem, como Google Fotos/Instagram), independente de tema.

## Hardcodes restantes (não migrados nesta etapa)

Continuam com a aparência do modo Padrão sempre, independente do tema
escolhido — decisão deliberada de escopo (seção 14 do documento-fonte
autoriza explicitamente não migrar tudo de uma vez):

- `splash_screen.dart`, `auth_header.dart` — momento de marca, decisão
  similar ao gradiente da capa.
- `login_screen.dart`, `cadastro_screen.dart`, `esqueci_senha_screen.dart`
  — fluxo de autenticação.
- Vacina/Consulta/Histórico/Localização — telas de lista e formulário, e
  seus tiles (`vacina_tile.dart`, `consulta_tile.dart`,
  `historico_tile.dart`, `localizacao_tile.dart`).

**Risco assumido**: navegar de uma tela migrada (ex.: perfil do pet, em
Escuro) para uma dessas ainda mostra o visual Padrão — inconsistência
visual conhecida, não um bug. Fica como próxima etapa de migração (issue
de backlog criada).

## Segurança

Nenhuma mudança de autorização, rota ou provider de dados — só
apresentação. Trocar tema não refaz login, não recarrega API, não perde
rota nem o pet selecionado (nenhum repository/provider de dado depende de
`themeModeProvider`).

## Acessibilidade

Seletor de tema nunca depende só de cor: ícone de check + `Semantics`
("Tema Escuro, selecionado"). `SettingsMenuTile` com touch target ≥48,
`Semantics` próprio, estado destrutivo/desabilitado comunicado além da
cor.

## Performance

Trocar o tema só reconstrói a árvore visual (novo `ThemeData`) — nenhuma
chamada de API, login ou navegação é refeita.

## Testes

- `flutter analyze` — sem apontamentos.
- `flutter test test/core/ test/features/pet/ test/features/auth/
  test/features/usuario/ --exclude-tags=e2e` — ver relatório da PR pro
  número exato.
- Novo: `theme_providers_test.dart` (padrão inicial, persistência de cada
  modo, restauração após "reabrir o app", valor corrompido cai em
  Padrão), `settings_menu_tile_test.dart`, `tema_screen_test.dart`,
  `configuracoes_screen_test.dart` (não existia nenhum teste desta tela
  antes), extensão de `pet_settings_screen_test.dart` (sem subtítulo).

## Rollback

Reverter o merge. A preferência de tema salva localmente fica órfã
(chave `tema_app` no `SharedPreferences` do aparelho) sem quebrar nada —
a versão anterior do app simplesmente ignora essa chave.

## Validação manual

Ver `docs/validation/theme-and-settings-menu.md`.
