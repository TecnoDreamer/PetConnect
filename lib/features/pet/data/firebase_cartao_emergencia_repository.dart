import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../domain/cartao_emergencia.dart';
import '../domain/cartao_emergencia_repository.dart';

/// Cartão de Emergência no Firestore: `Pets/{petId}/emergencia/cartao`.
///
/// Documento próprio, fora do documento do pet, porque a API lê o
/// documento do pet para montar a página pública do QR: os dados de saúde
/// nunca passam por ela. Ver docs/decisions/0009-cartao-emergencia-privado.md.
class FirebaseCartaoEmergenciaRepository implements CartaoEmergenciaRepository {
  FirebaseCartaoEmergenciaRepository({
    required FirebaseFirestore firestore,
    this.tempoLimite = const Duration(seconds: 20),
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  /// Sem rede, a transação não grava nada; este é o tempo máximo até a
  /// tela dizer isso, com o formulário intacto.
  final Duration tempoLimite;

  static const colecao = 'emergencia';
  static const documento = 'cartao';

  DocumentReference<Map<String, dynamic>> _ref(String petId) => _firestore
      .collection('Pets')
      .doc(petId)
      .collection(colecao)
      .doc(documento);

  @override
  Stream<LeituraDoCartao> observar(String petId) {
    return _ref(petId).snapshots(includeMetadataChanges: true).map((snap) {
      final dados = snap.data();
      return LeituraDoCartao(
        cartao: dados == null
            ? CartaoEmergencia.vazio
            : CartaoEmergencia.fromMap(
                dados,
                atualizadoEm: _data(dados['atualizadoEm']),
              ),
        doCacheLocal: snap.metadata.isFromCache,
        existe: snap.exists,
      );
    }).handleError(
      (Object erro) => throw traduzirErro(erro),
      test: (erro) => erro is! FalhaDoCartao,
    );
  }

  @override
  Future<void> salvar(
    String petId,
    CartaoEmergencia cartao, {
    required int revisaoEsperada,
  }) async {
    final ref = _ref(petId);
    try {
      await _firestore.runTransaction((tx) async {
        final atual = await tx.get(ref);
        final revisaoAtual = _revisao(atual.data());
        if (revisaoAtual != revisaoEsperada) {
          throw const CartaoAlteradoEmOutroLugar();
        }
        tx.set(ref, {
          ...cartao.toMap(),
          'revisao': revisaoAtual + 1,
          'atualizadoEm': FieldValue.serverTimestamp(),
        });
      }).timeout(tempoLimite);
    } on FalhaDoCartao {
      rethrow;
    } on TimeoutException {
      throw const CartaoSemConexao();
    } catch (erro) {
      throw traduzirErro(erro);
    }
  }

  static int _revisao(Map<String, dynamic>? dados) {
    final revisao = dados?['revisao'];
    return revisao is int && revisao > 0 ? revisao : 0;
  }

  static DateTime? _data(Object? valor) =>
      valor is Timestamp ? valor.toDate() : null;

  /// Só o código do erro é usado; a mensagem do Firestore não vai para a
  /// tela nem para o log.
  @visibleForTesting
  static FalhaDoCartao traduzirErro(Object erro) {
    if (erro is FalhaDoCartao) return erro;
    if (erro is FirebaseException) {
      switch (erro.code) {
        case 'permission-denied':
        case 'unauthenticated':
          return const CartaoSemPermissao();
        case 'unavailable':
        case 'deadline-exceeded':
          return const CartaoSemConexao();
      }
    }
    return const CartaoFalhaDesconhecida();
  }
}
