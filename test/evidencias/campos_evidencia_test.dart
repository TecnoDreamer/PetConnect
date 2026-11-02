// Evidência da padronização dos campos de texto
// (docs/features/padronizacao-campos.md): os mesmos campos nos três temas,
// com a aparência anterior (preenchida, sem borda) e a atual (borda da tela
// Entrar). Fora do CI. Grava build/evidencias/campos_antes_depois.png.
//   flutter test test/evidencias/campos_evidencia_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_connect/core/theme/app_palette.dart';
import 'package:pet_connect/core/theme/app_theme.dart';
import 'package:pet_connect/core/theme/app_theme_mode.dart';

import '../helpers/fonte_roboto.dart';

/// O tema de antes da padronização: preenchido e sem borda.
ThemeData _anterior(AppThemeMode modo) {
  final tema = AppTheme.build(modo);
  return tema.copyWith(
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tema.extension<AppPalette>()!.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      hintStyle: TextStyle(color: tema.extension<AppPalette>()!.textMuted),
    ),
  );
}

class _Campos extends StatelessWidget {
  const _Campos({required this.titulo});

  final String titulo;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ColoredBox(
      color: colors.background,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo,
                style: TextStyle(
                    color: colors.textPrimary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const TextField(
              decoration: InputDecoration(labelText: 'Nome da vacina'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: TextEditingController(text: '02/11/2026'),
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Data de aplicação',
                suffixIcon: Icon(Icons.calendar_today_outlined),
              ),
            ),
            const SizedBox(height: 12),
            const TextField(
              decoration: InputDecoration(
                  labelText: 'Veterinário', errorText: 'Campo obrigatório'),
            ),
            const SizedBox(height: 12),
            const TextField(
              enabled: false,
              decoration: InputDecoration(labelText: 'Desabilitado'),
            ),
            const SizedBox(height: 12),
            const TextField(
              minLines: 2,
              maxLines: 3,
              decoration: InputDecoration(
                  labelText: 'Observações', hintText: 'Opcional'),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  setUpAll(carregarRoboto);

  testWidgets('campos antes e depois, nos três temas', (tester) async {
    tester.view.physicalSize = const Size(1080, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final limite = GlobalKey();

    Widget coluna(AppThemeMode modo, bool depois) => Expanded(
          child: Theme(
            data: depois ? AppTheme.build(modo) : _anterior(modo),
            child: Material(
              child: _Campos(
                  titulo: '${modo.name} — ${depois ? 'depois' : 'antes'}'),
            ),
          ),
        );

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        key: limite,
        child: Column(children: [
          for (final depois in [false, true])
            Expanded(
              child: Row(children: [
                for (final modo in AppThemeMode.values) coluna(modo, depois),
              ]),
            ),
        ]),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final render =
          limite.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final imagem = await render.toImage(pixelRatio: 1);
      final png = await imagem.toByteData(format: ui.ImageByteFormat.png);
      imagem.dispose();
      Directory('build/evidencias').createSync(recursive: true);
      File('build/evidencias/campos_antes_depois.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
