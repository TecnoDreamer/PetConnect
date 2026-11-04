# Validação manual — layout estático do Login

> Branch: `fix/login-card-sobreposicao-estatica`. Fonte:
> `prompt_correcao_layout_login_estatico.md` (2026-09-14).

> **Atualização (2026-10-26):** o layout passou a distribuir a altura da
> tela (`docs/features/login-layout-distribuido.md`). Além do checklist
> abaixo, conferir:
>
> ```text
> [ ] Slogan "Conectando corações perdidos aos seus lares" visível (não fica atrás do card)
> [ ] Sem faixa branca grande embaixo: Google/Facebook e "Cadastre-se" ficam perto da base
> [ ] Área marrom maior em telas altas, com logo e textos centralizados
> [ ] Erro de login aparece sem o card subir ou descer
> ```

> **Atualização (2026-10-27):** Google, Facebook e "Cadastre-se" passaram a
> ficar logo abaixo do card (`docs/features/login-espacamento-acoes-sociais.md`).
> O item "ficam perto da base" acima deixa de valer. Conferir:
>
> ```text
> [ ] Google e Facebook ~28px abaixo do card, lado a lado, mesmo tamanho
> [ ] "Não tem uma conta? Cadastre-se" logo abaixo dos botões, centralizado
> [ ] Cabeçalho, logo, slogan e card no lugar (no máximo ~9px acima de antes)
> [ ] Teclado aberto/fechado, erro, carregamento e mostrar senha sem salto
> [ ] Cadastre-se abre o cadastro
> ```

## Como testar

Atualizar o app no celular com o código desta branch. Testar login com
credenciais válidas e inválidas, com e sem teclado aberto.

## Checklist

```text
[ ] Card está na frente da área marrom
[ ] Sobreposição está correta
[ ] Logo não se move
[ ] PetConnect não se move
[ ] Slogan não se move
[ ] Card não se move sozinho
[ ] Google/Facebook não se movem
[ ] Cadastre-se não se move
[ ] E-mail funciona
[ ] Senha funciona
[ ] Ícone de senha funciona
[ ] Teclado não quebra layout
[ ] Fechar teclado restaura posição
[ ] Erro de login não causa salto excessivo
[ ] Loading não reposiciona tela
[ ] Sem overflow
[ ] Sem clipping
```

## Observação sobre aparelhos muito pequenos (320×568 ou menores)

Nesses aparelhos, mesmo com a correção, pode sobrar conteúdo que não
cabe inteiro na tela (ver causa raiz em
`docs/features/login-layout-static-fix.md`, "Limitação aceita e
documentada") — o logo, que o documento-fonte proíbe encolher, já ocupa
quase 30% da altura da tela nesse tamanho. **O que não pode acontecer,
mesmo aí**, é o card ficar arrastável/se mover ao toque — se isso
acontecer em qualquer aparelho, é falha de verdade, marcar como tal.

## Fora do escopo desta validação (esperado)

- Cadastro e Esqueci senha não são o alvo desta correção — Cadastro já
  foi corrigido separadamente (`docs/validation/cadastro-redesign.md`).
  Esqueci senha só ganhou mais espaço de sobra (mudança aditiva no
  `AuthHeader` compartilhado), sem validação formal própria aqui.

## Como reportar

Marcar `[x]` (passou) ou `FALHOU: <o que aconteceu>` ao lado. Se algo
falhar, não mesclar a PR até corrigir.
