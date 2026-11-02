# Orientação da tela: só retrato (RNF25)

> Branch: `fix/android-orientacao-tela` (2026-11-02). Issue #95.

## Relato

O proprietário relatou que o app parecia mudar a rotação automática do
celular.

## Investigação

**No código** (base `e4b5c09`), o app não tinha nada que pudesse mudar a
configuração do sistema:
- nenhum `SystemChrome.setPreferredOrientations` nem `DeviceOrientation`;
- nenhum código nativo de orientação: `MainActivity` é só um
  `FlutterActivity`, sem `requestedOrientation`;
- nenhuma permissão `WRITE_SETTINGS` e nenhum acesso a `Settings.System`
  (`ACCELEROMETER_ROTATION`, `USER_ROTATION`). O manifesto final do
  release só tem `INTERNET`, `ACCESS_NETWORK_STATE`, `USE_BIOMETRIC`,
  `USE_FINGERPRINT`, `READ_GSERVICES` e a permissão interna do receiver;
- nenhum plugin de sensor ou de orientação.

Sem `WRITE_SETTINGS`, o Android não deixa um app comum alterar a rotação
automática.

**No aparelho** (motorola edge 60 fusion, Android 16, APK 0.1.1), lendo
`settings get system accelerometer_rotation` e `user_rotation` por `adb`:

| Momento | `accelerometer_rotation` | `user_rotation` |
|---|---|---|
| Antes de abrir o app | 0 (desligada) | 0 |
| App aberto | 0 | 0 |
| Depois de voltar à tela inicial | 0 | 0 |

O `dumpsys window` mostrou `USER_ROTATION_LOCKED` durante todo o teste.

## Causa provável (não confirmada no aparelho)

O app não travava a orientação, então seguia o que o Android permite:
- **com a rotação automática ligada**, o app girava para paisagem ao virar
  o celular, e as telas, feitas para retrato, ficavam estranhas;
- **com ela desligada**, o Android 9 ou mais novo mostra um botão de
  "girar" na barra de navegação quando o celular é virado. Tocar nele gira
  só o app aberto, sem ligar a rotação automática, mas parece que ligou.

Não foi possível virar o celular fisicamente durante a investigação.

## Correção

O app passa a ficar só em retrato, apenas na própria janela:
- **`lib/core/config/orientacao.dart`:** `fixarOrientacaoDoApp()` chama
  `SystemChrome.setPreferredOrientations([portraitUp])`, e
  `lib/main.dart` chama a função antes do `runApp`.
- **Android:** `android:screenOrientation="portrait"` na activity, para a
  splash nativa também abrir em retrato.
- **iPhone:** `UISupportedInterfaceOrientations` só com retrato. O iPad
  continua com todas as orientações, como o multitarefa do iPadOS exige.
  **Não foi testado em iOS.**

Nada disso lê ou muda configuração do sistema.

**Tablets e dobráveis:** com `targetSdk 36`, o Android 16 ignora travas de
orientação em telas grandes (menor lado com 600 dp ou mais). Nesses
aparelhos, o app pode girar. Em celulares, inclusive o do proprietário
(434 dp), a trava vale.

## Testes

- **`test/android/orientacao_test.dart` (5):**
  - o app pede só `portraitUp` pelo canal do sistema;
  - `main()` fixa a orientação antes do `runApp`;
  - o manifesto tem `screenOrientation="portrait"`;
  - nenhum arquivo Android contém `WRITE_SETTINGS`,
    `ACCELEROMETER_ROTATION`, `USER_ROTATION`, `Settings.System` ou
    `requestedOrientation`;
  - o iPhone só aceita retrato.
- **No aparelho:** a leitura da tabela acima. O teste depois da correção
  está em "Como conferir".

## Como conferir no aparelho

1. Com a rotação automática **desligada**, abra o app, entre, navegue, saia
   e feche. Depois, nas configurações rápidas, ela continua desligada.
2. Vire o celular com o app aberto: o app não gira, e não aparece o botão
   de girar.
3. **Ligue** a rotação automática e repita: o app continua em retrato, e a
   rotação automática continua ligada depois de fechar o app.
4. Abra o app com o celular deitado: a splash e o app abrem em retrato.

## Rollback

Reverter o merge. O app volta a seguir a orientação do sistema.
