# Avisos do QR Code por push

Fase 4 do épico #102 (issue #36), adiantada a pedido do proprietário em
2026-11-03. Empilhada sobre a fase 3 (#37, `docs/features/qr-avistamentos.md`).
A API correspondente está em AleksGustavo/PetConnect-API (branch
`feat/qr-notificacoes-tutor`).

## O que o tutor recebe

| Quando | Notificação | Frequência |
|---|---|---|
| A página do QR foi aberta | "O QR Code de [pet] foi acessado". O texto diz que isso não confirma que o pet foi visto | No máximo uma a cada 15 minutos por pet |
| Alguém enviou um relato | "Novo avistamento de [pet]", com ou sem localização | A cada relato novo; o mesmo envio repetido não avisa de novo |

- **Toque na notificação:** abre a aba Localização do pet. Se o toque abriu
  o app, ele espera a splash e a chegada à Home (e o login, se a sessão não
  estiver guardada) para abrir a tela.
- **App aberto:** o Android não mostra a notificação; o app mostra uma faixa
  com "Ver" e atualiza a aba Localização do pet.
- **Preferências:** em Configurações do pet > Compartilhamento via QR Code >
  Avisos no celular, o tutor liga e desliga separadamente o aviso de acesso
  e o de avistamento. Os dois vêm ligados. Valem com ou sem página
  publicada.
- **Permissão do Android:** se as notificações estiverem desativadas no
  aparelho, a mesma seção avisa e diz onde ativar.

Não há garantia de entrega nem de tempo: o push depende do Firebase Cloud
Messaging, da internet, da bateria e das configurações do celular.

## Como funciona

```text
Página do QR ──► API ──► grava o evento (fase 3)
                  └──► thread virtual ──► FCM ──► aparelhos do tutor
```

**App:**
- **Login** (`AvisosDoQr`): pede a permissão de notificação, que no Android
  13 ou mais novo o sistema mostra uma única vez, e registra o token do FCM
  em `PUT /api/v1/me/push-devices`. Token novo do FCM é registrado de novo.
- **Sair da conta:** remove o token na API (`DELETE`, token no corpo) e no
  aparelho, antes do signOut. Sem rede, o app sai mesmo assim; o servidor
  apaga o token quando o FCM disser que ele expirou.
- **Android:**
  - canal `qr_avisos` ("Avisos do QR Code", importância alta), criado em
    `MainActivity`;
  - ícone `res/drawable/ic_notificacao.xml` (pata branca);
  - permissão `POST_NOTIFICATIONS` no manifest.

**API:** ver o README da API, seção "Avisos ao tutor (push)".

## Privacidade

- **Payload:** só o título, o texto fixo e os ids do pet. Nada do relato, do
  contato de quem relatou ou da coordenada.
- **Tela bloqueada:** visibilidade privada no Android. O sistema pode
  esconder o texto, conforme a configuração do aparelho.
- **Token:** ele identifica o aparelho. Vai no corpo da requisição, nunca na
  URL ou em log.
- **Histórico de envios:** sem token nem texto, apagado em 30 dias.
- **Exclusão:** excluir a conta apaga aparelhos, preferências e histórico.

## Só com a API configurada

Sem `USE_API_QR` nem `USE_API_PETS`, o app não usa o Firebase Messaging, não
pede permissão e não mostra a seção de avisos.

## Configuração (proprietário)

1. **API do FCM:** no Google Cloud do projeto `pet-connect-c53f1`, confirmar
   que "Firebase Cloud Messaging API (V1)" está ativada (APIs e serviços).
2. **Conta de serviço:** a de `FIREBASE_SERVICE_ACCOUNT` no Render precisa
   poder enviar mensagens. A `firebase-adminsdk` já pode; uma conta dedicada
   precisa do papel "Firebase Cloud Messaging API Admin".
3. **Ordem de deploy:**
   - API da fase 3 e depois da fase 4;
   - página (`firebase deploy --only hosting`);
   - APK com `USE_API_QR=true` e `API_BASE_URL` do Render.

O `google-services.json` não muda: o FCM usa o mesmo app Android já
registrado.

## Rollback

- **App:** reverter o merge. Os tokens já registrados continuam na API até o
  FCM dizer que expiraram.
- **API:** reverter o merge. Os avisos param.

## Validação

Roteiro de aparelho em `docs/validation/qr-notificacoes.md`.
