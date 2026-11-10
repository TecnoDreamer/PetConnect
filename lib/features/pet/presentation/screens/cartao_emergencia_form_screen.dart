import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../usuario/presentation/providers/auth_providers.dart';
import '../../domain/cartao_emergencia.dart';
import '../../domain/telefone_de_contato.dart';
import '../providers/cartao_emergencia_providers.dart';

/// Edição do Cartão de Emergência (issue #41, RF-41-03/04/08).
///
/// Nenhum campo médico é obrigatório: dá para salvar com tudo em "Não
/// informado". O app não sugere dose, tipo sanguíneo nem tratamento.
class CartaoEmergenciaFormScreen extends ConsumerWidget {
  const CartaoEmergenciaFormScreen({
    super.key,
    required this.petId,
    this.inicial,
  });

  final String petId;

  /// Cartão como a tela de leitura mostrou. Nulo num link direto: aí o
  /// formulário espera a leitura do banco.
  final CartaoEmergencia? inicial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (inicial != null) {
      return _Formulario(petId: petId, inicial: inicial!);
    }
    final leitura = ref.watch(cartaoEmergenciaProvider(petId));
    final colors = context.colors;
    Widget mensagem(String texto) => Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(title: const Text('Editar cartão')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(texto,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.textMuted)),
            ),
          ),
        );
    return leitura.when(
      loading: () => Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(title: const Text('Editar cartão')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) =>
          mensagem('Não foi possível carregar o cartão para editar.'),
      data: (l) => l.doCacheLocal && !l.existe
          ? mensagem('Sem conexão, e o cartão ainda não foi baixado neste '
              'aparelho. Conecte-se para editar.')
          : _Formulario(petId: petId, inicial: l.cartao),
    );
  }
}

class _Formulario extends ConsumerStatefulWidget {
  const _Formulario({required this.petId, required this.inicial});

  final String petId;
  final CartaoEmergencia inicial;

  @override
  ConsumerState<_Formulario> createState() => _FormularioState();
}

class _AlergiaCampos {
  _AlergiaCampos(this.id,
      {String substancia = '', String reacao = '', String observacao = ''})
      : substancia = TextEditingController(text: substancia),
        reacao = TextEditingController(text: reacao),
        observacao = TextEditingController(text: observacao);

  final String id;
  final TextEditingController substancia;
  final TextEditingController reacao;
  final TextEditingController observacao;

  List<TextEditingController> get todos => [substancia, reacao, observacao];
}

class _MedicamentoCampos {
  _MedicamentoCampos(this.id,
      {String nome = '',
      String dose = '',
      String frequencia = '',
      String via = '',
      String observacao = ''})
      : nome = TextEditingController(text: nome),
        dose = TextEditingController(text: dose),
        frequencia = TextEditingController(text: frequencia),
        via = TextEditingController(text: via),
        observacao = TextEditingController(text: observacao);

  final String id;
  final TextEditingController nome;
  final TextEditingController dose;
  final TextEditingController frequencia;
  final TextEditingController via;
  final TextEditingController observacao;

  List<TextEditingController> get todos =>
      [nome, dose, frequencia, via, observacao];
}

class _FormularioState extends ConsumerState<_Formulario> {
  final _formKey = GlobalKey<FormState>();
  int _proximoId = 0;

  late SituacaoDaLista _situacaoAlergias = widget.inicial.situacaoAlergias;
  late SituacaoDaLista _situacaoMedicamentos =
      widget.inicial.situacaoMedicamentos;
  late SituacaoDaLista _situacaoCondicoes = widget.inicial.situacaoCondicoes;

