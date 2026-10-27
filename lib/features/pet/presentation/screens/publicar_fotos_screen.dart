import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/upload_error.dart';
import '../../../usuario/presentation/providers/auth_providers.dart';
import '../../domain/envio_de_fotos.dart';
import '../../domain/foto_pet.dart';
import '../../domain/pet.dart';
import '../providers/galeria_providers.dart';

/// Abre o seletor de fotos do sistema e, se o tutor escolher alguma, a tela
/// de prévia. Usa o seletor do sistema, que não pede permissão de acesso a
/// todas as fotos do aparelho.
///
/// O seletor já redimensiona para [LimitesGaleria.dimensaoMaxima] e
/// recomprime, gerando uma cópia: o arquivo original no aparelho não muda.
Future<void> adicionarFotosAoPet(BuildContext context, Pet pet) async {
  final List<XFile> escolhidas;
  try {
    escolhidas = await ImagePicker().pickMultiImage(
      maxWidth: LimitesGaleria.dimensaoMaxima,
      maxHeight: LimitesGaleria.dimensaoMaxima,
      imageQuality: LimitesGaleria.qualidade,
      limit: LimitesGaleria.fotosPorEnvio,
    );
  } catch (_) {
    if (context.mounted) {
      _avisar(context, 'Não foi possível abrir suas fotos.');
    }
    return;
  }
  if (escolhidas.isEmpty || !context.mounted) return;

  final itens = <ItemDeEnvio>[];
  final recusadas = <String>{};
  for (final arquivo in escolhidas.take(LimitesGaleria.fotosPorEnvio)) {
    final bytes = await arquivo.readAsBytes();
    final problema = validarImagem(bytes);
    if (problema == null) {
      itens.add(ItemDeEnvio(bytes: bytes));
    } else {
      recusadas.add(descreverProblemaImagem(problema));
    }
  }
  if (!context.mounted) return;

  if (recusadas.isNotEmpty) {
    final quantas = escolhidas.length - itens.length;
    _avisar(
      context,
      '${quantas == 1 ? '1 foto ficou' : '$quantas fotos ficaram'} de fora. '
      '${recusadas.join(' ')}',
    );
  }
  if (itens.isEmpty) return;

  await Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => PublicarFotosScreen(pet: pet, itens: itens),
  ));
}

void _avisar(BuildContext context, String mensagem) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem)));
}

/// Prévia das fotos escolhidas, com legenda opcional, e o envio com o
/// progresso de cada uma. Fotos publicadas entram na galeria na hora; as
/// que falharem ficam aqui para tentar de novo.
class PublicarFotosScreen extends ConsumerStatefulWidget {
  const PublicarFotosScreen(
      {super.key, required this.pet, required this.itens});

  final Pet pet;
  final List<ItemDeEnvio> itens;

  @override
  ConsumerState<PublicarFotosScreen> createState() =>
      _PublicarFotosScreenState();
}

class _PublicarFotosScreenState extends ConsumerState<PublicarFotosScreen> {
  late final List<ItemDeEnvio> _itens = [...widget.itens];
  EnvioDeFotos? _envio;
  bool _jaEnviou = false;

  bool get _enviando => _envio?.enviando ?? false;

  Future<void> _publicar() async {
    final uid = ref.read(currentUsuarioProvider).valueOrNull?.id;
    if (uid == null || _enviando || _itens.isEmpty) return;

    final envio = _envio ??= EnvioDeFotos(
      itens: _itens,
      repositorio: ref.read(galeriaRepositoryProvider),
      pet: widget.pet,
      userId: uid,
      aoMudar: () {
        if (mounted) setState(() {});
      },
    );
    _jaEnviou = true;
    // Lido antes do envio: a tela pode ser fechada no meio dele.
    final galeria = ref.read(galeriaControllerProvider(widget.pet.id).notifier);
    final mensageiro = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);

    await envio.enviar();
    if (galeria.mounted) galeria.inserir(envio.publicadas);
    if (!mounted) return;

