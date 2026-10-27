// Galeria de fotos por pet: validação, URLs derivadas, fila de envio e envio
// ao Cloudinary (docs/features/galeria-fotos-pet.md).
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_connect/core/utils/cloudinary_url.dart';
import 'package:pet_connect/features/pet/data/cloudinary_imagem_upload.dart';
import 'package:pet_connect/features/pet/domain/anexo_repository.dart';
import 'package:pet_connect/features/pet/domain/envio_de_fotos.dart';
import 'package:pet_connect/features/pet/domain/foto_pet.dart';
import 'package:pet_connect/features/pet/domain/galeria_repository.dart';
import 'package:pet_connect/features/pet/domain/pet.dart';
import 'package:pet_connect/features/pet/presentation/providers/galeria_providers.dart';

import 'fake_galeria_repository.dart';

Uint8List _bytes(List<int> inicio, [int resto = 16]) =>
    Uint8List.fromList([...inicio, ...List.filled(resto, 0)]);

final _jpeg = _bytes([0xFF, 0xD8, 0xFF, 0xE0]);
final _png = _bytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
final _webp = _bytes([
  0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50, //
]);
final _heic =
    _bytes([0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70, ...'heic'.codeUnits]);
final _gif = _bytes('GIF89a'.codeUnits);
final _pdf = _bytes('%PDF-1.7'.codeUnits);

const _original =
    'https://res.cloudinary.com/qgrx3f8s/image/upload/v1730000000/users/u1/abc.jpg';

Pet _pet() => const Pet(
      id: 'pet-1',
      userId: 'uid-1',
      nome: 'Rex',
      especie: '',
      raca: '',
      cor: '',
      genero: '',
      porte: '',
      peso: '',
      dataNascimento: '',
      vacinado: false,
    );

/// Publica na ordem; falha nos índices de [falharEm]; pode travar até
/// [liberar] completar, para testar o cancelamento.
class _GaleriaRoteirizada implements GaleriaRepository {
  _GaleriaRoteirizada({this.falharEm = const {}});

  Set<int> falharEm;
  Completer<void>? liberar;
  final chamadas = <Uint8List>[];

  @override
  Future<FotoPet> publicar({
    required Pet pet,
    required String userId,
    required Uint8List bytes,
    String? legenda,
    void Function(double fracao)? aoProgredir,
    Future<void>? cancelar,
  }) async {
    final n = chamadas.length;
    chamadas.add(bytes);
    aoProgredir?.call(0.5);
    final trava = liberar;
    if (trava != null) {
      await Future.any([trava.future, if (cancelar != null) cancelar]);
      if (!trava.isCompleted) throw const EnvioCancelado();
    }
    if (falharEm.contains(n)) throw Exception('falha $n');
    return FotoPet(
      id: 'f$n',
      petId: pet.id,
      userId: userId,
      url: 'https://res.cloudinary.com/demo/image/upload/v1/f$n.jpg',
      publicId: 'f$n',
      legenda: normalizarLegenda(legenda),
    );
  }

  @override
  Future<void> excluir(FotoPet foto) async {}

  @override
  Future<PaginaDeFotos> listar(String petId,
          {FotoPet? depoisDe, int limite = LimitesGaleria.porPagina}) async =>
      const PaginaDeFotos(fotos: [], temMais: false);
}

