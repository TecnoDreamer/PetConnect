import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../usuario/presentation/providers/auth_providers.dart';
import '../../domain/cartaz_desaparecido.dart';
import '../../domain/pet.dart';
import '../providers/cartaz_providers.dart';
import '../providers/pet_providers.dart';
import '../widgets/cartaz_fotos.dart';
import '../widgets/cartaz_procura_se.dart';
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
  late final _local =
      TextEditingController(text: _inicial.vistoPorUltimo.local);
  late final _observacoes = TextEditingController(text: _inicial.observacoes);
  late final _recompensaValor =
      TextEditingController(text: _textoDoValor(_inicial.recompensa.centavos));
  late final _recompensaTexto =
      TextEditingController(text: _inicial.recompensa.texto);

  static String _textoDoValor(int? centavos) =>
      centavos == null ? '' : formatarValorEmReais(centavos);

  CartazController get _controller =>
      ref.read(cartazControllerProvider(widget.pet.id).notifier);

  List<TextEditingController> get _campos => [
        _caracteristicas,
        _local,
        _observacoes,
        _recompensaValor,
        _recompensaTexto,
      ];

  @override
  void dispose() {
    for (final c in _campos) {
      c.dispose();
    }
    super.dispose();
  }

  /// Ao escolher uma foto, abre o ajuste logo em seguida: é a hora de
  /// conferir se o rosto do pet não ficou cortado.
  Future<void> _escolherFoto(int indice) async {
    final rascunho = ref.read(cartazControllerProvider(widget.pet.id));
    final emUso = {
      for (var i = 0; i < rascunho.espacos.length; i++)
        if (i != indice && rascunho.espacos[i].foto != null)
          rascunho.espacos[i].foto!,
    };
    final foto =
        await escolherFotoDoCartaz(context, pet: widget.pet, emUso: emUso);
    if (foto == null || !mounted) return;
    _controller.atualizar((r) => r.comEspaco(indice, EspacoDeFoto(foto: foto)));
    await _enquadrar(indice);
  }

  Future<void> _enquadrar(int indice) async {
    final rascunho = ref.read(cartazControllerProvider(widget.pet.id));
    final espaco = rascunho.espacos[indice];
    final foto = espaco.foto;
    if (foto == null) return;
    final novo = await Navigator.of(context).push<EnquadramentoFoto>(
      MaterialPageRoute(
        builder: (_) => EnquadramentoScreen(
          foto: foto,
          inicial: espaco.enquadramento,
          indice: indice,
          cartaz: ConteudoCartaz.de(
              pet: widget.pet, rascunho: rascunho, telefone: null),
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
              leading: const Icon(Icons.crop),
              title: const Text('Ajustar foto'),
              subtitle: const Text('Ponto de foco, zoom ou foto inteira'),
              onTap: () => Navigator.pop(context, 'enquadrar'),
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Trocar foto'),
              onTap: () => Navigator.pop(context, 'trocar'),
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

  void _mudarVisto(VistoPorUltimo Function(VistoPorUltimo atual) mudanca) =>
      _controller.atualizar(
          (r) => r.copyWith(vistoPorUltimo: mudanca(r.vistoPorUltimo)));

  void _mudarRecompensa(Recompensa Function(Recompensa atual) mudanca) =>
      _controller
          .atualizar((r) => r.copyWith(recompensa: mudanca(r.recompensa)));

  Future<void> _escolherData(DateTime? atual) async {
    final hoje = DateUtils.dateOnly(DateTime.now());
    final primeiro =
        hoje.subtract(const Duration(days: LimitesCartaz.diasDoCalendario));
    var inicial = atual ?? hoje;
    if (inicial.isAfter(hoje)) inicial = hoje;
    if (inicial.isBefore(primeiro)) inicial = primeiro;
    final escolhida = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: primeiro,
      lastDate: hoje,
      helpText: 'Visto por último em',
      builder: _emPortugues,
    );
    if (escolhida != null) _mudarVisto((v) => v.comData(escolhida));
  }

  Future<void> _escolherHorario(int? atual) async {
    final agora = TimeOfDay.now();
    final escolhido = await showTimePicker(
      context: context,
      initialTime: atual == null
          ? agora
          : TimeOfDay(hour: atual ~/ 60, minute: atual % 60),
      helpText: 'Horário em que foi visto',
      builder: _emPortugues,
    );
    if (escolhido != null) {
      _mudarVisto((v) => v.comHorario(escolhido.hour * 60 + escolhido.minute));
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
    for (final c in _campos) {
      c.clear();
    }
    _caracteristicas.text = sugerirCaracteristicas(widget.pet);
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
                    'menores. Em cada uma, escolha o ponto de foco ou mostre '
                    'a foto inteira. Elas não mudam a foto do perfil.',
              ),
              const SizedBox(height: 12),
              _EspacosDeFoto(
                rascunho: rascunho,
                aoTocar: _opcoesDoEspaco,
                aoAjustar: _enquadrar,
              ),
              const SizedBox(height: 24),
              const _Secao(
                titulo: 'Informações',
                ajuda: 'O nome vem do cadastro, e o título do cartaz (gato, '
                    'cachorro ou pet), da espécie. Campos opcionais vazios '
                    'não aparecem no cartaz.',
              ),
              const SizedBox(height: 12),
              _Campo(
                controller: _caracteristicas,
                rotulo: 'Características',
                dica: 'Ex.: pelo preto, mancha branca na orelha, coleira azul',
                limite: LimitesCartaz.caracteristicas,
                linhas: 3,
                aoMudar: (v) => _controller
                    .atualizar((r) => r.copyWith(caracteristicas: v)),
              ),
              _Campo(
                controller: _observacoes,
                rotulo: 'Observações (opcional)',
                ajuda: 'Aparecem em destaque no cartaz.',
                dica: 'Ex.: é medroso, não corra atrás dele; atende pelo nome',
                limite: LimitesCartaz.observacoes,
                linhas: 4,
                aoMudar: (v) =>
                    _controller.atualizar((r) => r.copyWith(observacoes: v)),
              ),
              const SizedBox(height: 12),
              const _Secao(
                titulo: 'Visto por último (opcional)',
                ajuda: 'Quando e onde o pet foi visto pela última vez.',
              ),
              const SizedBox(height: 8),
              _VistoPorUltimoCampos(
                visto: rascunho.vistoPorUltimo,
                local: _local,
                aoEscolherData: () =>
                    _escolherData(rascunho.vistoPorUltimo.data),
                aoTirarData: () => _mudarVisto((v) => v.comData(null)),
                aoEscolherPeriodo: (p) => _mudarVisto((v) => v.comPeriodo(p)),
                aoEscolherHorario: () =>
                    _escolherHorario(rascunho.vistoPorUltimo.horario),
                aoTirarHorario: () => _mudarVisto((v) => v.comHorario(null)),
                aoMudarLocal: (t) => _mudarVisto((v) => v.comLocal(t)),
              ),
              const SizedBox(height: 24),
              const _Secao(
                titulo: 'Recompensa (opcional)',
                ajuda: 'Deixe em branco se não houver.',
              ),
              const SizedBox(height: 12),
              _RecompensaCampos(
                recompensa: rascunho.recompensa,
                valor: _recompensaValor,
                texto: _recompensaTexto,
                aoEscolherTipo: (t) => _mudarRecompensa((r) => r.comTipo(t)),
                aoMudarValor: (c) => _mudarRecompensa((r) => r.comCentavos(c)),
                aoMudarTexto: (t) => _mudarRecompensa((r) => r.comTexto(t)),
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

/// O app não define o idioma do Material (os outros calendários seguem em
/// inglês); o calendário e o relógio do cartaz são mostrados em português.
Widget _emPortugues(BuildContext context, Widget? filho) =>
    Localizations.override(
      context: context,
      locale: const Locale('pt', 'BR'),
      delegates: GlobalMaterialLocalizations.delegates,
      child: filho,
    );

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
  const _EspacosDeFoto({
    required this.rascunho,
    required this.aoTocar,
    required this.aoAjustar,
  });

  final RascunhoCartaz rascunho;
  final ValueChanged<int> aoTocar;
  final ValueChanged<int> aoAjustar;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < LimitesCartaz.fotos; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _EspacoNoEditor(
              key: ValueKey('cartaz-espaco-$i'),
              indice: i,
              espaco: rascunho.espacos[i],
              aoTocar: () => aoTocar(i),
              aoAjustar: () => aoAjustar(i),
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
    required this.indice,
    required this.espaco,
    required this.aoTocar,
    required this.aoAjustar,
  });

  final int indice;
  final EspacoDeFoto espaco;
  final VoidCallback aoTocar;
  final VoidCallback aoAjustar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rotulo = nomesDosEspacos[indice];
    final lado = (140 * MediaQuery.devicePixelRatioOf(context)).round();
    final atual = espaco.foto;
    return Column(
      children: [
        Semantics(
          button: true,
          label: atual == null
              ? '$rotulo: vazia. Toque para escolher.'
              : '$rotulo: escolhida. Toque para ajustar, trocar ou mover.',
          excludeSemantics: true,
          child: AspectRatio(
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
                    // Com o mesmo foco do cartaz (num quadrado, então o
                    // recorte é aproximado).
                    : FotoEnquadrada(
                        imagem: miniaturaDoCartaz(atual, lado),
                        enquadramento: espaco.enquadramento,
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(rotulo,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textMuted, fontSize: 13)),
        if (atual != null)
          TextButton(
            key: ValueKey('cartaz-ajustar-$indice'),
            onPressed: aoAjustar,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text('Ajustar',
                semanticsLabel: 'Ajustar $rotulo',
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
      ],
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
    this.ajuda,
    this.linhas = 1,
  });

  final TextEditingController controller;
  final String rotulo;
  final String dica;
  final String? ajuda;
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
        decoration: InputDecoration(
            labelText: rotulo, hintText: dica, helperText: ajuda),
        onChanged: aoMudar,
      ),
    );
  }
}

/// Data (no calendário), período do dia ou horário exato, e o local, num
/// campo só do cartaz.
class _VistoPorUltimoCampos extends StatelessWidget {
  const _VistoPorUltimoCampos({
    required this.visto,
    required this.local,
    required this.aoEscolherData,
    required this.aoTirarData,
    required this.aoEscolherPeriodo,
    required this.aoEscolherHorario,
    required this.aoTirarHorario,
    required this.aoMudarLocal,
  });

  final VistoPorUltimo visto;
  final TextEditingController local;
  final VoidCallback aoEscolherData;
  final VoidCallback aoTirarData;
  final ValueChanged<PeriodoDoDia?> aoEscolherPeriodo;
  final VoidCallback aoEscolherHorario;
  final VoidCallback aoTirarHorario;
  final ValueChanged<String> aoMudarLocal;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final data = visto.data;
    final horario = visto.horario;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('cartaz-visto-data'),
                onPressed: aoEscolherData,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(data == null
                    ? 'Escolher a data'
                    : 'Dia ${formatarDataDoCartaz(data)}'),
              ),
            ),
            if (data != null)
              IconButton(
                tooltip: 'Tirar a data',
                onPressed: aoTirarData,
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Período ou horário',
            style: TextStyle(color: colors.textMuted, fontSize: 13)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final periodo in PeriodoDoDia.values)
              ChoiceChip(
                label: Text(periodo.rotulo),
                selected: visto.periodo == periodo,
                onSelected: (sim) => aoEscolherPeriodo(sim ? periodo : null),
              ),
            ChoiceChip(
              key: const ValueKey('cartaz-visto-horario'),
              avatar: const Icon(Icons.schedule, size: 18),
              label: Text(horario == null
                  ? 'Horário exato'
                  : 'Às ${formatarHorarioDoCartaz(horario)}'),
              selected: horario != null,
              onSelected: (sim) => sim || horario == null
                  ? aoEscolherHorario()
                  : aoTirarHorario(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: local,
          maxLength: LimitesCartaz.localVisto,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Onde',
            hintText: 'Bairro ou ponto de referência aproximado',
          ),
          onChanged: aoMudarLocal,
        ),
        if (visto.texto.isNotEmpty)
          Text(
            'No cartaz: ${visto.texto}',
            key: const ValueKey('cartaz-visto-resumo'),
            style: TextStyle(color: colors.textMuted),
          ),
      ],
    );
  }
}