  late final List<_AlergiaCampos> _alergias = [
    for (final a in widget.inicial.alergias)
      _AlergiaCampos(_id(a.id),
          substancia: a.substancia, reacao: a.reacao, observacao: a.observacao),
  ];
  late final List<_MedicamentoCampos> _medicamentos = [
    for (final m in widget.inicial.medicamentos)
      _MedicamentoCampos(_id(m.id),
          nome: m.nome,
          dose: m.dose,
          frequencia: m.frequencia,
          via: m.via,
          observacao: m.observacao),
  ];
  late final List<TextEditingController> _condicoes = [
    for (final c in widget.inicial.condicoes) TextEditingController(text: c),
  ];
  late final _tipoSanguineo =
      TextEditingController(text: widget.inicial.tipoSanguineo);
  late bool _tipoConfirmado = widget.inicial.tipoSanguineoConfirmado;
  late final _observacoes =
      TextEditingController(text: widget.inicial.observacoes);
  late final _vetNome =
      TextEditingController(text: widget.inicial.veterinario.nome);
  late final _vetClinica =
      TextEditingController(text: widget.inicial.veterinario.clinica);
  late final _vetTelefone = TextEditingController(
    text: widget.inicial.veterinario.telefone.isEmpty
        ? ''
        : formatarTelefone(widget.inicial.veterinario.telefone),
  );
  late bool _mostrarContato = widget.inicial.mostrarContatoDoTutor;

  late final String _assinaturaInicial = _assinatura(_montar());
  bool _salvando = false;
  bool _salvo = false;
  String? _erro;

  String _id(String existente) => existente.isNotEmpty
      ? existente
      : '${DateTime.now().microsecondsSinceEpoch}-${_proximoId++}';

  @override
  void initState() {
    super.initState();
    // Calcula a assinatura com os valores iniciais, antes de qualquer edição.
    _assinaturaInicial;
  }

