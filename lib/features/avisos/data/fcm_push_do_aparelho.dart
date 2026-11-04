import 'package:firebase_messaging/firebase_messaging.dart';

import '../domain/aviso_do_qr.dart';

/// [PushDoAparelho] pelo Firebase Cloud Messaging (issue #36).
///
/// No Android 13 ou mais novo, [pedirPermissao] mostra o pedido do sistema
/// uma vez; se o tutor negar, o sistema não pergunta de novo e o app só
/// informa a situação.
class FcmPushDoAparelho implements PushDoAparelho {
  FcmPushDoAparelho([FirebaseMessaging? messaging])
      : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  static PermissaoDeAviso _da(NotificationSettings s) =>
      switch (s.authorizationStatus) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional =>
          PermissaoDeAviso.concedida,
        AuthorizationStatus.denied => PermissaoDeAviso.negada,
        AuthorizationStatus.notDetermined => PermissaoDeAviso.naoPerguntada,
      };

  @override
  Future<PermissaoDeAviso> pedirPermissao() async =>
      _da(await _messaging.requestPermission());

  @override
  Future<PermissaoDeAviso> permissao() async =>
      _da(await _messaging.getNotificationSettings());

  @override
  Future<String?> token() => _messaging.getToken();

  @override
  Stream<String> get tokensNovos => _messaging.onTokenRefresh;

  @override
  Stream<MensagemDePush> get avisosComOAppAberto => FirebaseMessaging.onMessage
      .map((m) => MensagemDePush(titulo: m.notification?.title, dados: m.data));

  @override
  Stream<Map<String, dynamic>> get avisosTocados =>
      FirebaseMessaging.onMessageOpenedApp.map((m) => m.data);

  @override
  Future<Map<String, dynamic>?> avisoQueAbriuOApp() async =>
      (await _messaging.getInitialMessage())?.data;

  @override
  Future<void> apagarToken() => _messaging.deleteToken();
}
