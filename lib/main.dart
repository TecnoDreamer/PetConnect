import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/orientacao.dart';
import 'core/theme/theme_providers.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await fixarOrientacaoDoApp();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final prefs = await SharedPreferences.getInstance();
  // O signOut() que exige login a cada abertura do app (mesmo com sessão
  // persistida) não fica aqui — fica em sessionBootstrapProvider, aguardado
  // pela SplashScreen. Só assim dá pra testar a ordenação (bootstrap antes
  // da decisão de destino) sem depender de um app real rodando; feito aqui
  // dentro de main(), isso não seria possível de verificar em teste algum.
  runApp(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const PetConnectApp(),
  ));
}
