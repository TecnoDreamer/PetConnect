import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Cabeçalho com gradiente de marca, logo e padrão de patinhas, reaproveitado
/// nas telas de login, cadastro e recuperação de senha para manter a
/// identidade visual consistente entre elas.
///
/// O arquivo `assets/images/pawprints.png` precisa existir (PNG com fundo
/// transparente) para o padrão de patinhas aparecer — sem ele, a área some
/// silenciosamente (ver [_PawPrintsBackground]).
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, this.onBack});

  /// Quando não nulo, mostra uma seta de voltar (telas empilhadas sobre o
  /// login, como cadastro e esqueci-senha). O login, por ser a rota raiz,
  /// não passa esse callback.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      // Padding vertical reduzido em 2026-09-14 (fix/login-card-sobreposicao
      // -estatica): só espaçamento, nunca o logo/texto/cor em si — a tela de
      // Login não cabia numa única viewport em aparelhos comuns sem este
      // ajuste (ver docs/features/login-layout-static-fix.md). Benefício
      // colateral: Esqueci senha (mesmo cabeçalho) também ganha mais espaço.
      padding: EdgeInsets.fromLTRB(24, onBack != null ? 8 : 14, 24, 14),
      decoration: const BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(48),
          bottomRight: Radius.circular(48),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(48),
          bottomRight: Radius.circular(48),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: _PawPrintsBackground()),
            // O SizedBox força a coluna a ocupar a largura inteira do
            // cabeçalho — sem ele, quando não há botão de voltar (login), a
            // coluna encolhe para a largura do próprio conteúdo e fica
            // alinhada à esquerda do Stack em vez de centralizada.
            SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  if (onBack != null)
                    Align(
                      alignment: Alignment.topLeft,
                      child: IconButton(
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back,
                            color: AppColors.textOnBrand),
                      ),
                    ),
                  Image.asset('assets/images/logo.png',
                      width: 160, height: 160),
                  const SizedBox(height: 10),
                  const Text(
                    'PetConnect',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textOnBrand,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Conectando corações perdidos aos seus lares',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: AppColors.textOnBrand, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PawPrintsBackground extends StatelessWidget {
  const _PawPrintsBackground();

  @override
  Widget build(BuildContext context) {
    // ShaderMask com um gradiente branco->transparente de cima para baixo
    // "apaga" gradualmente as patinhas perto da base do header, dando a
    // impressão de que elas descem e somem.
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, Colors.white, Colors.transparent],
        stops: [0.0, 0.55, 1.0],
      ).createShader(bounds),
      child: Opacity(
        opacity: 0.16,
        child: Image.asset(
          'assets/images/pawprints.png',
          repeat: ImageRepeat.repeat,
          fit: BoxFit.none,
          alignment: Alignment.topLeft,
          // Decodifica a imagem menor que o tamanho original — é isso que
          // faz várias patinhas aparecerem lado a lado em vez de poucas
          // patinhas grandes e espaçadas. Valor maior = patinhas maiores.
          cacheWidth: 64,
          filterQuality: FilterQuality.medium,
          // Some silenciosamente se o arquivo ainda não foi adicionado, em vez
          // de mostrar o ícone de erro padrão do Flutter por cima do header.
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}
