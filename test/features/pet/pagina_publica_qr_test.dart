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

  group('fase 2 (issue #103)', () {
    final carrossel = html.substring(html.indexOf('function renderCarousel'),
        html.indexOf('function renderPet'));

    test('carrossel só com as três fotos, troca a cada 4 s e é cíclico', () {
      expect(html, contains('pet.photos && pet.photos.length > 1'));
      expect(html, contains('var CAROUSEL_INTERVAL_MS = 4000;'));
      expect(carrossel, contains('% imgs.length'), reason: 'volta ao perfil');
    });

    test('para de girar com reduced-motion, aba oculta e interação', () {
      expect(carrossel, contains('prefers-reduced-motion: reduce'));
      expect(carrossel, contains('var paused = reduceMotion;'));
      expect(carrossel, contains('document.hidden'));
      expect(carrossel, contains("addEventListener('visibilitychange'"));
      expect(
          carrossel, contains("addEventListener('touchstart', stopByVisitor"));
      expect(html, contains('.carousel .slide { transition: none; }'));
    });

    test('botões de voltar, avançar e pausar, com rótulo para leitor de tela',
        () {
      expect(carrossel, contains('aria-label="Foto anterior"'));
      expect(carrossel, contains('aria-label="Próxima foto"'));
      expect(carrossel, contains('Pausar a troca das fotos'));
      expect(carrossel, contains('aria-live="polite"'));
    });

    test('foto que não carrega sai do carrossel, sem distorcer as outras', () {
      expect(carrossel, contains("img.addEventListener('error'"));
      expect(html, contains('object-fit: cover;'));
    });

    test('WhatsApp: mensagem exata, só com telefone autorizado e válido', () {
      expect(html, contains("var WHATSAPP_TEXT = 'Olá, encontrei seu pet';"));
      expect(
          html,
          contains("'https://wa.me/' + m[1] + '?text=' + "
              'encodeURIComponent(WHATSAPP_TEXT)'));
      expect(html, contains(r'/^\+(\d{10,15})$/'));
      // O botão só nasce dentro do bloco do telefone que o tutor autorizou.
      final contato = html.substring(
          html.indexOf('if (pet.publicContactPhone)'),
          html.indexOf('renderSightingForm(card, publicId);\n  }'));
      expect(contato, contains('whatsappLink(pet.publicContactPhone)'));
      expect(html, isNot(contains('mensagem foi enviada')));
    });

    test('a mensagem codificada é a pedida na issue', () {
      expect(Uri.encodeComponent('Olá, encontrei seu pet'),
          'Ol%C3%A1%2C%20encontrei%20seu%20pet');
    });
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
