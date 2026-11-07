import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regras da página pública do QR (`public/index.html`, issues #35 e #37)
/// que dá para conferir no próprio arquivo. O comportamento no navegador está no
/// roteiro de aparelho (docs/validation/qr-compartilhamento-publico.md).
void main() {
  final html =
      File('public/index.html').readAsStringSync().replaceAll('\r\n', '\n');

  test('sem consentimento, mostra só o mínimo neutro', () {
    expect(html, contains('pet.shared === false'));
    expect(html, contains('Este pet está cadastrado no PetConnect'));
  });

  test('a localização é pedida assim que a página abre, uma vez só', () {
    expect(RegExp('getCurrentPosition').allMatches(html), hasLength(1));
    expect(html, isNot(contains('watchPosition')));
    final form = html.substring(html.indexOf('function renderSightingForm'),
        html.indexOf('function submitSighting'));
    expect(form, contains('} else {\n      requestLocation();\n    }'),
        reason: 'pedida ao montar o formulário, sem esperar clique');
    expect(form, contains('pede a sua localização assim que abre'),
        reason: 'o motivo aparece junto do pedido do navegador');
  });

  test('com permissão, a localização vai sozinha, com precisão e id próprio',
      () {
    final envio = html.substring(html.indexOf('function sendLocation'),
        html.indexOf('function requestLocation'));
    expect(envio, contains('clientRequestId: state.locationRequestId'));
    expect(envio, contains('accuracyMeters'));
    expect(html, contains('Localização enviada ao tutor'));
  });

  test('sem permissão, fica o relato em texto e um botão para tentar de novo',
      () {
    expect(html, contains('Você não permitiu a localização'));
    expect(html, contains('Tentar enviar a localização'));
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
