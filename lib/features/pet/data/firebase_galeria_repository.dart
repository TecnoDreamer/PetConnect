import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/network/api_exception.dart';
import '../domain/anexo_repository.dart';
import '../domain/foto_pet.dart';
import '../domain/galeria_repository.dart';
import '../domain/pet.dart';

/// Galeria no Firestore (`Pets/{petId}/fotos`) com os arquivos no
/// Cloudinary, enviados pelo [AnexoRepository] em uso (preset unsigned ou
/// assinatura da API, conforme `USE_API_UPLOAD`).
///
/// A ordenação por `criadoEm` usa só o índice automático do Firestore;
/// nenhum índice composto precisa ser criado.
class FirebaseGaleriaRepository implements GaleriaRepository {
  FirebaseGaleriaRepository({
    required FirebaseFirestore firestore,
    required AnexoRepository arquivos,
  })  : _firestore = firestore,
        _arquivos = arquivos;

  final FirebaseFirestore _firestore;
  final AnexoRepository _arquivos;

  CollectionReference<Map<String, dynamic>> _fotos(String petId) =>
      _firestore.collection('Pets').doc(petId).collection('fotos');

  @override
  Future<PaginaDeFotos> listar(
    String petId, {
    FotoPet? depoisDe,
    int limite = LimitesGaleria.porPagina,
  }) async {
    // O Firestore completa a ordenação com o id do documento, na mesma
    // direção; o cursor por documento usa os dois, então fotos com o mesmo
    // horário não se repetem nem somem entre páginas.
    var consulta = _fotos(petId).orderBy('criadoEm', descending: true);
    if (depoisDe != null) {
      final cursor = await _fotos(petId).doc(depoisDe.id).get();
      final criadoEm = depoisDe.criadoEm;
      if (cursor.exists) {
        consulta = consulta.startAfterDocument(cursor);
      } else if (criadoEm != null) {
        // A última foto carregada foi excluída em outro aparelho.
        consulta = consulta.startAfter([Timestamp.fromDate(criadoEm)]);
      }
    }
    // Um a mais só para saber se existe próxima página.
    final snapshot = await consulta.limit(limite + 1).get();
    final fotos = snapshot.docs
        .map((doc) => _fotoDoMapa(doc.id, doc.data()))
        // Registro de outro pet nunca aparece, mesmo que tenha sido gravado
        // no lugar errado por uma versão antiga ou ferramenta externa.
        .where((foto) => foto.petId == petId)
        .toList();
    final temMais = snapshot.docs.length > limite;
    return PaginaDeFotos(
      fotos: temMais ? fotos.take(limite).toList() : fotos,
      temMais: temMais,
    );
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
    final ref = _fotos(pet.id).doc();
    final formato = FormatoImagem.detectar(bytes);
    final enviada = await _arquivos.enviarImagem(
      nomeArquivo: '${ref.id}.${formato?.extensao ?? 'jpg'}',
      bytes: bytes,
      aoProgredir: aoProgredir,
      cancelar: cancelar,
    );

    final texto = normalizarLegenda(legenda);
    try {
      await ref.set({
        'petId': pet.id,
        'userId': userId,
        'url': enviada.url,
        'publicId': enviada.publicId,
        if (enviada.largura != null) 'largura': enviada.largura,
        if (enviada.altura != null) 'altura': enviada.altura,
        if (texto != null) 'legenda': texto,
        'criadoEm': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Sem registro, o arquivo enviado ficaria órfão. No modo unsigned a
      // remoção não faz nada (limitação documentada).
      try {
        await _arquivos.delete(enviada.url);
      } catch (_) {}
      rethrow;
    }

    return FotoPet(
      id: ref.id,
      petId: pet.id,
      userId: userId,
      url: enviada.url,
      publicId: enviada.publicId,
      largura: enviada.largura,
      altura: enviada.altura,
      legenda: texto,
      criadoEm: DateTime.now(),
    );
  }

  @override
  Future<void> excluir(FotoPet foto) async {
    try {
      await _arquivos.delete(foto.url);
    } on ApiException catch (e) {
      // 404: o arquivo já não existe ou está fora da pasta do tutor na API
      // (foto enviada pelo preset unsigned). Não há o que remover por lá;
      // segue para o registro.
      if (!e.isNotFound) throw FalhaAoExcluirFoto(e);
    } catch (e) {
      throw FalhaAoExcluirFoto(e);
    }
    await _fotos(foto.petId).doc(foto.id).delete();
  }

  static FotoPet _fotoDoMapa(String id, Map<String, dynamic> map) {
    final criadoEm = map['criadoEm'];
    return FotoPet(
      id: id,
      petId: map['petId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      url: map['url'] as String? ?? '',
      publicId: map['publicId'] as String? ?? '',
      largura: (map['largura'] as num?)?.toInt(),
      altura: (map['altura'] as num?)?.toInt(),
      legenda: normalizarLegenda(map['legenda'] as String?),
      criadoEm: criadoEm is Timestamp ? criadoEm.toDate() : null,
    );
  }
}
