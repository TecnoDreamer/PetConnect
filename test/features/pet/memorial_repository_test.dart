// Memorial do Pet: domínio e FirebasePetRepository (docs/features/memorial-pet.md).

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_connect/features/pet/data/firebase_pet_repository.dart';
import 'package:pet_connect/features/pet/domain/alteracao_situacao.dart';
import 'package:pet_connect/features/pet/domain/pet.dart';

const _dono = 'tutor-dono';

Map<String, dynamic> _petLegado() => {
      'userId': _dono,
      'nome': 'Mel',
      'especie': 'Gato',
      'raca': 'SRD',
      'cor': 'Rajada',
      'genero': 'Fêmea',
      'porte': 'Pequeno',
      'peso': '4kg',
      'dataNascimento': '10/02/2015',
      'vacinado': true,
      'foto': 'https://res.cloudinary.com/demo/mel.jpg',
    };

void main() {
  group('Domínio — situação do pet', () {
    test('pet legado sem o campo é ativo', () {
      final pet = Pet.fromMap('p1', _petLegado());
      expect(pet.situacao, SituacaoPet.ativo);
      expect(pet.falecido, isFalse);
    });

    test('FALECIDO é lido; valor desconhecido continua ativo', () {
      expect(
          Pet.fromMap('p1', {..._petLegado(), 'situacao': 'FALECIDO'}).falecido,
          isTrue);
      expect(Pet.fromMap('p1', {..._petLegado(), 'situacao': 'XYZ'}).situacao,
          SituacaoPet.ativo);
    });

    test('toMap não carrega situação: editar o perfil nunca a altera', () {
      final pet = Pet.fromMap('p1', {
        ..._petLegado(),
        'situacao': 'FALECIDO',
        'dataFalecimento': '01/10/2026',
        'homenagem': 'Saudades',
      });
      final mapa = pet.toMap();
      expect(mapa.containsKey('situacao'), isFalse);
      expect(mapa.containsKey('dataFalecimento'), isFalse);
      expect(mapa.containsKey('homenagem'), isFalse);
      expect(pet.copyWith(nome: 'Mel II').falecido, isTrue);
    });

    test('data e homenagem vazias viram "não informadas"', () {
      final alteracao = AlteracaoDeSituacao.registrarFalecimento(
          dataFalecimento: '  ', homenagem: '');
      expect(alteracao.dataFalecimento, isNull);
      expect(alteracao.homenagem, isNull);
    });
  });

  group('FirebasePetRepository.alterarSituacao', () {
    late FakeFirebaseFirestore firestore;
    late FirebasePetRepository repo;
    late String petId;

    Future<Map<String, dynamic>> lerPet() async =>
        (await firestore.collection('Pets').doc(petId).get()).data()!;

    Future<List<Map<String, dynamic>>> eventos() async =>
        (await firestore.collection('Pets/$petId/eventosSituacao').get())
            .docs
            .map((d) => d.data())
            .toList();

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      repo = FirebasePetRepository(firestore: firestore);
      petId = (await firestore.collection('Pets').add(_petLegado())).id;
      // Registros clínicos que precisam sobreviver ao memorial.
      await firestore
          .collection('Pets/$petId/vacinas')
          .add({'nome': 'V4', 'proximaDose': '10/11/2026'});
      await firestore
          .collection('Pets/$petId/consultas')
          .add({'data': '15/11/2026', 'status': 'agendada'});
      await firestore
          .collection('Pets/$petId/historicoMedico')
          .add({'descricao': 'Castração'});
    });

    test('registra falecimento com data, homenagem e auditoria', () async {
      await repo.alterarSituacao(
        petId,
        AlteracaoDeSituacao.registrarFalecimento(
            dataFalecimento: '01/10/2026', homenagem: 'Para sempre'),
        atorId: _dono,
      );

      final pet = await lerPet();
      expect(pet['situacao'], 'FALECIDO');
      expect(pet['dataFalecimento'], '01/10/2026');
      expect(pet['homenagem'], 'Para sempre');
      expect(pet['situacaoAtualizadaEm'], isNotNull);
      expect(pet['nome'], 'Mel');
      expect(pet['foto'], 'https://res.cloudinary.com/demo/mel.jpg');

      final log = await eventos();
      expect(log, hasLength(1));
      expect(log.single['atorId'], _dono);
      expect(log.single['situacaoAnterior'], 'ATIVO');
      expect(log.single['situacaoNova'], 'FALECIDO');
      expect(log.single['motivo'], 'registro_falecimento');
      expect(log.single['resultado'], 'aplicado');
      expect(log.single.containsKey('homenagem'), isFalse,
          reason: 'auditoria sem dados desnecessários');
    });

    test('sem data informada, nenhuma data é inventada', () async {
      await repo.alterarSituacao(
          petId, AlteracaoDeSituacao.registrarFalecimento(),
          atorId: _dono);

      final pet = await lerPet();
      expect(pet['situacao'], 'FALECIDO');
      expect(pet.containsKey('dataFalecimento'), isFalse);
    });

    test('repetir a marcação não duplica evento nem altera nada', () async {
      final marcar = AlteracaoDeSituacao.registrarFalecimento(
          dataFalecimento: '01/10/2026');
      await repo.alterarSituacao(petId, marcar, atorId: _dono);
      await repo.alterarSituacao(petId, marcar, atorId: _dono);
      await Future.wait([
        repo.alterarSituacao(petId, marcar, atorId: _dono),
        repo.alterarSituacao(petId, marcar, atorId: _dono),
      ]);

      expect(await eventos(), hasLength(1));
      expect((await lerPet())['situacao'], 'FALECIDO');
    });

    test('corrigir a marcação restaura o pet e preserva os dados clínicos',
        () async {
      await repo.alterarSituacao(
          petId,
          AlteracaoDeSituacao.registrarFalecimento(
              dataFalecimento: '01/10/2026', homenagem: 'x'),
          atorId: _dono);
      await repo.alterarSituacao(petId, AlteracaoDeSituacao.corrigirMarcacao(),
          atorId: _dono);

      final pet = await lerPet();
      expect(pet['situacao'], 'ATIVO');
      expect(pet.containsKey('dataFalecimento'), isFalse);
      expect(pet.containsKey('homenagem'), isFalse);

      for (final sub in ['vacinas', 'consultas', 'historicoMedico']) {
        final docs = await firestore.collection('Pets/$petId/$sub').get();
        expect(docs.docs, hasLength(1), reason: '$sub deveria continuar lá');
      }
      final log = await eventos();
      expect(log.map((e) => e['motivo']),
          ['registro_falecimento', 'correcao_marcacao']);
    });

    test('editar o perfil depois do falecimento mantém a situação', () async {
      await repo.alterarSituacao(
          petId, AlteracaoDeSituacao.registrarFalecimento(),
          atorId: _dono);
      final pet = Pet.fromMap(petId, await lerPet());

      await repo.updatePet(pet.copyWith(nome: 'Mel Rajada'));

      final atualizado = await lerPet();
      expect(atualizado['nome'], 'Mel Rajada');
      expect(atualizado['situacao'], 'FALECIDO');
    });

    test('pet inexistente', () async {
      expect(
        () => repo.alterarSituacao(
            'nao-existe', AlteracaoDeSituacao.registrarFalecimento(),
            atorId: _dono),
        throwsA(isA<PetNaoEncontradoException>()),
      );
    });

    test('suporta o memorial', () {
      expect(repo.suportaMemorial, isTrue);
    });
  });
}
