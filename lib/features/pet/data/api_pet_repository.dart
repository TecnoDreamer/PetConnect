import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/br_date.dart';
import '../domain/alteracao_situacao.dart';
import '../domain/pet.dart';
import '../domain/pet_repository.dart';

/// Implementação de [PetRepository] contra a API Spring (FASE 5).
///
/// A API já escopa a lista pelo tutor do token, então o `userId` recebido em
/// [watchPets] é ignorado para efeito de filtro (mantido só para preencher o
/// campo homônimo do modelo). Sem stream: cada `watch*` faz uma emissão única
/// e as telas chamam `ref.invalidate` após mutações.
class ApiPetRepository implements PetRepository {
  ApiPetRepository({required FirebaseAuth auth, required ApiClient api})
      : _auth = auth,
        _api = api;

  final FirebaseAuth _auth;
  final ApiClient _api;

  static const _especieParaApi = {
    'cachorro': 'DOG',
    'cão': 'DOG',
    'cao': 'DOG',
    'dog': 'DOG',
    'gato': 'CAT',
    'gata': 'CAT',
  };
  static const _especieDaApi = {
    'DOG': 'Cachorro',
    'CAT': 'Gato',
    'OTHER': 'Outro'
  };

  static const _generoParaApi = {'Macho': 'MALE', 'Fêmea': 'FEMALE'};
  static const _generoDaApi = {
    'MALE': 'Macho',
    'FEMALE': 'Fêmea',
    'UNKNOWN': ''
  };

  static const _porteParaApi = {
    'Pequeno': 'SMALL',
    'Médio': 'MEDIUM',
    'Grande': 'LARGE'
  };
  static const _porteDaApi = {
    'SMALL': 'Pequeno',
    'MEDIUM': 'Médio',
    'LARGE': 'Grande'
  };

  @override
  Stream<List<Pet>> watchPets(String userId) => Stream.fromFuture(_listPets());

  Future<List<Pet>> _listPets() async {
    final res = await _api.get('/pets');
    final list = (res['data'] as List?) ?? const [];
    final pets = list.cast<Map<String, dynamic>>().map(_petFromApi).toList()
      ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    return pets;
  }

  @override
  Stream<Pet?> watchPet(String petId) => Stream.fromFuture(_getPet(petId));

  Future<Pet?> _getPet(String petId) async {
    try {
      final res = await _api.get('/pets/$petId');
      return _petFromApi(res);
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  @override
  Future<String> createPet(Pet pet) async {
    final res = await _api.post('/pets', _petParaApi(pet, incluirNome: true));
    return res['id'] as String;
  }

  @override
  Future<void> updatePet(Pet pet) async {
    await _api.patch('/pets/${pet.id}', _petParaApi(pet, incluirNome: true));
  }

  @override
  Future<void> deletePet(String petId) async {
    await _api.delete('/pets/$petId');
  }

  /// Desligado de propósito: a API aceitaria `status: DECEASED`, mas a
  /// página pública do QR code (public/index.html, via
  /// `GET /public/pets/{publicId}`) exibe esse status como "Falecido" —
  /// registrar o falecimento por aqui exporia o fato publicamente. Fica
  /// pendente de uma mudança aprovada no backend (ver
  /// docs/features/memorial-pet.md, "Pendências").
  @override
  bool get suportaMemorial => false;

  @override
  Future<void> alterarSituacao(
    String petId,
    AlteracaoDeSituacao alteracao, {
    required String atorId,
  }) =>
      Future.error(const MemorialNaoSuportadoException());

  // ---------------------------------------------------------------- mapeamento

  Map<String, dynamic> _petParaApi(Pet p, {required bool incluirNome}) {
    return {
      if (incluirNome) 'name': p.nome,
      'species': _especieParaApi[p.especie.trim().toLowerCase()] ?? 'OTHER',
      'breed': p.raca,
      'color': p.cor,
      if (_generoParaApi[p.genero] != null) 'gender': _generoParaApi[p.genero],
      if (_porteParaApi[p.porte] != null) 'size': _porteParaApi[p.porte],
      'weightKg': _pesoParaKg(p.peso),
      if (p.dataNascimento.isNotEmpty) 'birthDate': brToIso(p.dataNascimento),
      'vaccinatedFlag': p.vacinado,
      'publicContactPhone': p.telefone,
      'photoUrl': p.foto,
      'coverPhotoUrl': p.capa,
      'coverPhotoAlignY': p.capaAlinhamentoY,
    };
  }

  Pet _petFromApi(Map<String, dynamic> m) {
    final peso = m['weightKg'];
    return Pet(
      id: (m['id'] ?? '') as String,
      userId: _auth.currentUser?.uid ?? '',
      nome: (m['name'] ?? '') as String,
      especie: _especieDaApi[m['species']] ?? '',
      raca: (m['breed'] ?? '') as String,
      cor: (m['color'] ?? '') as String,
      genero: _generoDaApi[m['gender']] ?? '',
      porte: _porteDaApi[m['size']] ?? '',
      peso: _kgParaPeso(peso is num ? peso.toDouble() : null),
      dataNascimento: isoToBr(m['birthDate'] as String?),
      vacinado: (m['vaccinatedFlag'] ?? false) as bool,
      telefone: m['publicContactPhone'] as String?,
      foto: m['photoUrl'] as String?,
      capa: m['coverPhotoUrl'] as String?,
      capaAlinhamentoY: (m['coverPhotoAlignY'] as num?)?.toDouble(),
      // A API gerencia o id público do QR (RF16/RF19).
      qrPublicId: m['publicId'] as String?,
      // Só leitura: um pet que já esteja DECEASED na API aparece no
      // Memorial. Os demais status da API (LOST, FOUND, ARCHIVED) não têm
      // equivalente no app e continuam como ativos.
      situacao:
          m['status'] == 'DECEASED' ? SituacaoPet.falecido : SituacaoPet.ativo,
    );
  }

  static double? _pesoParaKg(String peso) {
    final match =
        RegExp(r'-?\d+(?:[.,]\d+)?').firstMatch(peso.replaceAll(',', '.'));
    if (match == null) return null;
    final v = double.tryParse(match.group(0)!);
    return (v != null && v > 0) ? v : null;
  }

  static String _kgParaPeso(double? kg) {
    if (kg == null) return '';
    final s = kg == kg.roundToDouble() ? kg.toInt().toString() : kg.toString();
    return '${s}kg';
  }
}
