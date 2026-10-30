// Teste de verificação do fluxo real de autenticação (cadastro -> home ->
// logout -> login -> senha errada), agora seguro para rodar repetidamente
// (e eventualmente entrar no CI) — reescrito na FASE 12 (R-11) para não
// tocar em infraestrutura real:
//
// Tag `e2e`: precisa do Auth Emulator + API + Mongo de pé (ver pré-requisitos
// abaixo) — por isso fica de fora do `flutter test` do CI
// (--exclude-tags=e2e em ci.yml), ao contrário dos outros testes de
// test/features/auth/, que não dependem de infraestrutura externa.
//
//   - Firebase Auth: aponta pro **Auth Emulator** local, não pro projeto de
//     produção. O usuário de teste só existe no emulador (processo
//     efêmero) — nada é criado no Firebase real.
//   - Perfil do tutor: com `USE_API_USUARIO=true`, o app usa a API Spring
//     (`ApiUsuarioRepository`) em vez do Firestore — então o teste também
//     não escreve na coleção `Usuarios` de produção. Como bônus, é a
//     própria API+Mongo (o destino final da migração) que fica validada
//     aqui, não o caminho legado que está sendo desativado.
//   - Não precisamos do Firestore Emulator: além de não ser necessário
//     nesse caminho (API mode), ele é um processo Java e esbarra no mesmo
//     bug de loopback do Windows que quebra o Tomcat direto nesta máquina
//     (ver docs/migration/handoff.md, seção 3) — só o Auth Emulator
//     (Node.js) funciona sem contorno aqui.
//
// Pré-requisitos pra rodar (3 processos, nenhum novo além do que a FASE 2
// já usa — só aponta pro emulador em vez do projeto real):
//   1. firebase emulators:start --only auth --project pet-connect-c53f1
//   2. cd PetConnect-API && mongo já de pé (docker compose up -d mongo) e:
//        FIREBASE_AUTH_EMULATOR_HOST=host.docker.internal:9099 \
//          docker compose up -d api
//   3. flutter test --platform=chrome \
//        --dart-define=USE_API_USUARIO=true \
//        --dart-define=API_BASE_URL=http://localhost:8090 \
//        test/features/auth/auth_flow_test.dart
//
// Ainda não plugado no CI (falta automatizar os 3 processos acima num
// workflow) — mas agora é seguro rodar quantas vezes quiser: tudo o que é
// criado (usuário no emulador + perfil no Mongo local) é apagado no
// tearDown, e nada disso é infraestrutura de produção.
//
// NÃO EXECUTADO COM SUCESSO ainda (2026-09-11) — nem direto nesta máquina
// (mesmo bug de loopback do Windows que quebra o Tomcat/Firestore Emulator,
// ver handoff.md seção 3) nem via o contorno em container Linux
// (tool/web-test/Dockerfile): esse contorno resolve o travamento original e
// chega a compilar e abrir o Chrome, mas trava 12min em `setUpAll`
// (Firebase.initializeApp + useAuthEmulator) sem lançar exceção — mesmo com
// conectividade container→host confirmada via curl (suspeita não confirmada:
// SDK JS do Firebase Auth preso em algo de IndexedDB/storage num Chrome
// --no-sandbox como root). Detalhe completo no handoff.md, seção 3.
//
// A lógica do teste (auth via emulador + perfil via API) foi validada peça
// por peça, fora do harness de teste em navegador: o Auth Emulator sobe e
// responde nesta máquina, e um token emitido por ele foi aceito de ponta a
// ponta pela API real via curl (`GET`/`DELETE /api/v1/me`). Falta confirmar
// rodando de fato — o caminho mais provável de funcionar sem mais esforço de
// infra é um CI real (GitHub Actions `ubuntu-latest`, sem as camadas de
// container-dentro-de-container que o contorno local precisou empilhar).
@Tags(['e2e'])
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pet_connect/app.dart';
import 'package:pet_connect/firebase_options.dart';

const _apiBaseUrl = String.fromEnvironment('API_BASE_URL',
    defaultValue: 'http://localhost:8090');

