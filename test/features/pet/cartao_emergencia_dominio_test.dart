// Cartão de Emergência (issue #41): modelo, compatibilidade com documentos
// antigos ou malformados e limpeza do texto digitado.
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_connect/features/pet/domain/cartao_emergencia.dart';

void main() {
  group('leitura do banco', () {
    test('documento vazio ou antigo: tudo "Não informado", nada deduzido', () {
      final c = CartaoEmergencia.fromMap(const {});

      expect(c.situacaoAlergias, SituacaoDaLista.naoInformado);
      expect(c.situacaoMedicamentos, SituacaoDaLista.naoInformado);
      expect(c.situacaoCondicoes, SituacaoDaLista.naoInformado);
      expect(c.alergias, isEmpty);
      expect(c.tipoSanguineo, isEmpty);
      expect(c.revisao, 0);
      expect(c.mostrarContatoDoTutor, isTrue);
      expect(c.semDados, isTrue);
    });

    test('"Nenhuma conhecida" só quando o tutor declarou', () {
      final declarado = CartaoEmergencia.fromMap(
          const {'situacaoAlergias': 'NENHUMA_DECLARADA', 'revisao': 1});
      expect(declarado.situacaoAlergias, SituacaoDaLista.nenhumaDeclarada);

      final semCampo = CartaoEmergencia.fromMap(const {'revisao': 1});
      expect(semCampo.situacaoAlergias, SituacaoDaLista.naoInformado);
    });

    test('situação desconhecida vira "Não informado"', () {
      final c = CartaoEmergencia.fromMap(const {'situacaoAlergias': 'TALVEZ'});
      expect(c.situacaoAlergias, SituacaoDaLista.naoInformado);
    });

    test('"Informada" sem item válido não se sustenta', () {
      final c = CartaoEmergencia.fromMap(const {
        'situacaoAlergias': 'INFORMADA',
        'alergias': [
          {'id': 'a1', 'substancia': '   '},
          'texto solto',
          42,
        ],
      });
      expect(c.situacaoAlergias, SituacaoDaLista.naoInformado);
      expect(c.alergias, isEmpty);
    });

    test('itens malformados são ignorados, os válidos ficam', () {
      final c = CartaoEmergencia.fromMap(const {
        'situacaoMedicamentos': 'INFORMADA',
        'medicamentos': [
          {'id': 'm1', 'nome': 'Fenobarbital', 'dose': '50 mg'},
          {'id': 'm2'},
          null,
        ],
      });
      expect(c.medicamentos, hasLength(1));
      expect(c.medicamentos.single.nome, 'Fenobarbital');
      expect(c.medicamentos.single.dose, '50 mg');
    });

    test('lista com mais itens que o limite é cortada no limite', () {
      final c = CartaoEmergencia.fromMap({
        'situacaoCondicoes': 'INFORMADA',
        'condicoes': List.generate(30, (i) => 'Condição $i'),
      });
      expect(c.condicoes, hasLength(LimitesDoCartao.itensPorLista));
    });

    test('tipo sanguíneo sem confirmação não aparece', () {
      final semConfirmar = CartaoEmergencia.fromMap(
          const {'tipoSanguineo': 'A', 'tipoSanguineoConfirmado': false});
      expect(semConfirmar.tipoSanguineo, isEmpty);

      final confirmado = CartaoEmergencia.fromMap(
          const {'tipoSanguineo': 'A', 'tipoSanguineoConfirmado': true});
      expect(confirmado.tipoSanguineo, 'A');
      expect(confirmado.tipoSanguineoConfirmado, isTrue);
    });

    test('campos de outro tipo não quebram a leitura', () {
      final c = CartaoEmergencia.fromMap(const {
        'observacoes': 123,
        'veterinario': 'Dra. X',
        'mostrarContatoDoTutor': 'não',
        'revisao': '3',
      });
      expect(c.observacoes, isEmpty);
      expect(c.veterinario.vazio, isTrue);
      expect(c.mostrarContatoDoTutor, isTrue);
      expect(c.revisao, 0);
    });
  });

  group('gravação', () {
    test('ida e volta preserva o conteúdo', () {
      const original = CartaoEmergencia(
        situacaoAlergias: SituacaoDaLista.informada,
        alergias: [
          Alergia(id: 'a1', substancia: 'Dipirona', reacao: 'Vômito'),
        ],
        situacaoMedicamentos: SituacaoDaLista.nenhumaDeclarada,
        situacaoCondicoes: SituacaoDaLista.informada,
        condicoes: ['Epilepsia'],
        tipoSanguineo: 'DEA 1.1 positivo',
        tipoSanguineoConfirmado: true,
        observacoes: 'Morde quando sente dor.',
        veterinario: VeterinarioDeConfianca(
            nome: 'Dra. Exemplo', telefone: '+5519900000000'),
        mostrarContatoDoTutor: false,
      );

      final lido = CartaoEmergencia.fromMap(original.toMap());

      expect(lido.toMap(), original.toMap());
      expect(lido.alergias.single.reacao, 'Vômito');
      expect(lido.situacaoMedicamentos, SituacaoDaLista.nenhumaDeclarada);
    });

    test('lista fora de "Informada" não grava itens escondidos', () {
      const c = CartaoEmergencia(
        situacaoAlergias: SituacaoDaLista.nenhumaDeclarada,
        alergias: [Alergia(id: 'a1', substancia: 'Dipirona')],
      );
      expect(c.toMap()['alergias'], isEmpty);
    });

    test('tipo sanguíneo sem confirmação não é gravado', () {
      const c = CartaoEmergencia(tipoSanguineo: 'A');
      expect(c.toMap()['tipoSanguineo'], '');
      expect(c.toMap()['tipoSanguineoConfirmado'], isFalse);
    });

    test('grava a versão do esquema e nunca o telefone do tutor', () {
      final mapa = CartaoEmergencia.vazio.toMap();
      expect(mapa['versaoEsquema'], CartaoEmergencia.versaoEsquema);
      expect(mapa.keys, isNot(contains('telefoneDoTutor')));
      expect(mapa.keys, isNot(contains('revisao')));
      expect(mapa.keys, isNot(contains('atualizadoEm')));
    });
  });

  group('limparTexto', () {
    test('tira caracteres de controle e espaços nas pontas', () {
      expect(limparTexto('  Dipi\u0000rona\u0007 ', 80), 'Dipirona');
    });

    test('quebra de linha só fica no texto de várias linhas', () {
      expect(limparTexto('a\nb', 80), 'ab');
      expect(limparTexto('a\r\nb', 80, multilinha: true), 'a\nb');
    });

    test('corta no limite', () {
      expect(limparTexto('x' * 100, 40), hasLength(40));
    });

    test('não mexe em nomes com acento, apóstrofo ou hífen', () {
      expect(limparTexto("Pó d'água - anti-inflamatório", 80),
          "Pó d'água - anti-inflamatório");
    });
  });
}
