// Cartão de Emergência (issue #41): gravação e leitura no Firestore (fake),
// controle de revisão e tradução de erros. As regras de acesso são testadas
// no emulador (tool/firestore-rules/regras.test.js).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_connect/features/pet/data/firebase_cartao_emergencia_repository.dart';
import 'package:pet_connect/features/pet/domain/cartao_emergencia.dart';

const _cartao = CartaoEmergencia(
  situacaoAlergias: SituacaoDaLista.informada,
  alergias: [Alergia(id: 'a1', substancia: 'Dipirona')],
);

void main() {
  late FakeFirebaseFirestore db;
  late FirebaseCartaoEmergenciaRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirebaseCartaoEmergenciaRepository(firestore: db);
  });

  test('primeira gravação cria o documento do pet com revisão 1', () async {
    await repo.salvar('rex', _cartao, revisaoEsperada: 0);

    final doc = await db.doc('Pets/rex/emergencia/cartao').get();
    expect(doc.exists, isTrue);
    expect(doc.data()!['revisao'], 1);
    expect(doc.data()!['atualizadoEm'], isA<Timestamp>());
    expect(doc.data()!['situacaoAlergias'], 'INFORMADA');
    // Nada no documento do pet nem em outro pet.
    expect((await db.doc('Pets/rex').get()).exists, isFalse);
    expect((await db.doc('Pets/mel/emergencia/cartao').get()).exists, isFalse);
  });

  test('salvar e reabrir preserva o conteúdo (RF-41-03)', () async {
    await repo.salvar('rex', _cartao, revisaoEsperada: 0);

    // O fake não leva a escrita de uma transação para o `snapshots()`; o
    // documento gravado é lido direto e passa pelo mesmo `fromMap`.
    final doc = await db.doc('Pets/rex/emergencia/cartao').get();
    final lido = CartaoEmergencia.fromMap(doc.data()!);
    expect(lido.toMap(), _cartao.toMap());
    expect(lido.revisao, 1);
  });

  test('a leitura entrega o documento, a revisão e a data', () async {
    await db.doc('Pets/rex/emergencia/cartao').set({
      ..._cartao.toMap(),
      'revisao': 3,
      'atualizadoEm': Timestamp.fromDate(DateTime(2026, 11, 9, 10, 30)),
    });

    final leitura = await repo.observar('rex').first;

    expect(leitura.existe, isTrue);
    expect(leitura.doCacheLocal, isFalse);
    expect(leitura.cartao.alergias.single.substancia, 'Dipirona');
    expect(leitura.cartao.revisao, 3);
    expect(leitura.cartao.atualizadoEm, DateTime(2026, 11, 9, 10, 30));
  });

  test('cada gravação sobe a revisão', () async {
    await repo.salvar('rex', _cartao, revisaoEsperada: 0);
    await repo.salvar('rex', CartaoEmergencia.vazio, revisaoEsperada: 1);

    final doc = await db.doc('Pets/rex/emergencia/cartao').get();
    expect(doc.data()!['revisao'], 2);
    expect(doc.data()!['situacaoAlergias'], 'NAO_INFORMADO');
  });

  test('edição a partir de versão velha não sobrescreve', () async {
    await repo.salvar('rex', _cartao, revisaoEsperada: 0);
    await repo.salvar('rex', _cartao, revisaoEsperada: 1);

    await expectLater(
      repo.salvar('rex', CartaoEmergencia.vazio, revisaoEsperada: 1),
      throwsA(isA<CartaoAlteradoEmOutroLugar>()),
    );

    final doc = await db.doc('Pets/rex/emergencia/cartao').get();
    expect(doc.data()!['revisao'], 2);
    expect(doc.data()!['situacaoAlergias'], 'INFORMADA');
  });

  test('cartão criado em outro aparelho enquanto este estava vazio', () async {
    await repo.salvar('rex', _cartao, revisaoEsperada: 0);

    await expectLater(
      repo.salvar('rex', CartaoEmergencia.vazio, revisaoEsperada: 0),
      throwsA(isA<CartaoAlteradoEmOutroLugar>()),
    );
  });

  test('pet sem cartão: leitura vazia, sem erro', () async {
    final leitura = await repo.observar('rex').first;

    expect(leitura.existe, isFalse);
    expect(leitura.cartao.semDados, isTrue);
    expect(leitura.cartao.nuncaSalvo, isTrue);
  });

  test('documentos de pets diferentes não se misturam', () async {
    await repo.salvar('rex', _cartao, revisaoEsperada: 0);

    final mel = await repo.observar('mel').first;
    expect(mel.existe, isFalse);
    expect(mel.cartao.alergias, isEmpty);
  });

  group('tradução de erros', () {
    FirebaseException erro(String code) =>
        FirebaseException(plugin: 'cloud_firestore', code: code);

    test('permissão negada e sessão expirada viram "sem permissão"', () {
      expect(
          FirebaseCartaoEmergenciaRepository.traduzirErro(
              erro('permission-denied')),
          isA<CartaoSemPermissao>());
      expect(
          FirebaseCartaoEmergenciaRepository.traduzirErro(
              erro('unauthenticated')),
          isA<CartaoSemPermissao>());
    });

    test('rede indisponível vira "sem conexão"', () {
      expect(
          FirebaseCartaoEmergenciaRepository.traduzirErro(erro('unavailable')),
          isA<CartaoSemConexao>());
      expect(
          FirebaseCartaoEmergenciaRepository.traduzirErro(
              erro('deadline-exceeded')),
          isA<CartaoSemConexao>());
    });

    test('qualquer outro erro vira falha desconhecida', () {
      expect(FirebaseCartaoEmergenciaRepository.traduzirErro(erro('internal')),
          isA<CartaoFalhaDesconhecida>());
      expect(FirebaseCartaoEmergenciaRepository.traduzirErro(StateError('x')),
          isA<CartaoFalhaDesconhecida>());
    });
  });
}