// 'localhost' funciona rodando `flutter test` direto no host; dentro do
// container de tool/web-test/Dockerfile (contorno do bug de loopback desta
// máquina), o Auth Emulator está no HOST, não no container — por isso
// configurável via --dart-define=AUTH_EMULATOR_HOST=host.docker.internal.
const _authEmulatorHost =
    String.fromEnvironment('AUTH_EMULATOR_HOST', defaultValue: 'localhost');

void main() {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final testEmail = 'qa.petconnect.$timestamp@example.com';
  const testNome = 'QA PetConnect';
  const testPrimeiroNome = 'QA';
  // Precisa atender à política de senha do redesign do cadastro (2026-09-13,
  // ver docs/features/cadastro-redesign.md): 9+ caracteres, maiúscula,
  // minúscula, número e caractere especial.
  const testSenha = 'PetConnect@9';

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    // A partir daqui, todo signIn/signUp/signOut do FirebaseAuth.instance
    // fala com o emulador local — nunca com o projeto real.
    await FirebaseAuth.instance.useAuthEmulator(_authEmulatorHost, 9099);
  });

  tearDownAll(() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final token = await user.getIdToken();
    // Apaga o perfil no Mongo via API antes de apagar o usuário do Auth —
    // depois de apagado o Auth, o token não autentica mais nada. Falha
    // silenciosa aqui não deve derrubar o teste (já rodou, só é limpeza).
    try {
      await http.delete(
        Uri.parse('$_apiBaseUrl/api/v1/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (_) {}
    await user.delete();
  });

  Future<void> logout(WidgetTester tester) async {
    // Sair não fica mais num ícone na Home — é preciso entrar em
    // Configurações primeiro (mesmo fluxo do botão de voltar da Home).
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sair da conta'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Sair'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  testWidgets('cadastro -> home -> logout -> login -> senha errada',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PetConnectApp()));
    await tester.pumpAndSettle();

    // Abre na splash (tempo mínimo de exibição de 2,5s) antes de decidir
    // entre login/Home — avança o relógio para além desse tempo.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('Entrar'), findsOneWidget,
        reason: 'deveria abrir na tela de login');

    await tester.tap(find.text('Cadastre-se'));
    await tester.pumpAndSettle();

    expect(find.text('Crie sua conta'), findsOneWidget,
        reason: 'deveria navegar para o cadastro');

    final cadastroFields = find.byType(TextFormField);
    expect(cadastroFields, findsNWidgets(5));
    await tester.enterText(cadastroFields.at(0), testNome); // nome
    await tester.enterText(cadastroFields.at(1), testEmail); // e-mail
    await tester.enterText(cadastroFields.at(2), '19991562584'); // telefone
    await tester.enterText(cadastroFields.at(3), testSenha); // senha
    await tester.enterText(cadastroFields.at(4), testSenha); // confirmar senha

    await tester.tap(find.widgetWithText(ElevatedButton, 'CRIAR CONTA'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Meus Pets'), findsOneWidget,
        reason: 'cadastro deveria levar direto para a Home');
    expect(find.textContaining('Olá, $testPrimeiroNome'), findsOneWidget,
        reason:
            'Home deveria saudar o usuário recém-cadastrado pelo primeiro nome');

    await logout(tester);

    expect(find.text('Entrar'), findsOneWidget,
        reason: 'logout deveria voltar para a tela de login');

    final loginFields = find.byType(TextField);
    expect(loginFields, findsNWidgets(2));
    await tester.enterText(loginFields.at(0), testEmail);
    await tester.enterText(loginFields.at(1), testSenha);
    await tester.tap(find.widgetWithText(ElevatedButton, 'ENTRAR'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Meus Pets'), findsOneWidget,
        reason: 'login com credenciais corretas deveria voltar para a Home');

    await logout(tester);

    final loginFields2 = find.byType(TextField);
    await tester.enterText(loginFields2.at(0), testEmail);
    await tester.enterText(loginFields2.at(1), 'senhaErrada999');
    await tester.tap(find.widgetWithText(ElevatedButton, 'ENTRAR'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Entrar'), findsOneWidget,
        reason: 'senha errada não deveria navegar para a Home');
    expect(find.text('E-mail ou senha inválidos.'), findsOneWidget,
        reason:
            'deveria mostrar a mensagem de erro genérica de credenciais inválidas');
  });
}
