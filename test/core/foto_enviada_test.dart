// Foto de perfil nova aparece na hora (relato do proprietário de
// 2026-11-05: as imagens de perfil demoravam a atualizar).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_connect/core/theme/app_theme.dart';
import 'package:pet_connect/core/utils/foto_enviada.dart';
import 'package:pet_connect/core/widgets/avatar_picker.dart';

/// PNG de 1×1: a tela decodifica a foto local.
final _bytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=');
const _url = 'https://res.cloudinary.com/demo/image/upload/v1/foto.jpg';

void main() {
  group('guardarFotoEnviadaNoCache', () {
    test('guarda os bytes enviados com a URL do Cloudinary', () async {
      final guardadas = <String, Uint8List>{};
      await guardarFotoEnviadaNoCache(_url, _bytes,
          guardar: (url, bytes) async => guardadas[url] = bytes);
      expect(guardadas[_url], _bytes);
    });

    test('falha no cache não derruba o envio', () async {
      await expectLater(
        guardarFotoEnviadaNoCache(_url, _bytes,
            guardar: (_, __) async =>
                throw const FileSystemException('sem espaço')),
        completes,
      );
    });
  });

  group('AvatarPicker', () {
    Future<CircleAvatar> avatar(
        WidgetTester tester, AvatarPicker picker) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: Center(child: picker)),
      ));
      return tester.widgetList<CircleAvatar>(find.byType(CircleAvatar)).first;
    }

    testWidgets('foto recém-escolhida aparece na hora, antes do envio',
        (tester) async {
      final circulo = await avatar(
        tester,
        AvatarPicker(
          fotoUrl: _url,
          fotoLocal: _bytes,
          enviando: true,
          onTap: () {},
        ),
      );
      expect(circulo.backgroundImage, isA<MemoryImage>());
    });

    testWidgets('foto salva vem do cache de imagens', (tester) async {
      final circulo =
          await avatar(tester, AvatarPicker(fotoUrl: _url, onTap: () {}));
      expect(circulo.backgroundImage, isA<CachedNetworkImageProvider>());
    });

    testWidgets('sem foto, mostra o ícone', (tester) async {
      final circulo =
          await avatar(tester, AvatarPicker(fotoUrl: null, onTap: () {}));
      expect(circulo.backgroundImage, isNull);
      expect(find.byIcon(Icons.pets), findsOneWidget);
    });
  });
}
