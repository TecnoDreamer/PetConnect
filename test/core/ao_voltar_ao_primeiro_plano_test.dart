import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_connect/core/widgets/ao_voltar_ao_primeiro_plano.dart';

void main() {
  testWidgets('chama aoVoltar só quando o app volta ao primeiro plano',
      (tester) async {
    var chamadas = 0;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: AoVoltarAoPrimeiroPlano(
        aoVoltar: () => chamadas++,
        child: const Text('conteúdo'),
      ),
    ));
    expect(find.text('conteúdo'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(chamadas, 0, reason: 'indo para o segundo plano não faz nada');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(chamadas, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(chamadas, 2);
  });

  testWidgets('para de ouvir quando sai da tela', (tester) async {
    var chamadas = 0;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: AoVoltarAoPrimeiroPlano(
        aoVoltar: () => chamadas++,
        child: const SizedBox(),
      ),
    ));
    await tester.pumpWidget(const SizedBox());

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(chamadas, 0);
  });
}
