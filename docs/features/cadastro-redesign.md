# Redesign da tela de Cadastro

> **Layout substituído em 2026-10-24:** o cabeçalho compacto com
> teclado, o `SingleChildScrollView` + `Transform.translate` e a checklist
> que aparecia e sumia, descritos abaixo, foram trocados por uma composição
> estática. Ver `docs/features/cadastro-layout-estatico.md`. Campos,
> validações e fluxo de cadastro deste documento continuam valendo.

> Branch: `feat/redesign-cadastro`. Fonte:
> `prompt_redesign_tela_cadastro_petconnect.md` (2026-09-13) + vídeo
> `tela de cadastro.mp4` (comportamento no aparelho) + print de referência
> (mesma tela, mostrando o resultado esperado: telefone mascarado,
> checklist de senha em duas colunas, ícones de olho, aviso de senha
> igual).

## 1. Diagnóstico da tela anterior

- Cada campo mostrava rótulo (`"Telefone"`) e exemplo (`"(00) 00000-0000"`)
  ao mesmo tempo dentro do próprio campo, com o valor digitado alinhado à
  direita — ruído visual, sem padrão de campo do resto do app.
- Telefone sem máscara e sem limite: aceitava qualquer quantidade de
  dígitos, sem validação nenhuma (nem exigia preenchimento).
- Senha exigia só "8 caracteres", sem maiúscula/minúscula/número/
  caractere especial — política fraca pra uma conta com dados de tutor e
  localização de pets.
- Confirmar senha só validava "não vazio" — nunca comparava com a senha
  real antes do envio (o app comparava no `_handleCadastro`, mas sem
  feedback nenhum no campo em si).
- Tela inteira dentro de um `SingleChildScrollView` sem nenhum cuidado de
  altura — dependia de rolar pra ver tudo em aparelhos menores/com
  teclado aberto.
- Botão "CRIAR CONTA" sempre habilitado, mesmo com formulário incompleto
  — só falhava ao tentar enviar.
- Cabeçalho (`AuthHeader`, compartilhado com Login/Esqueci senha) ocupava
  bastante altura fixa, sem se adaptar ao teclado.

## 2. Auditoria (antes de implementar)

1. **Arquivo da tela**: `cadastro_screen.dart` — um `_CampoComRotulo`
   próprio (não usava `TextFormField` padrão do app).
2. **Cabeçalho**: `AuthHeader` (`core/widgets/auth_header.dart`),
   compartilhado por Login, Cadastro e Esqueci senha — **não alterado**:
   um cabeçalho compacto específico foi criado só para o Cadastro
   (`_CadastroHeader`, privado do arquivo da tela), pra não mudar a
   aparência das outras duas telas.
