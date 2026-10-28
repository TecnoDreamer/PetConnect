import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/auth_error_translator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/auth_header.dart';
import '../../../../core/widgets/composicao_cabecalho_painel.dart';
import '../../../usuario/domain/login_social.dart';
import '../../../usuario/presentation/providers/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _submitting = false;
  bool _senhaVisivel = false;
  String? _error;

  /// Provedor social em andamento. Enquanto houver um, nenhum outro login
  /// começa (nem o de e-mail): evita toques repetidos e logins cruzados.
  ProvedorSocial? _entrandoCom;

  bool get _ocupado => _submitting || _entrandoCom != null;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_ocupado) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(usuarioRepositoryProvider).signIn(
            email: _emailController.text.trim(),
            password: _senhaController.text,
          );
      // Navegação para /home é feita pelo redirect do go_router assim que
      // authStateChangesProvider detectar a sessão — ver app_router.dart.
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = translateAuthError(e.code));
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Não foi possível completar a operação. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _entrarCom(ProvedorSocial provedor) async {
    if (_ocupado) return;
    setState(() {
      _entrandoCom = provedor;
      _error = null;
    });
    try {
      await ref.read(usuarioRepositoryProvider).entrarComProvedor(provedor);
      // Como no e-mail/senha, o redirect do go_router leva à Home.
    } on ContaExisteComOutroMetodo catch (pendente) {
      if (mounted) await _resolverContaExistente(pendente);
    } catch (e) {
      _mostrarErroSocial(provedor, e);
    } finally {
      if (mounted) setState(() => _entrandoCom = null);
    }
  }

  /// Já existe conta com o e-mail do provedor: o tutor prova que é dono
  /// dela entrando pelo método que já usa, e só então o provedor novo é
  /// vinculado. Nada é unido automaticamente pelo e-mail.
  Future<void> _resolverContaExistente(
      ContaExisteComOutroMetodo pendente) async {
    final email = pendente.email;
    // O botão para de carregar enquanto o tutor decide; volta a carregar
    // só durante a vinculação.
    setState(() => _entrandoCom = null);
    if (email == null || email.isEmpty) {
      setState(() => _error = 'Já existe uma conta com este e-mail. Entre '
          'com o método que você já usa.');
      return;
    }
    final escolha = await showDialog<_EscolhaVinculo>(
      context: context,
      builder: (_) => _VincularContaDialog(pendente: pendente, email: email),
    );
    if (escolha == null || !mounted) return;

    setState(() => _entrandoCom = escolha.provedor ?? pendente.provedor);
    final repo = ref.read(usuarioRepositoryProvider);
    try {
      final senha = escolha.senha;
      if (senha != null) {
        await repo.entrarComSenhaEVincular(
            email: email, senha: senha, pendente: pendente);
      } else {
        await repo.entrarComProvedorEVincular(escolha.provedor!, pendente);
      }
    } catch (e) {
      _mostrarErroSocial(escolha.provedor ?? pendente.provedor, e,
          comSenha: escolha.senha != null);
    }
  }

  void _mostrarErroSocial(ProvedorSocial provedor, Object erro,
      {bool comSenha = false}) {
    if (!mounted || erro is LoginSocialCancelado) return;
    final String mensagem;
    if (erro is LoginSocialIndisponivel) {
      mensagem = 'Entrar com o ${provedor.nome} ainda não está disponível '
          'nesta versão.';
    } else if (erro is FirebaseAuthException) {
      mensagem = switch (erro.code) {
        // Com senha, é senha errada; com provedor, o token não valeu
        // (expirado ou acesso revogado).
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' when comSenha =>
          translateAuthError(erro.code),
        'invalid-credential' =>
          'O ${provedor.nome} não confirmou o login. Tente novamente.',
        'user-disabled' => 'Esta conta está desativada.',
        'credential-already-in-use' =>
          'Esta conta ${provedor.nome} já está ligada a outro cadastro.',
        _ => translateAuthError(erro.code),
      };
    } else {
      mensagem = 'Não foi possível entrar com o ${provedor.nome}. Tente '
          'novamente.';
    }
    setState(() => _error = mensagem);
  }

  /// Faixa da base do cabeçalho coberta pelo card.
  static const _sobreposicao = 32.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        // Correção de 2026-10-26 (docs/features/login-layout-distribuido.md):
        // a altura que sobra na tela é dividida entre o cabeçalho e o espaço
        // entre o card e o rodapé, em vez de virar uma faixa vazia embaixo;
        // e o slogan não fica mais escondido atrás do card.
        // Correção de 2026-10-27
        // (docs/features/login-espacamento-acoes-sociais.md): o rodapé
        // acompanha o card, a 28px dele, em vez de ficar ancorado na base.
        child: ComposicaoCabecalhoPainel(
          sobreposicao: _sobreposicao,
          margemHorizontal: 24,
          margemInferior: 16,
          fracaoDaSobraParaCabecalho: 0.5,
          espacoAntesDoRodape: 28,
          cabecalho: const AuthHeader(sobreposicao: _sobreposicao),
          painel: _LoginCard(
            emailController: _emailController,
            senhaController: _senhaController,
            submitting: _submitting,
            senhaVisivel: _senhaVisivel,
            onToggleSenhaVisivel: () =>
                setState(() => _senhaVisivel = !_senhaVisivel),
            error: _error,
            ocupado: _ocupado,
            onSubmit: _handleLogin,
            onForgotPassword: () => context.push('/esqueci-senha'),
          ),
          rodape: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SocialLoginRow(
                entrandoCom: _entrandoCom,
                habilitado: !_ocupado,
                aoEntrarCom: _entrarCom,
              ),
              const SizedBox(height: 16),
              _SignUpPrompt(onTap: () => context.push('/cadastro')),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.emailController,
    required this.senhaController,
    required this.submitting,
    required this.senhaVisivel,
    required this.onToggleSenhaVisivel,
    required this.error,
    required this.ocupado,
    required this.onSubmit,
    required this.onForgotPassword,
  });

  final TextEditingController emailController;
  final TextEditingController senhaController;
  final bool submitting;
  final bool senhaVisivel;
  final VoidCallback onToggleSenhaVisivel;
  final String? error;

  /// Algum login (e-mail ou social) em andamento.
  final bool ocupado;
  final VoidCallback onSubmit;
  final VoidCallback onForgotPassword;

  static const _estiloErro =
      TextStyle(color: AppColors.error, fontSize: 13, height: 1.25);

  @override
  Widget build(BuildContext context) {
    // Os campos desta tela ganham uma borda visível — diferente do padrão
    // "preenchido, sem borda" usado no resto do app (ver InputDecorationTheme
    // em app_theme.dart), a pedido específico para a tela de login.
    final borda = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide:
          BorderSide(color: AppColors.brandLight.withValues(alpha: 0.45)),
    );
    final bordaComFoco = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.brandDark, width: 1.5),
    );

    return Container(
      // Padding vertical reduzido (28 → 18) — a tela precisa caber sem
      // rolar em aparelhos comuns (correção de 2026-09-14); horizontal
      // mantido em 28.
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandDark.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Login',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'E-mail:',
              enabledBorder: borda,
              focusedBorder: bordaComFoco,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: senhaController,
            obscureText: !senhaVisivel,
            decoration: InputDecoration(
              hintText: 'Senha:',
              enabledBorder: borda,
              focusedBorder: bordaComFoco,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
              suffixIcon: IconButton(
                icon: Icon(
                  senhaVisivel
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.textMuted,
                ),
                tooltip: senhaVisivel ? 'Ocultar senha' : 'Mostrar senha',
                onPressed: onToggleSenhaVisivel,
              ),
            ),
          ),
          // Espaço do erro sempre reservado (2 linhas): a mensagem aparece
          // sem mudar a altura do card — senão a composição redistribuiria
          // a sobra e o card subiria um pouco a cada erro.
          SizedBox(
            height:
                MediaQuery.textScalerOf(context).scale(_estiloErro.fontSize!) *
                        _estiloErro.height! *
                        2 +
                    8,
            child: Center(
              child: error == null
                  ? null
                  : Text(
                      error!,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _estiloErro,
                    ),
            ),
          ),
          // Altura mínima reduzida (56 → 48) só neste botão, via Theme
          // local — ajuda a caber sem rolar em aparelhos pequenos; não
          // afeta nenhum outro botão do app.
          Theme(
            data: Theme.of(context).copyWith(
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: Theme.of(context).elevatedButtonTheme.style?.copyWith(
                      minimumSize:
                          const WidgetStatePropertyAll(Size.fromHeight(48)),
                    ),
              ),
            ),
            child: ElevatedButton(
              onPressed: ocupado ? null : onSubmit,
              child: submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textOnBrand,
                      ),
                    )
                  : const Text('ENTRAR'),
            ),
          ),
          Center(
            child: TextButton(
              onPressed: onForgotPassword,
              child: const Text(
                'Esqueceu a senha?',
                style: TextStyle(decoration: TextDecoration.underline),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialLoginRow extends StatelessWidget {
  const _SocialLoginRow({
    required this.entrandoCom,
    required this.habilitado,
    required this.aoEntrarCom,
  });

  final ProvedorSocial? entrandoCom;
  final bool habilitado;
  final ValueChanged<ProvedorSocial> aoEntrarCom;

  @override
  Widget build(BuildContext context) {
    // Altura já é o mínimo de área de toque acessível (48, ver
    // OutlinedButtonThemeData em app_theme.dart) — o Flutter aplica esse
    // piso via tapTargetSize independente de minimumSize, então não dá
    // pra encolher mais sem violar acessibilidade (seção 23 do
    // documento-fonte). Nada a reduzir aqui.
    Widget botao(ProvedorSocial provedor, Widget icone) {
      final carregando = entrandoCom == provedor;
      return Expanded(
        child: OutlinedButton.icon(
          onPressed: habilitado ? () => aoEntrarCom(provedor) : null,
          icon: carregando
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    semanticsLabel: 'Entrando com ${provedor.nome}',
                  ),
                )
              : icone,
          label: Text(provedor.nome),
        ),
      );
    }

    return Row(
      children: [
        botao(ProvedorSocial.google, const Icon(Icons.g_mobiledata, size: 28)),
        const SizedBox(width: 16),
        botao(ProvedorSocial.facebook,
            const Icon(Icons.facebook, color: Color(0xFF1877F2))),
      ],
    );
  }
}

/// Resposta do [_VincularContaDialog]: senha da conta existente, ou o
/// provedor com que o tutor já entra.
class _EscolhaVinculo {
  const _EscolhaVinculo.senha(String this.senha) : provedor = null;
  const _EscolhaVinculo.provedor(ProvedorSocial this.provedor) : senha = null;

  final String? senha;
  final ProvedorSocial? provedor;
}

class _VincularContaDialog extends StatefulWidget {
  const _VincularContaDialog({required this.pendente, required this.email});

  final ContaExisteComOutroMetodo pendente;
  final String email;

  @override
  State<_VincularContaDialog> createState() => _VincularContaDialogState();
}

class _VincularContaDialogState extends State<_VincularContaDialog> {
  final _senha = TextEditingController();
  bool _senhaVisivel = false;

  @override
  void dispose() {
    _senha.dispose();
    super.dispose();
  }

  void _confirmarSenha() {
    if (_senha.text.isEmpty) return;
    Navigator.of(context).pop(_EscolhaVinculo.senha(_senha.text));
  }

  @override
  Widget build(BuildContext context) {
    final novo = widget.pendente.provedor;
    final outros =
        ProvedorSocial.values.where((p) => p != novo).toList(growable: false);
    return AlertDialog(
      title: const Text('Você já tem uma conta'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Já existe uma conta PetConnect com o e-mail ${widget.email}. '
              'Para usar o ${novo.nome} nela, entre primeiro com o método '
              'que você já usa. Depois disso, o ${novo.nome} fica ligado à '
              'mesma conta, com os mesmos pets.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _senha,
              obscureText: !_senhaVisivel,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _confirmarSenha(),
              decoration: InputDecoration(
                labelText: 'Senha da conta',
                suffixIcon: IconButton(
                  icon: Icon(_senhaVisivel
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  tooltip: _senhaVisivel ? 'Ocultar senha' : 'Mostrar senha',
                  onPressed: () =>
                      setState(() => _senhaVisivel = !_senhaVisivel),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListenableBuilder(
              listenable: _senha,
              builder: (context, _) => FilledButton(
                onPressed: _senha.text.isEmpty ? null : _confirmarSenha,
                child: const Text('Entrar com senha e ligar'),
              ),
            ),
            for (final outro in outros)
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(_EscolhaVinculo.provedor(outro)),
                child: Text('Entrar com ${outro.nome} e ligar'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

class _SignUpPrompt extends StatelessWidget {
  const _SignUpPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Wrap (em vez de Row) evita overflow em telas estreitas: se não
    // couber na largura disponível, o link quebra para a linha de baixo
    // em vez de vazar pela borda da tela.
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        const Text(
          'Não tem uma conta? ',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        GestureDetector(
          onTap: onTap,
          child: const Text(
            'Cadastre-se',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
