import 'package:flutter/widgets.dart';

/// Chama [aoVoltar] toda vez que o app volta ao primeiro plano, depois de ter
/// ficado em segundo plano. Não desenha nada.
///
/// Serve para o app descartar as conexões de rede que ficaram abertas: no
/// Android, a rede do app é cortada em segundo plano e essas conexões morrem
/// (ver `ApiClient.descartarConexoesAntigas`).
class AoVoltarAoPrimeiroPlano extends StatefulWidget {
  const AoVoltarAoPrimeiroPlano({
    super.key,
    required this.aoVoltar,
    required this.child,
  });

  final VoidCallback aoVoltar;
  final Widget child;

  @override
  State<AoVoltarAoPrimeiroPlano> createState() =>
      _AoVoltarAoPrimeiroPlanoState();
}

class _AoVoltarAoPrimeiroPlanoState extends State<AoVoltarAoPrimeiroPlano>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.aoVoltar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
