/// Apaga na API o que ela guarda de um pet do Firestore ou da conta, antes
/// de o app apagar no Firestore (LGPD; docs/privacy/data-flow-and-lgpd-readiness.md).
///
/// Só existe com pets no Firestore e a API ligada para o QR
/// (`USE_API_QR=true`). Com `USE_API_PETS=true` a própria exclusão do pet
/// na API já apaga tudo em cascata.
///
/// Nada aqui lança exceção nem trava a exclusão: a API pode estar fora ou
/// acordando. O resultado diz o que aconteceu.
abstract class LimpezaNaApi {
  /// Chama `DELETE /legacy-pets/{petId}/qr-data` enquanto o pet ainda existe
  /// no Firestore (a API confere o dono lá).
  ///
  /// Com a API fora e [guardarSeFalhar], o pedido fica guardado neste
  /// aparelho e é repetido na próxima abertura com sessão
  /// ([retomarPendentes]); a API aceita a repetição mesmo com o pet já
  /// excluído do Firestore.
  Future<ResultadoDaLimpeza> antesDeExcluirPet(String petId,
      {bool guardarSeFalhar = true});

  /// Repete os pedidos guardados da conta logada. Os que a API aceitar (ou
  /// recusar de vez) saem da lista.
  Future<void> retomarPendentes();

  /// `DELETE /me`: a API apaga o que guarda da conta (aparelhos do push,
  /// páginas públicas, preferências, avisos, acessos e relatos dos pets) e
  /// remove o usuário do Firebase Auth. `true` se a API confirmou.
  Future<bool> excluirConta();
}

enum ResultadoDaLimpeza {
  /// A API apagou (ou não tinha nada).
  apagado,

  /// Sem resposta da API (sem rede, tempo esgotado, servidor fora ou
  /// acordando). Se pedido, ficou guardado para tentar de novo.
  apiInacessivel,

  /// A API respondeu com recusa (ex.: versão sem a rota). Não adianta repetir.
  recusado,
}
