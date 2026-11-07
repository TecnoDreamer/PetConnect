import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/auth_header.dart';
import '../../../usuario/presentation/providers/auth_providers.dart';

class EsqueciSenhaScreen extends ConsumerStatefulWidget {
  const EsqueciSenhaScreen({super.key});

  @override
  ConsumerState<EsqueciSenhaScreen> createState() => _EsqueciSenhaScreenState();
}

class _EsqueciSenhaScreenState extends ConsumerState<EsqueciSenhaScreen> {
  final _emailController = TextEditingController();
  bool _submitting = false;
  bool _enviado = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleEnviar() async {
    if (_emailController.text.trim().isEmpty) return;

    setState(() => _submitting = true);

    // Mesma mensagem de sucesso independentemente de o e-mail existir ou
    // não na base — evita enumeração de contas (ver docs/seguranca.md).
    try {
      await ref
          .read(usuarioRepositoryProvider)
          .sendPasswordReset(email: _emailController.text.trim());
    } catch (_) {
      // Ignorado de propósito — não revelamos ao usuário se a operação
      // falhou por e-mail inexistente ou outro motivo.
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _enviado = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthHeader(onBack: () => context.pop()),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Esqueceu sua senha?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Informe o e-mail da sua conta para receber um link de redefinição de senha.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 24),
                    if (_enviado)
                      const Text(
                        'Se esse e-mail estiver cadastrado, você vai receber um link de redefinição em instantes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textPrimary),
                      )
                    else ...[
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        // A borda vem do tema; a altura é a do campo de
                        // e-mail da tela Entrar.
                        decoration: const InputDecoration(
                          hintText: 'E-mail:',
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _submitting ? null : _handleEnviar,
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.textOnBrand,
                                ),
                              )
                            : const Text('ENVIAR'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
