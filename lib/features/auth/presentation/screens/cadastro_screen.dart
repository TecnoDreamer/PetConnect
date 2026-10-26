import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  final _composicaoKey = GlobalKey();
  bool _tecladoAberto = false;

  /// `false` quando o painel não cabe na tela nem com o cabeçalho no
  /// tamanho mínimo — aí a tela usa a rolagem de exceção.
  bool _cabeSemRolagem = true;

  /// Altura do cabeçalho na tela normal, mantida enquanto o teclado está
  /// aberto.
  double? _alturaCabecalhoEstatico;

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
  // Correção de 2026-10-24 (ver docs/features/cadastro-layout-estatico.md):
  // cabeçalho e painel são posicionados por [_CabecalhoComPainel], um
  // layout próprio que mede o painel primeiro e entrega ao cabeçalho só a
  // altura que sobra — sem SingleChildScrollView nem Transform.translate
  // no estado normal. O painel é o último filho, então é pintado por cima
  // do cabeçalho na faixa em que os dois se encontram.

  static const _sobreposicao = 32.0;
  static const _margemHorizontal = 20.0;
  static const _margemInferior = 12.0;

  /// Altura reservada para a mensagem de erro geral (Firebase) acima do
  /// botão, em linhas — reservada sempre, para o erro não empurrar nada.
  static const _linhasErroGeral = 2;
  static const _estiloErroGeral =
      TextStyle(color: AppColors.error, fontSize: 13, height: 1.25);

  void _aoMedirComposicao(_MedidaComposicao medida) {
    if (medida.alturaLimitada) {
      _alturaCabecalhoEstatico = medida.alturaCabecalho;
    }
    // Com o teclado aberto a altura disponível é a que sobrou acima dele —
    // não serve para decidir se a tela normal cabe sem rolagem.
    if (_tecladoAberto || medida.cabeSemRolagem == _cabeSemRolagem) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _cabeSemRolagem = medida.cabeSemRolagem);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tecladoAberto = MediaQuery.viewInsetsOf(context).bottom > 0;
    _tecladoAberto = tecladoAberto;
    final escala = MediaQuery.textScalerOf(context);
    final alturaMarca = _CadastroHeader.alturaDaMarca(escala);
    final alturaMinimaCabecalho = _CadastroHeader.alturaPara(
        alturaMarca: alturaMarca,
        logo: _CadastroHeader.logoMinimo,
        sobreposicao: _sobreposicao);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final composicao = _CabecalhoComPainel(
              // GlobalKey: ao abrir o teclado a composição muda de pai (entra
              // na rolagem temporária) sem perder o estado dos campos nem o
              // foco do campo que está sendo editado.
              key: _composicaoKey,
              geometria: _GeometriaComposicao(
                sobreposicao: _sobreposicao,
                margemHorizontal: _margemHorizontal,
                margemInferior: _margemInferior,
                alturaMinimaCabecalho: alturaMinimaCabecalho,
                // Com o teclado aberto o cabeçalho mantém exatamente a
                // altura da tela normal — só a rolagem muda, nada encolhe.
                alturaCabecalhoSemLimite: tecladoAberto
                    ? (_alturaCabecalhoEstatico ?? alturaMinimaCabecalho)
                    : alturaMinimaCabecalho,
                alturaDeReferencia: constraints.maxHeight,
              ),
              aoMedir: _aoMedirComposicao,
              cabecalho: _CadastroHeader(
                sobreposicao: _sobreposicao,
                onBack: () => context.pop(),
              ),
              painel: _construirPainel(escala),
            );

            // Estado normal: composição estática, sem nenhum Scrollable na
            // árvore. Rolagem só existe (a) enquanto o teclado estiver
            // aberto, para o campo focado continuar visível, ou (b) quando
            // o painel não cabe nem com o cabeçalho no tamanho mínimo
            // (aparelho muito baixo e/ou fonte do sistema muito ampliada) —
            // exceções documentadas em vez de campos inacessíveis.
            if (!tecladoAberto && _cabeSemRolagem) return composicao;
            return SingleChildScrollView(child: composicao);
          },
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
/// [_CabecalhoComPainel] e acomoda o logo no que sobra (entre
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

// --- Layout cabeçalho + painel -------------------------------------------

@immutable
class _GeometriaComposicao {
  const _GeometriaComposicao({
    required this.sobreposicao,
    required this.margemHorizontal,
    required this.margemInferior,
    required this.alturaMinimaCabecalho,
    required this.alturaCabecalhoSemLimite,
    required this.alturaDeReferencia,
  });

  /// Quanto o painel invade a base do cabeçalho.
  final double sobreposicao;
  final double margemHorizontal;
  final double margemInferior;
  final double alturaMinimaCabecalho;

  /// Altura do cabeçalho quando a composição está dentro de uma rolagem
  /// (altura sem limite) — não há "sobra" para distribuir.
  final double alturaCabecalhoSemLimite;

  /// Altura útil da tela, usada para dizer se a composição caberia sem
  /// rolagem mesmo quando ela está dentro de uma.
  final double alturaDeReferencia;

  @override
  bool operator ==(Object other) =>
      other is _GeometriaComposicao &&
      other.sobreposicao == sobreposicao &&
      other.margemHorizontal == margemHorizontal &&
      other.margemInferior == margemInferior &&
      other.alturaMinimaCabecalho == alturaMinimaCabecalho &&
      other.alturaCabecalhoSemLimite == alturaCabecalhoSemLimite &&
      other.alturaDeReferencia == alturaDeReferencia;