  @override
  void dispose() {
    for (final a in _alergias) {
      for (final c in a.todos) {
        c.dispose();
      }
    }
    for (final m in _medicamentos) {
      for (final c in m.todos) {
        c.dispose();
      }
    }
    for (final c in [
      ..._condicoes,
      _tipoSanguineo,
      _observacoes,
      _vetNome,
      _vetClinica,
      _vetTelefone,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// O cartão como está no formulário agora, já limpo e cortado nos
  /// limites. O que está oculto (lista em "Não informado") não entra.
  CartaoEmergencia _montar() {
    String limpo(TextEditingController c, int max, {bool multi = false}) =>
        limparTexto(c.text, max, multilinha: multi);
    final telefone = telefoneE164(_vetTelefone.text);
    final tipo = limpo(_tipoSanguineo, LimitesDoCartao.tipoSanguineo);
    return CartaoEmergencia(
      situacaoAlergias: _situacaoAlergias,
      alergias: [
        for (final a in _alergias)
          Alergia(
            id: a.id,
            substancia: limpo(a.substancia, LimitesDoCartao.nomeCurto),
            reacao: limpo(a.reacao, LimitesDoCartao.textoCurto),
            observacao: limpo(a.observacao, LimitesDoCartao.textoMedio),
          ),
      ],
      situacaoMedicamentos: _situacaoMedicamentos,
      medicamentos: [
        for (final m in _medicamentos)
          Medicamento(
            id: m.id,
            nome: limpo(m.nome, LimitesDoCartao.nomeCurto),
            dose: limpo(m.dose, LimitesDoCartao.textoCurto),
            frequencia: limpo(m.frequencia, LimitesDoCartao.textoCurto),
            via: limpo(m.via, LimitesDoCartao.nomeCurto),
            observacao: limpo(m.observacao, LimitesDoCartao.textoMedio),
          ),
      ],
      situacaoCondicoes: _situacaoCondicoes,
      condicoes: [
        for (final c in _condicoes) limpo(c, LimitesDoCartao.textoMedio),
      ],
      tipoSanguineo: tipo,
      tipoSanguineoConfirmado: _tipoConfirmado && tipo.isNotEmpty,
      observacoes:
          limpo(_observacoes, LimitesDoCartao.observacoes, multi: true),
      veterinario: VeterinarioDeConfianca(
        nome: limpo(_vetNome, LimitesDoCartao.nomeCurto),
        clinica: limpo(_vetClinica, LimitesDoCartao.nomeCurto),
        telefone: telefone ?? '',
      ),
      mostrarContatoDoTutor: _mostrarContato,
      revisao: widget.inicial.revisao,
    );
  }

  static String _assinatura(CartaoEmergencia c) => jsonEncode(c.toMap());

  bool get _alterado => _assinatura(_montar()) != _assinaturaInicial;

  Future<void> _salvar() async {
    if (_salvando) return;
    setState(() => _erro = null);
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _erro = 'Confira os campos destacados.');
      return;
    }
    setState(() => _salvando = true);
    var conflito = false;
    try {
      await ref.read(cartaoEmergenciaRepositoryProvider).salvar(
            widget.petId,
            _montar(),
            revisaoEsperada: widget.inicial.revisao,
          );
      if (!mounted) return;
      _salvo = true;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Cartão salvo.')));
      Navigator.of(context).pop();
    } on CartaoAlteradoEmOutroLugar {
      conflito = true;
    } on FalhaDoCartao catch (falha) {
      if (mounted) {
        setState(() => _erro = switch (falha) {
              CartaoSemConexao() => 'Sem conexão. Nada foi salvo; suas '
                  'alterações continuam aqui. Tente de novo quando a '
                  'internet voltar.',
              CartaoSemPermissao() => 'Não foi possível salvar: você não '
                  'tem permissão para alterar este cartão.',
              _ => 'Não foi possível salvar o cartão. Tente novamente.',
            });
      }
    } catch (_) {
      if (mounted) {
        setState(
            () => _erro = 'Não foi possível salvar o cartão. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
    // Depois de liberar o botão: o aviso não fica sobre um "salvando".
    if (conflito && mounted) await _avisarConflito();
  }

  Future<void> _avisarConflito() async {
    final descartar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('O cartão mudou'),
        content: const Text('O cartão foi salvo em outro lugar depois que '
            'você abriu esta tela. Para não apagar essa versão, nada foi '
            'salvo agora.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Continuar editando')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ver a versão atual')),
        ],
      ),
    );
    if (descartar == true && mounted) {
      _salvo = true; // sai sem perguntar de novo
      Navigator.of(context).pop();
    } else if (mounted) {
      setState(() => _erro = 'Nada foi salvo: o cartão mudou em outro lugar. '
          'Copie o que precisar e abra o cartão de novo.');
    }
  }

  Future<void> _aoTentarSair() async {
    final sair = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descartar alterações?'),
        content: const Text('O que você mudou neste cartão ainda não foi '
            'salvo.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Continuar editando')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Descartar')),
        ],
      ),
    );
    if (sair == true && mounted) {
      _salvo = true;
      Navigator.of(context).pop();
    }
  }

  Future<bool> _confirmarRemocao(String oQue) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remover $oQue?'),
        content: const Text('O item sai do formulário. O cartão só muda '
            'quando você salvar.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remover')),
        ],
      ),
    );
    return ok == true;
  }

  String? _obrigatorio(String? valor, String mensagem) =>
      (valor == null || valor.trim().isEmpty) ? mensagem : null;

  String? _listaVazia(SituacaoDaLista situacao, int itens) =>
      situacao == SituacaoDaLista.informada && itens == 0
          ? 'Adicione pelo menos um item ou escolha outra opção.'
          : null;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final telefoneDoPerfil = telefoneE164(
        ref.watch(currentUsuarioProvider).valueOrNull?.telefone ?? '');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (saiu, _) {
        if (saiu) return;
        if (_salvo || !_alterado) {
          _salvo = true;
          Navigator.of(context).pop();
        } else {
          _aoTentarSair();
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(title: const Text('Editar cartão')),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text(
                  'Preencha só o que você sabe. O que ficar em branco aparece '
                  'como "Não informado". Nada daqui vai para a página do QR '
                  'Code.',
                  style: TextStyle(color: colors.textMuted, fontSize: 14),
                ),
                const SizedBox(height: 20),
                const _Titulo('Alergias conhecidas'),
                _EscolhaDaSituacao(
                  rotulo: 'Alergias',
                  valor: _situacaoAlergias,
                  nenhuma: 'Nenhuma conhecida',
                  informar: 'Informar alergias',
                  aoMudar: (v) => setState(() => _situacaoAlergias = v),
                ),
                if (_situacaoAlergias == SituacaoDaLista.informada) ...[
                  for (final (i, a) in _alergias.indexed)
                    _Bloco(
                      key: ValueKey('alergia-${a.id}'),
                      titulo: 'Alergia ${i + 1}',
                      aoRemover: () async {
                        if (await _confirmarRemocao('esta alergia')) {
                          setState(() => _alergias.remove(a));
                        }
                      },
                      campos: [
                        _Campo(
                          controller: a.substancia,
                          rotulo: 'Substância ou alimento',
                          maximo: LimitesDoCartao.nomeCurto,
                          validator: (v) => _obrigatorio(
                              v, 'Informe a substância ou remova o item.'),
                        ),
                        _Campo(
                            controller: a.reacao,
                            rotulo: 'Reação (opcional)',
                            maximo: LimitesDoCartao.textoCurto),
                        _Campo(
                            controller: a.observacao,
                            rotulo: 'Observação (opcional)',
                            maximo: LimitesDoCartao.textoMedio),
                      ],
                    ),
                  _ErroDaLista(
                      lista: 'alergias',
                      mensagem:
                          _listaVazia(_situacaoAlergias, _alergias.length)),
                  if (_alergias.length < LimitesDoCartao.itensPorLista)
                    _Adicionar(
                      rotulo: 'Adicionar alergia',
                      aoTocar: () => setState(
                          () => _alergias.add(_AlergiaCampos(_id('')))),
                    ),
                ],
                const SizedBox(height: 24),
                const _Titulo('Medicamentos em uso'),
                _EscolhaDaSituacao(
                  rotulo: 'Medicamentos',
                  valor: _situacaoMedicamentos,
                  nenhuma: 'Nenhum em uso',
                  informar: 'Informar medicamentos',
                  aoMudar: (v) => setState(() => _situacaoMedicamentos = v),
                ),
                if (_situacaoMedicamentos == SituacaoDaLista.informada) ...[
                  for (final (i, m) in _medicamentos.indexed)
                    _Bloco(
                      key: ValueKey('medicamento-${m.id}'),
                      titulo: 'Medicamento ${i + 1}',
                      aoRemover: () async {
                        if (await _confirmarRemocao('este medicamento')) {
                          setState(() => _medicamentos.remove(m));
                        }
                      },
                      campos: [
                        _Campo(
                          controller: m.nome,
                          rotulo: 'Nome do medicamento',
                          maximo: LimitesDoCartao.nomeCurto,
                          validator: (v) => _obrigatorio(
                              v, 'Informe o nome ou remova o item.'),
                        ),
                        _Campo(
                            controller: m.dose,
                            rotulo: 'Dose, com a unidade (opcional)',
                            dica: 'Como está na receita. Ex.: 5 mg',
                            maximo: LimitesDoCartao.textoCurto),
                        _Campo(
                            controller: m.frequencia,
                            rotulo: 'Frequência ou horário (opcional)',
                            maximo: LimitesDoCartao.textoCurto),
                        _Campo(
                            controller: m.via,
                            rotulo: 'Via, ex.: oral (opcional)',
                            maximo: LimitesDoCartao.nomeCurto),
                        _Campo(
                            controller: m.observacao,
                            rotulo: 'Observação (opcional)',
                            maximo: LimitesDoCartao.textoMedio),
                      ],
                    ),
                  _ErroDaLista(
                      lista: 'medicamentos',
                      mensagem: _listaVazia(
                          _situacaoMedicamentos, _medicamentos.length)),
                  if (_medicamentos.length < LimitesDoCartao.itensPorLista)
                    _Adicionar(
                      rotulo: 'Adicionar medicamento',
                      aoTocar: () => setState(
                          () => _medicamentos.add(_MedicamentoCampos(_id('')))),
                    ),
                ],
                const SizedBox(height: 24),
                const _Titulo('Condições clínicas relevantes'),
                _EscolhaDaSituacao(
                  rotulo: 'Condições clínicas',
                  valor: _situacaoCondicoes,
                  nenhuma: 'Nenhuma conhecida',
                  informar: 'Informar condições',
                  aoMudar: (v) => setState(() => _situacaoCondicoes = v),
                ),
                if (_situacaoCondicoes == SituacaoDaLista.informada) ...[
                  for (final (i, c) in _condicoes.indexed)
                    _Bloco(
                      key: ObjectKey(c),
                      titulo: 'Condição ${i + 1}',
                      aoRemover: () async {
                        if (await _confirmarRemocao('esta condição')) {
                          setState(() => _condicoes.remove(c));
                        }
                      },
                      campos: [
                        _Campo(
                          controller: c,
                          rotulo: 'Condição, ex.: diabetes, cardiopatia',
                          maximo: LimitesDoCartao.textoMedio,
                          validator: (v) => _obrigatorio(
                              v, 'Descreva a condição ou remova o item.'),
                        ),
                      ],
                    ),
                  _ErroDaLista(
                      lista: 'condicoes',
                      mensagem:
                          _listaVazia(_situacaoCondicoes, _condicoes.length)),
                  if (_condicoes.length < LimitesDoCartao.itensPorLista)
                    _Adicionar(
                      rotulo: 'Adicionar condição',
                      aoTocar: () => setState(
                          () => _condicoes.add(TextEditingController())),
                    ),
                ],
                const SizedBox(height: 24),
                const _Titulo('Tipo sanguíneo'),
                _Campo(
                  controller: _tipoSanguineo,
                  rotulo: 'Tipo sanguíneo (opcional)',
                  dica: 'Exatamente como está no exame',
                  maximo: LimitesDoCartao.tipoSanguineo,
                  validator: (v) =>
                      (v ?? '').trim().isNotEmpty && !_tipoConfirmado
                          ? 'Marque a confirmação abaixo ou deixe em branco.'
                          : null,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _tipoConfirmado,
                  onChanged: (v) =>
                      setState(() => _tipoConfirmado = v ?? false),
                  title: const Text(
                      'Veio de um exame ou do veterinário (não é um palpite)'),
                ),
                const SizedBox(height: 16),
                const _Titulo('Observações de emergência'),
                _Campo(
                  controller: _observacoes,
                  rotulo: 'Observações (opcional)',
                  dica: 'Ex.: morde quando sente dor; usar focinheira',
                  maximo: LimitesDoCartao.observacoes,
                  multilinha: true,
                  contador: true,
                ),
                const SizedBox(height: 24),
                const _Titulo('Veterinário de confiança'),
                _Campo(
                    controller: _vetNome,
                    rotulo: 'Nome (opcional)',
                    maximo: LimitesDoCartao.nomeCurto),
                _Campo(
                    controller: _vetClinica,
                    rotulo: 'Clínica (opcional)',
                    maximo: LimitesDoCartao.nomeCurto),
                _Campo(
                  controller: _vetTelefone,
                  rotulo: 'Telefone (opcional)',
                  dica: 'Com DDD',
                  maximo: 20,
                  teclado: TextInputType.phone,
                  validator: (v) => (v ?? '').trim().isNotEmpty &&
                          telefoneE164(v!) == null
                      ? 'Telefone inválido. Use o DDD, ex.: (19) 99999-0000.'
                      : null,
                ),
                const SizedBox(height: 16),
                const _Titulo('Seu contato'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _mostrarContato,
                  onChanged: (v) => setState(() => _mostrarContato = v),
                  title: const Text('Mostrar meu telefone no cartão'),
                  subtitle: Text(telefoneDoPerfil == null
                      ? 'Seu perfil ainda não tem telefone.'
                      : 'Do seu perfil: ${formatarTelefone(telefoneDoPerfil)}'),
                ),
                if (_erro != null) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(_erro!,
                        style: TextStyle(color: colors.error, fontSize: 14)),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _salvando ? null : _salvar,
                  child: _salvando
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.textOnBrand,
                          ),
                        )
                      : const Text('SALVAR'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      header: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          texto,
          style: TextStyle(
            color: context.colors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
      ),
    );
  }
}

