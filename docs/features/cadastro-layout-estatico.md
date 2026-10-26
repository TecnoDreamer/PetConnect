# Correção definitiva da tela Criar conta: painel na frente e tela estática

> Branch: `fix/cadastro-sobreposicao-layout-estatico`. Fonte:
> `prompt_claude_opus_correcao_cadastro_petconnect.md` (2026-10-24), com
> as capturas do aparelho do solicitante (Login e Criar conta, 10:04).
> Substitui a tentativa da PR #64 (`fix/cadastro-tela-estatica-sem-scroll`),
> que nunca foi mesclada.

## Causa raiz (comprovada no código da branch-base)

Estrutura que estava em produção (`cadastro_screen.dart`):

```text
Scaffold > SafeArea > Column[
  _CadastroHeader (AnimatedContainer),
  Expanded > SingleChildScrollView > Transform.translate(0, -24) > painel
]
```

1. **O painel parecia atrás do marrom por recorte, não por z-index.**
   `Transform.translate` subia o painel 24px, mas ele continuava *dentro*
   do `SingleChildScrollView`, que recorta (`clipBehavior: Clip.hardEdge`,
   o padrão) tudo que sai da própria área. O pedaço que deveria invadir o
   cabeçalho era cortado exatamente na borda de baixo do marrom: é o
   que aparece na captura, com os cantos do painel sumindo sob o
   cabeçalho.
2. **O card se mexia porque a tela rolava de verdade.** O painel
   (5 campos, checklist e botão) era mais alto que a área do `Expanded`,
   então o `SingleChildScrollView` (física padrão) tinha rolagem real, e
   qualquer arrasto ou foco num campo (`ensureVisible`) deslocava o
   conteúdo.
3. **Agravantes:** o cabeçalho e o texto de apoio mudavam de tamanho com
   o teclado (`AnimatedContainer`/`AnimatedSize`/`AnimatedSwitcher`), e a
   checklist de senha aparecia/sumia com o foco. Tudo isso fazia o painel
   "pular".

A PR #64 trocou o recorte por `NeverScrollableScrollPhysics` +
`Transform.translate` no mesmo scroll do cabeçalho. Esse caminho é proibido
pelo documento-fonte (seção 5), porque disfarça o problema em vez de
resolvê-lo.

## Correção

### Composição: `_CabecalhoComPainel` (layout próprio, sem scroll)

Um `MultiChildRenderObjectWidget` com dois filhos, o cabeçalho e o painel:

1. Mede o **painel primeiro**, na altura natural dele.
2. Entrega ao **cabeçalho toda a altura que sobra** (com um mínimo), mais
   a faixa de sobreposição (32px).
3. Posiciona o painel começando 32px antes do fim do cabeçalho.
4. **Pinta o painel por último**, então ele fica na frente do marrom. O
   teste de toque segue a ordem inversa, então na faixa em comum o toque
   chega ao painel.

É exatamente a regra da seção 5: reservar o espaço do painel antes de
distribuir a altura ao cabeçalho. Não há `SingleChildScrollView`,
`Transform.translate`, `NeverScrollableScrollPhysics` nem valor absoluto
"mágico" de posição: a geometria sai das medidas reais de cada aparelho.

### Cabeçalho (`_CadastroHeader`)

- Recebe altura exata e acomoda o logo no que sobra: **mínimo 56px,
  máximo 160px** (o mesmo tamanho do Login). O conjunto logo + "PetConnect"
  fica centralizado na área marrom visível.
- Sem teto de altura: em telas altas a sobra vai para o marrom, nunca para
  uma faixa vazia embaixo do painel. O painel fica sempre ancorado 12px
  acima da barra de navegação.
- O botão Voltar fica posicionado no canto (não consome uma faixa de altura
  própria) e passou a ter a área de toque mínima de 48dp (antes, 44).
- Sem animações de geometria (removidos `AnimatedContainer`,
  `AnimatedSwitcher` e o modo "compacto" do teclado).

### Painel: alturas fixas, nada pula

- **Linha de erro reservada** em cada campo (`helperText: ' '`). O erro
  ocupa o mesmo espaço da linha de ajuda vazia, então mostrar ou esconder
  um erro não desloca nenhum campo.
- **Checklist de senha sempre visível**, com altura fixa. Os requisitos
  continuam iguais e os itens trocam de ícone e cor conforme são atendidos.
  Antes ela sumia quando a senha ficava válida, o que mudava a altura do
  painel.
- **Espaço fixo de 2 linhas** para o erro geral do cadastro (Firebase)
  acima do botão. O erro aparece sem empurrar o botão.
- **Texto de apoio sempre visível**, inclusive com o teclado aberto.
- **Botão** com altura mínima de 48dp (a mesma escolha do ENTRAR do
  Login). O loading troca só o conteúdo do botão, não o tamanho.
- Sombra suave igual à do card do Login, para reforçar o primeiro plano.

### Teclado aberto: exceção mínima documentada

A seção 5 permite uma adaptação mínima quando o formulário não cabe na
área acima do teclado, e ele **não cabe** em nenhum aparelho com o
teclado aberto (~300dp ocupados). A adaptação:

- Enquanto o teclado estiver aberto, a **mesma composição** (cabeçalho com
  a mesma altura da tela normal, nada encolhe) é colocada numa rolagem
  temporária. O Flutter rola só o necessário para o campo focado ficar
  visível acima do teclado.
- A composição muda de pai sem perder estado graças a uma `GlobalKey`:
  foco, cursor, texto e o teclado continuam abertos.
