// Fase 2 da página do QR (issue #103): duas fotos da galeria depois da de
// perfil, em carrossel. Ver docs/features/qr-compartilhamento-publico.md.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pet_connect/core/theme/app_theme.dart';
import 'package:pet_connect/features/pet/domain/compartilhamento_publico.dart';
import 'package:pet_connect/features/pet/domain/pet.dart';
import 'package:pet_connect/features/pet/presentation/providers/galeria_providers.dart';
import 'package:pet_connect/features/pet/presentation/providers/pet_providers.dart';
import 'package:pet_connect/features/pet/presentation/screens/compartilhamento_qr_screen.dart';
import 'package:pet_connect/features/usuario/domain/usuario.dart';
import 'package:pet_connect/features/usuario/presentation/providers/auth_providers.dart';

import 'fake_galeria_repository.dart';

const _tutor = Usuario(
  id: 'uid-1',
  usuarioID: 'uid-1',
  nome: 'Ana',
  email: 'ana@teste.com',
  telefone: '',
  dataNascimento: '',
  genero: '',
);

Pet _rex(
        {String? foto =
            'https://res.cloudinary.com/demo/image/upload/v1/rex.jpg'}) =>
    Pet(
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
      foto: foto,
    );

class _Repo implements CompartilhamentoRepository {
  _Repo(this.salvo);

  CompartilhamentoPublico salvo;
  final pedidos = <PedidoDeCompartilhamento>[];

  @override
  Future<CompartilhamentoPublico> buscar(Pet pet) async => salvo;

  @override
  Future<CompartilhamentoPublico> publicar(
      Pet pet, PedidoDeCompartilhamento pedido) async {
    pedidos.add(pedido);
    return salvo = CompartilhamentoPublico(
      ativado: true,
      ativo: true,
      campos: pedido.campos,
      fotosDaGaleria: pedido.fotosDaGaleria,
    );
  }

  @override
  Future<CompartilhamentoPublico> revogar(Pet pet) async => salvo =
      const CompartilhamentoPublico(ativado: false, ativo: false, campos: {});
}

const _desligado =
    CompartilhamentoPublico(ativado: false, ativo: false, campos: {});

Future<void> _montar(
  WidgetTester tester, {
  required _Repo repo,
  required FakeGaleriaRepository galeria,
  Pet? pet,
}) async {
  tester.view.physicalSize = const Size(1080, 5200);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUsuarioProvider.overrideWith((ref) => Stream.value(_tutor)),
      petProvider.overrideWith((ref, id) => Stream.value(pet ?? _rex())),
      compartilhamentoRepositoryProvider.overrideWithValue(repo),
      galeriaRepositoryProvider.overrideWithValue(galeria),
      galeriaDisponivelProvider.overrideWithValue(true),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const CompartilhamentoQrScreen(petId: 'pet-1'),
    ),
  ));
  await _assentar(tester);
}