    if (envio.concluido) {
      final total = envio.totalPublicadas;
      mensageiro.showSnackBar(SnackBar(
        content: Text(total == 1
            ? 'Foto publicada na galeria de ${widget.pet.nome}.'
            : '$total fotos publicadas na galeria de ${widget.pet.nome}.'),
      ));
      navegador.pop();
    }
  }

  void _remover(ItemDeEnvio item) {
    setState(() => _itens.remove(item));
    // Sem nada para enviar (ou só as já publicadas), não há o que fazer aqui.
    if (_itens.every((i) => !i.pendente)) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pendentes = _itens.where((i) => i.pendente).length;
    final publicadas =
        _itens.where((i) => i.estado == EstadoItemEnvio.publicada).length;

    return PopScope(
      canPop: !_enviando,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _avisar(context, 'Cancele o envio antes de sair.');
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          title: Text(_itens.length == 1 ? 'Publicar foto' : 'Publicar fotos'),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: _itens.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, indice) => _ItemPrevia(
                    key: ObjectKey(_itens[indice]),
                    item: _itens[indice],
                    numero: indice + 1,
                    nomeDoPet: widget.pet.nome,
                    editavel: !_enviando &&
                        _itens[indice].estado != EstadoItemEnvio.publicada,
                    aoRemover: () => _remover(_itens[indice]),
                  ),
                ),
              ),
              _Rodape(
                enviando: _enviando,
                pendentes: pendentes,
                publicadas: publicadas,
                jaEnviou: _jaEnviou,
                aoPublicar: _publicar,
                aoCancelar: () => _envio?.cancelar(),
                aoConcluir: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemPrevia extends StatelessWidget {
  const _ItemPrevia({
    super.key,
    required this.item,
    required this.numero,
    required this.nomeDoPet,
    required this.editavel,
    required this.aoRemover,
  });

  final ItemDeEnvio item;
  final int numero;
  final String nomeDoPet;
  final bool editavel;
  final VoidCallback aoRemover;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                image: true,
                label: 'Prévia da foto $numero',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    item.bytes,
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                    cacheWidth: 300,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => SizedBox(
                      width: 96,
                      height: 96,
                      child: Icon(Icons.image_not_supported_outlined,
                          color: colors.textMuted),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: item.legenda,
                  enabled: editavel,
                  maxLength: LimitesGaleria.tamanhoMaximoLegenda,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Legenda (opcional)',
                    hintText: 'Um momento com $nomeDoPet',
                  ),
                  onChanged: (texto) => item.legenda = texto,
                ),
              ),
              if (editavel)
                IconButton(
                  tooltip: 'Tirar a foto $numero do envio',
                  icon: Icon(Icons.close, color: colors.textMuted),
                  onPressed: aoRemover,
                ),
            ],
          ),
          _EstadoDoItem(item: item),
        ],
      ),
    );
  }
}

class _EstadoDoItem extends StatelessWidget {
  const _EstadoDoItem({required this.item});

  final ItemDeEnvio item;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (String? texto, Color cor) = switch (item.estado) {
      EstadoItemEnvio.aguardando => (null, colors.textMuted),
      EstadoItemEnvio.enviando => (
          'Enviando… ${(item.progresso * 100).round()}%',
          colors.textMuted
        ),
      EstadoItemEnvio.publicada => ('Publicada', colors.success),
      EstadoItemEnvio.falhou => (
          describirErroUpload(item.erro ?? '', item: 'esta foto'),
          colors.error
        ),
      EstadoItemEnvio.cancelada => ('Envio cancelado', colors.textMuted),
    };
    if (texto == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (item.estado == EstadoItemEnvio.enviando) ...[
              LinearProgressIndicator(value: item.progresso),
              const SizedBox(height: 4),
            ],
            Text(texto, style: TextStyle(color: cor, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _Rodape extends StatelessWidget {
  const _Rodape({
    required this.enviando,
    required this.pendentes,
    required this.publicadas,
    required this.jaEnviou,
    required this.aoPublicar,
    required this.aoCancelar,
    required this.aoConcluir,
  });

  final bool enviando;
  final int pendentes;
  final int publicadas;
  final bool jaEnviou;
  final VoidCallback aoPublicar;
  final VoidCallback aoCancelar;
  final VoidCallback aoConcluir;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final List<Widget> botoes;
    if (enviando) {
      botoes = [
        OutlinedButton(
            onPressed: aoCancelar, child: const Text('Cancelar envio')),
      ];
    } else if (jaEnviou && pendentes > 0) {
      botoes = [
        Text(
          publicadas == 0
              ? 'Nenhuma foto foi publicada.'
              : '$publicadas publicada${publicadas == 1 ? '' : 's'}, '
                  '$pendentes não.',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textMuted),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: aoPublicar,
          child: Text(pendentes == 1
              ? 'Tentar de novo'
              : 'Tentar de novo as $pendentes'),
        ),
        TextButton(onPressed: aoConcluir, child: const Text('Concluir')),
      ];
    } else {
      botoes = [
        FilledButton(
          onPressed: pendentes == 0 ? null : aoPublicar,
          child:
              Text(pendentes == 1 ? 'Publicar' : 'Publicar $pendentes fotos'),
        ),
      ];
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: botoes,
      ),
    );
  }
}
