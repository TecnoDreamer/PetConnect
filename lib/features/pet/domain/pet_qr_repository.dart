import 'pet.dart';

/// QR code regenerável (RF19, issue #29). Quem resolve o QR é a API (página
/// pública → `GET /public/pets/{publicId}`), então regenerar sempre passa
/// por ela; a fonte de pets (Firestore ou API) só guarda o resultado.
abstract class PetQrRepository {
  /// Se esta configuração permite regenerar. Quando `false`, a opção não
  /// aparece na UI e [regenerar] lança [QrRegeneracaoException].
  bool get suportaRegeneracao;

  /// Troca o QR do pet e devolve o novo `publicId`. O QR que o app está
  /// mostrando deixa de funcionar na hora. Lança [QrRegeneracaoException].
  Future<String> regenerar(Pet pet);

  /// Busca o QR atual na API e, se for diferente do que o app tem salvo,
  /// atualiza o pet. Corrige o caso em que a troca foi feita (em outro
  /// aparelho, ou a resposta se perdeu na rede) mas não chegou aqui.
  Future<void> sincronizar(Pet pet);
}

enum QrFalha {
  /// O QR já tinha sido trocado (outro aparelho, toque duplo).
  conflito,

  /// Limite de regenerações por pet estourado.
  limite,

  /// O pet ainda não existe na API (pets novos só chegam lá pela migração).
  naoSincronizado,

  /// Sem resposta do servidor — não dá para saber se a troca aconteceu.
  semConexao,

  /// A API trocou o QR, mas não foi possível salvar o novo neste aparelho.
  naoSalvo,

  /// Regeneração desligada nesta configuração do app.
  indisponivel,

  desconhecida,
}

class QrRegeneracaoException implements Exception {
  const QrRegeneracaoException(this.falha);

  final QrFalha falha;

  @override
  String toString() => 'QrRegeneracaoException($falha)';
}

/// Sem API configurada: o QR continua funcionando, só não dá para trocar.
class QrRegeneracaoIndisponivel implements PetQrRepository {
  const QrRegeneracaoIndisponivel();

  @override
  bool get suportaRegeneracao => false;

  @override
  Future<String> regenerar(Pet pet) =>
      Future.error(const QrRegeneracaoException(QrFalha.indisponivel));

  @override
  Future<void> sincronizar(Pet pet) async {}
}
