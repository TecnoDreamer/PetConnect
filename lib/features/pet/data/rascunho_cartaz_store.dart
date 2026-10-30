import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/cartaz_desaparecido.dart';

/// Rascunho do cartaz de pet desaparecido, guardado só neste aparelho
/// (docs/features/cartaz-pet-desaparecido.md, "Rascunho").
///
/// Uma chave por tutor e pet. Guarda o que [RascunhoCartaz.toJson] guarda:
/// textos, fotos que já estão no Cloudinary do pet e o enquadramento. Nunca
/// o telefone, o consentimento nem fotos do celular.
class RascunhoCartazStore {
  RascunhoCartazStore(this._prefs);

  final SharedPreferences _prefs;

  static String chave(String uid, String petId) =>
      'cartaz_rascunho_v1_${uid}_$petId';

  /// Nulo se não há rascunho. Um rascunho ilegível conta como nenhum.
  RascunhoCartaz? ler(String uid, String petId) {
    final texto = _prefs.getString(chave(uid, petId));
    if (texto == null) return null;
    try {
      return RascunhoCartaz.fromJson(jsonDecode(texto));
    } on FormatException {
      return null;
    }
  }

  Future<void> salvar(String uid, String petId, RascunhoCartaz rascunho) =>
      _prefs.setString(chave(uid, petId), jsonEncode(rascunho.toJson()));

  Future<void> apagar(String uid, String petId) =>
      _prefs.remove(chave(uid, petId));
}
