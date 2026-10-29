import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/cloudinary_url.dart';
import '../../domain/cartaz_desaparecido.dart';

/// Imagem de uma foto do cartaz. Decodificada com no máximo
/// [CartazProcuraSe.ladoMaximoDaFoto] px de largura: nítida no PNG em 2×,
/// sem manter três fotos enormes na memória.
ImageProvider imagemDoCartaz(FotoDoCartaz foto) {
  final ImageProvider original = switch (foto) {
    FotoDaGaleria() => CachedNetworkImageProvider(foto.ampliadaUrl),
    FotoDoPerfil(:final url) =>
      CachedNetworkImageProvider(ampliadaCloudinary(url) ?? url),
    FotoDoAparelho(:final bytes) => MemoryImage(bytes),
  };
  return ResizeImage(original,
      width: CartazProcuraSe.ladoMaximoDaFoto, policy: ResizeImagePolicy.fit);
}

/// Cartaz "Procura-se" (docs/features/cartaz-pet-desaparecido.md), na
/// composição do modelo minimalista: cabeçalho preto com "PROCURA-SE",
/// faixa inclinada com o nome, três fotos (uma grande à esquerda, duas
/// empilhadas à direita), os dados do pet e o rodapé com o contato.
///
/// Sempre do mesmo tamanho lógico ([largura] × [altura], proporção do
/// modelo, próxima do A4), com cores próprias, independentes do tema e do
/// tamanho de fonte do sistema. A prévia mostra este widget reduzido e a
/// exportação captura o mesmo widget, então os dois nunca divergem.
class CartazProcuraSe extends StatelessWidget {
  const CartazProcuraSe({
    super.key,
    required this.conteudo,
    this.imagem = imagemDoCartaz,
  });

  final ConteudoCartaz conteudo;

  /// Trocável nos testes, que usam imagens em memória.
  final ImageProvider Function(FotoDoCartaz foto) imagem;

  static const largura = 1055.0;
  static const altura = 1491.0;
  static const ladoMaximoDaFoto = 1400;

  /// Altura mínima do mosaico de fotos. Os dados do pet usam o resto e, se
  /// passarem disso, encolhem (no máximo o que os limites de texto
  /// permitem, ver [LimitesCartaz]) em vez de serem cortados.
  static const alturaMinimaDasFotos = 340.0;

  static const preto = Color(0xFF111111);
  static const cinza = Color(0xFFEDEDED);
  static const _margem = 40.0;

