import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_providers.dart';
import '../../../usuario/presentation/providers/auth_providers.dart';
import '../../data/exportacao_cartaz.dart';
import '../../data/rascunho_cartaz_store.dart';
import '../../domain/cartaz_desaparecido.dart';

/// Cartaz de pet desaparecido (docs/features/cartaz-pet-desaparecido.md).

final rascunhoCartazStoreProvider = Provider<RascunhoCartazStore>(
  (ref) => RascunhoCartazStore(ref.watch(sharedPreferencesProvider)),
);

final destinoDoCartazProvider =
    Provider<DestinoDoCartaz>((ref) => const DestinoDoCartazNoAparelho());

/// Rascunho em edição de um pet, compartilhado pelo editor e pela prévia.
/// Começa do rascunho salvo no aparelho e salva cada mudança (com uma
/// pequena espera, para não gravar a cada tecla).
class CartazController extends StateNotifier<RascunhoCartaz> {
  CartazController(this._store, this._uid, this.petId)
      : super((_uid.isEmpty ? null : _store.ler(_uid, petId)) ??
            const RascunhoCartaz());

  final RascunhoCartazStore _store;
  final String _uid;
  final String petId;
  Timer? _espera;

  static const esperaAntesDeSalvar = Duration(milliseconds: 400);

  void atualizar(RascunhoCartaz Function(RascunhoCartaz atual) mudanca) {
    state = mudanca(state);
    _espera?.cancel();
    _espera = Timer(esperaAntesDeSalvar, _salvar);
  }

  /// Apaga o rascunho salvo e recomeça do zero.
  Future<void> descartar() async {
    _espera?.cancel();
    state = const RascunhoCartaz();
    if (_uid.isNotEmpty) await _store.apagar(_uid, petId);
  }

  void _salvar() {
    if (_uid.isNotEmpty) _store.salvar(_uid, petId, state);
  }

  @override
  void dispose() {
    if (_espera?.isActive ?? false) {
      _espera!.cancel();
      _salvar();
    }
    super.dispose();
  }
}

final cartazControllerProvider = StateNotifierProvider.autoDispose
    .family<CartazController, RascunhoCartaz, String>((ref, petId) {
  // `read`, não `watch`: uma atualização do perfil não pode recriar o
  // editor e perder as fotos do celular e o consentimento. As rotas do
  // cartaz só abrem com o tutor já carregado (PetSituacaoGuard).
  final uid = ref.read(currentUsuarioProvider).valueOrNull?.id ?? '';
  return CartazController(ref.watch(rascunhoCartazStoreProvider), uid, petId);
});
