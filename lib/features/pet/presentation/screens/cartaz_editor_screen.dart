import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../usuario/presentation/providers/auth_providers.dart';
import '../../domain/cartaz_desaparecido.dart';
import '../../domain/pet.dart';
import '../providers/cartaz_providers.dart';
import '../providers/pet_providers.dart';
import '../widgets/cartaz_fotos.dart';
import '../widgets/pet_avatar.dart';

/// Editor do cartaz de pet desaparecido
/// (docs/features/cartaz-pet-desaparecido.md). Só para pet ativo do tutor
/// (a rota usa PetSituacaoGuard). Montar o cartaz não muda nada no pet nem
/// publica nada: o rascunho fica só neste aparelho.
class CartazEditorScreen extends ConsumerWidget {
  const CartazEditorScreen({super.key, required this.petId});

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final petAsync = ref.watch(petProvider(petId));
    final usuario = ref.watch(currentUsuarioProvider).valueOrNull;

    return petAsync.when(
      loading: () => Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(),
        body: Center(
          child: Text('Não foi possível carregar este pet.',
              style: TextStyle(color: colors.error)),
        ),
      ),
      data: (pet) {
        if (pet == null || usuario == null || pet.userId != usuario.id) {
          return Scaffold(
            backgroundColor: colors.background,
            appBar: AppBar(),
            body: Center(
              child: Text('Pet não encontrado.',
                  style: TextStyle(color: colors.textMuted)),
            ),
          );
        }
        return _Editor(pet: pet, telefoneDoTutor: usuario.telefone);
      },
    );
  }
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({required this.pet, required this.telefoneDoTutor});

  final Pet pet;
  final String telefoneDoTutor;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  late final RascunhoCartaz _inicial =
      ref.read(cartazControllerProvider(widget.pet.id));

  late final _caracteristicas = TextEditingController(
      text: _inicial.caracteristicas ?? sugerirCaracteristicas(widget.pet));
  late final _vistoPorUltimoEm =
      TextEditingController(text: _inicial.vistoPorUltimoEm);
  late final _desapareceuEm =
      TextEditingController(text: _inicial.desapareceuEm);
  late final _observacoes = TextEditingController(text: _inicial.observacoes);
  late final _recompensa = TextEditingController(text: _inicial.recompensa);

  CartazController get _controller =>
      ref.read(cartazControllerProvider(widget.pet.id).notifier);

  @override
  void dispose() {
    for (final c in [
      _caracteristicas,
      _vistoPorUltimoEm,
      _desapareceuEm,
      _observacoes,
      _recompensa,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _escolherFoto(int indice) async {
    final rascunho = ref.read(cartazControllerProvider(widget.pet.id));
    final emUso = {
      for (var i = 0; i < rascunho.espacos.length; i++)
        if (i != indice && rascunho.espacos[i].foto != null)
          rascunho.espacos[i].foto!,
    };
    final foto =
        await escolherFotoDoCartaz(context, pet: widget.pet, emUso: emUso);
    if (foto == null) return;
    _controller.atualizar((r) => r.comEspaco(indice, EspacoDeFoto(foto: foto)));
  }

  Future<void> _enquadrar(int indice) async {
    final espaco =
        ref.read(cartazControllerProvider(widget.pet.id)).espacos[indice];
    final foto = espaco.foto;
    if (foto == null) return;
    final novo = await Navigator.of(context).push<EnquadramentoFoto>(
      MaterialPageRoute(
        builder: (_) => EnquadramentoScreen(
          foto: foto,
          inicial: espaco.enquadramento,
          principal: indice == 0,
        ),
      ),
    );
    if (novo == null) return;
    _controller.atualizar((r) =>
        r.comEspaco(indice, EspacoDeFoto(foto: foto, enquadramento: novo)));
  }

  Future<void> _opcoesDoEspaco(int indice) async {
    final rascunho = ref.read(cartazControllerProvider(widget.pet.id));
    if (rascunho.espacos[indice].foto == null) return _escolherFoto(indice);
    final acao = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Trocar foto'),
              onTap: () => Navigator.pop(context, 'trocar'),
            ),
            ListTile(
              leading: const Icon(Icons.crop),
              title: const Text('Ajustar enquadramento'),
              onTap: () => Navigator.pop(context, 'enquadrar'),
            ),
            for (var destino = 0; destino < LimitesCartaz.fotos; destino++)
              if (destino != indice)
                ListTile(
                  leading: const Icon(Icons.open_with),
                  title: Text('Mover para ${nomesDosEspacos[destino]}'),
                  onTap: () => Navigator.pop(context, 'mover$destino'),
                ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remover do cartaz'),
              onTap: () => Navigator.pop(context, 'remover'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || acao == null) return;
    switch (acao) {
      case 'trocar':
        await _escolherFoto(indice);
      case 'enquadrar':
        await _enquadrar(indice);
      case 'remover':
        _controller.atualizar((r) => r.comEspaco(indice, EspacoDeFoto.vazio));
      default:
        final destino = int.parse(acao.substring('mover'.length));
        _controller.atualizar((r) => r.trocarEspacos(indice, destino));
    }
  }

  Future<void> _descartar() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descartar rascunho?'),
        content: const Text('As fotos escolhidas e os textos deste cartaz '
            'serão apagados deste celular. O cadastro do pet não muda.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Descartar')),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;
    await _controller.descartar();
    _caracteristicas.text = sugerirCaracteristicas(widget.pet);
    for (final c in [
      _vistoPorUltimoEm,
      _desapareceuEm,
      _observacoes,
      _recompensa,
    ]) {
      c.clear();
    }
  }

  /// Fotos do celular não ficam no rascunho salvo; avisa antes de sair.
  Future<void> _aoTentarSair() async {
    final sair = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair do cartaz?'),
        content: const Text('Os textos e as fotos da galeria ficam salvos '
            'neste celular, mas as fotos escolhidas do celular, não: você '
            'vai precisar escolhê-las de novo.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Continuar editando')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sair')),
        ],
      ),
    );
    if (sair == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pet = widget.pet;
    final rascunho = ref.watch(cartazControllerProvider(pet.id));
    final contatos =
        contatosDisponiveis(telefoneDoTutor: widget.telefoneDoTutor, pet: pet);
    final origem = origemEscolhida(rascunho: rascunho, contatos: contatos);
    final telefone = contatos[origem];

    return PopScope(
      canPop: !rascunho.temFotoDoAparelho,
      onPopInvokedWithResult: (saiu, _) {
        if (!saiu) _aoTentarSair();
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          title: const Text('Pet desaparecido'),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'Mais opções',
              onSelected: (_) => _descartar(),
              itemBuilder: (_) => const [
                PopupMenuItem(
                    value: 'descartar', child: Text('Descartar rascunho')),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _Explicacao(nome: pet.nome),
              const SizedBox(height: 16),
              _PetConfirmado(pet: pet),
              const SizedBox(height: 24),
              const _Secao(
                titulo: 'Fotos',
                ajuda: 'O cartaz usa 3 fotos coloridas: uma grande e duas '
                    'menores. Elas não mudam a foto do perfil.',
              ),
              const SizedBox(height: 12),
              _EspacosDeFoto(
                rascunho: rascunho,
                aoTocar: _opcoesDoEspaco,
              ),
              const SizedBox(height: 24),
              const _Secao(
                titulo: 'Informações',
                ajuda: 'Nome, espécie, raça e cor vêm do cadastro do pet. '
                    'Campos opcionais vazios não aparecem no cartaz.',
              ),
              const SizedBox(height: 12),
              _Campo(
                controller: _caracteristicas,
                rotulo: 'Características',
                dica: 'Ex.: mancha branca na orelha, coleira azul',
                limite: LimitesCartaz.caracteristicas,
                linhas: 3,
                aoMudar: (v) => _controller
                    .atualizar((r) => r.copyWith(caracteristicas: v)),
              ),
              _Campo(
                controller: _vistoPorUltimoEm,
                rotulo: 'Visto por último em (opcional)',
                dica: 'Bairro ou ponto de referência aproximado',
                limite: LimitesCartaz.vistoPorUltimoEm,
                aoMudar: (v) => _controller
                    .atualizar((r) => r.copyWith(vistoPorUltimoEm: v)),
              ),
              _Campo(
                controller: _desapareceuEm,
                rotulo: 'Desapareceu em (opcional)',
                dica: 'Ex.: 20/10, à noite',
                limite: LimitesCartaz.desapareceuEm,
                aoMudar: (v) =>
                    _controller.atualizar((r) => r.copyWith(desapareceuEm: v)),
              ),
              _Campo(
                controller: _observacoes,
                rotulo: 'Observações (opcional)',
                dica: 'Ex.: é medroso, não corra atrás dele',
                limite: LimitesCartaz.observacoes,
                linhas: 3,
                aoMudar: (v) =>
                    _controller.atualizar((r) => r.copyWith(observacoes: v)),
              ),
              _Campo(
                controller: _recompensa,
                rotulo: 'Recompensa (opcional)',
                dica: 'Deixe em branco se não houver',
                limite: LimitesCartaz.recompensa,
                aoMudar: (v) =>
                    _controller.atualizar((r) => r.copyWith(recompensa: v)),
              ),
              const SizedBox(height: 12),
              const _Secao(
                titulo: 'Contato',
                ajuda: 'O telefone vem do seu cadastro. Ele só aparece no '
                    'cartaz se você autorizar.',
              ),
              const SizedBox(height: 8),
              _Contato(
                contatos: contatos,
                origem: origem,
                autorizado:
                    telefone != null && rascunho.telefoneAutorizado == telefone,
                aoEscolher: (o) =>
                    _controller.atualizar((r) => r.copyWith(contato: o)),
                aoAutorizar: (sim) => _controller.atualizar(
                    (r) => r.autorizarTelefone(sim ? telefone : null)),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.push('/pet/${pet.id}/cartaz/previa'),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Ver cartaz'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Explicacao extends StatelessWidget {
  const _Explicacao({required this.nome});

  final String nome;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'Monte um cartaz "Procura-se" para divulgar o desaparecimento de '
        '$nome. Ele é gerado no seu celular: nada é publicado no app, e o '
        'cadastro do pet não muda. Depois de compartilhado ou impresso, o '
        'cartaz pode continuar circulando, mesmo que você apague o rascunho.',
        style: TextStyle(color: colors.textPrimary),
      ),
    );
  }
}

class _PetConfirmado extends StatelessWidget {
  const _PetConfirmado({required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final detalhes = [pet.especie, pet.raca]
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join(' · ');
    return Row(
      children: [
        PetAvatar(fotoUrl: pet.foto, radius: 28, nomeDoPet: pet.nome),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pet.nome,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              if (detalhes.isNotEmpty)
                Text(detalhes, style: TextStyle(color: colors.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Secao extends StatelessWidget {
  const _Secao({required this.titulo, required this.ajuda});

  final String titulo;
  final String ajuda;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(ajuda, style: TextStyle(color: context.colors.textMuted)),
      ],
    );
  }
}

class _EspacosDeFoto extends StatelessWidget {
  const _EspacosDeFoto({required this.rascunho, required this.aoTocar});

  final RascunhoCartaz rascunho;
  final ValueChanged<int> aoTocar;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < LimitesCartaz.fotos; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _EspacoNoEditor(
              key: ValueKey('cartaz-espaco-$i'),
              rotulo: nomesDosEspacos[i],
              foto: rascunho.espacos[i].foto,
              aoTocar: () => aoTocar(i),
            ),
          ),
        ],
      ],
    );
  }
}

