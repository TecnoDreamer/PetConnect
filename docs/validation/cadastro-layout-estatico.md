# Validação manual — tela Criar conta (painel na frente, tela estática)

> Branch: `fix/cadastro-sobreposicao-layout-estatico`. Detalhes técnicos em
> `docs/features/cadastro-layout-estatico.md`.

## Identificação do teste

```text
Aparelho:
Resolução / densidade:
Versão do Android:
Navegação (gestos ou 3 botões):
Tamanho da fonte do sistema:
Build (commit):
Data:
Testado por:
```

## Como testar

1. Instalar o app com o código desta branch.
2. Na tela de Login, tocar em **Cadastre-se**.
3. Percorrer o checklist abaixo sem pressa, com e sem teclado aberto.
4. Repetir com a fonte do sistema ampliada, se possível.

## Checklist

```text
[ ] Cabeçalho marrom fica atrás do painel
[ ] Painel de cadastro aparece inteiro no primeiro plano
[ ] Nenhum campo/texto é coberto pelo cabeçalho
[ ] Logo, nome e Voltar mantêm alinhamento correto
[ ] Tela normal não possui scroll horizontal ou vertical
[ ] Todos os campos e botão aparecem sem rolagem no dispositivo-alvo
[ ] Layout não se move espontaneamente
[ ] Campos recebem foco e permitem digitação
[ ] Teclado não oculta permanentemente o campo focado
[ ] Fechar teclado restaura exatamente o layout normal
[ ] Regras de senha são exibidas e atualizadas corretamente
[ ] Mostrar/ocultar senha funciona
[ ] Erros são visíveis sem encobrir controles
[ ] Botão desabilitado/loading mantém a posição
[ ] Voltar e cadastro continuam funcionando
[ ] Sem overflow, recorte, texto ilegível ou perda de alvos de toque
[ ] Tela de login não sofreu regressão
```

## O que é esperado (e não é falha)

- **Com o teclado aberto**, o conteúdo pode subir para mostrar o campo
  focado acima do teclado. É a exceção documentada. O cabeçalho não muda
  de tamanho, e ao fechar o teclado tudo tem que voltar exatamente ao lugar
  de antes. Se não voltar, é falha.
- **Em aparelhos baixos (~720dp de altura ou menos) ou com a fonte do
  sistema bem ampliada**, a tela pode permitir rolagem mesmo sem teclado,
  porque o formulário não cabe sem esconder campos. Também é exceção
  documentada. No aparelho das capturas (≈412×915), com a fonte padrão, a
  tela tem que ficar **totalmente estática**.
- **O espaço entre "Confirmar senha" e o botão** é reservado para a
  mensagem de erro do cadastro (ex.: "Já existe uma conta com este
  e-mail."), para ela não empurrar o botão quando aparecer.

## Resultado

```text
Resultado geral: [ ] Aprovado  [ ] Reprovado
Observações:
Evidências (prints/vídeo):
```

Marcar `[x]` (passou) ou `FALHOU: <o que aconteceu>` ao lado de cada
item. Se algo falhar, não mesclar a PR até corrigir.