- **Ao fechar o teclado**, a rolagem é removida da árvore e a tela volta ao
  layout estático exato. Os testes comparam a posição de cada elemento
  antes e depois.

Isso **não** é "zero scroll em todas as circunstâncias". É a exceção que o
documento-fonte autoriza, limitada ao período em que o teclado está aberto.

### Aparelho muito baixo ou fonte muito ampliada: exceção documentada

Quando o painel não cabe nem com o cabeçalho no tamanho mínimo, a tela usa
a mesma rolagem de exceção **também sem teclado**, em vez de esconder
campos ou cortar conteúdo. Esse estado é detectado pelo próprio layout, que
mede o painel a cada quadro. A troca acontece no quadro seguinte, e nesse
único quadro o excedente fica recortado, sem erro de overflow.

> **Atualização (2026-10-26):** o layout `_CabecalhoComPainel` virou o
> componente compartilhado `ComposicaoCabecalhoPainel`
> (`lib/core/widgets/composicao_cabecalho_painel.dart`), também usado pelo
> Login. O comportamento do Cadastro não mudou.

## Medidas reais (Roboto, status bar 24dp + navegação de 3 botões 48dp)

| Viewport | Fonte 1.0 | Fonte 1.3 |
|---|---|---|
| 412×915 (o aparelho das capturas) | estática, logo 160 | estática, logo ~104 |
| 390×844 | estática, logo ~136 | rolagem de exceção (faltam ~22dp) |
| 360×800 | estática, logo ~92 | rolagem de exceção |
| 360×720 / 360×640 | rolagem de exceção | rolagem de exceção |
| 320×568 | rolagem de exceção | rolagem de exceção |

Com a navegação por gestos (barra de 24dp), sobram mais 24dp. Por exemplo,
390×844 em fonte 1.3 fica estática.

**Limitação a aprovar:** para caber estática em telas de ~720dp ou menos
(ou em 360×800 com fonte 1.3), seria preciso tirar a reserva das linhas de
erro (o que faz os campos pularem quando um erro aparece), esconder a
checklist ou reduzir os campos abaixo de 48dp. O documento-fonte proíbe as
três coisas. Por isso a escolha foi a rolagem de exceção, que é acessível.

## Arquivos modificados

- `lib/features/auth/presentation/screens/cadastro_screen.dart`:
  composição, cabeçalho, painel, `_CabecalhoComPainel`.
- `lib/features/auth/presentation/widgets/cadastro_text_field.dart`:
  linha de erro reservada, `isDense`, padding vertical de 12.
- `test/features/auth/cadastro_screen_test.dart`: testes novos (ver abaixo)
  e testes antigos ajustados à checklist sempre visível.
- `test/helpers/fonte_roboto.dart` (novo) e `test/fonts/` (Roboto
  regular/medium/bold, Apache 2.0): carrega a Roboto nos testes de
  geometria. Versionada no repositório porque o cache de fontes do
  Flutter SDK não existe na máquina do CI.

O Login e o `AuthHeader` compartilhado **não foram tocados**. Validação,
política de senha, integração Firebase/Spring, navegação e textos também
continuam iguais.

## Testes

Os testes de layout carregam a **Roboto real** (`test/helpers/fonte_roboto.dart`).
A fonte padrão do `flutter test` ("FlutterTest") desenha cada caractere
com 1em de largura, quebra em várias linhas textos que cabem numa linha no
aparelho e distorce qualquer medida de altura.

Cobertura nova em `cadastro_screen_test.dart`:

- 360×800, 390×844 e 412×915: nenhum `SingleChildScrollView`/`ListView`/
  `CustomScrollView`, tudo dentro da área útil (fora da status bar e da
  barra de navegação) e sem overflow. 412×915 também com fonte 1.3.
- O painel invade o cabeçalho, e um teste de toque na faixa em comum
  confirma que o painel está na frente (o cabeçalho nem é consultado).
- O logo não sobrepõe o Voltar, e o Voltar tem pelo menos 48×48.
- Nada se move ao focar cada campo, ao mostrar/ocultar a senha, ao exibir
  erros de validação, ao exibir o erro geral nem durante o loading
  (comparação da posição exata de cabeçalho, painel, logo, título, cada
  campo, checklist e botão).
- Teclado aberto: cada um dos 5 campos continua focado e visível acima do
  teclado, e o cabeçalho não encolhe. Ao fechar, a rolagem some e o layout
  volta exatamente ao original.
- Exceções (320×568 em fonte 1.0, 360×800 em 1.3, 320×480 em 1.6): sem
  overflow, todos os campos alcançáveis e focáveis, e o botão alcançável.
- O Voltar retorna para a tela anterior.

Golden tests não foram adicionados: a renderização de texto e sombra difere
entre Windows (desenvolvimento) e Linux (CI), e isso deixaria o teste
instável. A sobreposição é verificada por geometria e por teste de toque.

## Riscos

- **Troca de pai ao abrir o teclado:** coberta por teste (foco preservado
  nos 5 campos). Num aparelho real, vale observar se o teclado "pisca" ao
  abrir. Não deveria, porque o estado do campo é preservado.
- **Fontes do fabricante:** aparelhos com fonte do sistema diferente da
  Roboto podem ter medidas um pouco diferentes. O layout se adapta
  sozinho, cabendo estático ou ativando a exceção, sem quebrar.

## Rollback

Reverter o merge. A mudança é só de apresentação, sem dados, rotas ou
autenticação envolvidos.

## Validação manual

Ver `docs/validation/cadastro-layout-estatico.md`.
