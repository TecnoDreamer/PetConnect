import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Abre um link fora do app (o ponto de um avistamento no app de mapas, por
/// exemplo). Devolve se conseguiu. Provider para os testes trocarem.
final abrirLinkProvider = Provider<Future<bool> Function(Uri link)>((ref) {
  return (link) async {
    try {
      return await launchUrl(link, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  };
});
