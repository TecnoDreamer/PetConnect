import 'package:cloud_firestore/cloud_firestore.dart';

/// Subcoleções de `Pets/{petId}` apagadas antes do próprio pet, tanto ao
/// excluir um pet (`FirebasePetRepository.deletePet`) quanto ao excluir a
/// conta (`FirebaseUsuarioRepository.deleteAccount`) — LGPD, RF09/RNF13. O
/// Firestore não apaga subcoleções junto com o pai, e as regras só autorizam
/// o `delete` delas enquanto o pet existe.
///
/// `eventosSituacao` (auditoria do Memorial) fica de fora: `firestore.rules`
/// nega `delete` nela, inclusive para o dono. Apagar ou reter esses eventos é
/// decisão pendente do proprietário (ver
/// docs/security/firestore-isolamento-por-dono.md).
const subcolecoesApagadasComOPet = [
  'vacinas',
  'consultas',
  'historicoMedico',
  'localizacoes',
  'fotos',
];

/// Apaga cada subcoleção de [subcolecoesApagadasComOPet] e, por último, o
/// pet. Os arquivos da galeria no Cloudinary não são apagados daqui — ver
/// docs/features/galeria-fotos-pet.md, "Retenção".
Future<void> apagarPetComSubcolecoes(
    DocumentReference<Map<String, dynamic>> pet) async {
  for (final sub in subcolecoesApagadasComOPet) {
    final docs = await pet.collection(sub).get();
    for (final doc in docs.docs) {
      await doc.reference.delete();
    }
  }
  await pet.delete();
}
