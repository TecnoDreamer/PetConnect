/// O que aconteceu com o QR Code de um pet (issue #37): relatos de quem
/// encontrou o pet e acessos à página pública. Vem da API; só o tutor vê.
///
/// Acesso e avistamento ficam separados de propósito: abrir a página não
/// prova que alguém está com o pet (leitores de QR também abrem o link para
/// pré-visualizar), e o app nunca apresenta um acesso como avistamento.
class AtividadeDoQr {
  const AtividadeDoQr({
    required this.avistamentos,
    required this.acessosRecentes,
    required this.acessosNosUltimos30Dias,
  });

  /// Mais recentes primeiro.
  final List<AvistamentoDoQr> avistamentos;

  /// Horários dos últimos acessos à página, mais recentes primeiro.
  final List<DateTime> acessosRecentes;

  final int acessosNosUltimos30Dias;

  DateTime? get ultimoAcesso =>
      acessosRecentes.isEmpty ? null : acessosRecentes.first;

  factory AtividadeDoQr.daApi(Map<String, dynamic> json) {
    final avistamentos = ((json['sightings'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(AvistamentoDoQr.daApi)
        .whereType<AvistamentoDoQr>()
        .toList()
      ..sort((a, b) => b.quando.compareTo(a.quando));
    final acessos = ((json['recentAccesses'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((m) => _data(m['occurredAt']))
        .whereType<DateTime>()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    return AtividadeDoQr(
      avistamentos: avistamentos,
      acessosRecentes: acessos,
      acessosNosUltimos30Dias:
          (json['accessesLast30Days'] as num?)?.toInt() ?? acessos.length,
    );
  }
}

/// Relato enviado pela página do QR. A coordenada, quando existe, é a que o
/// navegador de quem relatou informou; nada disso é verificado.
class AvistamentoDoQr {
  const AvistamentoDoQr({
    required this.id,
    required this.quando,
    this.latitude,
    this.longitude,
    this.precisaoMetros,
    this.descricao,
    this.contato,
  });

  final String id;

  /// No fuso do aparelho.
  final DateTime quando;
  final double? latitude;
  final double? longitude;
  final double? precisaoMetros;
  final String? descricao;
  final String? contato;

  bool get temLocalizacao => latitude != null && longitude != null;

  /// Abre o ponto no app de mapas do aparelho (ou no navegador). O mapa
  /// dentro do app é a fase 5 (#38).
  Uri? get linkDoMapa => temLocalizacao
      ? Uri.https('www.google.com', '/maps/search/', {
          'api': '1',
          'query': '$latitude,$longitude',
        })
      : null;

  /// `null` quando o registro não tem data: sem data não dá para ordenar.
  static AvistamentoDoQr? daApi(Map<String, dynamic> json) {
    final quando = _data(json['reportedAt']);
    if (quando == null) return null;
    String? texto(Object? v) {
      final s = (v as String?)?.trim();
      return s == null || s.isEmpty ? null : s;
    }

    return AvistamentoDoQr(
      id: (json['id'] ?? '') as String,
      quando: quando,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      precisaoMetros: (json['accuracyMeters'] as num?)?.toDouble(),
      descricao: texto(json['description']),
      contato: texto(json['reporterContact']),
    );
  }
}

/// "cerca de 35 m", "cerca de 1,2 km".
String descreverPrecisao(double metros) {
  if (metros >= 1000) {
    final km = (metros / 100).round() / 10;
    return 'cerca de ${km.toString().replaceAll('.', ',')} km';
  }
  return 'cerca de ${metros.round().clamp(1, 999)} m';
}

DateTime? _data(Object? v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;

abstract class AtividadeDoQrRepository {
  Future<AtividadeDoQr> buscar(String petId);
}