class _EscolhaDaSituacao extends StatelessWidget {
  const _EscolhaDaSituacao({
    required this.rotulo,
    required this.valor,
    required this.nenhuma,
    required this.informar,
    required this.aoMudar,
  });

  final String rotulo;
  final SituacaoDaLista valor;
  final String nenhuma;
  final String informar;
  final ValueChanged<SituacaoDaLista> aoMudar;

  @override
  Widget build(BuildContext context) {
    final opcoes = {
      SituacaoDaLista.naoInformado: 'Não informado',
      SituacaoDaLista.nenhumaDeclarada: nenhuma,
      SituacaoDaLista.informada: informar,
    };
    return RadioGroup<SituacaoDaLista>(
      groupValue: valor,
      onChanged: (v) {
        if (v != null) aoMudar(v);
      },
      child: Semantics(
        label: rotulo,
        child: Column(
          children: [
            for (final MapEntry(key: situacao, value: texto) in opcoes.entries)
              RadioListTile<SituacaoDaLista>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: situacao,
                title: Text(texto),
              ),
          ],
        ),
      ),
    );
  }
}

class _Bloco extends StatelessWidget {
  const _Bloco({
    super.key,
    required this.titulo,
    required this.campos,
    required this.aoRemover,
  });

  final String titulo;
  final List<Widget> campos;
  final VoidCallback aoRemover;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(titulo,
                    style: TextStyle(
                        color: colors.textMuted, fontWeight: FontWeight.w600)),
              ),
              IconButton(
                tooltip: 'Remover ${titulo.toLowerCase()}',
                icon: Icon(Icons.delete_outline, color: colors.textMuted),
                onPressed: aoRemover,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(children: campos),
          ),
        ],
      ),
    );
  }
}

