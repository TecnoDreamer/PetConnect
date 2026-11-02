/// Telefone de contato da página pública do QR em E.164
/// (`+5519999990000`). Mesma regra da API (`ContactPhone.java`): sem `+`, o
/// número é tratado como brasileiro. Validar o formato não diz se o número
/// tem WhatsApp; isso só o próprio WhatsApp sabe.
library;

/// DDDs em uso no Brasil (Anatel).
const _ddds = {
  '11', '12', '13', '14', '15', '16', '17', '18', '19', //
  '21', '22', '24', '27', '28',
  '31', '32', '33', '34', '35', '37', '38',
  '41', '42', '43', '44', '45', '46', '47', '48', '49',
  '51', '53', '54', '55',
  '61', '62', '63', '64', '65', '66', '67', '68', '69',
  '71', '73', '74', '75', '77', '79',
  '81', '82', '83', '84', '85', '86', '87', '88', '89',
  '91', '92', '93', '94', '95', '96', '97', '98', '99',
};

/// O número em E.164 ou `null` se não for válido.
String? telefoneE164(String bruto) {
  final texto = bruto.trim();
  if (texto.isEmpty || !RegExp(r'^[+0-9 ().-]+$').hasMatch(texto)) {
    return null;
  }
  var digitos = texto.replaceAll(RegExp(r'\D'), '');
  if (!texto.startsWith('+')) {
    // Número nacional tem no máximo 11 dígitos; com 12 ou 13 começando por
    // 55, o código do Brasil já veio. Senão, tira o 0 de discagem.
    digitos = digitos.replaceFirst(RegExp(r'^0+'), '');
    if (!(digitos.length >= 12 && digitos.startsWith('55'))) {
      digitos = '55$digitos';
    }
  }
  if (digitos.startsWith('55')) {
    final nacional = digitos.substring(2);
    final celular = nacional.length == 11 && nacional[2] == '9';
    final fixo = nacional.length == 10 && '2345'.contains(nacional[2]);
    if (!(celular || fixo) || !_ddds.contains(nacional.substring(0, 2))) {
      return null;
    }
    return '+$digitos';
  }
  if (!RegExp(r'^[1-9][0-9]{7,14}$').hasMatch(digitos)) return null;
  return '+$digitos';
}

/// `+5519999990000` → `(19) 99999-0000`; outros países ficam em E.164.
String formatarTelefone(String e164) {
  if (!e164.startsWith('+55')) return e164;
  final n = e164.substring(3);
  final ddd = n.substring(0, 2);
  final resto = n.substring(2);
  final corte = resto.length - 4;
  return '($ddd) ${resto.substring(0, corte)}-${resto.substring(corte)}';
}
