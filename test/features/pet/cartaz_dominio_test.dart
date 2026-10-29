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
        rascunho: const RascunhoCartaz(
          vistoPorUltimoEm: ' Praça da Sé ',
          desapareceuEm: '20/10, à noite',
          observacoes: 'Mancha na orelha',
          recompensa: 'R\$ 200',
        ),
        telefone: '11900000000',
      );
      expect(conteudo.titulo, TituloCartaz.cachorro);
      expect(conteudo.nome, 'REX');
      expect(conteudo.telefone, '(11) 90000-0000');
      expect(conteudo.campos, const [
        CampoDoCartaz('Nome', 'Rex'),
        CampoDoCartaz('Espécie/Raça', 'Cachorro / SRD'),
        CampoDoCartaz('Cor', 'Caramelo'),
        CampoDoCartaz('Características', 'Macho, porte médio'),
        CampoDoCartaz('Visto por último em', 'Praça da Sé'),
        CampoDoCartaz('Desapareceu em', '20/10, à noite'),
        CampoDoCartaz('Observações', 'Mancha na orelha'),
        CampoDoCartaz('Recompensa', 'R\$ 200'),
      ]);
    });

    test('campos vazios somem: sem rótulo vazio, sem "null", sem recompensa',
        () {
      final conteudo = ConteudoCartaz.de(
        pet: _pet(raca: '', cor: '', genero: '', porte: ''),
        rascunho: const RascunhoCartaz(recompensa: '   '),
        telefone: null,
      );
      expect(conteudo.campos, const [
        CampoDoCartaz('Nome', 'Rex'),
        CampoDoCartaz('Espécie/Raça', 'Cachorro'),
      ]);
      expect(conteudo.telefone, isNull);
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

    test('enquadramento fica dentro dos limites', () {
      final e = EnquadramentoFoto.centralizado.ajustado(x: 5, y: -3, zoom: 9);
      expect([e.x, e.y, e.zoom], [1, -1, EnquadramentoFoto.zoomMaximo]);
    });

    test('salvo sem telefone, consentimento nem foto do celular', () {
      final rascunho = RascunhoCartaz(
        espacos: [
          const EspacoDeFoto(
              foto: _galeria, enquadramento: EnquadramentoFoto(x: 0.5)),
          EspacoDeFoto(foto: _aparelho),
          const EspacoDeFoto(foto: FotoDoPerfil(_url)),
        ],
        caracteristicas: 'Coleira azul',
        recompensa: 'R\$ 100',
        contato: OrigemDoContato.pet,
        telefoneAutorizado: '11900000000',
      );
      final texto = jsonEncode(rascunho.toJson());
      expect(texto, isNot(contains('11900000000')));

      final lido = RascunhoCartaz.fromJson(jsonDecode(texto));
      expect(lido.espacos[0].foto, _galeria);
      expect(lido.espacos[0].enquadramento.x, 0.5);
      expect(lido.espacos[1].foto, isNull);
      expect(lido.espacos[2].foto, const FotoDoPerfil(_url));
      expect(lido.caracteristicas, 'Coleira azul');
      expect(lido.recompensa, 'R\$ 100');
      expect(lido.contato, OrigemDoContato.pet);
      expect(lido.telefoneAutorizado, isNull);
    });

    test('rascunho corrompido ou com URL de fora do Cloudinary vira vazio', () {
      expect(RascunhoCartaz.fromJson('lixo').fotosEscolhidas, 0);
      expect(RascunhoCartaz.fromJson({'versao': 99}).fotosEscolhidas, 0);
      final lido = RascunhoCartaz.fromJson({
        'versao': 1,
        'espacos': [
          {'tipo': 'perfil', 'url': 'https://exemplo.com/a.jpg'},
          {'tipo': 'galeria', 'url': 'http://res.cloudinary.com/x.jpg'},
          {'tipo': 'galeria', 'url': _url},
        ],
        'observacoes': 'x' * 500,
      });
      expect(lido.fotosEscolhidas, 0);
      expect(lido.observacoes, hasLength(LimitesCartaz.observacoes));
    });

    test('store: uma chave por tutor e pet; ilegível conta como nenhum',
        () async {
      SharedPreferences.setMockInitialValues({
        RascunhoCartazStore.chave('uid-1', 'pet-2'): '{nao e json',
      });
      final store = RascunhoCartazStore(await SharedPreferences.getInstance());
      await store.salvar(
          'uid-1', 'pet-1', const RascunhoCartaz(recompensa: 'R\$ 50'));

      expect(store.ler('uid-1', 'pet-1')?.recompensa, 'R\$ 50');
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
