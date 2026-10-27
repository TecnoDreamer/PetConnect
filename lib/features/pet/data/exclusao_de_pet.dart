import 'package:cloud_firestore/cloud_firestore.dart';

/// Subcoleções de `Pets/{petId}` apagadas uma a uma antes do próprio pet,
/// tanto ao excluir um pet (`FirebasePetRepository.deletePet`) quanto ao
/// excluir a conta (`FirebaseUsuarioRepository.deleteAccount`) — LGPD,
/// RF09/RNF13. O Firestore não apaga subcoleções junto com o pai, e as regras
/// só autorizam o `delete` delas enquanto o pet existe.
///
/// `eventosSituacao` (auditoria do Memorial) não está aqui: `firestore.rules`
/// só aceita apagar esses eventos no mesmo lote que apaga o perfil do dono,
/// então só a exclusão de conta os apaga (ver
/// docs/security/firestore-isolamento-por-dono.md, "Decisão:
/// `eventosSituacao` é apagado na exclusão de conta").
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
}
