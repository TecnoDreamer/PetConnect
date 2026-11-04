import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Composição das telas de autenticação (Login e Cadastro): cabeçalho
/// marrom atrás, painel na frente invadindo [sobreposicao] pixels da base
/// do cabeçalho e, opcionalmente, um [rodape] logo abaixo do painel.
///
/// O painel e o rodapé são medidos primeiro, na altura natural; a parte
/// [fracaoDaSobraParaCabecalho] da altura que sobra na tela vai para o
/// cabeçalho e o restante fica abaixo de tudo. O rodapé acompanha o painel,
/// a [espacoAntesDoRodape] dele, em vez de ficar ancorado na base da tela.
/// Sem `SingleChildScrollView` nem `Transform` no estado normal (ver
/// docs/features/cadastro-layout-estatico.md,
/// docs/features/login-layout-distribuido.md e
/// docs/features/login-espacamento-acoes-sociais.md).
///
/// Rolagem só existe como exceção documentada: enquanto o teclado está
/// aberto (para o campo focado continuar visível, com o cabeçalho na mesma
/// altura) ou quando o conteúdo não cabe nem com o cabeçalho no mínimo
/// (aparelho muito baixo e/ou fonte do sistema muito ampliada).
class ComposicaoCabecalhoPainel extends StatefulWidget {
  const ComposicaoCabecalhoPainel({
    super.key,
    required this.cabecalho,
    required this.painel,
    this.rodape,
    required this.sobreposicao,
    required this.margemHorizontal,
    required this.margemInferior,
    this.alturaMinimaCabecalho,
    this.fracaoDaSobraParaCabecalho = 1.0,
    this.espacoAntesDoRodape = 16,
  });

  /// Recebe uma altura exata; o conteúdo precisa terminar acima da faixa de
  /// [sobreposicao] coberta pelo painel.
  final Widget cabecalho;
  final Widget painel;
  final Widget? rodape;
  final double sobreposicao;
  final double margemHorizontal;
  final double margemInferior;

  /// Altura mínima do cabeçalho (incluindo a [sobreposicao]). Se nula, usa a
  /// altura intrínseca mínima do próprio cabeçalho.
  final double? alturaMinimaCabecalho;

  /// Quanto da sobra de altura vai para o cabeçalho (0 a 1); o restante
  /// fica abaixo do painel e do rodapé.
  final double fracaoDaSobraParaCabecalho;

  /// Distância entre a base do painel e o topo do rodapé.
  final double espacoAntesDoRodape;

  @override
  State<ComposicaoCabecalhoPainel> createState() =>
      _ComposicaoCabecalhoPainelState();
}

class _ComposicaoCabecalhoPainelState extends State<ComposicaoCabecalhoPainel> {
  // GlobalKey: ao abrir o teclado a composição muda de pai (entra na
  // rolagem temporária) sem perder o estado dos campos nem o foco.
  final _chave = GlobalKey();
  bool _tecladoAberto = false;
  bool _cabeSemRolagem = true;

  /// Altura do cabeçalho na tela normal, mantida com o teclado aberto.
  double? _alturaCabecalhoEstatico;

  void _aoMedir(_MedidaComposicao medida) {
    if (medida.alturaLimitada) {
      _alturaCabecalhoEstatico = medida.alturaCabecalho;
    }
    // Com o teclado aberto a altura disponível é a que sobrou acima dele —
    // não serve para decidir se a tela normal cabe sem rolagem.
    if (_tecladoAberto || medida.cabeSemRolagem == _cabeSemRolagem) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _cabeSemRolagem = medida.cabeSemRolagem);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Lido da View, não de MediaQuery: o Scaffold remove os viewInsets
        // do MediaQuery que entrega ao body. O LayoutBuilder roda de novo a
        // cada abertura/fechamento do teclado, porque a altura disponível
        // muda junto.
        final tecladoAberto = View.of(context).viewInsets.bottom > 0;
        _tecladoAberto = tecladoAberto;