3. **Tema**: Login/Cadastro/Esqueci senha continuam fora da migração de
   tema (ver docs/features/theme-and-settings-menu.md, "Hardcodes
   restantes") — este redesign manteve o mesmo padrão, usando
   `AppColors` fixo, não `context.colors`. Um único token novo foi
   adicionado a `AppColors`: `success` (mesmo valor de
   `AppPalette.padrao.success`, reaproveitado, não inventado).
4. **Autenticação**: `UsuarioRepository.signUp` (Firebase Auth) — não
   alterado. Erros continuam traduzidos por `translateAuthError`
   (`core/errors/auth_error_translator.dart`), já cobria
   `email-already-in-use`/`weak-password`/etc.
5. **Testes existentes**: nenhum teste de widget da tela de Cadastro
   existia antes (só o e2e `auth_flow_test.dart`, com tag `e2e`, fora do
   CI).
6. **Fluxo de navegação**: Cadastro → `signUp` → redirect automático do
   `go_router` pra `/home` (via `authStateChangesProvider`) — inalterado.

## 3. O que mudou

### Cabeçalho compacto

`_CadastroHeader` (privado de `cadastro_screen.dart`, não o `AuthHeader`
compartilhado): logo menor (72px, era 160px), sem o slogan, e encolhe
para uma barra fina (logo 32px + nome ao lado do botão voltar) quando o
teclado abre (`MediaQuery.viewInsets.bottom > 0`), com uma transição de
200ms (`AnimatedContainer`/`AnimatedSwitcher`).

### Campos: rótulo flutuante em vez de "some por completo"

O documento-fonte pedia que o rótulo desaparecesse por completo ao focar
o campo. Implementado como **label flutuante** (`labelText` +
`FloatingLabelBehavior.auto`, padrão do próprio Material) em vez disso —
adaptação deliberada, não uma simplificação por preguiça:

- É o mecanismo de acessibilidade do próprio Flutter, testado e mantido
  pelo framework — a alternativa (esconder o `hintText` manualmente no
  foco) exigiria replicar a semântica do campo à mão (`ExcludeSemantics`
  + `Semantics` customizado), arriscando remover ações de edição que o
  leitor de tela espera de um campo de texto padrão.
- O documento-fonte prioriza explicitamente acessibilidade acima de
  fidelidade visual literal (seção 41: "nunca sacrifique [...]
  acessibilidade [...] apenas para deixar a tela mais bonita").
- O efeito prático é o mesmo pedido: o espaço de digitação fica limpo
  assim que o usuário foca ou digita, sem repetir rótulo+exemplo+valor.

Os exemplos redundantes (`"Ex: Maria Silva"`, `"seu@email.com"`,
`"(00) 00000-0000"`, `"Repita a senha"`) foram removidos — o rótulo
sozinho já basta.

### Telefone com máscara automática

`BrPhoneInputFormatter`
(`features/auth/presentation/utils/br_phone_formatter.dart`): usuário só
digita números; a máscara `(DD) XXXX-XXXX` (fixo) ou `(DD) 9XXXX-XXXX`
(celular) é aplicada automaticamente, com limite real de 11 dígitos
(inclusive ao colar um texto maior). Telefone agora é obrigatório
(`"Informe um telefone válido."`), o que não acontecia antes (não havia
validação nenhuma).

### Política de senha + checklist visual

`cadastro_validators.dart`: mínimo 9 caracteres, com maiúscula,
minúscula, número e caractere especial — todos obrigatórios.
`PasswordRequirementsChecklist` mostra os 5 requisitos com ícone (círculo
vazio → check verde) sempre que o campo está focado **ou** a senha ainda
não atende a tudo (por isso já aparece antes de qualquer digitação: uma
senha vazia nunca atende aos requisitos) — soma sozinho quando a senha
fica válida e o campo perde o foco.

### Confirmar senha

Sem erro no primeiro caractere digitado — só passa a comparar depois que
a confirmação atinge o mesmo tamanho da senha, ou quando o campo perde o
foco (validação obrigatória nesse momento). Ícone de sucesso discreto
(✓ verde) quando as senhas coincidem.

### Validação por campo: ao perder o foco, não a cada tecla

Nome, e-mail e telefone só mostram erro depois de perder o foco pelo
menos uma vez (`_tocado`) — nenhum campo começa "vermelho" antes de
qualquer interação. O erro some assim que o valor é corrigido.

### Botão "CRIAR CONTA" com estado real

Fica desabilitado até que os 5 campos estejam válidos (reativo, via
`Listenable.merge` nos 5 controllers) — antes, ficava sempre habilitado e
só falhava ao tentar enviar. Estados de loading (spinner) e erro geral
(mensagem amigável, nunca a mensagem crua do Firebase) preservados da
implementação anterior.

### Tela única, sem depender de rolagem em condições normais

O `SingleChildScrollView` que envolvia a tela inteira **não é mais a
solução padrão**: o cabeçalho compacto + espaçamentos reduzidos fazem o
conteúdo caber numa única viewport em aparelhos normais, com ou sem
teclado aberto. Um `SingleChildScrollView` continua existindo em volta
do cartão do formulário — não como mecanismo principal, mas como **rede
de segurança** contra overflow em combinações extremas (fonte do sistema
bem ampliada + aparelho muito pequeno + teclado aberto), evitando que a
tela quebre com um erro de `RenderFlex` nesses casos raros. Em qualquer
aparelho normal ele nunca chega a rolar de fato.

## 4. Arquivos afetados

- [`cadastro_screen.dart`](../../lib/features/auth/presentation/screens/cadastro_screen.dart) — reescrita.
- [`cadastro_validators.dart`](../../lib/features/auth/presentation/utils/cadastro_validators.dart) (novo) — funções puras de validação.
- [`br_phone_formatter.dart`](../../lib/features/auth/presentation/utils/br_phone_formatter.dart) (novo) — máscara de telefone.
- [`cadastro_text_field.dart`](../../lib/features/auth/presentation/widgets/cadastro_text_field.dart) (novo) — campo reutilizável desta tela.
- [`password_requirements_checklist.dart`](../../lib/features/auth/presentation/widgets/password_requirements_checklist.dart) (novo).
- [`app_colors.dart`](../../lib/core/theme/app_colors.dart) — novo token `success` (reaproveitado de `AppPalette.padrao.success`).
- `AuthHeader`, `login_screen.dart`, `esqueci_senha_screen.dart` — **não
  alterados** (fora do escopo deste redesign).
- `UsuarioRepository`/`FirebaseUsuarioRepository`/`ApiUsuarioRepository`/
  `translateAuthError` — **não alterados**.

## 5. Validações implementadas

| Campo | Regra | Mensagem |
|---|---|---|
| Nome | obrigatório | "Informe seu nome." |
| E-mail | obrigatório + formato | "Informe um e-mail válido." |
| Telefone | 10 ou 11 dígitos | "Informe um telefone válido." |
| Senha | 9+ caracteres, maiúscula, minúscula, número, especial | "Sua senha ainda não atende aos requisitos." |
| Confirmar senha | igual à senha | "Confirme sua senha." / "As senhas não coincidem." |

## 6. Acessibilidade

- Rótulo dos campos sempre disponível a leitores de tela (label
  flutuante nativo do Flutter, não um hint escondido manualmente).
- Botões de olho (mostrar/ocultar senha) com `tooltip` "Mostrar
  senha"/"Ocultar senha".
- Checklist de senha e badges de erro nunca dependem só de cor (ícone +
  texto sempre presentes); o checklist expõe um único `Semantics` com o
  resumo de todos os requisitos, em vez de 5 anúncios soltos por tecla
  digitada.
- Botão voltar do cabeçalho com área de toque mínima 44×44 e `tooltip`.
- Autofill hints: `name`, `email`, `telephoneNumber`, `newPassword`
  (senha e confirmação).

## 7. Segurança

Nenhuma mudança na lógica de autenticação: a validação de senha no
frontend é só UX — o Firebase Auth continua sendo a autoridade real
(rejeita senhas fracas independentemente do que o formulário permitir
enviar). Senha nunca aparece em log nem em mensagem de erro. Máscara de
telefone é só apresentação — o texto mascarado é o que é enviado a
`signUp` (mesmo campo livre que já existia antes; nenhum novo dado
sensível trafega).

## 8. Performance

Reconstrução do formulário a cada tecla é local (um `AnimatedBuilder`
escutando os 5 controllers) — nenhuma chamada de rede acontece antes do
toque em "CRIAR CONTA".

## 9. Testes

- `flutter analyze` — sem apontamentos.
- `flutter test test/core/ test/features/pet/ test/features/auth/
  test/features/usuario/ --exclude-tags=e2e` — ver relatório da PR pro
  número exato.
- Novo `test/features/auth/cadastro_validators_test.dart` — todas as
  regras de nome/e-mail/telefone/senha/confirmação, isoladas (sem
  widget).
- Novo `test/features/auth/br_phone_formatter_test.dart` — formato
  final (fixo/celular), limite de 11 dígitos mesmo colando um número
  maior, colagem com caracteres não numéricos, backspace, cursor sempre
  no final, migração de fixo pra celular ao digitar o 11º dígito.
- Novo `test/features/auth/cadastro_screen_test.dart` (20 testes) —
  layout inicial, máscara de telefone em uso real, validação ao perder o
  foco, checklist de senha (aparece/permanece/some), confirmar senha
  (sem erro precoce, erro ao divergir, some ao corrigir), botão (habilita
  quando válido, chama `signUp` com os dados certos, loading, erro de
  e-mail já cadastrado, erro genérico), cabeçalho compacto com teclado
  simulado, e responsividade em 320×480 — **encontrou e corrigiu um
  overflow real** no checklist de senha (mesmo padrão `Flexible` +
  `ellipsis` já usado em `VaccinePendingBadge`/`PetGenderBadge` na Home).
- `test/features/auth/auth_flow_test.dart` (e2e, tag `e2e`, fora do CI)
  — senha de teste atualizada pra atender à nova política.

## 10. Critérios de aceitação (seção 39 do documento-fonte)

- [x] tela funciona sem scroll em viewport normal suportada — com uma
      rede de segurança (`SingleChildScrollView`) pra casos extremos, ver
      seção 3.
- [x] teclado não torna campos/CTA inacessíveis — cabeçalho compacta e
      botão continua alcançável (com scroll, se necessário, em telas
      muito pequenas).
- [x] cabeçalho se adapta quando necessário.
- [x] exemplos redundantes removidos.
- [~] label visual desaparece durante foco — **adaptado** para label
      flutuante (Material padrão), não desaparecimento total — ver
      justificativa na seção 3.
- [x] label reaparece se o campo vazio perder o foco (comportamento
      nativo do `FloatingLabelBehavior.auto`).
- [x] acessibilidade mantém identificação dos campos.
- [x] telefone possui limite real (11 dígitos).
- [x] máscara de telefone é automática.
- [x] telefone não aceita mais dígitos que o permitido (mesmo colando).
- [x] senha possui mínimo de 9 caracteres.
- [x] senha exige maiúscula/minúscula/número/caractere especial.
- [x] requisitos apresentados de forma clara e compacta (checklist).
- [x] confirmação precisa ser igual à senha.
- [x] mensagem de incompatibilidade é amigável.
- [x] botão possui disabled/enabled/loading.
- [x] não há double submit (botão desabilitado durante `_submitting`).
- [x] erros técnicos não são expostos (`translateAuthError` +
      mensagem genérica para erro inesperado).
- [x] navegação de teclado funciona (`textInputAction` next/next/next/
      next/done, focando o próximo campo).
- [x] contraste adequado (cores já usadas no resto do app).
- [x] componentes respeitam SafeArea.
- [x] não existem overflows (verificado em 320×480, com e sem teclado).
- [x] testes relevantes passam.
- [x] funcionalidades anteriores continuam funcionando (fluxo de
      cadastro, navegação, tratamento de erro do Firebase).

## 11. Riscos ou pendências

- A máscara de telefone sempre move o cursor para o final do texto após
  cada edição (não preserva a posição ao editar no meio do número) —
  limitação aceita, comum a este tipo de máscara (documentada no próprio
  `BrPhoneInputFormatter`).
- Apagar exatamente o caractere "-" ou ")" da máscara não remove nenhum
  dígito por si só (o usuário só precisa apertar backspace mais uma vez)
  — mesma limitação, documentada.
- Login e Esqueci senha continuam com o cabeçalho antigo e sem a
  política de senha nova (fora do escopo deste documento) — Login não
  tem campo de senha NOVA (só autentica), então a política não se aplica
  lá; caso um redesign futuro de Login/Esqueci senha seja pedido, pode
  reaproveitar `cadastro_validators.dart`/`BrPhoneInputFormatter`.

## 12. Rollback

Reverter o merge. Nenhuma migração de dado é necessária — a política de
senha mais forte só se aplica a contas criadas depois da mudança; contas
antigas com senha mais curta continuam autenticando normalmente (o
Firebase Auth nunca reavalia a política de uma senha já definida).

## 13. Validação manual

Ver `docs/validation/cadastro-redesign.md`.
