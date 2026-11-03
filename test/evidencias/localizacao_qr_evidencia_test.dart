// Evidência visual da aba Localização com relatos e acessos do QR (issue
// #37). Fora do CI: grava build/evidencias/localizacao_qr.png. Dados
// fictícios.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_connect/core/theme/app_theme.dart';
import 'package:pet_connect/features/pet/domain/atividade_do_qr.dart';
import 'package:pet_connect/features/pet/domain/localizacao.dart';
import 'package:pet_connect/features/pet/presentation/providers/localizacao_providers.dart';
import 'package:pet_connect/features/pet/presentation/screens/localizacao_list_screen.dart';

import '../helpers/fonte_roboto.dart';

final _atividade = AtividadeDoQr.daApi({
  'sightings': [
    {
      'id': 's-gps',
      'reportedAt': '2026-11-03T13:42:00Z',
      'latitude': -22.1701,
      'longitude': -47.3912,
      'accuracyMeters': 35.4,
      'positionSource': 'BROWSER_GEOLOCATION',
      'description': 'Perto da praça, sem coleira',
    },
    {
      'id': 's-texto',
      'reportedAt': '2026-11-01T12:10:00Z',
      'description': 'Vi passando na rua da escola',
      'reporterContact': 'Carlos',
      'positionSource': 'NONE',
    },
  ],
  'recentAccesses': [
    {'occurredAt': '2026-11-03T13:40:00Z'},
  ],
  'accessesLast30Days': 3,
});

void main() {
  setUpAll(carregarRoboto);

  testWidgets('aba Localização com relatos do QR', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final limite = GlobalKey();

    await tester.pumpWidget(RepaintBoundary(
      key: limite,
      child: ProviderScope(
        overrides: [
          localizacoesProvider.overrideWith((ref, petId) => Stream.value(const [
                Localizacao(
                    id: 't-1',
                    data: '02/11/2026',
                    descricao: 'Registro do tutor: vizinho viu no portão'),
              ])),
          atividadeDoQrProvider.overrideWith((ref, petId) async => _atividade),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const LocalizacaoListScreen(petId: 'pet-1'),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final render =
          limite.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final imagem = await render.toImage(pixelRatio: 2);
      final png = await imagem.toByteData(format: ui.ImageByteFormat.png);
      imagem.dispose();
      Directory('build/evidencias').createSync(recursive: true);
      File('build/evidencias/localizacao_qr.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