  @override
  int get hashCode => Object.hash(
        sobreposicao,
        margemHorizontal,
        margemInferior,
        alturaMinimaCabecalho,
        alturaCabecalhoSemLimite,
        alturaDeReferencia,
      );
}

class _MedidaComposicao {
  const _MedidaComposicao({
    required this.alturaCabecalho,
    required this.alturaLimitada,
    required this.cabeSemRolagem,
  });

  final double alturaCabecalho;

  /// `true` quando a composição foi medida na tela normal (altura fixa),
  /// `false` quando estava dentro da rolagem.
  final bool alturaLimitada;

  /// Se o painel caberia inteiro na [_GeometriaComposicao.alturaDeReferencia]
  /// com o cabeçalho no tamanho mínimo.
  final bool cabeSemRolagem;
}

/// Cabeçalho (1º filho) atrás, painel (2º filho) na frente.
///
/// O painel é medido primeiro, na sua altura natural; o cabeçalho recebe a
/// altura que sobra (entre o mínimo e o máximo) mais a [sobreposicao], e o
/// painel é posicionado começando [sobreposicao] pixels antes do fim do
/// cabeçalho. Como o painel é pintado depois, ele fica na frente na faixa
/// em comum — e também recebe os toques primeiro nessa faixa.
class _CabecalhoComPainel extends MultiChildRenderObjectWidget {
  _CabecalhoComPainel({
    super.key,
    required this.geometria,
    required this.aoMedir,
    required Widget cabecalho,
    required Widget painel,
  }) : super(children: [cabecalho, painel]);

  final _GeometriaComposicao geometria;
  final ValueChanged<_MedidaComposicao> aoMedir;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCabecalhoComPainel(geometria: geometria, aoMedir: aoMedir);

  @override
  void updateRenderObject(
      BuildContext context, _RenderCabecalhoComPainel renderObject) {
    renderObject
      ..geometria = geometria
      ..aoMedir = aoMedir;
  }
}

class _PosicaoNaComposicao extends ContainerBoxParentData<RenderBox> {}

class _RenderCabecalhoComPainel extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _PosicaoNaComposicao>,
        RenderBoxContainerDefaultsMixin<RenderBox, _PosicaoNaComposicao> {
  _RenderCabecalhoComPainel({
    required _GeometriaComposicao geometria,
    required this.aoMedir,
  }) : _geometria = geometria;

  _GeometriaComposicao _geometria;
  set geometria(_GeometriaComposicao valor) {
    if (valor == _geometria) return;
    _geometria = valor;
    markNeedsLayout();
  }

  ValueChanged<_MedidaComposicao> aoMedir;

  bool _transbordou = false;
  final _recorte = LayerHandle<ClipRectLayer>();

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _PosicaoNaComposicao) {
      child.parentData = _PosicaoNaComposicao();
    }
  }

  @override
  void performLayout() {
    final g = _geometria;
    final cabecalho = firstChild!;
    final painel = childAfter(cabecalho)!;
    final largura = constraints.maxWidth;

    painel.layout(
      BoxConstraints.tightFor(
          width: math.max(0, largura - 2 * g.margemHorizontal)),
      parentUsesSize: true,
    );
    final alturaPainel = painel.size.height;

    final alturaLimitada = constraints.hasBoundedHeight;
    final alturaCabecalho = alturaLimitada
        // Sem teto: toda a sobra vai para o cabeçalho, então o painel fica
        // sempre ancorado logo acima da margem inferior, sem faixa vazia
        // embaixo dele em telas altas.
        ? math.max(
            g.alturaMinimaCabecalho,
            constraints.maxHeight -
                alturaPainel -
                g.margemInferior +
                g.sobreposicao,
          )
        : g.alturaCabecalhoSemLimite;
    cabecalho.layout(
        BoxConstraints.tightFor(width: largura, height: alturaCabecalho));

    (cabecalho.parentData! as _PosicaoNaComposicao).offset = Offset.zero;
    (painel.parentData! as _PosicaoNaComposicao).offset =
        Offset(g.margemHorizontal, alturaCabecalho - g.sobreposicao);

    final alturaConteudo =
        alturaCabecalho - g.sobreposicao + alturaPainel + g.margemInferior;
    size = alturaLimitada
        ? constraints.biggest
        : constraints.constrain(Size(largura, alturaConteudo));
    _transbordou = alturaConteudo > size.height + 0.5;

    final alturaNecessaria = g.alturaMinimaCabecalho -
        g.sobreposicao +
        alturaPainel +
        g.margemInferior;
    aoMedir(_MedidaComposicao(
      alturaCabecalho: alturaCabecalho,
      alturaLimitada: alturaLimitada,
      cabeSemRolagem: alturaNecessaria <= g.alturaDeReferencia + 0.5,
    ));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // Só recorta no único quadro em que o painel ainda não coube (antes de
    // a tela trocar para a rolagem de exceção) — nunca no uso normal, para
    // não cortar a sombra do painel.
    if (_transbordou) {
      _recorte.layer = context.pushClipRect(
          needsCompositing, offset, Offset.zero & size, defaultPaint,
          oldLayer: _recorte.layer);
    } else {
      _recorte.layer = null;
      defaultPaint(context, offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void dispose() {
    _recorte.layer = null;
    super.dispose();
  }
}