  @override
  Widget build(BuildContext context) {
    final midia = MediaQuery.maybeOf(context) ?? const MediaQueryData();
    return MediaQuery(
      data: midia.copyWith(textScaler: TextScaler.noScaling),
      child: DefaultTextStyle(
        style: TextStyle(
          // A fonte do app (Roboto), com fallback do sistema para acentos
          // e emojis.
          fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
          color: preto,
          fontSize: 30,
          height: 1.15,
          decoration: TextDecoration.none,
          fontWeight: FontWeight.w500,
        ),
        child: SizedBox(
          width: largura,
          height: altura,
          child: ColoredBox(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(_margem, 24, _margem, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Cabecalho(nome: conteudo.nome),
                  const SizedBox(height: 12),
                  _Titulo(texto: conteudo.titulo.texto),
                  const SizedBox(height: 14),
                  Expanded(
                    child: LayoutBuilder(builder: (context, restricoes) {
                      final maximoDosDados =
                          restricoes.maxHeight - alturaMinimaDasFotos - 20;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _Mosaico(
                                espacos: conteudo.espacos, imagem: imagem),
                          ),
                          if (conteudo.campos.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            ConstrainedBox(
                              constraints:
                                  BoxConstraints(maxHeight: maximoDosDados),
                              child: FittedBox(
                                key: const ValueKey('cartaz-dados'),
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.topLeft,
                                child: SizedBox(
                                  width: restricoes.maxWidth,
                                  child: _Dados(campos: conteudo.campos),
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  _Rodape(telefone: conteudo.telefone),
                  const SizedBox(height: 8),
                  const Text(
                    'Cartaz gerado no app PetConnect',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 20, color: Color(0xFF777777)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.nome});

  final String nome;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 350,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 36,
            right: 36,
            top: 0,
            height: 350,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: CartazProcuraSe.preto,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(40, 14, 40, 0),
                  child: SizedBox(
                    height: 170,
                    child: FittedBox(
                      child: Text(
                        'PROCURA-SE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 170,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -2,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Faixa levemente inclinada, como no modelo. O nome encolhe para
          // caber numa linha, nunca é cortado.
          Positioned(
            left: 0,
            right: 0,
            top: 190,
            height: 136,
            child: Transform.rotate(
              angle: -0.03,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: CartazProcuraSe.preto, width: 7),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 36, vertical: 8),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        nome,
                        key: const ValueKey('cartaz-nome'),
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 112,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FittedBox(
        child: Text(
          texto,
          key: const ValueKey('cartaz-titulo'),
          style: const TextStyle(
            fontSize: 46,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _Mosaico extends StatelessWidget {
  const _Mosaico({required this.espacos, required this.imagem});

  final List<EspacoDeFoto> espacos;
  final ImageProvider Function(FotoDoCartaz foto) imagem;

  @override
  Widget build(BuildContext context) {
    Widget espaco(int i) => _EspacoDaFoto(
          key: ValueKey('cartaz-foto-$i'),
          indice: i,
          espaco: espacos[i],
          imagem: imagem,
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 62, child: espaco(0)),
        const SizedBox(width: 18),
        Expanded(
          flex: 38,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: espaco(1)),
              const SizedBox(height: 18),
              Expanded(child: espaco(2)),
            ],
          ),
        ),
      ],
    );
  }
}

class _EspacoDaFoto extends StatelessWidget {
  const _EspacoDaFoto({
    super.key,
    required this.indice,
    required this.espaco,
    required this.imagem,
  });

  final int indice;
  final EspacoDeFoto espaco;
  final ImageProvider Function(FotoDoCartaz foto) imagem;

  @override
  Widget build(BuildContext context) {
    final foto = espaco.foto;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: foto == null
          ? _EspacoVazio(rotulo: nomesDosEspacos[indice].toUpperCase())
          : FotoEnquadrada(
              imagem: imagem(foto),
              enquadramento: espaco.enquadramento,
            ),
    );
  }
}

/// Uma foto preenchendo o espaço, com o enquadramento escolhido. Também
/// usada no editor de enquadramento, para o tutor ver o mesmo recorte.
class FotoEnquadrada extends StatelessWidget {
  const FotoEnquadrada({
    super.key,
    required this.imagem,
    required this.enquadramento,
  });

  final ImageProvider imagem;
  final EnquadramentoFoto enquadramento;

  @override
  Widget build(BuildContext context) {
    final ancora = Alignment(enquadramento.x, enquadramento.y);
    return ClipRect(
      child: Transform.scale(
        scale: enquadramento.zoom,
        alignment: ancora,
        child: Image(
          image: imagem,
          fit: BoxFit.cover,
          alignment: ancora,
          width: double.infinity,
          height: double.infinity,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          errorBuilder: (context, _, __) => const ColoredBox(
            color: CartazProcuraSe.cinza,
            child: Center(
              child: Icon(Icons.broken_image_outlined,
                  size: 72, color: Color(0xFF777777)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Só aparece na prévia de um rascunho incompleto: a exportação exige as
/// três fotos.
class _EspacoVazio extends StatelessWidget {
  const _EspacoVazio({required this.rotulo});

  final String rotulo;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CartazProcuraSe.cinza,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF9E9E9E), width: 3),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.photo_camera_outlined,
                    size: 96, color: Color(0xFF555555)),
                const SizedBox(height: 8),
                Text(rotulo,
                    style: const TextStyle(
                        fontSize: 32, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dados extends StatelessWidget {
  const _Dados({required this.campos});

  final List<CampoDoCartaz> campos;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < campos.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 280,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${campos[i].rotulo}:',
                    style: const TextStyle(
                        fontSize: 32, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: CartazProcuraSe.cinza,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    child: Text(campos[i].valor),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Rodape extends StatelessWidget {
  const _Rodape({required this.telefone});

  final String? telefone;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      padding: const EdgeInsets.fromLTRB(36, 18, 18, 18),
      decoration: BoxDecoration(
        color: CartazProcuraSe.preto,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: Text(
              'CONTATO:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 60,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      telefone ?? '',
                      key: const ValueKey('cartaz-telefone'),
                      style: const TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