class _RecompensaCampos extends StatelessWidget {
  const _RecompensaCampos({
    required this.recompensa,
    required this.valor,
    required this.texto,
    required this.aoEscolherTipo,
    required this.aoMudarValor,
    required this.aoMudarTexto,
  });

  final Recompensa recompensa;
  final TextEditingController valor;
  final TextEditingController texto;
  final ValueChanged<TipoRecompensa> aoEscolherTipo;
  final ValueChanged<int?> aoMudarValor;
  final ValueChanged<String> aoMudarTexto;

  @override
  Widget build(BuildContext context) {
    final emDinheiro = recompensa.tipo == TipoRecompensa.dinheiro;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<TipoRecompensa>(
          segments: const [
            ButtonSegment(
              value: TipoRecompensa.dinheiro,
              icon: Icon(Icons.payments_outlined),
              label: Text('Em dinheiro'),
            ),
            ButtonSegment(
              value: TipoRecompensa.outra,
              icon: Icon(Icons.card_giftcard_outlined),
              label: Text('Outra'),
            ),
          ],
          selected: {recompensa.tipo},
          onSelectionChanged: (escolha) => aoEscolherTipo(escolha.first),
        ),
        const SizedBox(height: 12),
        if (emDinheiro)
          TextField(
            key: const ValueKey('cartaz-recompensa-valor'),
            controller: valor,
            keyboardType: TextInputType.number,
            inputFormatters: [MascaraDeReais()],
            decoration: const InputDecoration(
              labelText: 'Valor',
              prefixText: 'R\$ ',
              hintText: '0,00',
            ),
            onChanged: (t) => aoMudarValor(MascaraDeReais.centavos(t)),
          )
        else
          TextField(
            key: const ValueKey('cartaz-recompensa-texto'),
            controller: texto,
            maxLength: LimitesCartaz.recompensaTexto,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Recompensa',
              hintText: 'Ex.: um vale-presente',
            ),
            onChanged: aoMudarTexto,
          ),
      ],
    );
  }
}

/// Máscara de valor em reais: só números, que entram pela direita, com
/// ponto no milhar e vírgula nos centavos (digitar 2, 0, 0, 0, 0 mostra
/// `200,00`). O "R$" fica fora do texto, como prefixo do campo.
class MascaraDeReais extends TextInputFormatter {
  static int? centavos(String texto) {
    final digitos = texto.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitos.isEmpty) return null;
    final valor = int.parse(digitos);
    return valor == 0 ? null : valor;
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digitos = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final maximo = LimitesCartaz.recompensaEmCentavos.toString().length;
    if (digitos.length > maximo) digitos = digitos.substring(0, maximo);
    final valor = centavos(digitos);
    final formatado = valor == null ? '' : formatarValorEmReais(valor);
    return TextEditingValue(
      text: formatado,
      selection: TextSelection.collapsed(offset: formatado.length),
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
