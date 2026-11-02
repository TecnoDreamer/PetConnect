# Login: layout distribuído na altura da tela

> Branch: `fix/login-layout-distribuido` (2026-10-26). Pedido: print do
> aparelho (≈412×915) com todos os elementos agrupados no topo e cerca de
> 30% da tela vazia embaixo.

> **Atualização (2026-10-27):** o rodapé deixou de ficar ancorado embaixo
> e passou a acompanhar o card. Ver
> `docs/features/login-espacamento-acoes-sociais.md`.

## Causa raiz

O layout da correção anterior (`docs/features/login-layout-static-fix.md`)
empilhava cabeçalho e card numa `Column` de altura fixa, dentro de um
`SingleChildScrollView` travado com `NeverScrollableScrollPhysics`. O card
subia 48px com `Transform.translate`. Esse arranjo tinha dois problemas:

1. **Sobra sempre embaixo.** Nada distribuía a altura disponível: em telas
   mais altas que 360×800, toda a diferença virava uma faixa branca abaixo
   de "Cadastre-se".
2. **O slogan ficava atrás do card.** O `Transform` de 48px cobria a última
   linha do cabeçalho, "Conectando corações perdidos aos seus lares",
   visível no print.

## Correção

- **`ComposicaoCabecalhoPainel`** (`lib/core/widgets/`): o layout criado
  para o Cadastro (`docs/features/cadastro-layout-estatico.md`) virou um
  componente compartilhado, com um **rodapé opcional**. Ele mede o card e
  o rodapé, e divide a altura que sobra:
  - **50% para o cabeçalho**: a área marrom cresce, com logo, nome e
    slogan centralizados;
  - **50% entre o card e o rodapé**.

  O rodapé (Google/Facebook + "Cadastre-se") fica **ancorado embaixo**,
  16px acima da barra de navegação, e o card continua 32px na frente do
  cabeçalho.
- **`AuthHeader(sobreposicao: …)`**: modo novo, usado só pelo Login. O
  conteúdo termina acima da faixa coberta pelo card, então o slogan nunca
  é coberto. Esqueci senha continua usando o modo anterior, sem nenhuma
  mudança.
- **Erro de login com espaço reservado** (2 linhas): a mensagem aparece sem
  mudar a altura do card. Sem isso, a composição redistribuiria a sobra e
  o card subiria um pouco a cada erro.
- **Cadastro** passou a usar o mesmo componente, com o mesmo comportamento
  e os 34 testes inalterados.
- **Teclado:** o componente lê os insets da `View`. O `Scaffold` remove os
  insets do `MediaQuery` que entrega ao `body`, e sem isso a composição
  não perceberia o teclado.

O logo, as cores, os textos, o fluxo do Firebase Auth e a navegação
continuam iguais.

## Exceções (as mesmas do Cadastro)

- **Teclado aberto:** rolagem temporária com o cabeçalho na mesma altura,
  só para manter o campo focado visível. Ao fechar, o layout volta ao
  exato.
- **Aparelho muito baixo (ex.: 320×568) ou fonte muito ampliada:** se
  nem com o cabeçalho no mínimo o conteúdo cabe, a tela usa a rolagem de
  exceção. Antes, o excedente era cortado e ficava inacessível.

## Testes (`test/features/auth/login_screen_test.dart`, Roboto real)

- 360×800, 390×844 e 412×915: nenhum `SingleChildScrollView`/`ListView`;
  logo, nome, slogan, card, "Esqueceu a senha?", Google, Facebook e
  "Cadastre-se" dentro da área útil; rodapé ancorado embaixo (no máximo
  20px até a barra de navegação).
- O slogan nunca fica atrás do card (360×800 e 412×915). Esse teste falha
  no layout anterior.
- O card fica na frente do cabeçalho, verificado por teste de toque.
- 320×568: sem overflow e com e-mail, ENTRAR e "Cadastre-se" alcançáveis.
- Os testes anteriores continuam valendo: teclado, mostrar/ocultar senha,
  loading e erro sem mover o card.

## Campos do mesmo tamanho (2026-11-02)

**Problema:** o campo de senha era mais alto que o de e-mail.

**Causa:** o botão de mostrar/ocultar senha (`IconButton` no `suffixIcon`)
reservava 48 × 48, o alvo de toque padrão do Material, e o `InputDecorator`
também exige 48 de altura mínima para ícones laterais. O campo de e-mail,
denso, tem 42 com a fonte padrão. Medido com a Roboto a 390×844:

| | E-mail | Senha |
|---|---|---|
| Antes | 286 × 42 | 286 × 48 |
| Depois | 286 × 42 | 286 × 42 |

**Correção** (só no campo de senha, `login_screen.dart`):
`suffixIconConstraints` de 48 × 40 e o `IconButton` com 48 × 40, sem
padding e sem a área de toque extra (`MaterialTapTargetSize.shrinkWrap`).

**O que não mudou:**
- o campo de e-mail;
- o ícone e o que ele faz;
- o espaço entre os campos e até o botão ENTRAR;
- cores, bordas, fontes e o resto da tela.

Como o card ficou 6 px mais baixo, o layout distribuído desloca o
conteúdo em cerca de 3 px. Isso foi conferido comparando capturas de antes
e depois.

**Acessibilidade:** o botão do olho passa a ter área de toque de 48 × 40
(antes, 48 × 48). Fica abaixo dos 48 × 48 recomendados na altura; tocar
logo acima ou abaixo dele foca o campo de senha.

**Testes:** grupo "e-mail e senha do mesmo tamanho" em
`login_screen_test.dart`. Ele confere largura, altura e alinhamento iguais
em 360×800 e 412×915, inclusive com fonte 1,3×, com foco, senha visível e
mensagem de erro. Também confere que mostrar/ocultar senha continua
funcionando. Antes da correção, a altura diferia em 6 px.

## Rollback

Reverter o merge. A mudança é só de apresentação.