        final composicao = _CabecalhoComPainel(
          key: _chave,
          geometria: _GeometriaComposicao(
            sobreposicao: widget.sobreposicao,
            margemHorizontal: widget.margemHorizontal,
            margemInferior: widget.margemInferior,
            alturaMinimaCabecalho: widget.alturaMinimaCabecalho,
            fracaoDaSobraParaCabecalho: widget.fracaoDaSobraParaCabecalho,
            espacoAntesDoRodape: widget.espacoAntesDoRodape,
            alturaCabecalhoSemLimite:
                tecladoAberto ? _alturaCabecalhoEstatico : null,
            alturaDeReferencia: constraints.maxHeight,
          ),
          aoMedir: _aoMedir,
          cabecalho: widget.cabecalho,
          painel: widget.painel,
          rodape: widget.rodape,
        );

        if (!tecladoAberto && _cabeSemRolagem) return composicao;
        return SingleChildScrollView(child: composicao);
      },
    );
  }
}

@immutable
class _GeometriaComposicao {
  const _GeometriaComposicao({
    required this.sobreposicao,
    required this.margemHorizontal,
    required this.margemInferior,
    required this.alturaMinimaCabecalho,
    required this.fracaoDaSobraParaCabecalho,
    required this.espacoAntesDoRodape,
    required this.alturaCabecalhoSemLimite,
    required this.alturaDeReferencia,
  });

  final double sobreposicao;
  final double margemHorizontal;
  final double margemInferior;
  final double? alturaMinimaCabecalho;
  final double fracaoDaSobraParaCabecalho;
  final double espacoAntesDoRodape;

  /// Altura do cabeçalho dentro da rolagem (altura sem limite); nula = o
  /// mínimo.
  final double? alturaCabecalhoSemLimite;

  /// Altura útil da tela, para dizer se a composição caberia sem rolagem
  /// mesmo quando ela está dentro de uma.
  final double alturaDeReferencia;

  @override
  bool operator ==(Object other) =>
      other is _GeometriaComposicao &&
      other.sobreposicao == sobreposicao &&
      other.margemHorizontal == margemHorizontal &&
      other.margemInferior == margemInferior &&
      other.alturaMinimaCabecalho == alturaMinimaCabecalho &&
      other.fracaoDaSobraParaCabecalho == fracaoDaSobraParaCabecalho &&
      other.espacoAntesDoRodape == espacoAntesDoRodape &&
      other.alturaCabecalhoSemLimite == alturaCabecalhoSemLimite &&
      other.alturaDeReferencia == alturaDeReferencia;

  @override
  int get hashCode => Object.hash(
        sobreposicao,
        margemHorizontal,
        margemInferior,
        alturaMinimaCabecalho,
        fracaoDaSobraParaCabecalho,
        espacoAntesDoRodape,
        alturaCabecalhoSemLimite,
        alturaDeReferencia,
      );
}

class _MedidaComposicao {
  const _MedidaComposicao({
    required this.alturaCabecalho,
    required this.alturaLimitada,
    required this.cabeSemRolagem,
  });

  final double alturaCabecalho;

  /// `true` quando medida na tela normal (altura fixa), `false` quando
  /// estava dentro da rolagem.
  final bool alturaLimitada;

  /// Se tudo caberia na [_GeometriaComposicao.alturaDeReferencia] com o
  /// cabeçalho no tamanho mínimo.
  final bool cabeSemRolagem;
}

/// Cabeçalho (1º filho) atrás, painel (2º) na frente, rodapé (3º, opcional).
/// Como o painel é pintado depois do cabeçalho, ele fica na frente na faixa
/// em comum — e também recebe os toques primeiro nessa faixa.
class _CabecalhoComPainel extends MultiChildRenderObjectWidget {
  _CabecalhoComPainel({
    super.key,
    required this.geometria,
    required this.aoMedir,
    required Widget cabecalho,
    required Widget painel,
    Widget? rodape,
  }) : super(children: [cabecalho, painel, if (rodape != null) rodape]);

  final _GeometriaComposicao geometria;
  final ValueChanged<_MedidaComposicao> aoMedir;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCabecalhoComPainel(geometria: geometria, aoMedir: aoMedir);

  @override
  void updateRenderObject(
      BuildContext context, _RenderCabecalhoComPainel renderObject) {
    renderObject
      ..geometria = geometria
      ..aoMedir = aoMedir;
  }
}

class _PosicaoNaComposicao extends ContainerBoxParentData<RenderBox> {}

