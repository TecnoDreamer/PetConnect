# Validação manual — redesign da tela de Cadastro

> Branch: `feat/redesign-cadastro`. Fonte:
> `prompt_redesign_tela_cadastro_petconnect.md` (2026-09-13).

## Como testar

Atualizar o app no celular com o código desta branch. Testar em pelo
menos um aparelho pequeno (ex.: um Android de tela menor) e um médio/
grande, com e sem teclado aberto, e com um cadastro completo de ponta a
ponta (conta nova de verdade, depois excluída em Configurações).

## Checklist

### Layout geral

- [ ] Tela cabe inteira sem precisar rolar, com o teclado fechado
- [ ] Ao abrir o teclado num campo, ainda dá pra ver o campo e o botão
      "CRIAR CONTA" sem esforço (rolando um pouco, se o aparelho for bem
      pequeno, mas sem nada cortado ou inacessível)
- [ ] Cabeçalho encolhe visivelmente quando o teclado abre
- [ ] Botão voltar do cabeçalho funciona nos dois estados (compacto e
      normal)
- [ ] **(2026-09-14)** Arrastar o dedo em qualquer ponto da tela (fora
      de um campo de texto) não move nada — nem o card, nem o
      cabeçalho; o card nunca aparece "atrás" ou desgrudado do
      cabeçalho marrom
- [ ] **(2026-09-14, 2ª rodada)** Tocar em CADA campo (Nome, E-mail,
      Telefone, Senha, Confirmar senha), um por um: o card não "sobe"
      sozinho, e a sobreposição com a base do cabeçalho continua igual
      antes e depois de cada toque — esse era o sintoma real que a
      primeira correção não pegou (rolagem disparada pelo próprio
      Flutter ao focar o campo, não pelo dedo do usuário)

### Campos

- [ ] Nenhum campo mostra rótulo + exemplo ao mesmo tempo
- [ ] Rótulo sobe (flutua) ao focar ou digitar, sem sumir por completo
- [ ] Rótulo volta pro lugar se o campo ficar vazio e perder o foco
- [ ] Nenhum campo mostra erro vermelho antes de ser tocado

### Telefone

- [ ] Máscara `(DD) 9XXXX-XXXX` aparece automaticamente ao digitar
- [ ] Não é possível digitar mais que 11 dígitos
- [ ] Backspace remove dígitos normalmente
- [ ] Deixar vazio e tentar avançar mostra "Informe um telefone válido."

### Senha

- [ ] Checklist de requisitos aparece assim que o campo é focado
- [ ] Cada requisito muda de ícone (não só de cor) ao ser atendido
- [ ] Checklist some quando a senha atende a tudo e o campo perde o foco
- [ ] Botão de olho mostra/oculta a senha corretamente
- [ ] Senha fraca (ex.: "123456789") não passa a validação

### Confirmar senha

- [ ] Não mostra erro no primeiro caractere digitado
- [ ] Mostra "As senhas não coincidem." quando diferente
- [ ] Ícone de sucesso (✓ verde) aparece quando as senhas coincidem
- [ ] Erro some assim que a confirmação é corrigida

### Botão "CRIAR CONTA"

- [ ] Começa desabilitado
- [ ] Habilita só quando todos os campos estão válidos
- [ ] Mostra o spinner de carregamento durante o cadastro
- [ ] Não é possível tocar duas vezes durante o carregamento
- [ ] Cadastro com e-mail já existente mostra "Já existe uma conta com
      este e-mail." (não uma mensagem técnica do Firebase)

### Fluxo completo

- [ ] Cadastro de ponta a ponta (dados válidos) leva direto para a Home
- [ ] Nome, e-mail e telefone informados aparecem certos no perfil depois
- [ ] Conta de teste é excluída ao final da validação (Configurações →
      Excluir conta)

## Fora do escopo desta validação (esperado)

- Login e Esqueci senha **não foram alterados** por este redesign —
  continuam com o cabeçalho e o layout de antes.
- Login social (Google/Facebook) não faz parte deste documento.

## Como reportar

Marcar `[x]` (passou) ou `FALHOU: <o que aconteceu>` ao lado. Se algo
falhar, não mesclar a PR até corrigir.