/// Miniaturas de rede não terminam de carregar em teste; avança o tempo em
/// vez de esperar tudo assentar.
Future<void> _assentar(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _tocar(WidgetTester tester, Finder alvo) async {
  await tester.ensureVisible(alvo);
  await tester.tap(alvo);
  await _assentar(tester);
}

CheckboxListTile _caixa(WidgetTester tester, String api) =>
    tester.widget<CheckboxListTile>(find.byKey(ValueKey('campo-$api')));

bool _publicarHabilitado(WidgetTester tester) =>
    tester
        .widget<FilledButton>(find.byKey(const ValueKey('publicar')))
        .onPressed !=
    null;

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets(
      'marcar as fotos da galeria marca a de perfil, pede exatamente duas e '
      'envia os ids na ordem escolhida', (tester) async {
    final galeria = FakeGaleriaRepository()..semear('pet-1', 3);
    final fotos = galeria.fotosDe('pet-1');
    final repo = _Repo(_desligado);
    await _montar(tester, repo: repo, galeria: galeria);

    await _tocar(tester, find.byKey(const ValueKey('campo-GALLERY_PHOTOS')));
    expect(_caixa(tester, 'PROFILE_PHOTO').value, isTrue,
        reason: 'a foto de perfil abre o carrossel');
    await _tocar(tester, find.byKey(const ValueKey('consentimento')));
    expect(_publicarHabilitado(tester), isFalse, reason: 'nenhuma foto ainda');

    await _tocar(tester, find.byKey(ValueKey('foto-galeria-${fotos[2].id}')));
    expect(_publicarHabilitado(tester), isFalse, reason: 'só uma foto');
    await _tocar(tester, find.byKey(ValueKey('foto-galeria-${fotos[0].id}')));
    expect(find.text('Escolha 2 fotos: 2 de 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('previa-carrossel')), findsOneWidget);

    // Com as duas escolhidas, uma terceira não entra.
    await _tocar(tester, find.byKey(ValueKey('foto-galeria-${fotos[1].id}')));
    expect(find.text('Escolha 2 fotos: 2 de 2'), findsOneWidget);

    expect(_publicarHabilitado(tester), isTrue);
    await _tocar(tester, find.byKey(const ValueKey('publicar')));

    final pedido = repo.pedidos.single;
    expect(pedido.fotosDaGaleria, [fotos[2].id, fotos[0].id]);
    expect(pedido.paraApi()['galleryPhotoIds'], [fotos[2].id, fotos[0].id]);
    expect(pedido.paraApi()['fields'],
        containsAll(['PROFILE_PHOTO', 'GALLERY_PHOTOS']));
  });

  testWidgets('desmarcar a foto de perfil desmarca as fotos da galeria',
      (tester) async {
    final galeria = FakeGaleriaRepository()..semear('pet-1', 2);
    await _montar(tester, repo: _Repo(_desligado), galeria: galeria);

    await _tocar(tester, find.byKey(const ValueKey('campo-GALLERY_PHOTOS')));
    await _tocar(tester, find.byKey(const ValueKey('campo-PROFILE_PHOTO')));

    expect(_caixa(tester, 'GALLERY_PHOTOS').value, isFalse);
    expect(find.byKey(const ValueKey('contagem-fotos-galeria')), findsNothing);
  });

  testWidgets('galeria com menos de duas fotos: opção desabilitada e aviso',
      (tester) async {
    final galeria = FakeGaleriaRepository()..semear('pet-1', 1);
    await _montar(tester, repo: _Repo(_desligado), galeria: galeria);

    expect(_caixa(tester, 'GALLERY_PHOTOS').onChanged, isNull);
    expect(find.textContaining('menos de duas fotos'), findsOneWidget);
  });

  testWidgets('pet sem foto de perfil: opção desabilitada e aviso',
      (tester) async {
    final galeria = FakeGaleriaRepository()..semear('pet-1', 3);
    await _montar(tester,
        repo: _Repo(_desligado), galeria: galeria, pet: _rex(foto: null));

    expect(_caixa(tester, 'GALLERY_PHOTOS').onChanged, isNull);
    expect(
        find.textContaining('Precisa de uma foto de perfil'), findsOneWidget);
  });

  testWidgets('sem internet: avisa e tenta carregar a galeria de novo',
      (tester) async {
    final galeria = FakeGaleriaRepository()
      ..semear('pet-1', 2)
      ..falharListagem = true;
    await _montar(tester, repo: _Repo(_desligado), galeria: galeria);

    expect(find.textContaining('Não foi possível carregar a galeria'),
        findsOneWidget);
    expect(_caixa(tester, 'GALLERY_PHOTOS').onChanged, isNull);

    galeria.falharListagem = false;
    await _tocar(tester, find.byKey(const ValueKey('recarregar-galeria')));
    expect(_caixa(tester, 'GALLERY_PHOTOS').onChanged, isNotNull);
  });

  testWidgets(
      'foto escolhida que saiu da galeria: aviso, e só publica depois de '
      'escolher outra', (tester) async {
    final galeria = FakeGaleriaRepository()..semear('pet-1', 3);
    final fotos = galeria.fotosDe('pet-1');
    final repo = _Repo(CompartilhamentoPublico(
      ativado: true,
      ativo: true,
      campos: const {CampoPublico.fotoPerfil, CampoPublico.fotosGaleria},
      fotosDaGaleria: [fotos[0].id, 'foto-que-saiu'],
    ));
    await _montar(tester, repo: repo, galeria: galeria);

    expect(find.byKey(const ValueKey('foto-saiu-da-galeria')), findsOneWidget);
    expect(find.text('Escolha 2 fotos: 1 de 2'), findsOneWidget);
    await _tocar(tester, find.byKey(const ValueKey('consentimento')));
    expect(_publicarHabilitado(tester), isFalse);

    await _tocar(tester, find.byKey(ValueKey('foto-galeria-${fotos[1].id}')));
    expect(find.byKey(const ValueKey('foto-saiu-da-galeria')), findsNothing);
    expect(_publicarHabilitado(tester), isTrue);
  });

  test('CompartilhamentoPublico lê os ids das fotos da API', () {
    final salvo = CompartilhamentoPublico.daApi({
      'enabled': true,
      'active': true,
      'fields': ['PROFILE_PHOTO', 'GALLERY_PHOTOS'],
      'galleryPhotoIds': ['f2', 'f3'],
    });
    expect(salvo.campos, {CampoPublico.fotoPerfil, CampoPublico.fotosGaleria});
    expect(salvo.fotosDaGaleria, ['f2', 'f3']);
  });

  test('sem a opção da galeria, os ids não vão para a API', () {
    const pedido = PedidoDeCompartilhamento(
      campos: {CampoPublico.fotoPerfil},
      fotosDaGaleria: ['f2', 'f3'],
    );
    expect(pedido.paraApi().containsKey('galleryPhotoIds'), isFalse);
  });
}