class _EspacoNoEditor extends StatelessWidget {
  const _EspacoNoEditor({
    super.key,
    required this.rotulo,
    required this.foto,
    required this.aoTocar,
  });

  final String rotulo;
  final FotoDoCartaz? foto;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lado = (140 * MediaQuery.devicePixelRatioOf(context)).round();
    final atual = foto;
    return Semantics(
      button: true,
      label: atual == null
          ? '$rotulo: vazia. Toque para escolher.'
          : '$rotulo: escolhida. Toque para trocar, enquadrar ou mover.',
      excludeSemantics: true,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Material(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: aoTocar,
                child: atual == null
                    ? Icon(Icons.add_a_photo_outlined,
                        color: colors.textMuted, size: 32)
                    : Image(
                        image: miniaturaDoCartaz(atual, lado),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                            Icons.broken_image_outlined,
                            color: colors.textMuted),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(rotulo,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}

class _Campo extends StatelessWidget {
  const _Campo({
    required this.controller,
    required this.rotulo,
    required this.dica,
    required this.limite,
    required this.aoMudar,
    this.linhas = 1,
  });

  final TextEditingController controller;
  final String rotulo;
  final String dica;
  final int limite;
  final int linhas;
  final ValueChanged<String> aoMudar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLength: limite,
        minLines: linhas == 1 ? 1 : 2,
        maxLines: linhas,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: rotulo, hintText: dica),
        onChanged: aoMudar,
      ),
    );
  }
}