class _Campo extends StatelessWidget {
  const _Campo({
    required this.controller,
    required this.rotulo,
    required this.maximo,
    this.dica,
    this.validator,
    this.multilinha = false,
    this.contador = false,
    this.teclado,
  });

  final TextEditingController controller;
  final String rotulo;
  final int maximo;
  final String? dica;
  final FormFieldValidator<String>? validator;
  final bool multilinha;
  final bool contador;
  final TextInputType? teclado;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        minLines: multilinha ? 3 : 1,
        maxLines: multilinha ? 8 : 1,
        keyboardType: teclado ?? (multilinha ? TextInputType.multiline : null),
        textCapitalization: TextCapitalization.sentences,
        maxLength: contador ? maximo : null,
        inputFormatters: [LengthLimitingTextInputFormatter(maximo)],
        decoration: InputDecoration(labelText: rotulo, helperText: dica),
        validator: validator,
      ),
    );
  }
}

/// Erro de uma lista em "Informar" sem nenhum item. A chave muda com a
/// mensagem, então o erro some assim que o tutor adiciona um item.
class _ErroDaLista extends FormField<void> {
  _ErroDaLista({required String lista, required String? mensagem})
      : super(
          key: ValueKey(('erro-da-lista', lista, mensagem)),
          validator: (_) => mensagem,
          builder: (state) => state.hasError
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    state.errorText!,
                    style: TextStyle(
                        color: Theme.of(state.context).colorScheme.error),
                  ),
                )
              : const SizedBox.shrink(),
        );
}

class _Adicionar extends StatelessWidget {
  const _Adicionar({required this.rotulo, required this.aoTocar});

  final String rotulo;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        icon: const Icon(Icons.add),
        label: Text(rotulo),
        onPressed: aoTocar,
      ),
    );
  }
}
