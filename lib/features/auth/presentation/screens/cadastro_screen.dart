import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/auth_error_translator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/composicao_cabecalho_painel.dart';
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
///
/// Layout (painel na frente do cabeçalho, sem rolagem no estado normal):
/// correção de 2026-10-24, ver docs/features/cadastro-layout-estatico.md.
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
    _senhaFocus.addListener(
        () => _aoPerderFoco(_senhaFocus, () => _senhaTocado = true));
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

  // --- Composição da tela ---------------------------------------------
  //
  // Cabeçalho atrás e painel na frente, sem SingleChildScrollView nem
  // Transform no estado normal — ver [ComposicaoCabecalhoPainel] e
  // docs/features/cadastro-layout-estatico.md.

  static const _sobreposicao = 32.0;

  /// Altura reservada para a mensagem de erro geral (Firebase) acima do
  /// botão, em linhas — reservada sempre, para o erro não empurrar nada.
  static const _linhasErroGeral = 2;
  static const _estiloErroGeral =
      TextStyle(color: AppColors.error, fontSize: 13, height: 1.25);

  @override
  Widget build(BuildContext context) {
    final escala = MediaQuery.textScalerOf(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ComposicaoCabecalhoPainel(
          sobreposicao: _sobreposicao,
          margemHorizontal: 20,
          margemInferior: 12,
          alturaMinimaCabecalho: _CadastroHeader.alturaPara(
            alturaMarca: _CadastroHeader.alturaDaMarca(escala),
            logo: _CadastroHeader.logoMinimo,
            sobreposicao: _sobreposicao,
          ),
          cabecalho: _CadastroHeader(
            sobreposicao: _sobreposicao,
            onBack: () => context.pop(),
          ),
          painel: _construirPainel(escala),
        ),
      ),
    );
  }

  Widget _construirPainel(TextScaler escala) {
    return Container(
      key: const ValueKey('cadastro-painel'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandDark.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: _campos,
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Crie sua conta',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Cadastre seus dados para começar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            CadastroTextField(
              label: 'Nome completo',
              controller: _nomeController,
              focusNode: _nomeFocus,
              keyboardType: TextInputType.name,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              errorText: _erroNome,
              onFieldSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(_emailFocus),
            ),
            CadastroTextField(
              label: 'E-mail',
              controller: _emailController,
              focusNode: _emailFocus,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              errorText: _erroEmail,
              onFieldSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(_telefoneFocus),
            ),
            CadastroTextField(
              label: 'Telefone',
              controller: _telefoneController,
              focusNode: _telefoneFocus,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              inputFormatters: [BrPhoneInputFormatter()],
              autofillHints: const [AutofillHints.telephoneNumber],
              errorText: _erroTelefone,
              onFieldSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(_senhaFocus),
            ),
            CadastroTextField(
              label: 'Senha',
              controller: _senhaController,
              focusNode: _senhaFocus,
              obscureText: !_senhaVisivel,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              errorText: _erroSenha,
              suffixIcon: IconButton(
                icon: Icon(
                  _senhaVisivel
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                tooltip: _senhaVisivel ? 'Ocultar senha' : 'Mostrar senha',
                onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
              ),
              onFieldSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(_confirmarSenhaFocus),
            ),
            // Sempre visível (antes aparecia/sumia com o foco): ocupa uma
            // altura fixa, então marcar um requisito como atendido nunca
            // move os campos de baixo.
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child:
                  PasswordRequirementsChecklist(senha: _senhaController.text),
            ),
            CadastroTextField(
              label: 'Confirmar senha',
              controller: _confirmarSenhaController,
              focusNode: _confirmarSenhaFocus,
              obscureText: !_confirmarSenhaVisivel,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
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
                          _confirmarSenhaVisivel = !_confirmarSenhaVisivel),
                    ),
              onFieldSubmitted: (_) {
                FocusScope.of(context).unfocus();
                if (_formularioValido) _handleCadastro();
              },
            ),
            SizedBox(
              height: escala.scale(_estiloErroGeral.fontSize!) *
                      _estiloErroGeral.height! *
                      _linhasErroGeral +
                  4,
              child: Center(
                child: _erroGeral == null
                    ? null
                    : Text(
                        _erroGeral!,
                        textAlign: TextAlign.center,
                        maxLines: _linhasErroGeral,
                        overflow: TextOverflow.ellipsis,
                        style: _estiloErroGeral,
                      ),
              ),
            ),
            ElevatedButton(
              // 48 (não os 56 do tema): mínimo de área de toque acessível,
              // mesma escolha do botão ENTRAR do Login.
              style: const ButtonStyle(
                minimumSize: WidgetStatePropertyAll(Size.fromHeight(48)),
              ),
              onPressed:
                  (_submitting || !_formularioValido) ? null : _handleCadastro,
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
          ],
        ),
      ),
    );
  }
}

/// Cabeçalho marrom do Cadastro — recebe uma altura exata de
/// [ComposicaoCabecalhoPainel] e acomoda o logo no que sobra (entre
/// [logoMinimo] e [logoMaximo], o mesmo tamanho do Login), com o conjunto
/// logo + nome centralizado na área marrom visível. Não reaproveita o
/// [AuthHeader]
/// compartilhado (Login/Esqueci senha) porque precisa ter altura variável.
class _CadastroHeader extends StatelessWidget {
  const _CadastroHeader({required this.sobreposicao, required this.onBack});

  /// Faixa inferior coberta pelo painel — o conteúdo do cabeçalho termina
  /// acima dela.
  final double sobreposicao;
  final VoidCallback onBack;

  static const logoMinimo = 56.0;
  static const logoMaximo = 160.0;
  static const _respiroTopo = 6.0;
  static const _respiroBase = 10.0;
  static const _espacoLogoMarca = 4.0;
  static const _estiloMarca = TextStyle(
    color: AppColors.textOnBrand,
    fontSize: 30,
    fontWeight: FontWeight.bold,
    // Altura de linha explícita: torna a altura do texto previsível para
    // calcular o tamanho do cabeçalho (ver [alturaDaMarca]).
    height: 1.2,
  );

  static double alturaDaMarca(TextScaler escala) =>
      escala.scale(_estiloMarca.fontSize!) * _estiloMarca.height!;

  static double alturaPara({
    required double alturaMarca,
    required double logo,
    required double sobreposicao,
  }) =>
      _respiroTopo +
      logo +
      _espacoLogoMarca +
      alturaMarca +
      _respiroBase +
      sobreposicao;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('cadastro-cabecalho'),
      decoration: const BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, _respiroTopo, 16, _respiroBase + sobreposicao),
            child: LayoutBuilder(
              builder: (context, area) {
                // -1: folga contra arredondamento de ponto flutuante na
                // altura do texto (evita overflow de fração de pixel).
                final lado = (area.maxHeight -
                        _espacoLogoMarca -
                        alturaDaMarca(MediaQuery.textScalerOf(context)) -
                        1)
                    .clamp(0.0, logoMaximo);
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/images/logo.png',
                        width: lado, height: lado),
                    const SizedBox(height: _espacoLogoMarca),
                    const Text(
                      'PetConnect',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: _estiloMarca,
                    ),
                  ],
                );
              },
            ),
          ),
          // Fora do fluxo do logo: não consome uma faixa de altura própria
          // (o logo é centralizado e nunca alcança o canto esquerdo).
          Positioned(top: 4, left: 4, child: _BotaoVoltar(onBack: onBack)),
        ],
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
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    );
  }
}
