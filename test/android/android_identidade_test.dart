// Identidade do app no Android: nome no launcher, ícone com o logo oficial
// e splash nativa da marca (docs/branding/icone-e-splash-android.md).
// Inspeciona os arquivos do projeto Android — não precisa de build.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _res = 'android/app/src/main/res';
const _densidades = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];

String _ler(String caminho) => File(caminho).readAsStringSync();

void main() {
  test('nome exibido é "PetConnect" via @string/app_name', () {
    final manifesto = _ler('android/app/src/main/AndroidManifest.xml');
    expect(manifesto, contains('android:label="@string/app_name"'));
    expect(manifesto, isNot(contains('pet_connect"')),
        reason: 'nenhum rótulo literal com o nome interno do projeto');
    expect(_ler('$_res/values/strings.xml'),
        contains('<string name="app_name">PetConnect</string>'));

    for (final variante in ['debug', 'profile']) {
      expect(_ler('android/app/src/$variante/AndroidManifest.xml'),
          isNot(contains('android:label')),
          reason: 'a variante $variante não pode sobrescrever o nome');
    }
  });

  test('applicationId e namespace continuam os mesmos (atualização possível)',
      () {
    final gradle = File('android/app/build.gradle.kts').existsSync()
        ? _ler('android/app/build.gradle.kts')
        : _ler('android/app/build.gradle');
    expect(gradle, contains('applicationId = "com.petconnect.pet_connect"'));
    expect(gradle, contains('namespace = "com.petconnect.pet_connect"'));
  });

  test('adaptive icon com fundo, logo e versão monocromática', () {
    final adaptive = _ler('$_res/mipmap-anydpi-v26/ic_launcher.xml');
    expect(adaptive, contains('@drawable/ic_launcher_background'));
    expect(adaptive, contains('@mipmap/ic_launcher_foreground'));
    expect(adaptive, contains('@mipmap/ic_launcher_monochrome'));
    expect(
        File('$_res/drawable/ic_launcher_background.xml').existsSync(), isTrue);
    expect(_ler('android/app/src/main/AndroidManifest.xml'),
        contains('android:icon="@mipmap/ic_launcher"'));
  });

  test('todas as densidades têm ícone legado, camadas e logo da splash', () {
    for (final d in _densidades) {
      for (final arquivo in [
        '$_res/mipmap-$d/ic_launcher.png',
        '$_res/mipmap-$d/ic_launcher_foreground.png',
        '$_res/mipmap-$d/ic_launcher_monochrome.png',
        '$_res/drawable-$d/splash_logo.png',
      ]) {
        expect(File(arquivo).existsSync(), isTrue, reason: arquivo);
      }
    }
  });

  test('nenhum ícone do launcher é o ícone padrão do template do Flutter', () {
    final raizFlutter = Platform.environment['FLUTTER_ROOT'];
    final template = raizFlutter == null
        ? null
        : '$raizFlutter/packages/flutter_tools/templates/app/android.tmpl/'
            'app/src/main/res';
    if (template == null || !Directory(template).existsSync()) {
      markTestSkipped('templates do Flutter SDK indisponíveis neste ambiente');
      return;
    }
    for (final d in _densidades) {
      final nosso = File('$_res/mipmap-$d/ic_launcher.png').readAsBytesSync();
      final padrao =
          File('$template/mipmap-$d/ic_launcher.png').readAsBytesSync();
      expect(_iguais(nosso, padrao), isFalse,
          reason: 'mipmap-$d/ic_launcher.png ainda é o ícone do Flutter');
    }
  });

  test('splash nativa com a cor e o logo da marca (Android 12+ e anteriores)',
      () {
    for (final pasta in ['values-v31', 'values-night-v31']) {
      final estilos = _ler('$_res/$pasta/styles.xml');
      expect(estilos,
          contains('android:windowSplashScreenBackground">@color/splash_fundo'),
          reason: pasta);
      expect(
          estilos,
          contains(
              'android:windowSplashScreenAnimatedIcon">@drawable/splash_logo'),
          reason: pasta);
    }
    for (final pasta in ['drawable', 'drawable-v21']) {
      final fundo = _ler('$_res/$pasta/launch_background.xml');
      expect(fundo, contains('@color/splash_fundo'), reason: pasta);
      expect(fundo, contains('@drawable/splash_logo'), reason: pasta);
    }
    // Mesma cor da SplashScreen do Flutter (AppColors.brandMedium).
    expect(_ler('$_res/values/colors.xml'),
        contains('<color name="splash_fundo">#5C3A24</color>'));
  });
}

bool _iguais(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