class _Contato extends StatelessWidget {
  const _Contato({
    required this.contatos,
    required this.origem,
    required this.autorizado,
    required this.aoEscolher,
    required this.aoAutorizar,
  });

  final Map<OrigemDoContato, String> contatos;
  final OrigemDoContato? origem;
  final bool autorizado;
  final ValueChanged<OrigemDoContato> aoEscolher;
  final ValueChanged<bool> aoAutorizar;

  static const _nomes = {
    OrigemDoContato.tutor: 'Seu telefone',
    OrigemDoContato.pet: 'Contato do QR code do pet',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (contatos.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seu cadastro não tem um telefone válido, com DDD. Sem ele, o '
            'cartaz não pode ser gerado.',
            key: const ValueKey('cartaz-sem-telefone'),
            style: TextStyle(color: colors.error),
          ),
          TextButton(
            onPressed: () => context.push('/configuracoes/editar-perfil'),
            child: const Text('Cadastrar telefone em Editar perfil'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RadioGroup<OrigemDoContato>(
          groupValue: origem,
          onChanged: (o) {
            if (o != null) aoEscolher(o);
          },
          child: Column(
            children: [
              for (final MapEntry(key: o, value: digitos) in contatos.entries)
                RadioListTile<OrigemDoContato>(
                  value: o,
                  contentPadding: EdgeInsets.zero,
                  title: Text(formatarTelefoneDoCartaz(digitos)),
                  subtitle: Text(_nomes[o]!),
                ),
            ],
          ),
        ),
        CheckboxListTile(
          key: const ValueKey('cartaz-consentimento'),
          value: autorizado,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: (v) => aoAutorizar(v ?? false),
          title: const Text('Autorizo mostrar este telefone no cartaz'),
          subtitle: const Text('Qualquer pessoa que receber ou vir o cartaz '
              'vai ver o número. E-mail e endereço nunca aparecem.'),
        ),
      ],
    );
  }
}
