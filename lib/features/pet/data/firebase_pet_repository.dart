import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/alteracao_situacao.dart';
import '../domain/pet.dart';
import '../domain/pet_repository.dart';
import 'exclusao_de_pet.dart';

class FirebasePetRepository implements PetRepository {
  FirebasePetRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _pets =>
      _firestore.collection('Pets');

  @override
  Stream<List<Pet>> watchPets(String userId) {
    // Filtra por userId (RF12) — isolamento também é reforçado pelas regras
    // de segurança do Firestore (docs/seguranca.md), não só aqui na query.
    return _pets.where('userId', isEqualTo: userId).snapshots().map((snapshot) {
      final pets =
          snapshot.docs.map((doc) => Pet.fromMap(doc.id, doc.data())).toList();
      pets.sort((a, b) => a.nome.compareTo(b.nome));
      return pets;
    });
  }

  @override
  Stream<Pet?> watchPet(String petId) {
    return _pets.doc(petId).snapshots().map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return Pet.fromMap(doc.id, data);
    });
  }

  @override
  Future<String> createPet(Pet pet) async {
    final doc = await _pets.add(pet.toMap());
    return doc.id;
  }

  @override
  Future<void> updatePet(Pet pet) async {
    await _pets.doc(pet.id).update(pet.toMap());
  }

  /// Apaga antes as subcoleções de [subcolecoesApagadasComOPet] (registros
  /// clínicos e galeria). `eventosSituacao` fica: a regra só aceita apagar
  /// esses eventos no lote da exclusão de conta.
  @override
  Future<void> deletePet(String petId) async {
    final pet = _pets.doc(petId);
    await apagarSubcolecoesDoPet(pet);
    await pet.delete();
  }

  @override
  bool get suportaMemorial => true;

  /// Transação: lê a situação atual e, só se ela mudar, atualiza o pet e
  /// grava o evento de auditoria juntos — dois toques simultâneos (ou uma
  /// repetição após falha de rede) nunca geram dois eventos nem um estado
  /// pela metade.
  ///
  /// Autorização: em firestore.rules, só o dono altera `Pets/{petId}` e o
  /// evento só é aceito junto com essa mudança de situação, então a
  /// transação inteira falha para qualquer outra conta. Vale a partir do
  /// deploy das regras de isolamento por dono
  /// (docs/security/firestore-isolamento-por-dono.md).
  @override
  Future<void> alterarSituacao(
    String petId,
    AlteracaoDeSituacao alteracao, {
    required String atorId,
  }) async {
    final petRef = _pets.doc(petId);
    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(petRef);
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        throw const PetNaoEncontradoException();
      }

      final anterior = SituacaoPet.doBanco(data['situacao']);
      if (anterior == alteracao.nova) return;

      final falecido = alteracao.nova == SituacaoPet.falecido;
      tx.update(petRef, {
        'situacao': alteracao.nova.valor,
        'dataFalecimento': falecido && alteracao.dataFalecimento != null
            ? alteracao.dataFalecimento
            : FieldValue.delete(),
        'homenagem': falecido && alteracao.homenagem != null
            ? alteracao.homenagem
            : FieldValue.delete(),
        'situacaoAtualizadaEm': FieldValue.serverTimestamp(),
      });
      // Auditoria mínima: quem, de/para, quando e por quê — sem data de
      // falecimento nem homenagem (não são necessárias para auditar).
      tx.set(petRef.collection('eventosSituacao').doc(), {
        'atorId': atorId,
        'situacaoAnterior': anterior.valor,
        'situacaoNova': alteracao.nova.valor,
        'motivo': alteracao.motivo.valor,
        'resultado': 'aplicado',
        'origem': 'app',
        'em': FieldValue.serverTimestamp(),
      });
    });
  }
}