class _RenderCabecalhoComPainel extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _PosicaoNaComposicao>,
        RenderBoxContainerDefaultsMixin<RenderBox, _PosicaoNaComposicao> {
  _RenderCabecalhoComPainel({
    required _GeometriaComposicao geometria,
    required this.aoMedir,
  }) : _geometria = geometria;

  _GeometriaComposicao _geometria;
  set geometria(_GeometriaComposicao valor) {
    if (valor == _geometria) return;
    _geometria = valor;
    markNeedsLayout();
  }

  ValueChanged<_MedidaComposicao> aoMedir;

  bool _transbordou = false;
  final _recorte = LayerHandle<ClipRectLayer>();

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _PosicaoNaComposicao) {
      child.parentData = _PosicaoNaComposicao();
    }
  }

  @override
  void performLayout() {
    final g = _geometria;
    final cabecalho = firstChild!;
    final painel = childAfter(cabecalho)!;
    final rodape = childAfter(painel);
    final largura = constraints.maxWidth;
    final larguraConteudo = math.max(0.0, largura - 2 * g.margemHorizontal);

    painel.layout(BoxConstraints.tightFor(width: larguraConteudo),
        parentUsesSize: true);
    rodape?.layout(BoxConstraints.tightFor(width: larguraConteudo),
        parentUsesSize: true);
    final alturaPainel = painel.size.height;
    final alturaRodape = rodape?.size.height ?? 0;
    final espacoRodape = rodape == null ? 0.0 : g.espacoAntesDoRodape;

    final alturaMinimaCabecalho =
        g.alturaMinimaCabecalho ?? cabecalho.getMinIntrinsicHeight(largura);
    final alturaNecessaria = alturaMinimaCabecalho -
        g.sobreposicao +
        alturaPainel +
        espacoRodape +
        alturaRodape +
        g.margemInferior;

    final alturaLimitada = constraints.hasBoundedHeight;
    final alturaCabecalho = alturaLimitada
        ? alturaMinimaCabecalho +
            math.max(0.0, constraints.maxHeight - alturaNecessaria) *
                g.fracaoDaSobraParaCabecalho
        : math.max(alturaMinimaCabecalho,
            g.alturaCabecalhoSemLimite ?? alturaMinimaCabecalho);
    cabecalho.layout(
        BoxConstraints.tightFor(width: largura, height: alturaCabecalho));

    final topoPainel = alturaCabecalho - g.sobreposicao;
    (cabecalho.parentData! as _PosicaoNaComposicao).offset = Offset.zero;
    (painel.parentData! as _PosicaoNaComposicao).offset =
        Offset(g.margemHorizontal, topoPainel);

    var fimDoConteudo = topoPainel + alturaPainel;
    if (rodape != null) {
      // Logo abaixo do painel, com ou sem rolagem. Ancorado na base da tela,
      // ele ficava isolado do card, com metade da sobra no meio.
      final topoRodape = fimDoConteudo + espacoRodape;
      (rodape.parentData! as _PosicaoNaComposicao).offset =
          Offset(g.margemHorizontal, topoRodape);
      fimDoConteudo = topoRodape + alturaRodape;
    }

    final alturaConteudo = fimDoConteudo + g.margemInferior;
    size = alturaLimitada
        ? constraints.biggest
        : constraints.constrain(Size(largura, alturaConteudo));
    _transbordou = alturaConteudo > size.height + 0.5;

    aoMedir(_MedidaComposicao(
      alturaCabecalho: alturaCabecalho,
      alturaLimitada: alturaLimitada,
      cabeSemRolagem: alturaNecessaria <= g.alturaDeReferencia + 0.5,
    ));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // Só recorta no único quadro em que o conteúdo ainda não coube (antes de
    // a tela trocar para a rolagem de exceção) — nunca no uso normal, para
    // não cortar a sombra do painel.
    if (_transbordou) {
      _recorte.layer = context.pushClipRect(
          needsCompositing, offset, Offset.zero & size, defaultPaint,
          oldLayer: _recorte.layer);
    } else {
      _recorte.layer = null;
      defaultPaint(context, offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void dispose() {
    _recorte.layer = null;
    super.dispose();
  }
}
