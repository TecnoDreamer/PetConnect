import 'dart:async';

import 'package:pet_connect/features/pet/domain/alteracao_situacao.dart';
import 'package:pet_connect/features/pet/domain/pet.dart';
import 'package:pet_connect/features/pet/domain/pet_repository.dart';

/// Repositório em memória para testes de widget, sem depender de um
/// Firestore real (ver "Testes" em docs/arquitetura.md).
class FakePetRepository implements PetRepository {
  final Map<String, Pet> _store = {};
  final _changes = StreamController<void>.broadcast();
  int _nextId = 0;

  @override
  Stream<List<Pet>> watchPets(String userId) async* {
    yield _snapshot(userId);
    await for (final _ in _changes.stream) {
      yield _snapshot(userId);
    }
  }

  @override
  Stream<Pet?> watchPet(String petId) async* {
    yield _store[petId];
    await for (final _ in _changes.stream) {
      yield _store[petId];
    }
  }

  @override
  Future<String> createPet(Pet pet) async {
    final id = 'pet-${_nextId++}';
    _store[id] = Pet.fromMap(id, pet.toMap());
    _changes.add(null);
    return id;
  }

  @override
  Future<void> updatePet(Pet pet) async {
    _store[pet.id] = pet;
    _changes.add(null);
  }

  @override
  Future<void> deletePet(String petId) async {
    _store.remove(petId);
    _changes.add(null);
  }

  /// Simula a fonte sem suporte ao Memorial (modo API).
  bool suportaMemorialFake = true;

  /// Se definido, [alterarSituacao] falha com este erro sem alterar nada.
  Object? erroAoAlterarSituacao;

  /// Eventos de auditoria gravados por [alterarSituacao].
  final eventosSituacao = <({String petId, String atorId, SituacaoPet nova})>[];

  @override
  bool get suportaMemorial => suportaMemorialFake;

  /// Mesmas garantias do Firestore: só o dono altera (regra de update de
  /// `Pets`), idempotente e sem tocar em nada além dos campos de situação.
  @override
  Future<void> alterarSituacao(
    String petId,
    AlteracaoDeSituacao alteracao, {
    required String atorId,
  }) async {
    if (!suportaMemorialFake) throw const MemorialNaoSuportadoException();
    if (erroAoAlterarSituacao != null) throw erroAoAlterarSituacao!;
    final pet = _store[petId];
    if (pet == null) throw const PetNaoEncontradoException();
    if (pet.userId != atorId) throw StateError('permission-denied');
    if (pet.situacao == alteracao.nova) return;

    final falecido = alteracao.nova == SituacaoPet.falecido;
    _store[petId] = Pet.fromMap(petId, {
      ...pet.toMap(),
      'situacao': alteracao.nova.valor,
      if (falecido) 'dataFalecimento': alteracao.dataFalecimento,
      if (falecido) 'homenagem': alteracao.homenagem,
    });
    eventosSituacao.add((petId: petId, atorId: atorId, nova: alteracao.nova));
    _changes.add(null);
  }

  List<Pet> _snapshot(String userId) {
    final list = _store.values.where((pet) => pet.userId == userId).toList();
    list.sort((a, b) => a.nome.compareTo(b.nome));
    return list;
  }
}
