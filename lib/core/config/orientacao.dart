import 'package:flutter/services.dart';

/// O app fica só em retrato (docs/features/orientacao-retrato.md).
///
/// Vale só para a janela do PetConnect. A rotação automática do celular é
/// uma configuração do sistema, e o app não a lê nem a altera: com ela
/// ligada, o app não gira; com ela desligada, o Android não oferece o
/// botão de girar dentro do app. As telas foram feitas para retrato (o
/// Entrar e o Cadastro, por exemplo, não rolam).
const orientacoesDoApp = [DeviceOrientation.portraitUp];

Future<void> fixarOrientacaoDoApp() =>
    SystemChrome.setPreferredOrientations(orientacoesDoApp);
