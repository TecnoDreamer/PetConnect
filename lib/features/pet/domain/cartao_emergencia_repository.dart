import 'cartao_emergencia.dart';

/// Cartão de Emergência de um pet (issue #41). A UI depende desta
/// abstração, não do Firestore.
abstract class CartaoEmergenciaRepository {
  /// Observa o cartão do pet. Falhas chegam como [FalhaDoCartao].
  Stream<LeituraDoCartao> observar(String petId);

  /// Grava o cartão se a revisão no banco ainda for [revisaoEsperada] (a
  /// que o formulário abriu). Lança [CartaoAlteradoEmOutroLugar] se outra
  /// gravação aconteceu antes, e as outras [FalhaDoCartao] nos demais casos.
  Future<void> salvar(
    String petId,
    CartaoEmergencia cartao, {
    required int revisaoEsperada,
  });
}
