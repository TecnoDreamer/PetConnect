import 'dart:typed_data';

import 'package:pet_connect/features/pet/domain/foto_pet.dart';
import 'package:pet_connect/features/pet/domain/galeria_repository.dart';
import 'package:pet_connect/features/pet/domain/pet.dart';

/// Galeria em memória para testes de widget. As fotos de cada pet ficam
/// separadas por id, como as subcoleções do Firestore.
class FakeGaleriaRepository implements GaleriaRepository {
  final Map<String, List<FotoPet>> _porPet = {};
  var _proximo = 0;

  /// Faz [listar] falhar enquanto verdadeiro.
  bool falharListagem = false;

  /// Faz [excluir] falhar enquanto verdadeiro.
  bool falharExclusao = false;

  /// Índices (na ordem das chamadas a [publicar]) que falham.
  Set<int> falharPublicacaoEm = {};

  final listagens = <({String petId, String? depoisDe})>[];
  var _publicacoes = 0;

  /// Cria [quantas] fotos para [petId]; a última criada é a mais recente.
  void semear(String petId, int quantas, {String? legenda}) {
    for (var i = 0; i < quantas; i++) {
      final n = _proximo++;
      _porPet.putIfAbsent(petId, () => []).insert(
            0,
            FotoPet(
              id: '$petId-foto$n',
              petId: petId,
              userId: 'uid-1',
              url:
                  'https://res.cloudinary.com/demo/image/upload/v1/$petId/$n.jpg',
              publicId: '$petId/$n',
              legenda: legenda,
              criadoEm: DateTime(2026, 10, 1).add(Duration(minutes: n)),
            ),
          );
    }
  }

  List<FotoPet> fotosDe(String petId) => List.of(_porPet[petId] ?? const []);

  @override
  Future<PaginaDeFotos> listar(String petId,
      {FotoPet? depoisDe, int limite = LimitesGaleria.porPagina}) async {
    listagens.add((petId: petId, depoisDe: depoisDe?.id));
    if (falharListagem) throw Exception('sem rede');
    final todas = fotosDe(petId);
    final inicio =
        depoisDe == null ? 0 : todas.indexWhere((f) => f.id == depoisDe.id) + 1;
    final pagina = todas.skip(inicio).take(limite).toList();
    return PaginaDeFotos(
        fotos: pagina, temMais: inicio + pagina.length < todas.length);
  }

  @override
  Future<FotoPet> publicar({
    required Pet pet,
    required String userId,
    required Uint8List bytes,
    String? legenda,
    void Function(double fracao)? aoProgredir,
    Future<void>? cancelar,
  }) async {
    final chamada = _publicacoes++;
    aoProgredir?.call(0.5);
    if (falharPublicacaoEm.contains(chamada)) throw Exception('sem rede');
    final n = _proximo++;
    final foto = FotoPet(
      id: '${pet.id}-foto$n',
      petId: pet.id,
      userId: userId,
      url: 'https://res.cloudinary.com/demo/image/upload/v1/${pet.id}/$n.jpg',
      publicId: '${pet.id}/$n',
      legenda: normalizarLegenda(legenda),
      criadoEm: DateTime.now(),
    );
    _porPet.putIfAbsent(pet.id, () => []).insert(0, foto);
    return foto;
  }

  @override
  Future<void> excluir(FotoPet foto) async {
    if (falharExclusao) throw FalhaAoExcluirFoto(Exception('sem rede'));
    _porPet[foto.petId]?.removeWhere((f) => f.id == foto.id);
  }
}
