import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regras da página pública do QR (`public/index.html`, issue #35) que dá
/// para conferir no próprio arquivo. O comportamento no navegador está no
/// roteiro de aparelho (docs/validation/qr-compartilhamento-publico.md).
void main() {
  final html = File('public/index.html').readAsStringSync();

  test('sem consentimento, mostra só o mínimo neutro', () {
    expect(html, contains('pet.shared === false'));
    expect(html, contains('Este pet está cadastrado no PetConnect'));
  });

  test('a localização de quem achou o pet não vem marcada', () {
    final caixa = RegExp(r'<input type="checkbox" id="geo"[^>]*>')
        .firstMatch(html)
        ?.group(0);
    expect(caixa, isNotNull);
    expect(caixa, isNot(contains('checked')));
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
