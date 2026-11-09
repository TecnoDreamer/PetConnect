import 'package:cloud_firestore/cloud_firestore.dart';

/// Subcoleções de `Pets/{petId}` apagadas uma a uma antes do próprio pet,
/// tanto ao excluir um pet (`FirebasePetRepository.deletePet`) quanto ao
/// excluir a conta (`FirebaseUsuarioRepository.deleteAccount`) — LGPD,
/// RF09/RNF13. O Firestore não apaga subcoleções junto com o pai, e as regras
/// só autorizam o `delete` delas enquanto o pet existe.
///
/// `eventosSituacao` (auditoria do Memorial) não está aqui: `firestore.rules`
/// só aceita apagar esses eventos no mesmo lote que apaga o pet ou o perfil
/// do dono, então `deletePet` e `deleteAccount` os apagam nesse lote (ver
/// docs/security/firestore-isolamento-por-dono.md, "Decisão:
/// `eventosSituacao` sai também ao excluir um pet").
const subcolecoesApagadasComOPet = [
  'vacinas',
  'consultas',
  'historicoMedico',
  'localizacoes',
  'fotos',
];

/// Apaga os documentos de cada subcoleção de [subcolecoesApagadasComOPet];
/// o pet fica para quem chamou. Os arquivos da galeria no Cloudinary não são
/// apagados daqui — ver docs/features/galeria-fotos-pet.md, "Retenção".
Future<void> apagarSubcolecoesDoPet(
    DocumentReference<Map<String, dynamic>> pet) async {
  for (final sub in subcolecoesApagadasComOPet) {
    final docs = await pet.collection(sub).get();
    for (final doc in docs.docs) {
      await doc.reference.delete();
    }
  }
  await apagarCartaoDeEmergencia(pet);
}

/// Cartão de Emergência (issue #41): um documento só,
/// `Pets/{petId}/emergencia/cartao`, apagado direto, sem listar.
///
/// Com as regras do Firestore anteriores ao cartão, o caminho não tem regra
/// e a exclusão é negada. Nesse caso nenhum cartão pode existir (a gravação
/// também era negada), então a negação é ignorada e a exclusão do pet ou da
/// conta continua. Qualquer outro erro sobe.
Future<void> apagarCartaoDeEmergencia(
    DocumentReference<Map<String, dynamic>> pet) async {
  try {
    await pet.collection('emergencia').doc('cartao').delete();
  } on FirebaseException catch (erro) {
    if (erro.code != 'permission-denied') rethrow;
  }
}
