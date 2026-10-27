// QR code regenerável (RF19, issue #29) — o sheet "QR Code do Pet".
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_connect/core/theme/app_theme.dart';
import 'package:pet_connect/core/theme/app_theme_mode.dart';
import 'package:pet_connect/features/pet/domain/pet.dart';
import 'package:pet_connect/features/pet/domain/pet_qr_code.dart';
import 'package:pet_connect/features/pet/domain/pet_qr_repository.dart';
import 'package:pet_connect/features/pet/presentation/providers/pet_providers.dart';
import 'package:pet_connect/features/pet/presentation/widgets/pet_qr_sheet.dart';

import '../../helpers/fonte_roboto.dart';

const _deterministico = 'b5ab5677-27c9-3f7c-98f8-370d7fcd526c'; // de 'pet-1'

Pet _pet({String? qrPublicId}) => Pet(
      id: 'pet-1',
      userId: 'uid-1',
      nome: 'Rex',
      especie: 'Cachorro',
      raca: '',
      cor: '',
      genero: '',
      porte: '',
      peso: '',
      dataNascimento: '',
      vacinado: false,
      qrPublicId: qrPublicId,
    );

/// Simula a API + a fonte do pet: regenerar troca o pet que [petProvider]
/// devolve, como o stream do Firestore faria.
class _FakeQr implements PetQrRepository {
  _FakeQr(
      {this.suporta = true, this.falhaAoRegenerar, this.falhaAoSincronizar});

  final bool suporta;
  QrFalha? falhaAoRegenerar;
  QrFalha? falhaAoSincronizar;
  Pet petAtual = _pet();
  int regeneracoes = 0;
  int sincronizacoes = 0;

  @override
  bool get suportaRegeneracao => suporta;

  @override
  Future<String> regenerar(Pet pet) async {
    regeneracoes++;
    final falha = falhaAoRegenerar;
    if (falha != null) throw QrRegeneracaoException(falha);
    petAtual = _pet(qrPublicId: 'qr-$regeneracoes');
    return petAtual.qrPublicId!;
  }

  @override
  Future<void> sincronizar(Pet pet) async {
    sincronizacoes++;
    final falha = falhaAoSincronizar;
    if (falha != null) throw QrRegeneracaoException(falha);
  }
}

Future<void> _abrir(
  WidgetTester tester,
  _FakeQr qr, {
  AppThemeMode modo = AppThemeMode.padrao,
  Size tamanho = const Size(412, 915),
  double escalaFonte = 1,
}) async {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      petQrRepositoryProvider.overrideWithValue(qr),
      petProvider.overrideWith((ref, id) => Stream.value(qr.petAtual)),
    ],
    child: MaterialApp(
      theme: AppTheme.build(modo),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(escalaFonte)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: PetQrSheet(pet: _pet()),
                  ),
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

Finder _qrCom(String publicId) =>
    find.byKey(ValueKey(publicPetUrl(_pet(qrPublicId: publicId))));

