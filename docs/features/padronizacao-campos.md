# Campos de texto com a aparência da tela Entrar

> Branch: `refactor/ui-padronizacao-campos` (2026-11-02). Issue #97.

## Referência: os campos da tela Entrar

Medidos em `login_screen.dart`:
- **Borda:** fina, em `brandLight` com 45% de opacidade, raio 16.
- **Com foco:** `brandDark`, com 1,5 de espessura.
- **Fundo:** o `surface` do tema (preenchido).
- **Dica:** em `textMuted`.
- **Espaçamento interno:** 20 nas laterais.

## O que havia antes

As telas internas usavam o `InputDecorationTheme` global: campo
preenchido, **sem borda** (`BorderSide.none`) e raio 16. No tema Claro, o
campo era só um retângulo cinza, sem contorno. Só a tela Entrar e o
Cadastro tinham borda, cada um com a própria decoração. "Esqueceu sua
senha?" usava o padrão global, sem borda.

## Correção

**No tema** (`lib/core/theme/app_theme.dart`, `inputDecorationTheme`), com
os tokens de cada um dos três temas:

| Estado | Borda |
|---|---|
| Repouso | `brandLight` a 45%, 1 px, raio 16 |
| Foco | `brandDark`, 1,5 px |
| Erro | a mesma borda em `palette.error`, mais grossa com foco (padrão do Material a partir de `border`) |
| Desabilitado | `brandLight` a 20% |

O resto continua igual: preenchido com `surface`, dica em `textMuted` e
espaçamento interno de 20 × 18. As telas internas mantêm a altura maior
que a da tela Entrar: há campos de várias linhas e listas, e a área de
toque fica maior. O tema só afeta decoração de campo de texto; botões,
cards e o resto não mudam.

**Ajustes pontuais:**
- **Esqueceu sua senha?:** o campo de e-mail ganhou a altura do e-mail da
  tela Entrar (`isDense`, 20 × 9). A borda vem do tema.
- **Cadastro:** a borda passou de 35% para 45% de opacidade, igual à da
  tela Entrar. O resto da decoração própria (fundo branco, rótulo
  flutuante, linha de erro reservada) continua.

## Inventário

| Tela | Arquivo | Campos | Como fica |
|---|---|---|---|
| Entrar | `auth/.../login_screen.dart` | e-mail, senha | Referência, sem mudança nesta PR. A altura igual dos dois campos está na PR #98 |
| Cadastro | `auth/.../cadastro_text_field.dart` | nome, e-mail, telefone, nascimento, senha, confirmação | Decoração própria; borda a 45% |
| Esqueceu sua senha? | `auth/.../esqueci_senha_screen.dart` | e-mail | Borda do tema e altura da tela Entrar |
| Editar perfil | `usuario/.../editar_perfil_screen.dart` | Nome, Sobrenome, Telefone, Data de nascimento, Gênero (lista) | Tema |
| Cadastro e edição do pet | `pet/.../pet_form_screen.dart` | Nome, Espécie, Raça, Cor, Gênero e Porte (listas), Peso, Data de nascimento | Tema |
| Vacina | `pet/.../vacina_form_screen.dart` | Nome da vacina, Data de aplicação, Próxima dose, Veterinário/clínica, Observações | Tema |
| Consulta | `pet/.../consulta_form_screen.dart` | Data, Horário, Veterinário/clínica, Motivo | Tema |
| Histórico médico | `pet/.../historico_form_screen.dart` | Data, Descrição, Veterinário/clínica | Tema |
| Localização | `pet/.../localizacao_form_screen.dart` | Data, Contato de quem viu | Tema |
| Registrar falecimento (Memorial) | `pet/.../registrar_falecimento_screen.dart` | Data do falecimento, Homenagem | Tema |
| Galeria: publicar fotos | `pet/.../publicar_fotos_screen.dart` | Legenda | Tema |
| Cartaz de pet desaparecido | `pet/.../cartaz_editor_screen.dart` | características, observações, local, valor da recompensa (máscara de reais), recompensa em texto | Tema |
| Página pública do QR (web) | `public/index.html` | descrição, contato | **Sem mudança**, ver abaixo |

**O que não mudou em nenhum campo:**
- controllers, máscaras (telefone, reais), validações, limites de
  caracteres, teclado, autofill, rótulos e ações;
- calendários, relógios e listas (gênero, porte) continuam como eram, com
  a borda do tema.

**Exceção justificada, a página pública do QR:**
- **Identidade própria:** é a página web que quem encontra o pet abre, com
  a paleta da web (laranja `#e07a3f`).
- **Já tem campos com borda:** 1 px e foco destacado.
- **Precisaria de deploy:** a mudança só valeria depois de publicada no
  Firebase Hosting, o que exige autorização do proprietário.

## Acessibilidade e temas

- **Contraste:** a borda de repouso segue a da tela Entrar (`brandLight` a
  45%) e é discreta. O que separa o campo do fundo é também o
  preenchimento `surface`, como antes. A borda com foco (`brandDark`) é
  bem visível nos três temas; no Escuro, `brandDark` é `#A47854`, claro
  sobre o fundo escuro.
- **Rótulos:** cada tela continua como era.
  - As telas internas e a tela Entrar identificam o campo pela dica
    (`hintText`, por exemplo "Nome:"), que some quando o tutor digita.
    Essa limitação já existia e não mudou.
  - O Cadastro, o Memorial, a galeria e o cartaz usam rótulo flutuante
    (`labelText`), que continua visível.
  - Trocar as dicas por rótulos flutuantes nas telas internas fica como
    sugestão, porque muda o texto e o layout de cada tela.
- **Mensagens de erro:** continuam abaixo do campo, e o texto digitado é
  mantido.
- **Telas de autenticação:** seguem com o tema fixo (`AuthThemeScope`)
  mesmo com o app em Escuro.

## Testes

- **`test/core/theme/campos_de_texto_test.dart` (7):**
  - nos três temas, a borda, o raio, o foco e o preenchimento do tema são
    os da tela Entrar;
  - num formulário, as bordas de repouso, foco e desabilitado; a validação
    mostra o erro e mantém o texto digitado;
  - "Esqueceu sua senha?" com a mesma borda e a mesma altura do e-mail da
    tela Entrar.
- **Os testes de tela de antes passam sem mudança:** cadastro, perfil,
  pet, vacinas, consultas, histórico, Memorial, galeria e cartaz. São 498
  testes no conjunto do CI.
- **`test/evidencias/campos_evidencia_test.dart`** (fora do CI): grava
  `build/evidencias/campos_antes_depois.png`, com os mesmos campos (normal,
  data, erro, desabilitado, várias linhas) antes e depois, nos três temas.

**Sem teste no aparelho.** Conferir nos três temas, com fonte grande e
teclado aberto, ao menos Editar perfil, cadastro do pet, vacina e
"Esqueceu sua senha?".

## Rollback

Reverter o merge. Banco, API e regras não mudam.
