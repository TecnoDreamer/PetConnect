import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/auth_error_translator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../usuario/presentation/providers/auth_providers.dart';
import '../utils/br_phone_formatter.dart';
import '../utils/cadastro_validators.dart';
import '../widgets/cadastro_text_field.dart';
import '../widgets/password_requirements_checklist.dart';

/// Tela de cadastro (RF03) — redesign de 2026-09-13, ver
/// docs/features/cadastro-redesign.md e
/// prompt_redesign_tela_cadastro_petconnect.md.
///
/// Cabeçalho, fluxo de criação de conta (`UsuarioRepository.signUp`),
/// navegação e tratamento de erro do Firebase Auth são os mesmos de
/// antes — só a apresentação (campos, validação, layout) mudou.
class CadastroScreen extends ConsumerStatefulWidget {
  const CadastroScreen({super.key});

  @override
  ConsumerState<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends ConsumerState<CadastroScreen> {
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();

  final _nomeFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _telefoneFocus = FocusNode();
  final _senhaFocus = FocusNode();
  final _confirmarSenhaFocus = FocusNode();

  // "Tocado" (perdeu o foco ao menos uma vez) — controla o momento da
  // validação: nada de vermelho antes da primeira interação com o campo
  // (seção 15 do briefing). Confirmar senha tem uma regra própria, mais
  // permissiva ainda (ver [_erroConfirmarSenha]).
  bool _nomeTocado = false;
  bool _emailTocado = false;
  bool _telefoneTocado = false;
  bool _senhaTocado = false;
  bool _confirmarSenhaTocado = false;

  bool _senhaVisivel = false;
  bool _confirmarSenhaVisivel = false;
  bool _submitting = false;
  String? _erroGeral;

  late final _campos = Listenable.merge([
    _nomeController,
    _emailController,
    _telefoneController,
    _senhaController,
    _confirmarSenhaController,
  ]);

  @override
  void initState() {
    super.initState();
    _nomeFocus
        .addListener(() => _aoPerderFoco(_nomeFocus, () => _nomeTocado = true));
    _emailFocus.addListener(
        () => _aoPerderFoco(_emailFocus, () => _emailTocado = true));
    _telefoneFocus.addListener(
        () => _aoPerderFoco(_telefoneFocus, () => _telefoneTocado = true));
    _senhaFocus.addListener(() {
      _aoPerderFoco(_senhaFocus, () => _senhaTocado = true);
      // A checklist aparece/some com o foco — precisa de rebuild mesmo
      // quando a senha em si não mudou.
      setState(() {});
    });
    _confirmarSenhaFocus.addListener(() => _aoPerderFoco(
        _confirmarSenhaFocus, () => _confirmarSenhaTocado = true));
  }

  void _aoPerderFoco(FocusNode node, VoidCallback marcarTocado) {
    if (!node.hasFocus) setState(marcarTocado);
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _telefoneController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    _nomeFocus.dispose();
    _emailFocus.dispose();
    _telefoneFocus.dispose();
    _senhaFocus.dispose();
    _confirmarSenhaFocus.dispose();
    super.dispose();
  }

  String? get _erroNome =>
      _nomeTocado ? validarNome(_nomeController.text) : null;
  String? get _erroEmail =>
      _emailTocado ? validarEmail(_emailController.text) : null;
  String? get _erroTelefone =>
      _telefoneTocado ? validarTelefone(_telefoneController.text) : null;
  String? get _erroSenha =>
      _senhaTocado ? validarSenha(_senhaController.text) : null;

  /// "não mostrar erro vermelho no primeiro caractere; após existir
  /// conteúdo suficiente para comparação, verificar igualdade; ao perder
  /// o foco, validar obrigatoriamente" (seção 12).
  String? get _erroConfirmarSenha {
    final senha = _senhaController.text;
    final confirmacao = _confirmarSenhaController.text;
    if (_confirmarSenhaTocado) {
      return validarConfirmacaoSenha(senha, confirmacao);
    }
    if (confirmacao.isEmpty) return null;
    if (confirmacao.length < senha.length) return null;
    return confirmacao == senha ? null : 'As senhas não coincidem.';
  }

  bool get _confirmarSenhaCoincide =>
      _confirmarSenhaController.text.isNotEmpty &&
      _confirmarSenhaController.text == _senhaController.text;

  bool get _formularioValido =>
      validarNome(_nomeController.text) == null &&
      validarEmail(_emailController.text) == null &&
      validarTelefone(_telefoneController.text) == null &&
      senhaAtendeRequisitos(_senhaController.text) &&
      _confirmarSenhaCoincide;

  void _marcarTudoTocado() {
    setState(() {
      _nomeTocado = true;
      _emailTocado = true;
      _telefoneTocado = true;
      _senhaTocado = true;
      _confirmarSenhaTocado = true;
    });
  }

  Future<void> _handleCadastro() async {
    _marcarTudoTocado();
    setState(() => _erroGeral = null);
    if (!_formularioValido) return;

    setState(() => _submitting = true);

    try {
      await ref.read(usuarioRepositoryProvider).signUp(
            nome: _nomeController.text.trim(),
            email: _emailController.text.trim(),
            password: _senhaController.text,
            telefone: _telefoneController.text.trim(),
            // Data de nascimento não é mais pedida no cadastro — fica para
            // a edição de perfil (RF08), mantendo o formulário curto.
            dataNascimento: '',
          );
      // Navegação para /home é feita pelo redirect do go_router.
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _erroGeral = translateAuthError(e.code));
    } catch (_) {
      if (mounted) {
        setState(() => _erroGeral =
            'Não foi possível completar a operação. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Com o teclado aberto, o cabeçalho encolhe pra sobrar altura pros
    // campos e o botão — a tela continua cabendo numa única viewport sem
    // exigir rolagem em condições normais de uso (seção 4 do briefing).
    final tecladoAberto = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: Colors.white,
      // Cabeçalho e card ficam dentro do MESMO SingleChildScrollView, como
      // uma única Column (mesma estrutura da tela de Login, ver
      // login_screen.dart) — correção de 2026-09-14, 2ª rodada: com o
      // cabeçalho FORA do scroll (numa Column separada, versão anterior
      // desta correção), o Flutter ainda movia o card sozinho ao focar um
      // campo (EditableText chama Scrollable.ensureVisible() ao ganhar
      // foco — isso é uma rolagem PROGRAMÁTICA, que
      // NeverScrollableScrollPhysics não bloqueia, só bloqueia arrasto do
      // usuário), descolando visualmente o card do cabeçalho fixo. Com os
      // dois dentro do mesmo scroll, qualquer deslocamento move os dois
      // juntos — a sobreposição nunca se desfaz, não importa o que
      // dispare uma tentativa de rolagem.
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CadastroHeader(
                compacto: tecladoAberto,
                onBack: () => context.pop(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Transform.translate(
                  offset: const Offset(0, -32),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 6, 24, 6),
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.all(Radius.circular(32)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Crie sua conta',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        // O texto de apoio some com o teclado aberto — um
                        // dos elementos "decorativos" sacrificados primeiro
                        // pra sobrar altura (seção 20), já que o título
                        // sozinho já basta pra orientar o usuário nesse
                        // momento.
                        AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          child: tecladoAberto
                              ? const SizedBox(height: 6)
                              : const Column(
                                  children: [
                                    Text(
                                      'Cadastre seus dados para começar.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 13),
                                    ),
                                    SizedBox(height: 4),
                                  ],
                                ),
                        ),
                        AnimatedBuilder(
                          animation: _campos,
                          builder: (context, _) => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              CadastroTextField(
                                label: 'Nome completo',
                                controller: _nomeController,
                                focusNode: _nomeFocus,
                                keyboardType: TextInputType.name,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.name],
                                errorText: _erroNome,
                                onFieldSubmitted: (_) => FocusScope.of(context)
                                    .requestFocus(_emailFocus),
                              ),
                              const SizedBox(height: 4),
                              CadastroTextField(
                                label: 'E-mail',
                                controller: _emailController,
                                focusNode: _emailFocus,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                errorText: _erroEmail,
                                onFieldSubmitted: (_) => FocusScope.of(context)
                                    .requestFocus(_telefoneFocus),
                              ),
                              const SizedBox(height: 4),
                              CadastroTextField(
                                label: 'Telefone',
                                controller: _telefoneController,
                                focusNode: _telefoneFocus,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                                inputFormatters: [BrPhoneInputFormatter()],
                                autofillHints: const [
                                  AutofillHints.telephoneNumber
                                ],
                                errorText: _erroTelefone,
                                onFieldSubmitted: (_) => FocusScope.of(context)
                                    .requestFocus(_senhaFocus),
                              ),
                              const SizedBox(height: 4),
                              CadastroTextField(
                                label: 'Senha',
                                controller: _senhaController,
                                focusNode: _senhaFocus,
                                obscureText: !_senhaVisivel,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [
                                  AutofillHints.newPassword
                                ],
                                errorText: _erroSenha,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _senhaVisivel
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: AppColors.textMuted,
                                    size: 20,
                                  ),
                                  tooltip: _senhaVisivel
                                      ? 'Ocultar senha'
                                      : 'Mostrar senha',
                                  onPressed: () => setState(
                                      () => _senhaVisivel = !_senhaVisivel),
                                ),
                                onFieldSubmitted: (_) => FocusScope.of(context)
                                    .requestFocus(_confirmarSenhaFocus),
                              ),
                              // Some sozinho quando a senha já atende a
                              // todos os requisitos e o campo não está mais
                              // focado — só ocupa espaço quando é útil
                              // (seção 11).
                              AnimatedSize(
                                duration: const Duration(milliseconds: 200),
                                alignment: Alignment.topCenter,
                                child: (_senhaFocus.hasFocus ||
                                        !senhaAtendeRequisitos(
                                            _senhaController.text))
                                    ? Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            4, 4, 4, 0),
                                        child: PasswordRequirementsChecklist(
                                            senha: _senhaController.text),
                                      )
                                    : const SizedBox(width: double.infinity),
                              ),
                              const SizedBox(height: 4),
                              CadastroTextField(
                                label: 'Confirmar senha',
                                controller: _confirmarSenhaController,
                                focusNode: _confirmarSenhaFocus,
                                obscureText: !_confirmarSenhaVisivel,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [
                                  AutofillHints.newPassword
                                ],
                                errorText: _erroConfirmarSenha,
                                showSuccessIcon: _confirmarSenhaCoincide,
                                suffixIcon: _confirmarSenhaCoincide
                                    ? null
                                    : IconButton(
                                        icon: Icon(
                                          _confirmarSenhaVisivel
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          color: AppColors.textMuted,
                                          size: 20,
                                        ),
                                        tooltip: _confirmarSenhaVisivel
                                            ? 'Ocultar senha'
                                            : 'Mostrar senha',
                                        onPressed: () => setState(() =>
                                            _confirmarSenhaVisivel =
                                                !_confirmarSenhaVisivel),
                                      ),
                                onFieldSubmitted: (_) {
                                  FocusScope.of(context).unfocus();
                                  if (_formularioValido) _handleCadastro();
                                },
                              ),
                              if (_erroGeral != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _erroGeral!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: AppColors.error, fontSize: 13),
                                ),
                              ],
                              const SizedBox(height: 8),
                              // Botão mais baixo que o padrão do app (48 em
                              // vez de 56) só nesta tela, via Theme local —
                              // ajuda a caber sem rolar em aparelhos comuns
                              // (360x800) sem afetar o botão em nenhuma
                              // outra tela do app.
                              Theme(
                                data: Theme.of(context).copyWith(
                                  elevatedButtonTheme: ElevatedButtonThemeData(
                                    style: Theme.of(context)
                                        .elevatedButtonTheme
                                        .style
                                        ?.copyWith(
                                          minimumSize:
                                              const WidgetStatePropertyAll(
                                                  Size.fromHeight(48)),
                                        ),
                                  ),
                                ),
                                child: ElevatedButton(
                                  onPressed: (_submitting || !_formularioValido)
                                      ? null
                                      : _handleCadastro,
                                  child: _submitting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.textOnBrand,
                                          ),
                                        )
                                      : const Text('CRIAR CONTA'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cabeçalho compacto específico do Cadastro — não reaproveita o
/// [AuthHeader] compartilhado (usado por Login/Esqueci senha, fora do
/// escopo deste redesign) porque precisa encolher com o teclado, algo que
/// alteraria a aparência das outras duas telas se fosse feito no
/// componente comum.
class _CadastroHeader extends StatelessWidget {
  const _CadastroHeader({required this.compacto, required this.onBack});

  final bool compacto;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: double.infinity,
      padding:
          EdgeInsets.fromLTRB(20, compacto ? 4 : 10, 20, compacto ? 12 : 10),
      decoration: const BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        // layoutBuilder default empilha o conteúdo que está saindo por
        // cima do que está entrando (Stack), dimensionado pela união dos
        // dois — com o cabeçalho cheio bem maior que o compacto, essa
        // união transitória pode passar do espaço disponível numa tela
        // pequena com teclado bem alto (RenderFlex overflow só durante a
        // animação, nunca depois de acomodada). Como o AnimatedContainer
        // já cuida da transição suave do tamanho do próprio cabeçalho,
        // aqui só precisamos do fade do conteúdo — sem empilhar os dois
        // estados.
        layoutBuilder: (currentChild, previousChildren) =>
            currentChild ?? const SizedBox.shrink(),
        child: compacto
            ? Row(
                key: const ValueKey('compacto'),
                children: [
                  _BotaoVoltar(onBack: onBack),
                  const SizedBox(width: 4),
                  Image.asset('assets/images/logo.png', width: 32, height: 32),
                  const SizedBox(width: 10),
                  const Text(
                    'PetConnect',
                    style: TextStyle(
                      color: AppColors.textOnBrand,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            : Column(
                key: const ValueKey('completo'),
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: _BotaoVoltar(onBack: onBack),
                  ),
                  Image.asset('assets/images/logo.png',
                      width: 108, height: 108),
                  const SizedBox(height: 6),
                  const Text(
                    'PetConnect',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textOnBrand,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _BotaoVoltar extends StatelessWidget {
  const _BotaoVoltar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onBack,
      icon: const Icon(Icons.arrow_back, color: AppColors.textOnBrand),
      tooltip: 'Voltar',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    );
  }
}
