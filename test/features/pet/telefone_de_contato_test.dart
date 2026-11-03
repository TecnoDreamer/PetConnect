import 'package:flutter_test/flutter_test.dart';
import 'package:pet_connect/features/pet/domain/telefone_de_contato.dart';

/// Mesmos casos de `ContactPhoneTest` da API: o app e a API precisam
/// concordar sobre o que é um telefone válido.
void main() {
  group('telefoneE164', () {
    const validos = {
      '(19) 99999-0000': '+5519999990000',
      '19999990000': '+5519999990000',
      '019 99999-0000': '+5519999990000',
      '+55 19 99999-0000': '+5519999990000',
      '5519999990000': '+5519999990000',
      '(55) 99999-0000': '+5555999990000',
      '(11) 3333-4444': '+551133334444',
      '+1 415 555 2671': '+14155552671',
      '+351 912 345 678': '+351912345678',
    };
    validos.forEach((entrada, esperado) {
      test('"$entrada" vira $esperado', () {
        expect(telefoneE164(entrada), esperado);
      });
    });

    const invalidos = [
      '',
      ' ',
      '123',
      '(19) 8999-00000',
      '(20) 99999-0000',
      '(19) 19999-0000',
      '(19) 1333-4444',
      '+55 19 9999',
      '+0 123 456 789',
      '+1234567890123456',
      '19 99999-0000 ramal 2',
      'tel:19999990000',
    ];
    for (final entrada in invalidos) {
      test('recusa "$entrada"', () {
        expect(telefoneE164(entrada), isNull);
      });
    }
  });

  test('formatarTelefone mostra o número brasileiro com DDD', () {
    expect(formatarTelefone('+5519999990000'), '(19) 99999-0000');
    expect(formatarTelefone('+551133334444'), '(11) 3333-4444');
    expect(formatarTelefone('+14155552671'), '+14155552671');
  });
}
