# Login: ações sociais junto do card

> Branch: `fix/login-espacamento-acoes-sociais` (2026-10-27). Pedido: print
> do aparelho com um vão grande entre o card de login e os botões Google e
> Facebook, que ficavam colados na base da tela junto com "Cadastre-se".

> **Atualização (2026-10-27):** o Facebook saiu do escopo
> (`docs/features/login-social.md`). No lugar dos dois botões lado a lado,
> fica um só, "Entrar com Google", na largura do card. Os espaçamentos
> continuam os mesmos.

## Causa raiz

A correção de 2026-10-26 (`docs/features/login-layout-distribuido.md`)
**ancorava o rodapé na base da tela** em `ComposicaoCabecalhoPainel`
(`lib/core/widgets/composicao_cabecalho_painel.dart`). A altura que sobrava
ia 50% para o cabeçalho e 50% para o **vão entre o card e o rodapé**. Não
havia `Spacer`, `Expanded` nem `Positioned`. O espaço vinha da posição do
rodapé, `max(logo abaixo do card, base da tela − margem − altura do
rodapé)`.

Medição antes da correção, em teste de widget com Roboto e barras de
24 + 48 px:

| Tela | Card → Google | Botões → "Cadastre-se" |
|---|---|---|
| 360×800 | 35,75 px | 10 px |
| 390×844 | 57,75 px | 10 px |
| 412×915 | 93,25 px | 10 px |

## Correção

- **`ComposicaoCabecalhoPainel`:** o rodapé passa a ficar **logo abaixo do
  painel**, a `espacoAntesDoRodape` dele, com ou sem rolagem.
  - O parâmetro antes se chamava `espacoMinimoAntesDoRodape`.
  - A parte da sobra que não vai para o cabeçalho fica abaixo de tudo.
  - Só o Login usa rodapé. O Cadastro não muda (testes inalterados).
- **Login:**
  - `espacoAntesDoRodape: 28` (dentro da referência de 24–32 px);
  - 16 px entre os botões e "Cadastre-se" (antes 10).
- **Sem mudança:** botões, estilos, cores, textos, handlers e rotas.

Depois da correção:

| Tela | Card → Google | Botões → "Cadastre-se" | Espaço livre na base |
|---|---|---|---|
| 360×800 | 28 px | 16 px | 26,75 px |
| 390×844 | 28 px | 16 px | 48,75 px |
| 412×915 | 28 px | 16 px | 84,25 px |

## Efeito colateral

**Efeito colateral conhecido:** o cabeçalho e o card **subiram 9 px**. O
grupo inferior ficou 18 px mais alto (+12 de espaço antes, +6 até
"Cadastre-se"), e o cabeçalho continua recebendo 50% da sobra.

Manter a posição exata exigiria compensar com números mágicos. O slogan
continua acima do card, e o teste "o slogan nunca fica atrás do card"
continua passando.

## Exceções (as mesmas de antes)

- **Teclado aberto, ou tela muito baixa com fonte ampliada:** a rolagem de
  exceção continua.
- **320×640:** já rolava antes e continua rolando. O rodapé segue logo
  abaixo do card também ali.

## Testes (`test/features/auth/login_screen_test.dart`)

- **320, 360, 390 e 412 de largura:**
  - card → Google entre 24 e 32 px;
  - Google e Facebook na mesma linha, com a mesma largura e centralizados
    sob o card;
  - botões → "Cadastre-se" entre 16 e 24 px;
  - convite "Não tem uma conta? Cadastre-se" centralizado.
- **Fonte 1,3x em 360×800:** sem overflow, com Google, Facebook e
  Cadastre-se alcançáveis e na mesma linha.
- **Navegação:** "Cadastre-se" abre o cadastro. Google e Facebook continuam
  tocáveis (ainda sem login social), sem erro nem navegação.
- **Removida:** a verificação "rodapé ancorado embaixo (≤ 20 px da barra de
  navegação)", que é justamente o comportamento corrigido.

## Rollback

Reverter o merge. A mudança é só de apresentação.
