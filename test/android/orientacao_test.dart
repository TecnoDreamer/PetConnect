// Orientação: o app fica em retrato e nunca mexe na rotação automática do
// celular (docs/features/orientacao-retrato.md). Inspeciona o projeto e o
// canal do sistema; não precisa de build nem de aparelho.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_connect/core/config/orientacao.dart';

String _ler(String caminho) => File(caminho).readAsStringSync();

/// Código e manifestos do app Android (sem o que o Flutter gera).
Iterable<File> _fontesAndroid() => Directory('android/app/src')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) =>
        RegExp(r'\.(kt|java|xml)$').hasMatch(f.path) &&
        !f.path.contains('GeneratedPluginRegistrant'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('o app pede só retrato, pelo canal do sistema da própria janela',
      () async {
    final chamadas = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (chamada) async {
      chamadas.add(chamada);
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await fixarOrientacaoDoApp();

    expect(chamadas.single.method, 'SystemChrome.setPreferredOrientations');
    expect(chamadas.single.arguments, ['DeviceOrientation.portraitUp']);
  });

  test('main() fixa a orientação antes de abrir o app', () {
    final main = _ler('lib/main.dart');
    expect(main, contains('await fixarOrientacaoDoApp();'));
    expect(main.indexOf('fixarOrientacaoDoApp();'),
        lessThan(main.indexOf('runApp(')));
  });

  test('Android: a activity abre em retrato desde a splash', () {
    expect(_ler('android/app/src/main/AndroidManifest.xml'),
        contains('android:screenOrientation="portrait"'));
  });

  test('Android: nada lê ou altera a rotação automática do sistema', () {
    for (final arquivo in _fontesAndroid()) {
      final texto = _ler(arquivo.path);
      for (final proibido in [
        'WRITE_SETTINGS',
        'ACCELEROMETER_ROTATION',
        'USER_ROTATION',
        'Settings.System',
        'requestedOrientation',
      ]) {
        expect(texto, isNot(contains(proibido)),
            reason: '${arquivo.path} contém $proibido');
      }
    }
  });

  test('iPhone: só retrato no Info.plist', () {
    final plist = _ler('ios/Runner/Info.plist');
    final inicio = plist.indexOf('<key>UISupportedInterfaceOrientations</key>');
    final fim = plist.indexOf('</array>', inicio);
    final lista = plist.substring(inicio, fim);
    expect(lista, contains('UIInterfaceOrientationPortrait'));
    expect(lista, isNot(contains('Landscape')));
  });
}
