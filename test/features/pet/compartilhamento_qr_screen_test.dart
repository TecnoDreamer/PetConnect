import 'package:flutter/material.dart';
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

const _tutor = Usuario(
  id: 'uid-1',
  usuarioID: 'uid-1',
  nome: 'Ana',
  sobrenome: 'Souza',
  email: 'ana@teste.com',
  telefone: '19999990000',
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

const _desligado =
    CompartilhamentoPublico(ativado: false, ativo: false, campos: {});

class _FakeRepo implements CompartilhamentoRepository {
  _FakeRepo(this.salvo);

  CompartilhamentoPublico salvo;
  final pedidos = <PedidoDeCompartilhamento>[];
  int revogacoes = 0;
  CompartilhamentoException? falhaAoPublicar;

  @override
  Future<CompartilhamentoPublico> buscar(Pet pet) async => salvo;

  @override
  Future<CompartilhamentoPublico> publicar(
      Pet pet, PedidoDeCompartilhamento pedido) async {
    pedidos.add(pedido);
    if (falhaAoPublicar != null) throw falhaAoPublicar!;
    return salvo = CompartilhamentoPublico(
      ativado: true,
      ativo: true,
      campos: pedido.campos,
      nomeTutor: pedido.nomeTutor,
      telefone: pedido.telefone,
      consentidoEm: DateTime(2026, 11, 2, 18, 30),
    );
  }

  @override
  Future<CompartilhamentoPublico> revogar(Pet pet) async {
    revogacoes++;
    return salvo = CompartilhamentoPublico(
      ativado: false,
      ativo: false,
      campos: const {},
      revogadoEm: DateTime(2026, 11, 2, 19),
    );
  }
}

Widget _app(CompartilhamentoRepository? repo) => ProviderScope(
      overrides: [
        currentUsuarioProvider.overrideWith((ref) => Stream.value(_tutor)),
        petProvider.overrideWith((ref, id) => Stream.value(_pet)),
        compartilhamentoRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const CompartilhamentoQrScreen(petId: 'pet-1'),
      ),
    );

/// Tela alta: a lista monta tudo de uma vez e os botões do fim existem.
Future<void> _montar(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(1080, 4800);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
}

bool _marcado(WidgetTester tester, String chave) =>
    tester.widget<CheckboxListTile>(find.byKey(ValueKey(chave))).value!;

bool _publicarHabilitado(WidgetTester tester) =>
    tester
        .widget<FilledButton>(find.byKey(const ValueKey('publicar')))
        .onPressed !=
    null;

Future<void> _tocar(WidgetTester tester, String chave) async {
  await tester.ensureVisible(find.byKey(ValueKey(chave)));
  await tester.tap(find.byKey(ValueKey(chave)));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('página nova: nenhuma caixa marcada e prévia com o mínimo neutro',
      (tester) async {
    await _montar(tester, _app(_FakeRepo(_desligado)));
    await tester.pumpAndSettle();

    for (final campo in CampoPublico.values) {
      expect(_marcado(tester, 'campo-${campo.api}'), isFalse,
          reason: campo.rotulo);
    }
    expect(_marcado(tester, 'consentimento'), isFalse);
    expect(_publicarHabilitado(tester), isFalse);
    expect(find.text('Página pública desativada'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('previa')),
            matching: find.textContaining('cadastrado no PetConnect')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('desativar')), findsNothing);
  });

  testWidgets('só publica com dado marcado e consentimento', (tester) async {
    final repo = _FakeRepo(_desligado);
    await _montar(tester, _app(repo));
    await tester.pumpAndSettle();

    await _tocar(tester, 'campo-PET_NAME');
    expect(_publicarHabilitado(tester), isFalse);
    expect(find.text('Marque o consentimento para publicar.'), findsOneWidget);

    await _tocar(tester, 'consentimento');
    expect(_publicarHabilitado(tester), isTrue);

    await _tocar(tester, 'publicar');
    expect(repo.pedidos.single.campos, {CampoPublico.nomePet});
    expect(find.text('Página pública ativada.'), findsOneWidget);
    expect(find.text('Página pública ativa'), findsOneWidget);
    // Cada publicação é um consentimento novo.
    expect(_marcado(tester, 'consentimento'), isFalse);
    expect(find.text('Salvar alterações'), findsOneWidget);
  });

  testWidgets('prévia mostra só o que está marcado', (tester) async {
    await _montar(tester, _app(_FakeRepo(_desligado)));
    await tester.pumpAndSettle();
    final previa = find.byKey(const ValueKey('previa'));

    await _tocar(tester, 'campo-PET_NAME');
    await _tocar(tester, 'campo-COLOR');

    expect(find.descendant(of: previa, matching: find.text('Rex')),
        findsOneWidget);
    expect(find.descendant(of: previa, matching: find.text('Cor: Caramelo')),
        findsOneWidget);
    expect(find.descendant(of: previa, matching: find.textContaining('SRD')),
        findsNothing);
    expect(find.descendant(of: previa, matching: find.textContaining('99999')),
        findsNothing);
  });

  testWidgets(
      'telefone vem do perfil, é validado e vai em E.164 sem mudar o perfil',
      (tester) async {
    final repo = _FakeRepo(_desligado);
    await _montar(tester, _app(repo));
    await tester.pumpAndSettle();

    await _tocar(tester, 'campo-CONTACT_PHONE');
    expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('telefone')))
            .controller!
            .text,
        '(19) 99999-0000');
    expect(find.textContaining('não muda o telefone do seu perfil'),
        findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('telefone')), '123');
    await tester.pumpAndSettle();
    await _tocar(tester, 'consentimento');
    expect(find.textContaining('Telefone inválido'), findsOneWidget);
    expect(_publicarHabilitado(tester), isFalse);

    await tester.enterText(
        find.byKey(const ValueKey('telefone')), '(11) 98888-7777');
    await tester.pumpAndSettle();
    await _tocar(tester, 'publicar');
    expect(repo.pedidos.single.telefone, '+5511988887777');
  });

  testWidgets('nome do tutor vem do perfil e não pode ficar vazio',
      (tester) async {
    final repo = _FakeRepo(_desligado);
    await _montar(tester, _app(repo));
    await tester.pumpAndSettle();

    await _tocar(tester, 'campo-TUTOR_NAME');
    final campo =
        tester.widget<TextField>(find.byKey(const ValueKey('nome-tutor')));
    expect(campo.controller!.text, 'Ana');

    await tester.enterText(find.byKey(const ValueKey('nome-tutor')), '  ');
    await tester.pumpAndSettle();
    await _tocar(tester, 'consentimento');
    expect(_publicarHabilitado(tester), isFalse);
  });

  testWidgets('página ativa: mostra o que foi salvo e permite desativar',
      (tester) async {
    final repo = _FakeRepo(CompartilhamentoPublico(
      ativado: true,
      ativo: true,
      campos: const {CampoPublico.nomePet, CampoPublico.fotoPerfil},
      consentidoEm: DateTime(2026, 11, 2, 18, 30),
    ));
    await _montar(tester, _app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Página pública ativa'), findsOneWidget);
    expect(find.text('Consentimento dado em 02/11/2026 às 18:30.'),
        findsOneWidget);
    expect(_marcado(tester, 'campo-PET_NAME'), isTrue);
    expect(_marcado(tester, 'campo-CONTACT_PHONE'), isFalse);
    expect(_marcado(tester, 'consentimento'), isFalse);

    await _tocar(tester, 'desativar');
    expect(find.text('Desativar página pública'), findsWidgets);
    await tester.tap(find.widgetWithText(TextButton, 'Desativar'));
    await tester.pumpAndSettle();

    expect(repo.revogacoes, 1);
    expect(find.text('Página pública desativada.'), findsOneWidget);
    expect(_marcado(tester, 'campo-PET_NAME'), isFalse);
    expect(find.text('Desativada em 02/11/2026 às 19:00.'), findsOneWidget);
  });

  testWidgets('cancelar a desativação não revoga', (tester) async {
    final repo = _FakeRepo(const CompartilhamentoPublico(
        ativado: true, ativo: true, campos: {CampoPublico.nomePet}));
    await _montar(tester, _app(repo));
    await tester.pumpAndSettle();

    await _tocar(tester, 'desativar');
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();
    expect(repo.revogacoes, 0);
  });

  testWidgets('falha ao publicar aparece na tela e nada é dado como salvo',
      (tester) async {
    final repo = _FakeRepo(_desligado)
      ..falhaAoPublicar = const CompartilhamentoException(
          FalhaDoCompartilhamento.servidorIndisponivel);
    await _montar(tester, _app(repo));
    await tester.pumpAndSettle();

    await _tocar(tester, 'campo-PET_NAME');
    await _tocar(tester, 'consentimento');
    await _tocar(tester, 'publicar');

    expect(
        find.textContaining('não conseguiu confirmar o pet'), findsOneWidget);
    expect(find.text('Página pública desativada'), findsOneWidget);
    expect(find.text('Página pública ativada.'), findsNothing);
  });

  testWidgets(
      'publicação em texto antigo aparece pausada e sem caixas marcadas',
      (tester) async {
    await _montar(
        tester,
        _app(_FakeRepo(const CompartilhamentoPublico(
            ativado: true, ativo: false, campos: {CampoPublico.nomePet}))));
    await tester.pumpAndSettle();

    expect(find.text('Página pública pausada'), findsOneWidget);
    expect(_marcado(tester, 'campo-PET_NAME'), isFalse);
  });

  testWidgets('sem servidor configurado explica e não mostra o formulário',
      (tester) async {
    await _montar(tester, _app(null));
    await tester.pumpAndSettle();

    expect(find.textContaining('precisa do servidor'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
  });
}
