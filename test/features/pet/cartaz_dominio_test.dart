// Cartaz de pet desaparecido — regras do domínio, rascunho e exportação
// (docs/features/cartaz-pet-desaparecido.md). Dados fictícios.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_connect/features/pet/data/exportacao_cartaz.dart';
import 'package:pet_connect/features/pet/data/rascunho_cartaz_store.dart';
import 'package:pet_connect/features/pet/domain/cartaz_desaparecido.dart';
import 'package:pet_connect/features/pet/domain/pet.dart';
import 'package:shared_preferences/shared_preferences.dart';

Pet _pet({
  String nome = 'Rex',
  String especie = 'Cachorro',
  String raca = 'SRD',
  String cor = 'Caramelo',
  String genero = 'Macho',
  String porte = 'Médio',
  String? telefone,
}) =>
    Pet(
      id: 'pet-1',
      userId: 'uid-1',
      nome: nome,
      especie: especie,
      raca: raca,
      cor: cor,
      genero: genero,
      porte: porte,
      peso: '',
      dataNascimento: '',
      vacinado: true,
      telefone: telefone,
    );

const _url = 'https://res.cloudinary.com/demo/image/upload/v1/pets/a.jpg';
const _galeria = FotoDaGaleria(fotoId: 'f1', url: _url);
final _aparelho = FotoDoAparelho(Uint8List.fromList(const [1, 2, 3]));

RascunhoCartaz _comFotos(int quantas) => RascunhoCartaz(espacos: [
      for (var i = 0; i < LimitesCartaz.fotos; i++)
        i < quantas
            ? EspacoDeFoto(foto: FotoDaGaleria(fotoId: 'f$i', url: _url))
            : EspacoDeFoto.vazio,
    ]);