Future<void> _gerarNovo(WidgetTester tester, {bool confirmar = true}) async {
  await tester.tap(find.text('Gerar novo QR code'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(confirmar ? 'Gerar novo' : 'Cancelar'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(carregarRoboto);

  testWidgets('sem API configurada, mostra o QR mas não oferece regenerar',
      (tester) async {
    final qr = _FakeQr(suporta: false);
    await _abrir(tester, qr);

    expect(_qrCom(_deterministico), findsOneWidget);
    expect(find.text('Gerar novo QR code'), findsNothing);
    expect(qr.sincronizacoes, 0);
  });

  testWidgets('ao abrir, sincroniza o QR com a API em segundo plano',
      (tester) async {
    final qr = _FakeQr();
    await _abrir(tester, qr);

    expect(qr.sincronizacoes, 1);
    expect(_qrCom(_deterministico), findsOneWidget);
  });

  testWidgets('pede confirmação explicando que o QR antigo para de funcionar',
      (tester) async {
    final qr = _FakeQr();
    await _abrir(tester, qr);

    await tester.tap(find.text('Gerar novo QR code'));
    await tester.pumpAndSettle();

    expect(find.text('Gerar um novo QR code?'), findsOneWidget);
    expect(find.textContaining('deixa de funcionar na hora'), findsOneWidget);
    expect(find.textContaining('etiquetas já impressas'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(qr.regeneracoes, 0);
    expect(_qrCom(_deterministico), findsOneWidget);
  });

  testWidgets('confirmando, troca o QR exibido e avisa que o antigo parou',
      (tester) async {
    final qr = _FakeQr();
    await _abrir(tester, qr);

    await _gerarNovo(tester);

    expect(qr.regeneracoes, 1);
    expect(_qrCom('qr-1'), findsOneWidget);
    expect(_qrCom(_deterministico), findsNothing);
    expect(find.textContaining('O anterior não funciona mais'), findsOneWidget);
  });

  for (final (falha, trecho, verificar) in [
    (QrFalha.limite, 'Tente novamente amanhã', false),
    (QrFalha.naoSincronizado, 'ainda não está disponível', false),
    (QrFalha.semConexao, 'Não conseguimos confirmar', true),
    (QrFalha.naoSalvo, 'não conseguimos salvá-lo', true),
    (QrFalha.desconhecida, 'continua valendo', false),
  ]) {
    testWidgets('falha $falha mantém o QR atual e explica o que houve',
        (tester) async {
      final qr = _FakeQr(falhaAoRegenerar: falha);
      await _abrir(tester, qr);

      await _gerarNovo(tester);

      expect(_qrCom(_deterministico), findsOneWidget);
      expect(find.textContaining(trecho), findsOneWidget);
      expect(find.text('Verificar de novo'),
          verificar ? findsOneWidget : findsNothing);
      // Dá para tentar de novo: o botão volta a ficar ativo.
      expect(
          tester
              .widget<TextButton>(find.ancestor(
                  of: find.text('Gerar novo QR code'),
                  matching: find.byWidgetPredicate((w) => w is TextButton)))
              .onPressed,
          isNotNull);
    });
  }

  testWidgets('"Verificar de novo" sincroniza e confirma o QR atual',
      (tester) async {
    final qr = _FakeQr(falhaAoRegenerar: QrFalha.semConexao);
    await _abrir(tester, qr);
    await _gerarNovo(tester);
    expect(qr.sincronizacoes, 1);

    await tester.tap(find.text('Verificar de novo'));
    await tester.pumpAndSettle();

    expect(qr.sincronizacoes, 2);
    expect(find.textContaining('este é o QR code atual'), findsOneWidget);
    expect(find.text('Verificar de novo'), findsNothing);
  });

  testWidgets('"Verificar de novo" sem conexão mantém a opção de verificar',
      (tester) async {
    final qr = _FakeQr(
      falhaAoRegenerar: QrFalha.semConexao,
      falhaAoSincronizar: QrFalha.semConexao,
    );
    await _abrir(tester, qr);
    await _gerarNovo(tester);

    await tester.tap(find.text('Verificar de novo'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Não conseguimos confirmar'), findsOneWidget);
    expect(find.text('Verificar de novo'), findsOneWidget);
  });

  testWidgets('conflito: informa que já tinha sido trocado, sem tom de erro',
      (tester) async {
    final qr = _FakeQr(falhaAoRegenerar: QrFalha.conflito);
    await _abrir(tester, qr);

    await _gerarNovo(tester);

    expect(find.textContaining('já tinha sido trocado'), findsOneWidget);
  });

  for (final modo in AppThemeMode.values) {
    testWidgets('cabe em 360x800 com fonte 1.3 no tema ${modo.name}',
        (tester) async {
      final qr = _FakeQr(falhaAoRegenerar: QrFalha.naoSalvo);
      await _abrir(tester, qr,
          modo: modo, tamanho: const Size(360, 800), escalaFonte: 1.3);
      await _gerarNovo(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Verificar de novo'), findsOneWidget);
      await tester.ensureVisible(find.text('Gerar novo QR code'));
      expect(find.text('Gerar novo QR code').hitTestable(), findsOneWidget);
    });
  }
}
