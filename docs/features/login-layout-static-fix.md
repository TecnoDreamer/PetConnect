# Correção do layout da tela de Login: sobreposição e estabilidade

> Branch: `fix/login-card-sobreposicao-estatica`. Fonte:
> `prompt_correcao_layout_login_estatico.md` (2026-09-14). Correção
> visual de alta fidelidade — não um redesign (regra explícita do
> documento-fonte).

## Diagnóstico (seção 32 do documento-fonte, respondido antes de implementar)

1. **Arquivo da tela**: `lib/features/auth/presentation/screens/login_screen.dart`.
2. **Estrutura atual**: `Scaffold > SafeArea(bottom: false) >
   SingleChildScrollView > Column [AuthHeader, Padding(Transform.translate
   (offset: (0,-32), child: Column[_LoginCard, _SocialLoginRow,
   _SignUpPrompt]))]`. `AuthHeader` (`core/widgets/auth_header.dart`) é
   compartilhado com Esqueci senha.
3. **Existe `Stack`?** Só dentro do próprio `AuthHeader` (para o padrão de
   patinhas no fundo do cabeçalho) — não na composição
   header/card/footer da tela de Login em si.
4. **Existe clipping?** Só o `ClipRRect` interno do `AuthHeader` (cantos
   arredondados do próprio cabeçalho) — nada cortando o card.
5. **Existe animação estrutural?** Não — sem
   `AnimatedContainer`/`AnimatedPositioned`/`TweenAnimationBuilder` nesta
   tela.
6. **O teclado altera a posição?** Não há lógica própria de teclado
   (diferente do Cadastro, que ganhou um cabeçalho compacto reativo ao
   teclado em outra correção) — o `SingleChildScrollView` já existia,
   mas sem `physics` definida (herdava o padrão da plataforma).
7. **Causa exata do card "ficar atrás"**: não é um bug de z-order —
   `Column` sempre pinta os filhos depois por cima dos de antes, então o
   card (segundo filho, com `Transform.translate` negativo) já pintava
   por cima do cabeçalho. A causa real é a mesma da seção seguinte:
   **overflow genuíno de rolagem**. Como cabeçalho e card ficam dentro do
   *mesmo* `SingleChildScrollView` (diferente do Cadastro, onde só o
   card rola), eles se movem juntos como um bloco rígido — mas como o
   card tinha overflow real e nenhuma trava de física, arrastar a tela
   descolava visualmente a composição da posição de repouso onde a
   sobreposição tinha sido desenhada, dando a impressão de estar "atrás".
8. **Causa exata do movimento**: `SingleChildScrollView` sem
   `physics: NeverScrollableScrollPhysics()` — a tela dependia de
   rolagem de verdade para caber, então qualquer toque/arrasto movia o
   conteúdo. Medido com precisão
   (`ScrollPosition.maxScrollExtent`, simulando status bar + barra de
   gestos): **226px de overflow em 360×800**, um dos tamanhos de
   aparelho mais comuns do mercado.
9. **Arquivos modificados**:
   - `lib/features/auth/presentation/screens/login_screen.dart`
   - `lib/core/widgets/auth_header.dart` (só padding — ver seção
     "Por que tocar em um arquivo compartilhado" abaixo)
10. **Testes planejados**: novo
    `test/features/auth/login_screen_test.dart` cobrindo layout estático
    (rolagem zero nos tamanhos comuns), sobreposição, comportamento de
    teclado, e os 5 estados da seção 25 do documento-fonte (normal,
    loading, erro, senha visível/oculta) — nenhum deles pode mover o
    card.

## Correção aplicada

### 1. Compactação de espaçamento (não da identidade visual)

Reduzidos: padding do `AuthHeader` (topo/base), espaço após o logo,
padding interno do card, espaço entre título/campos/botão, densidade dos
campos (`isDense` + `contentPadding` menor), espaço entre
card/social/cadastro, e a altura mínima do botão "ENTRAR" (56 → 48, só
nesta tela, via `Theme` local — não afeta nenhum outro botão do app).