void main() {
  group('título pela espécie', () {
    test('gato e cachorro, com variações de grafia e acento', () {
      for (final especie in ['Gato', 'gata', 'GATO SIAMÊS', 'Felino']) {
        expect(TituloCartaz.daEspecie(especie).texto, 'GATO DESAPARECIDO',
            reason: especie);
      }
      for (final especie in ['Cachorro', 'cão', 'CÃES', 'Cadela', 'canino']) {
        expect(TituloCartaz.daEspecie(especie).texto, 'CACHORRO DESAPARECIDO',
            reason: especie);
      }
    });

    test('outras espécies ou espécie vazia: PET DESAPARECIDO', () {
      for (final especie in ['Coelho', 'Calopsita', '', 'gatorade', 'Caoba']) {
        expect(TituloCartaz.daEspecie(especie), TituloCartaz.pet,
            reason: especie);
      }
    });
  });

  group('telefone', () {
    test('aceita fixo e celular com DDD, com ou sem máscara e +55', () {
      expect(telefoneDoCartaz('(11) 90000-0000'), '11900000000');
      expect(telefoneDoCartaz('1134567890'), '1134567890');
      expect(telefoneDoCartaz('+55 21 90000-0000'), '21900000000');
    });

    test('recusa vazio, incompleto, longo demais e DDD inválido', () {
      for (final bruto in [
        null,
        '',
        '90000-0000',
        '119876543',
        '119000000000',
        '(01) 90000-0000',
        '+1 212 555 0100',
      ]) {
        expect(telefoneDoCartaz(bruto), isNull, reason: '$bruto');
      }
    });

    test('formata como no cadastro', () {
      expect(formatarTelefoneDoCartaz('11900000000'), '(11) 90000-0000');
      expect(formatarTelefoneDoCartaz('1134567890'), '(11) 3456-7890');
    });

    test('opções: do tutor e do pet, só se válidas e diferentes', () {
      expect(contatosDisponiveis(telefoneDoTutor: '', pet: _pet()), isEmpty);
      expect(
          contatosDisponiveis(
              telefoneDoTutor: '(11) 90000-0000',
              pet: _pet(telefone: '11900000000')),
          {OrigemDoContato.tutor: '11900000000'});
      expect(
          contatosDisponiveis(
              telefoneDoTutor: '123', pet: _pet(telefone: '(21) 3456-7890')),
          {OrigemDoContato.pet: '2134567890'});
    });

    test('origem escolhida cai na primeira disponível', () {
      final contatos = {
        OrigemDoContato.tutor: '11900000000',
        OrigemDoContato.pet: '2134567890',
      };
      expect(
          telefoneEscolhido(
              rascunho: const RascunhoCartaz(), contatos: contatos),
          '11900000000');
      expect(
          telefoneEscolhido(
              rascunho: const RascunhoCartaz(contato: OrigemDoContato.pet),
              contatos: contatos),
          '2134567890');
      expect(
          telefoneEscolhido(
              rascunho: const RascunhoCartaz(contato: OrigemDoContato.pet),
              contatos: {OrigemDoContato.tutor: '11900000000'}),
          '11900000000');
    });
  });

  group('o que bloqueia a exportação', () {
    test('exige exatamente 3 fotos', () {
      for (var n = 0; n <= 3; n++) {
        final problemas = problemasDoCartaz(
            rascunho: _comFotos(n).autorizarTelefone('11900000000'),
            telefone: '11900000000');
        expect(problemas.contains(ProblemaCartaz.faltamFotos), n < 3,
            reason: '$n fotos');
      }
      expect(ProblemaCartaz.faltamFotos.descricao(0),
          'Faltam 3 fotos: o cartaz usa 3.');
      expect(ProblemaCartaz.faltamFotos.descricao(2),
          'Falta 1 foto: o cartaz usa 3.');
    });

    test('um rascunho salvo com 4 fotos fica com as 3 primeiras', () {
      final json = _comFotos(3).toJson();
      (json['espacos']! as List).add((json['espacos']! as List).first);
      final lido = RascunhoCartaz.fromJson(jsonDecode(jsonEncode(json)));
      expect(lido.espacos, hasLength(3));
    });

    test('sem telefone válido: bloqueia, sem pedir consentimento', () {
      expect(problemasDoCartaz(rascunho: _comFotos(3), telefone: null),
          [ProblemaCartaz.semTelefone]);
    });

    test('consentimento vale só para o número autorizado', () {
      final autorizado = _comFotos(3).autorizarTelefone('11900000000');
      expect(problemasDoCartaz(rascunho: autorizado, telefone: '11900000000'),
          isEmpty);
      expect(problemasDoCartaz(rascunho: autorizado, telefone: '2134567890'),
          [ProblemaCartaz.semConsentimento]);
      expect(
          problemasDoCartaz(
              rascunho: autorizado.autorizarTelefone(null),
              telefone: '11900000000'),
          [ProblemaCartaz.semConsentimento]);
    });
  });

  group('conteúdo do cartaz', () {
    test('dados do cadastro e campos preenchidos, na ordem do cartaz', () {
      final conteudo = ConteudoCartaz.de(
        pet: _pet(),
        rascunho: RascunhoCartaz(
          vistoPorUltimo: VistoPorUltimo(
              data: DateTime(2026, 10, 20),
              periodo: PeriodoDoDia.noite,
              local: ' Praça da Sé '),
          observacoes: ' Mancha na orelha ',
          recompensa: const Recompensa(centavos: 20000),
          cor: CorDoCartaz.azul,
        ),
        telefone: '11900000000',
      );
      expect(conteudo.titulo, TituloCartaz.cachorro);
      expect(conteudo.nome, 'REX');
      expect(conteudo.telefone, '(11) 90000-0000');
      expect(conteudo.cor, CorDoCartaz.azul);
      // Espécie/raça, cor e "Desapareceu em" saíram do cartaz; as
      // observações têm caixa própria.
      expect(conteudo.campos, const [
        CampoDoCartaz('Nome', 'Rex'),
        CampoDoCartaz('Características', 'Macho, porte médio'),
        CampoDoCartaz('Visto por último', '20/10/2026, à noite — Praça da Sé'),
        CampoDoCartaz('Recompensa', 'R\$ 200,00'),
      ]);
      expect(conteudo.observacoes, 'Mancha na orelha');
    });

    test('campos vazios somem: sem rótulo vazio, sem "null", sem recompensa',
        () {
      final conteudo = ConteudoCartaz.de(
        pet: _pet(raca: '', cor: '', genero: '', porte: ''),
        rascunho: const RascunhoCartaz(
            recompensa: Recompensa(tipo: TipoRecompensa.outra, texto: '   ')),
        telefone: null,
      );
      expect(conteudo.campos, const [CampoDoCartaz('Nome', 'Rex')]);
      expect(conteudo.observacoes, isEmpty);
      expect(conteudo.telefone, isNull);
      expect(conteudo.cor, CorDoCartaz.preto);
      expect(conteudo.campos.join(), isNot(contains('null')));
    });

    test('características editadas substituem a sugestão; vazio tira a linha',
        () {
      ConteudoCartaz com(String? caracteristicas) => ConteudoCartaz.de(
          pet: _pet(),
          rascunho: RascunhoCartaz(caracteristicas: caracteristicas),
          telefone: null);
      expect(com('Coleira azul').campos.last,
          const CampoDoCartaz('Características', 'Coleira azul'));
      expect(com('').campos.map((c) => c.rotulo),
          isNot(contains('Características')));
    });

    test('semFotos: mesmo cartaz, espaços vazios', () {
      final conteudo = ConteudoCartaz.de(
          pet: _pet(), rascunho: _comFotos(3), telefone: '11900000000');
      final medida = conteudo.semFotos;
      expect(medida.espacos.every((e) => e.foto == null), isTrue);
      expect(medida.campos, conteudo.campos);
      expect(medida.telefone, conteudo.telefone);
    });
  });

  group('visto por último', () {
    test('data, período ou horário e local num texto só', () {
      final dia = DateTime(2026, 10, 29, 18, 45);
      expect(VistoPorUltimo.vazio.texto, '');
      expect(VistoPorUltimo(data: dia).texto, '29/10/2026');
      expect(
          VistoPorUltimo(
                  data: dia,
                  periodo: PeriodoDoDia.tarde,
                  local: 'Em '
                      'casa, no quintal')
              .texto,
          '29/10/2026, à tarde — Em casa, no quintal');
      expect(VistoPorUltimo(data: dia, horario: 15 * 60 + 5).texto,
          '29/10/2026, às 15h05');
      expect(const VistoPorUltimo(horario: 9 * 60).texto, 'Às 9h');
      expect(
          const VistoPorUltimo(
                  periodo: PeriodoDoDia.madrugada, local: 'rua das Flores')
              .texto,
          'De madrugada — rua das Flores');
      expect(const VistoPorUltimo(local: '  perto da praça ').texto,
          'Perto da praça');
    });

    test('período e horário exato não ficam juntos; a data perde a hora', () {
      final visto = const VistoPorUltimo()
          .comData(DateTime(2026, 10, 29, 18, 45))
          .comPeriodo(PeriodoDoDia.manha)
          .comHorario(600);
      expect(visto.data, DateTime(2026, 10, 29));
      expect(visto.periodo, isNull);
      expect(visto.horario, 600);
      expect(visto.comPeriodo(PeriodoDoDia.noite).horario, isNull);
    });
  });

  group('recompensa', () {
    test('valor em reais com ponto no milhar e vírgula nos centavos', () {
      expect(formatarReais(5), 'R\$ 0,05');
      expect(formatarReais(20000), 'R\$ 200,00');
      expect(formatarReais(150050), 'R\$ 1.500,50');
      expect(
          formatarReais(LimitesCartaz.recompensaEmCentavos), 'R\$ 999.999,99');
      expect(const Recompensa().noCartaz, '');
      expect(const Recompensa().comCentavos(0).noCartaz, '');
    });

    test('em dinheiro ou outra: só a escolhida vai no cartaz', () {
      const ambas = Recompensa(centavos: 10000, texto: 'Um vale-presente');
      expect(ambas.noCartaz, 'R\$ 100,00');
      expect(ambas.comTipo(TipoRecompensa.outra).noCartaz, 'Um vale-presente');
    });

    test('texto antigo vira valor quando dá para ler', () {
      expect(centavosDoTexto('200 R\$'), 20000);
      expect(centavosDoTexto('R\$ 1.500,00'), 150000);
      expect(centavosDoTexto('100,5'), 10050);
      expect(centavosDoTexto('Um vale-presente'), isNull);
      expect(centavosDoTexto('0'), isNull);
      expect(
          Recompensa.doTextoAntigo('100'), const Recompensa(centavos: 10000));
      expect(Recompensa.doTextoAntigo('Um abraço'),
          const Recompensa(tipo: TipoRecompensa.outra, texto: 'Um abraço'));
      expect(Recompensa.doTextoAntigo(' '), Recompensa.nenhuma);
    });
  });

  group('enquadramento', () {
    test('foco, zoom e modo ficam dentro dos limites', () {
      final e = EnquadramentoFoto.centralizado
          .ajustado(focoX: 5, focoY: -3, zoom: 9, inteira: true);
      expect([e.focoX, e.focoY, e.zoom], [1, 0, EnquadramentoFoto.zoomMaximo]);
      expect(e.inteira, isTrue);
    });

    test('a área visível tem o formato do espaço e fica centrada no foco', () {
      // Foto 3:2 num espaço quadrado: aparece 2/3 da largura, toda a altura.
      const centro = EnquadramentoFoto();
      final a = centro.areaVisivel(proporcaoDaFoto: 1.5, proporcaoDoEspaco: 1);
      expect(a.largura, closeTo(2 / 3, 1e-9));
      expect(a.altura, 1);
      expect(a.esquerda, closeTo(1 / 6, 1e-9));
      expect(a.topo, 0);

      // Foco na esquerda: a área encosta na borda, sem sair da foto.
      final esquerda = const EnquadramentoFoto(focoX: 0.1)
          .areaVisivel(proporcaoDaFoto: 1.5, proporcaoDoEspaco: 1);
      expect(esquerda.esquerda, 0);

      // Com zoom 2, metade da área, centrada no foco (0,4; 0,4).
      final zoom = const EnquadramentoFoto(focoX: 0.4, focoY: 0.4, zoom: 2)
          .areaVisivel(proporcaoDaFoto: 1.5, proporcaoDoEspaco: 1);
      expect(zoom.largura, closeTo(1 / 3, 1e-9));
      expect(zoom.altura, 0.5);
      expect(zoom.esquerda, closeTo(0.4 - 1 / 6, 1e-9));
      expect(zoom.topo, closeTo(0.15, 1e-9));

      // Espaço mais largo que a foto: corta em cima e embaixo.
      final largo = const EnquadramentoFoto(focoY: 0.2)
          .areaVisivel(proporcaoDaFoto: 1, proporcaoDoEspaco: 2);
      expect(largo.largura, 1);
      expect(largo.altura, 0.5);
      expect(largo.topo, 0);
    });

    test('rascunho antigo (âncora de -1 a 1) vira o foco equivalente', () {
      final e = EnquadramentoFoto.fromJson({'x': -1, 'y': 0.5, 'zoom': 2});
      expect([e.focoX, e.focoY, e.zoom], [0, 0.75, 2]);
      expect(e.inteira, isFalse);
    });
  });

  group('rascunho', () {
    test('troca de posição leva o enquadramento junto', () {
      const zoom = EnquadramentoFoto(zoom: 2);
      final rascunho = const RascunhoCartaz()
          .comEspaco(0, const EspacoDeFoto(foto: _galeria, enquadramento: zoom))
          .trocarEspacos(0, 2);
      expect(rascunho.espacos[0].foto, isNull);
      expect(rascunho.espacos[2].foto, _galeria);
      expect(rascunho.espacos[2].enquadramento, zoom);
    });

    test('salvo sem telefone, consentimento nem foto do celular', () {
      final visto = VistoPorUltimo(
          data: DateTime(2026, 10, 29),
          horario: 15 * 60 + 30,
          local: 'Praça da Sé');
      final rascunho = RascunhoCartaz(
        espacos: [
          const EspacoDeFoto(
              foto: _galeria,
              enquadramento:
                  EnquadramentoFoto(focoX: 0.2, focoY: 0.3, zoom: 1.5)),
          EspacoDeFoto(foto: _aparelho),
          const EspacoDeFoto(
              foto: FotoDoPerfil(_url),
              enquadramento: EnquadramentoFoto(inteira: true)),
        ],
        caracteristicas: 'Coleira azul',
        vistoPorUltimo: visto,
        observacoes: 'Medroso',
        recompensa: const Recompensa(centavos: 10000),
        cor: CorDoCartaz.vermelho,
        contato: OrigemDoContato.pet,
        telefoneAutorizado: '11900000000',
      );
      final texto = jsonEncode(rascunho.toJson());
      expect(texto, isNot(contains('11900000000')));

      final lido = RascunhoCartaz.fromJson(jsonDecode(texto));
      expect(lido.espacos[0].foto, _galeria);
      expect(lido.espacos[0].enquadramento,
          const EnquadramentoFoto(focoX: 0.2, focoY: 0.3, zoom: 1.5));
      expect(lido.espacos[1].foto, isNull);
      expect(lido.espacos[2].foto, const FotoDoPerfil(_url));
      expect(lido.espacos[2].enquadramento.inteira, isTrue);
      expect(lido.caracteristicas, 'Coleira azul');
      expect(lido.vistoPorUltimo, visto);
      expect(lido.observacoes, 'Medroso');
      expect(lido.recompensa, const Recompensa(centavos: 10000));
      expect(lido.cor, CorDoCartaz.vermelho);
      expect(lido.contato, OrigemDoContato.pet);
      expect(lido.telefoneAutorizado, isNull);
    });

    test('rascunho da versão 1 é convertido', () {
      final lido = RascunhoCartaz.fromJson({
        'versao': 1,
        'espacos': [],
        'vistoPorUltimoEm': 'Em casa',
        'desapareceuEm': '29/10 à tarde.',
        'recompensa': '200 R\$',
      });
      expect(lido.vistoPorUltimo, const VistoPorUltimo(local: 'Em casa'));
      expect(lido.recompensa, const Recompensa(centavos: 20000));
      expect(lido.cor, CorDoCartaz.preto);
    });

    test('rascunho corrompido ou com URL de fora do Cloudinary vira vazio', () {
      expect(RascunhoCartaz.fromJson('lixo').fotosEscolhidas, 0);
      expect(RascunhoCartaz.fromJson({'versao': 99}).fotosEscolhidas, 0);
      final lido = RascunhoCartaz.fromJson({
        'versao': 2,
        'espacos': [
          {'tipo': 'perfil', 'url': 'https://exemplo.com/a.jpg'},
          {'tipo': 'galeria', 'url': 'http://res.cloudinary.com/x.jpg'},
          {'tipo': 'galeria', 'url': _url},
        ],
        'observacoes': 'x' * 500,
        'vistoPorUltimo': {
          'data': 'ontem',
          'periodo': 'hora do almoço',
          'horario': -5,
          'local': 'y' * 500,
        },
        'recompensa': {'tipo': 'pix', 'centavos': -1, 'texto': 3},
        'cor': 'verde',
      });
      expect(lido.fotosEscolhidas, 0);
      expect(lido.observacoes, hasLength(LimitesCartaz.observacoes));
      expect(lido.vistoPorUltimo.data, isNull);
      expect(lido.vistoPorUltimo.periodo, isNull);
      expect(lido.vistoPorUltimo.horario, isNull);
      expect(lido.vistoPorUltimo.local, hasLength(LimitesCartaz.localVisto));
      expect(lido.recompensa, Recompensa.nenhuma);
      expect(lido.cor, CorDoCartaz.preto);
    });

    test('store: uma chave por tutor e pet; ilegível conta como nenhum',
        () async {
      SharedPreferences.setMockInitialValues({
        RascunhoCartazStore.chave('uid-1', 'pet-2'): '{nao e json',
      });
      final store = RascunhoCartazStore(await SharedPreferences.getInstance());
      await store.salvar('uid-1', 'pet-1',
          const RascunhoCartaz(recompensa: Recompensa(centavos: 5000)));

      expect(store.ler('uid-1', 'pet-1')?.recompensa.noCartaz, 'R\$ 50,00');
      expect(store.ler('uid-2', 'pet-1'), isNull);
      expect(store.ler('uid-1', 'pet-2'), isNull);
      await store.apagar('uid-1', 'pet-1');
      expect(store.ler('uid-1', 'pet-1'), isNull);
    });
  });

  group('exportação', () {
    test('nome do arquivo sem nome do pet, telefone nem id interno', () {
      final nome = nomeDoArquivoDoCartaz(
          petId: 'pet-abc', data: DateTime(2026, 10, 9), extensao: 'png');
      expect(
          nome,
          matches(
              RegExp(r'^petconnect_procura-se_[0-9a-f]{8}_20261009\.png$')));
      expect(nome, isNot(contains('pet-abc')));
      expect(
          nomeDoArquivoDoCartaz(
              petId: 'outro', data: DateTime(2026, 10, 9), extensao: 'png'),
          isNot(nome));
    });

    test('PDF: um documento de uma página A4 com a imagem', () async {
      // PNG 1×1 válido.
      final png = base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg==');
      final pdf = await gerarPdfDoCartaz(png);
      final texto = latin1.decode(pdf);
      expect(texto, startsWith('%PDF'));
      expect(RegExp(r'/Type\s*/Page\b').allMatches(texto), hasLength(1));
      // A4 em pontos: 595,28 × 841,89.
      expect(texto, contains('595.27'));
    });
  });
}
