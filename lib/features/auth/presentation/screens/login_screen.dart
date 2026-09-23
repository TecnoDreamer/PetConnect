import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/auth_error_translator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/auth_header.dart';
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

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          // NeverScrollableScrollPhysics: a tela não pode se mover ao toque
          // (correção de 2026-09-14, ver docs/features/login-layout-static
          // -fix.md) — mesmo que uma combinação futura ainda mais extrema
          // (fonte do sistema muito ampliada + aparelho muito pequeno) volte
          // a sobrar conteúdo, ele é cortado embaixo, nunca vira arrastável.
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthHeader(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                child: Transform.translate(
                  // Sobreposição um pouco maior que antes (32 → 48): o card
                  // invade mais a base da área marrom, de propósito — ajuda
                  // a tela a caber sem rolar e deixa a sobreposição mais
                  // nítida (seção 14 do documento-fonte).
                  offset: const Offset(0, -48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _LoginCard(
                        emailController: _emailController,
                        senhaController: _senhaController,
                        submitting: _submitting,
                        senhaVisivel: _senhaVisivel,
                        onToggleSenhaVisivel: () =>
                            setState(() => _senhaVisivel = !_senhaVisivel),
                        error: _error,
                        onSubmit: _handleLogin,
                        onForgotPassword: () => context.push('/esqueci-senha'),
                      ),
                      const SizedBox(height: 10),
                      const _SocialLoginRow(),
                      const SizedBox(height: 10),
                      _SignUpPrompt(onTap: () => context.push('/cadastro')),
                    ],
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

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.emailController,
    required this.senhaController,
    required this.submitting,
    required this.senhaVisivel,
    required this.onToggleSenhaVisivel,
    required this.error,
    required this.onSubmit,
    required this.onForgotPassword,
  });

  final TextEditingController emailController;
  final TextEditingController senhaController;
  final bool submitting;
  final bool senhaVisivel;
  final VoidCallback onToggleSenhaVisivel;
  final String? error;
  final VoidCallback onSubmit;
  final VoidCallback onForgotPassword;

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
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(
              error!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ],
          const SizedBox(height: 10),
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
              onPressed: submitting ? null : onSubmit,
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
  const _SocialLoginRow();

  @override
  Widget build(BuildContext context) {
    // Altura já é o mínimo de área de toque acessível (48, ver
    // OutlinedButtonThemeData em app_theme.dart) — o Flutter aplica esse
    // piso via tapTargetSize independente de minimumSize, então não dá
    // pra encolher mais sem violar acessibilidade (seção 23 do
    // documento-fonte). Nada a reduzir aqui.
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              // TODO(auth): ligar ao UsuarioRepository.signInWithGoogle()
            },
            icon: const Icon(Icons.g_mobiledata, size: 28),
            label: const Text('Google'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              // TODO(auth): ligar ao UsuarioRepository.signInWithFacebook()
            },
            icon: const Icon(Icons.facebook, color: Color(0xFF1877F2)),
            label: const Text('Facebook'),
          ),
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
