import 'dart:async';
import 'dart:typed_data';

import 'anexo_repository.dart';
import 'foto_pet.dart';
import 'galeria_repository.dart';
import 'pet.dart';

/// Situação de cada foto num envio.
enum EstadoItemEnvio { aguardando, enviando, publicada, falhou, cancelada }

/// Uma foto escolhida para publicar.
class ItemDeEnvio {
  ItemDeEnvio({required this.bytes});

  final Uint8List bytes;
  String legenda = '';
  EstadoItemEnvio estado = EstadoItemEnvio.aguardando;
  double progresso = 0;
  FotoPet? publicada;
  Object? erro;

  bool get pendente =>
      estado == EstadoItemEnvio.aguardando ||
      estado == EstadoItemEnvio.falhou ||
      estado == EstadoItemEnvio.cancelada;
}

/// Envia as fotos uma de cada vez e guarda o resultado de cada uma.
///
/// - Sucesso parcial: as já publicadas ficam publicadas; [enviar] de novo
///   só reenvia as pendentes (falhas e canceladas).
/// - Duplo toque: enquanto [enviando], uma segunda chamada não faz nada.
/// - [cancelar] interrompe a foto em andamento e não começa as seguintes.
class EnvioDeFotos {
  EnvioDeFotos({
    required this.itens,
    required GaleriaRepository repositorio,
    required this.pet,
    required this.userId,
    this.aoMudar,
  }) : _repositorio = repositorio;

  final List<ItemDeEnvio> itens;
  final GaleriaRepository _repositorio;
  final Pet pet;
  final String userId;
  final void Function()? aoMudar;

  bool _enviando = false;
  Completer<void>? _cancelamento;

  bool get enviando => _enviando;

  List<FotoPet> get publicadas => [
        for (final item in itens)
          if (item.publicada != null) item.publicada!,
      ];

  int get totalPublicadas =>
      itens.where((i) => i.estado == EstadoItemEnvio.publicada).length;
  int get totalComFalha =>
      itens.where((i) => i.estado == EstadoItemEnvio.falhou).length;
  bool get concluido =>
      itens.every((i) => i.estado == EstadoItemEnvio.publicada);

  Future<void> enviar() async {
    if (_enviando) return;
    _enviando = true;
    final cancelamento = _cancelamento = Completer<void>();
    _avisar();

    try {
      for (final item in itens) {
        if (!item.pendente) continue;
        if (cancelamento.isCompleted) {
          item.estado = EstadoItemEnvio.cancelada;
          continue;
        }
        item
          ..estado = EstadoItemEnvio.enviando
          ..progresso = 0
          ..erro = null;
        _avisar();
        try {
          item.publicada = await _repositorio.publicar(
            pet: pet,
            userId: userId,
            bytes: item.bytes,
            legenda: item.legenda,
            cancelar: cancelamento.future,
            aoProgredir: (fracao) {
              item.progresso = fracao;
              _avisar();
            },
          );
          item
            ..estado = EstadoItemEnvio.publicada
            ..progresso = 1;
        } on EnvioCancelado {
          item.estado = EstadoItemEnvio.cancelada;
        } catch (e) {
          item
            ..estado = EstadoItemEnvio.falhou
            ..erro = e;
        }
        _avisar();
      }
    } finally {
      _enviando = false;
      _cancelamento = null;
      _avisar();
    }
  }

  void cancelar() {
    final cancelamento = _cancelamento;
    if (cancelamento != null && !cancelamento.isCompleted) {
      cancelamento.complete();
    }
  }

  void _avisar() => aoMudar?.call();
}
