import 'dart:typed_data';

import 'foto_pet.dart';
import 'pet.dart';

/// Galeria particular de um pet (docs/features/galeria-fotos-pet.md).
///
/// Só o tutor dono lista, publica e exclui — garantido pelas regras do
/// Firestore, não só por esta interface. Sem curtidas, comentários nem
/// leitura pública: um módulo social futuro fica em outro repositório,
/// lendo [FotoPet.id], sem mudar este contrato.
abstract class GaleriaRepository {
  /// Fotos de [petId], mais recentes primeiro (data de publicação e, no
  /// empate, id). [depoisDe] é a última foto da página anterior.
  Future<PaginaDeFotos> listar(
    String petId, {
    FotoPet? depoisDe,
    int limite = LimitesGaleria.porPagina,
  });

  /// Envia o arquivo e só então grava o registro. Se a gravação falhar, o
  /// arquivo enviado é removido (quando o modo de upload permite) e o erro
  /// sobe — nunca fica registro apontando para arquivo que não existe. O
  /// arquivo vai com o id do registro como nome, nunca com o nome original
  /// do aparelho.
  Future<FotoPet> publicar({
    required Pet pet,
    required String userId,
    required Uint8List bytes,
    String? legenda,
    void Function(double fracao)? aoProgredir,
    Future<void>? cancelar,
  });

  /// Remove o arquivo e depois o registro. Se a remoção do arquivo falhar,
  /// nada muda e dá para tentar de novo (as duas etapas são idempotentes).
  Future<void> excluir(FotoPet foto);
}

class PaginaDeFotos {
  const PaginaDeFotos({required this.fotos, required this.temMais});

  final List<FotoPet> fotos;
  final bool temMais;
}

/// A remoção do arquivo falhou; o registro foi mantido.
class FalhaAoExcluirFoto implements Exception {
  const FalhaAoExcluirFoto(this.causa);

  final Object causa;

  @override
  String toString() => 'FalhaAoExcluirFoto($causa)';
}
