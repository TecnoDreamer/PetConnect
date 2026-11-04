// Evidência visual da tela "Compartilhamento via QR Code" (issue #35). Fora
// do CI: grava build/evidencias/compartilhamento_qr.png com a página nova
// (nada marcado) e a página com nome, cor e telefone marcados. Dados
// fictícios.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pet_connect/core/theme/app_theme.dart';
import 'package:pet_connect/features/pet/domain/compartilhamento_publico.dart';
import 'package:pet_connect/features/pet/domain/pet.dart';
import 'package:pet_connect/features/pet/presentation/providers/pet_providers.dart';
import 'package:pet_connect/features/pet/presentation/screens/compartilhamento_qr_screen.dart';
import 'package:pet_connect/features/usuario/domain/usuario.dart';
import 'package:pet_connect/features/usuario/presentation/providers/auth_providers.dart';

import '../helpers/fonte_roboto.dart';

const _tutor = Usuario(
  id: 'uid-1',
  usuarioID: 'uid-1',
  nome: 'Ana',
  email: 'ana@exemplo.com',
  telefone: '19900000000',
  dataNascimento: '',
  genero: '',
);

const _pet = Pet(
  id: 'pet-1',
  userId: 'uid-1',
  nome: 'Rex',
  especie: 'Cachorro',
  raca: 'SRD',
  cor: 'Caramelo',
  genero: '',
  porte: '',
  peso: '',
  dataNascimento: '',
  vacinado: false,
);

class _Repo implements CompartilhamentoRepository {
  _Repo(this.salvo);

  final CompartilhamentoPublico salvo;

  @override
  Future<CompartilhamentoPublico> buscar(Pet pet) async => salvo;

  @override
  Future<CompartilhamentoPublico> publicar(
          Pet pet, PedidoDeCompartilhamento pedido) =>
      throw UnimplementedError();

  @override
  Future<CompartilhamentoPublico> revogar(Pet pet) =>
      throw UnimplementedError();
}

Widget _tela(CompartilhamentoPublico salvo) => ProviderScope(
      overrides: [
        currentUsuarioProvider.overrideWith((ref) => Stream.value(_tutor)),
        petProvider.overrideWith((ref, id) => Stream.value(_pet)),
        compartilhamentoRepositoryProvider.overrideWithValue(_Repo(salvo)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const CompartilhamentoQrScreen(petId: 'pet-1'),
      ),
    );

void main() {
  setUpAll(() async {
    await carregarRoboto();
    await initializeDateFormatting('pt_BR');
  });

  testWidgets('tela de compartilhamento: nova e publicada', (tester) async {
    tester.view.physicalSize = const Size(840, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final limite = GlobalKey();

    await tester.pumpWidget(RepaintBoundary(
      key: limite,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(children: [
          Expanded(
              child: _tela(const CompartilhamentoPublico(
                  ativado: false, ativo: false, campos: {}))),
          const SizedBox(width: 8),
          Expanded(
            child: _tela(CompartilhamentoPublico(
              ativado: true,
              ativo: true,
              campos: const {
                CampoPublico.nomePet,
                CampoPublico.cor,
                CampoPublico.telefone,
              },
              telefone: '+5519900000000',
              consentidoEm: DateTime(2026, 11, 2, 18, 30),
            )),
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
      File('build/evidencias/compartilhamento_qr.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
