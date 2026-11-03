import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regras da página pública do QR (`public/index.html`, issues #35 e #37)
/// que dá para conferir no próprio arquivo. O comportamento no navegador está no
/// roteiro de aparelho (docs/validation/qr-compartilhamento-publico.md).
void main() {
  final html = File('public/index.html').readAsStringSync();

  test('sem consentimento, mostra só o mínimo neutro', () {
    expect(html, contains('pet.shared === false'));
    expect(html, contains('Este pet está cadastrado no PetConnect'));
  });

  test('a localização só é pedida depois do clique no botão (issue #37)', () {
    expect(html, contains('Compartilhar local onde vi o pet'));
    expect(RegExp('getCurrentPosition').allMatches(html), hasLength(1));
    final clique = html.indexOf("geoBtn.addEventListener('click'");
    expect(clique, isNot(-1));
    expect(html.indexOf('getCurrentPosition'), greaterThan(clique));
    expect(html, isNot(contains('watchPosition')));
  });

  test('o relato com localização leva a precisão e um id de envio', () {
    expect(html, contains('body.accuracyMeters'));
    expect(html, contains('clientRequestId: state.requestId'));
  });

  test('a abertura da página é um evento à parte, sem coordenada', () {
    final inicio = html.indexOf('function reportPageOpened');
    final fim = html.indexOf('}\n', html.indexOf("type: 'qr_page_opened'"));
    expect(inicio, isNot(-1));
    final evento = html.substring(inicio, fim);
    expect(evento, contains('/events'));
    expect(evento, isNot(contains('latitude')));
  });

  test('não promete que o tutor foi avisado', () {
    expect(html, isNot(contains('O tutor foi avisado')));
  });

  test('continua fora dos buscadores', () {
    expect(html, contains('<meta name="robots" content="noindex" />'));
  });

  test('o texto vindo da API passa por escapeHtml', () {
    for (final campo in [
      'pet.name',
      'pet.breed',
      'pet.color',
      'pet.tutorName',
      'pet.publicContactPhone',
    ]) {
      expect(html, contains('escapeHtml($campo'), reason: campo);
    }
  });
}
