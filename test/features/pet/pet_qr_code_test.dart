import 'package:flutter_test/flutter_test.dart';
import 'package:pet_connect/features/pet/domain/pet.dart';
import 'package:pet_connect/features/pet/domain/pet_qr_code.dart';

Pet _pet({String? qrCodeId, String? qrPublicId}) {
  return Pet(
    id: 'pet-1',
    userId: 'uid-1',
    nome: 'Rex',
    especie: 'Cachorro',
    raca: '',
    cor: '',
    genero: '',
    porte: '',
    peso: '',
    dataNascimento: '',
    vacinado: false,
    qrCodeId: qrCodeId,
    qrPublicId: qrPublicId,
  );
}

void main() {
  test(
      'sem qrPublicId, calcula o publicId determinístico a partir do id (RF16 '
      '— causa raiz documentada em docs/fixes/qr-public-pet-not-found.md)', () {
    // 'pet-1' -> mesmo cálculo que legacy_public_id_test.dart, conferido
    // contra o algoritmo do backend (LegacyMigrationService).
    expect(publicPetUrl(_pet()),
        'https://pet-connect-c53f1.web.app/pet/b5ab5677-27c9-3f7c-98f8-370d7fcd526c');
  });

  test('usa o qrPublicId do QR regenerado (RF19)', () {
    expect(publicPetUrl(_pet(qrPublicId: 'qr-novo')),
        'https://pet-connect-c53f1.web.app/pet/qr-novo');
  });

  test('ignora o qrCodeId legado do app antigo, que a API nunca reconheceu',
      () {
    expect(publicIdDoQr(_pet(qrCodeId: 'qr-legado')),
        'b5ab5677-27c9-3f7c-98f8-370d7fcd526c');
  });

  test('fromMap lê qrPublicId, mas toMap não o grava', () {
    final pet = Pet.fromMap('pet-1', {'nome': 'Rex', 'qrPublicId': 'qr-novo'});
    expect(pet.qrPublicId, 'qr-novo');
    expect(pet.copyWith(nome: 'Rex 2').qrPublicId, 'qr-novo');
    // Editar o perfil com um Pet carregado antes da regeneração não pode
    // voltar o QR para um id já revogado.
    expect(pet.toMap().containsKey('qrPublicId'), isFalse);
  });
}