void main() {
  group('formato e validação', () {
    test('reconhece JPEG, PNG, WebP e HEIC pelo conteúdo', () {
      expect(FormatoImagem.detectar(_jpeg), FormatoImagem.jpeg);
      expect(FormatoImagem.detectar(_png), FormatoImagem.png);
      expect(FormatoImagem.detectar(_webp), FormatoImagem.webp);
      expect(FormatoImagem.detectar(_heic), FormatoImagem.heic);
    });

    test('recusa outros formatos, arquivo vazio e acima do limite', () {
      expect(validarImagem(_gif), ProblemaImagem.formatoNaoSuportado);
      expect(validarImagem(_pdf), ProblemaImagem.formatoNaoSuportado);
      expect(validarImagem(Uint8List(0)), ProblemaImagem.vazia);
      final grande = Uint8List(LimitesGaleria.tamanhoMaximoBytes + 1)
        ..setAll(0, [0xFF, 0xD8, 0xFF]);
      expect(validarImagem(grande), ProblemaImagem.muitoGrande);
      expect(validarImagem(_jpeg), isNull);
    });

    test('legenda: sem espaços nas pontas, vazia vira nula', () {
      expect(normalizarLegenda('  Na praia '), 'Na praia');
      expect(normalizarLegenda('   '), isNull);
      expect(normalizarLegenda(null), isNull);
    });
  });

  group('URLs derivadas do Cloudinary', () {
    test('miniatura e ampliada inserem a transformação', () {
      expect(
          miniaturaCloudinary(_original),
          contains(
              '/image/upload/c_fill,w_360,h_360,q_auto,f_auto/v1730000000/'));
      expect(ampliadaCloudinary(_original),
          contains('/image/upload/c_limit,w_1600,h_1600,q_auto,f_auto/v'));
    });

    test('não transforma URL de fora do padrão do app', () {
      for (final url in [
        'https://evil.example.com/image/upload/v1/x.jpg',
        'http://res.cloudinary.com/c/image/upload/v1/x.jpg',
        'https://res.cloudinary.com/c/image/upload/c_fill,w_10/v1/x.jpg',
        'https://res.cloudinary.com/c/raw/upload/v1/x.pdf',
        'https://res.cloudinary.com/c/image/upload/v1/x.jpg?a=1',
      ]) {
        expect(miniaturaCloudinary(url), isNull, reason: url);
      }
    });

    test('a foto usa a versão derivada, ou a original como último recurso', () {
      const foto = FotoPet(
          id: 'f', petId: 'p', userId: 'u', url: _original, publicId: 'x');
      expect(foto.miniaturaUrl, isNot(_original));
      const externa = FotoPet(
          id: 'f',
          petId: 'p',
          userId: 'u',
          url: 'https://fake.storage/x.jpg',
          publicId: 'x');
      expect(externa.miniaturaUrl, 'https://fake.storage/x.jpg');
    });
  });

  group('EnvioDeFotos', () {
    List<ItemDeEnvio> itens(int n) =>
        [for (var i = 0; i < n; i++) ItemDeEnvio(bytes: _jpeg)];

    test('publica todas, com a legenda de cada uma', () async {
      final repo = _GaleriaRoteirizada();
      final lista = itens(3)..[1].legenda = ' Dormindo ';
      final envio = EnvioDeFotos(
          itens: lista, repositorio: repo, pet: _pet(), userId: 'uid-1');

      await envio.enviar();

      expect(envio.concluido, isTrue);
      expect(envio.publicadas, hasLength(3));
      expect(envio.publicadas[1].legenda, 'Dormindo');
    });

    test('sucesso parcial: tentar de novo só reenvia as que falharam',
        () async {
      final repo = _GaleriaRoteirizada(falharEm: {1});
      final envio = EnvioDeFotos(
          itens: itens(3), repositorio: repo, pet: _pet(), userId: 'uid-1');

      await envio.enviar();
      expect(envio.totalPublicadas, 2);
      expect(envio.totalComFalha, 1);
      expect(envio.itens[1].estado, EstadoItemEnvio.falhou);
      expect(envio.concluido, isFalse);

      repo.falharEm = {};
      await envio.enviar();
      expect(repo.chamadas, hasLength(4)); // 3 + só a que falhou
      expect(envio.concluido, isTrue);
    });

    test('segundo toque durante o envio não duplica', () async {
      final repo = _GaleriaRoteirizada()..liberar = Completer<void>();
      final envio = EnvioDeFotos(
          itens: itens(2), repositorio: repo, pet: _pet(), userId: 'uid-1');

      final primeiro = envio.enviar();
      final segundo = envio.enviar();
      repo.liberar!.complete();
      await Future.wait([primeiro, segundo]);

      expect(repo.chamadas, hasLength(2));
      expect(envio.totalPublicadas, 2);
    });

    test('cancelar interrompe a atual e não começa as seguintes', () async {
      final repo = _GaleriaRoteirizada()..liberar = Completer<void>();
      final envio = EnvioDeFotos(
          itens: itens(3), repositorio: repo, pet: _pet(), userId: 'uid-1');

      final enviando = envio.enviar();
      await Future<void>.delayed(Duration.zero);
      envio.cancelar();
      await enviando;

      expect(repo.chamadas, hasLength(1));
      expect(envio.itens.map((i) => i.estado),
          everyElement(EstadoItemEnvio.cancelada));
      expect(envio.publicadas, isEmpty);

      // Depois de cancelar, dá para mandar de novo.
      repo.liberar = null;
      await envio.enviar();
      expect(envio.concluido, isTrue);
    });
  });

  group('envio ao Cloudinary', () {
    test('vai ao endpoint de imagem, com o progresso e o resultado', () async {
      late http.BaseRequest recebido;
      var corpoLido = 0;
      final cliente = MockClient.streaming((request, corpo) async {
        recebido = request;
        await corpo.forEach((pedaco) => corpoLido += pedaco.length);
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({
            'secure_url': _original,
            'public_id': 'users/u1/abc',
            'width': 2048,
            'height': 1536,
          }))),
          200,
        );
      });
      final progresso = <double>[];

      final enviada = await enviarImagemAoCloudinary(
        cliente: cliente,
        cloudName: 'demo',
        campos: {'upload_preset': 'preset'},
        nomeArquivo: 'f1.jpg',
        bytes: _jpeg,
        aoProgredir: progresso.add,
      );

      expect(recebido.url.path, '/v1_1/demo/image/upload');
      expect(corpoLido, greaterThan(_jpeg.length));
      expect(progresso, isNotEmpty);
      expect(progresso.last, 1);
      expect(enviada.publicId, 'users/u1/abc');
      expect(enviada.largura, 2048);
      expect(enviada.url, _original);
    });

    test('erro do Cloudinary vira exceção', () async {
      final cliente = MockClient(
          (_) async => http.Response('{"error":"Invalid image"}', 400));
      await expectLater(
        enviarImagemAoCloudinary(
          cliente: cliente,
          cloudName: 'demo',
          campos: const {},
          nomeArquivo: 'f.jpg',
          bytes: _pdf,
        ),
        throwsException,
      );
    });
  });

  group('GaleriaController', () {
    test('páginas sem repetir; pedidos simultâneos viram um só', () async {
      final repo = FakeGaleriaRepository()..semear('pet-1', 65);
      final controller = GaleriaController(repo, 'pet-1');
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.fotos, hasLength(30));
      expect(controller.state.temMais, isTrue);

      await Future.wait([controller.carregarMais(), controller.carregarMais()]);
      expect(controller.state.fotos, hasLength(60));
      await controller.carregarMais();
      expect(controller.state.fotos, hasLength(65));
      expect(controller.state.temMais, isFalse);
      expect(controller.state.fotos.map((f) => f.id).toSet(), hasLength(65));
      expect(repo.listagens, hasLength(3));
      controller.dispose();
    });

    test('inserir põe as novas no topo; excluir com falha mantém a foto',
        () async {
      final repo = FakeGaleriaRepository()..semear('pet-1', 2);
      final controller = GaleriaController(repo, 'pet-1');
      await Future<void>.delayed(Duration.zero);

      const nova = FotoPet(
          id: 'nova',
          petId: 'pet-1',
          userId: 'uid-1',
          url: _original,
          publicId: 'x');
      controller.inserir([nova]);
      controller.inserir([nova]);
      expect(controller.state.fotos.first.id, 'nova');
      expect(controller.state.fotos, hasLength(3));

      repo.falharExclusao = true;
      await expectLater(controller.excluir(controller.state.fotos.last),
          throwsA(isA<FalhaAoExcluirFoto>()));
      expect(controller.state.fotos, hasLength(3));
      controller.dispose();
    });
  });
}