**Nada do seguinte foi alterado**, conforme a regra principal do
documento-fonte (seção 3): logo (tamanho/imagem), cores, textos,
integração Firebase, validações, rotas, fluxo de autenticação.

### 2. Sobreposição um pouco maior (32px → 48px)

O card agora invade um pouco mais a base da área marrom — ajuda a caber
sem rolar e deixa a sobreposição mais nítida (seção 14 do
documento-fonte: "a sobreposição precisa parecer proposital").

### 3. `physics: NeverScrollableScrollPhysics()`

Garantia dura: a tela nunca pode ser arrastada, em nenhuma circunstância
— mesmo numa combinação futura ainda mais extrema (fonte do sistema
muito ampliada + aparelho muito pequeno), o conteúdo residual é cortado
embaixo, nunca vira arrastável.

## Por que tocar em `auth_header.dart` (arquivo compartilhado)

O documento-fonte pede correção *exclusiva* da tela de Login, mas o
cabeçalho (`AuthHeader`) é compartilhado com Esqueci senha. Sem reduzir
o *padding* (nunca o logo/texto/cor) do próprio `AuthHeader`, não havia
orçamento de altura suficiente para eliminar o overflow nos tamanhos de
aparelho exigidos pela seção 22 — o cabeçalho sozinho (padding + logo
160px + título + slogan) já consumia mais de 300px antes desta
correção. A mudança é estritamente de espaçamento, então o efeito em
Esqueci senha é estritamente positivo (mais espaço sobrando, nunca
menos) — essa tela não foi testada/validada nesta branch por estar fora
do escopo pedido, mas não há razão para regressão.

## Limitação aceita e documentada: 320×568

Em 320×568 (aparelho pequeno/antigo, ex.: iPhone SE 1ª geração), mesmo
depois de toda a compactação possível, ainda restam ~222px de conteúdo
que não cabe (era 458px antes da correção — redução de ~52%). A causa é
estrutural: só o logo (160px, que a seção 3 proíbe explicitamente
alterar) já ocupa ~28% da altura total da tela nesse tamanho. A tela
**continua 100% estática** mesmo aqui — graças ao
`NeverScrollableScrollPhysics()`, o conteúdo excedente é cortado
silenciosamente embaixo, nunca fica arrastável — mas nem todo o
conteúdo é visível sem alterar o logo. Documentado explicitamente em vez
de escondido.

## Testes

- `flutter analyze` — sem apontamentos.
- `dart format --output=none --set-exit-if-changed .` — sem mudanças.
- `flutter test test/core/ test/features/pet/ test/features/auth/
  test/features/usuario/ --exclude-tags=e2e` — 168 testes, todos
  passando.
- Novo `login_screen_test.dart` (12 testes): rolagem zero em 360×800/
  390×844/412×915; física sempre `NeverScrollableScrollPhysics` mesmo em
  320×568; card sobreposto na frente do cabeçalho (comparação de
  posição Y); campos acessíveis com foco no e-mail/senha; posição exata
  restaurada ao fechar o teclado; ordem vertical dos elementos na
  renderização normal; alternar visibilidade da senha não move o card;
  loading não reposiciona; erro de login não move o título do card.

## Riscos ou pendências

- Esqueci senha (mesmo `AuthHeader`) não foi formalmente validada nesta
  branch — só ganhou mais espaço (mudança estritamente aditiva), risco
  de regressão avaliado como muito baixo.
- 320×568 continua com conteúdo que não cabe totalmente na tela (ver
  seção acima) — aceito conscientemente dado o limite de não alterar o
  logo.

## Rollback

Reverter o merge. Nenhuma mudança de dado, rota ou autenticação —
reversão é puramente visual/estrutural.

## Validação manual

Ver `docs/validation/login-layout-static.md`.
