import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_connect/core/theme/app_theme.dart';
import 'package:pet_connect/features/avisos/domain/aviso_do_qr.dart';
import 'package:pet_connect/features/avisos/presentation/avisos_do_pet_secao.dart';
import 'package:pet_connect/features/avisos/presentation/avisos_providers.dart';

/// "Avisos no celular" na tela Compartilhamento via QR Code (issue #36).
class _Repo implements AvisosRepository {
  _Repo(this.atual);

  PreferenciasDeAviso atual;
  final salvas = <PreferenciasDeAviso>[];
  bool falhar = false;

  @override
  Future<PreferenciasDeAviso> preferencias(String petId) async => atual;

  @override
  Future<PreferenciasDeAviso> salvarPreferencias(
      String petId, PreferenciasDeAviso p) async {
    if (falhar) throw Exception('sem rede');
    salvas.add(p);
    return atual = p;
  }

  @override
  Future<void> registrarAparelho(String token) async {}

  @override
  Future<void> removerAparelho(String token) async {}
}

const _ligados =
    PreferenciasDeAviso(avisarAcesso: true, avisarAvistamento: true);

Future<void> _montar(WidgetTester tester, AvisosRepository? repo,
    {PermissaoDeAviso permissao = PermissaoDeAviso.concedida}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      avisosRepositoryProvider.overrideWithValue(repo),
      permissaoDeAvisoProvider.overrideWith((ref) async => permissao),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(
          body: SingleChildScrollView(child: AvisosDoPetSecao(petId: 'pet-1'))),
    ),
  ));
  await tester.pumpAndSettle();
}

bool _ligado(WidgetTester tester, String chave) =>
    tester.widget<SwitchListTile>(find.byKey(ValueKey(chave))).value;

void main() {
  testWidgets('sem a API configurada, a seção não aparece', (tester) async {
    await _montar(tester, null);
    expect(find.text('AVISOS NO CELULAR'), findsNothing);
  });

  testWidgets('mostra os dois avisos ligados por padrão', (tester) async {
    await _montar(tester, _Repo(_ligados));

    expect(find.text('AVISOS NO CELULAR'), findsOneWidget);
    expect(_ligado(tester, 'avisar-acesso'), isTrue);
    expect(_ligado(tester, 'avisar-avistamento'), isTrue);
    expect(find.textContaining('não confirma que alguém viu o pet'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('notificacoes-negadas')), findsNothing);
  });

  testWidgets('desligar o aviso de acesso salva só ele', (tester) async {
    final repo = _Repo(_ligados);
    await _montar(tester, repo);

    await tester.tap(find.byKey(const ValueKey('avisar-acesso')));
    await tester.pumpAndSettle();

    expect(repo.salvas.single.avisarAcesso, isFalse);
    expect(repo.salvas.single.avisarAvistamento, isTrue);
    expect(_ligado(tester, 'avisar-acesso'), isFalse);
  });

  testWidgets('falha ao salvar volta ao valor anterior', (tester) async {
    final repo = _Repo(_ligados)..falhar = true;
    await _montar(tester, repo);

    await tester.tap(find.byKey(const ValueKey('avisar-avistamento')));
    await tester.pumpAndSettle();

    expect(_ligado(tester, 'avisar-avistamento'), isTrue);
    expect(find.text('Não foi possível salvar agora. Tente de novo.'),
        findsOneWidget);
  });

  testWidgets('avisa quando as notificações estão desativadas no Android',
      (tester) async {
    await _montar(tester, _Repo(_ligados), permissao: PermissaoDeAviso.negada);

    expect(find.byKey(const ValueKey('notificacoes-negadas')), findsOneWidget);
  });
}
