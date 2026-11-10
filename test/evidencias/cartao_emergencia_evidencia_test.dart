// Evidência visual do Cartão de Emergência (issue #41). Fora do CI: grava
// build/evidencias/cartao_emergencia.png com o cartão vazio, o cartão
// preenchido e o formulário. Dados fictícios.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pet_connect/core/theme/app_theme.dart';
import 'package:pet_connect/features/pet/domain/cartao_emergencia.dart';
import 'package:pet_connect/features/pet/domain/cartao_emergencia_repository.dart';
import 'package:pet_connect/features/pet/domain/pet.dart';
import 'package:pet_connect/features/pet/presentation/providers/cartao_emergencia_providers.dart';
import 'package:pet_connect/features/pet/presentation/providers/pet_providers.dart';
import 'package:pet_connect/features/pet/presentation/screens/cartao_emergencia_form_screen.dart';
import 'package:pet_connect/features/pet/presentation/screens/cartao_emergencia_screen.dart';
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

final _completo = CartaoEmergencia(
  situacaoAlergias: SituacaoDaLista.informada,
  alergias: const [
    Alergia(id: 'a1', substancia: 'Dipirona', reacao: 'Vômito e coceira'),
  ],
  situacaoMedicamentos: SituacaoDaLista.informada,
  medicamentos: const [
    Medicamento(
        id: 'm1',
        nome: 'Fenobarbital',
        dose: '50 mg',
        frequencia: '12 em 12 h'),
  ],
  situacaoCondicoes: SituacaoDaLista.nenhumaDeclarada,
  observacoes: 'Morde quando sente dor. Usar focinheira.',
  veterinario: const VeterinarioDeConfianca(
      nome: 'Dra. Exemplo',
      clinica: 'Clínica Exemplo',
      telefone: '+5519900000001'),
  atualizadoEm: DateTime(2026, 11, 9, 10, 30),
  revisao: 3,
);

class _Repo implements CartaoEmergenciaRepository {
  _Repo(this.cartao);

  final CartaoEmergencia cartao;

  @override
  Stream<LeituraDoCartao> observar(String petId) => Stream.value(
      LeituraDoCartao(cartao: cartao, doCacheLocal: false, existe: true));

  @override
  Future<void> salvar(String petId, CartaoEmergencia cartao,
          {required int revisaoEsperada}) =>
      throw UnimplementedError();
}

Widget _tela(Widget tela, CartaoEmergencia cartao) => ProviderScope(
      overrides: [
        currentUsuarioProvider.overrideWith((ref) => Stream.value(_tutor)),
        petProvider.overrideWith((ref, id) => Stream.value(_pet)),
        cartaoEmergenciaDisponivelProvider.overrideWithValue(true),
        cartaoEmergenciaRepositoryProvider.overrideWithValue(_Repo(cartao)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: tela,
      ),
    );

/// Sem a fonte de ícones, `flutter test` desenha quadrados. Ela vem do
/// próprio Flutter SDK; se não estiver lá, a evidência sai sem ícones.
Future<void> _carregarIcones() async {
  final raiz = Platform.environment['FLUTTER_ROOT'];
  if (raiz == null) return;
  final arquivo = File(
      '$raiz/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
  if (!arquivo.existsSync()) return;
  final bytes = arquivo.readAsBytesSync();
  await (FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.view(bytes.buffer))))
      .load();
}

void main() {
  setUpAll(() async {
    await carregarRoboto();
    await _carregarIcones();
    await initializeDateFormatting('pt_BR');
  });

  testWidgets('cartão vazio, preenchido e formulário', (tester) async {
    tester.view.physicalSize = const Size(1290, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final limite = GlobalKey();

    await tester.pumpWidget(RepaintBoundary(
      key: limite,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(children: [
          Expanded(
            child: _tela(const CartaoEmergenciaScreen(petId: 'pet-1'),
                CartaoEmergencia.vazio),
          ),
          const SizedBox(width: 8),
          Expanded(
            child:
                _tela(const CartaoEmergenciaScreen(petId: 'pet-1'), _completo),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _tela(
                CartaoEmergenciaFormScreen(petId: 'pet-1', inicial: _completo),
                _completo),
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
      File('build/evidencias/cartao_emergencia.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
