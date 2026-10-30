# APK para testadores externos

> Branch: `build/apk-testes-externos` (2026-10-27). Fase 2 de
> `prompt_opus_memorial_apk_login_social_petconnect.md`. O APK **não** é
> publicado nem enviado automaticamente: o proprietário distribui.

## Versão 0.1.1 (2026-10-30)

Segundo APK para testadores, da base `feature/backend-spring-mongodb-migration`
depois das PRs #87 a #91. Instala por cima da `0.1.0`, porque usa a mesma
chave de upload e o versionCode é maior (`2`).

**Novidades para quem testou a 0.1.0:**
- **Entrar com Google** (PR #87). O Facebook saiu do escopo e não tem
  botão.
- **Cartaz de pet desaparecido** (PR #89): PNG ou PDF gerado no celular,
  com ponto de foco nas fotos, cor e telefone só com autorização.
- **App em português do Brasil** (PR #91): calendários e textos do sistema
  em português, e o título da tela de entrada passa a "Entrar".

**Ainda não entra** (PRs abertas): a exclusão de conta e de pet que apaga
tudo em cascata (#81, #82), porque depende da publicação das regras do
Firestore.

## Decisões do proprietário (2026-10-27)

| Tema | Decisão |
|---|---|
| Assinatura | **Chave de upload** própria, gerada pelo proprietário. Os próximos APKs atualizam sem desinstalar, e a mesma chave serve depois para a Play Store (Play App Signing, `docs/release/plano-publicacao-android.md`, PR #79). |
| Ambiente | **Firebase atual** (`pet-connect-c53f1`), com contas de teste e dados fictícios. Sem projeto de staging. |
| Galeria de fotos | **Ligada** neste APK (`--dart-define=GALERIA_FOTOS=true`). |

Login social **não** entra neste APK: é a Fase 3. Os botões continuam na
tela de login, mas ainda não fazem nada. **Atualização (2026-10-27):** a
Fase 3 ficou só com o Google, e o Facebook saiu do escopo
(`docs/features/login-social.md`). O próximo APK traz o "Entrar com
Google".

## O que entra no APK

| Item | Valor |
|---|---|
| Código | `0.1.0`: base com a correção do Memorial (PR #85). `0.1.1`: base depois da PR #91 (ver "Versão 0.1.1") |
| Variante | `release`, APK universal (todas as ABIs), assinado com a chave de upload |
| Versão | `0.1.1` (versionCode `2`), de `pubspec.yaml`. A anterior foi `0.1.0` (`1`) |
| `applicationId` | `com.petconnect.pet_connect` (sem mudança) |
| Android | 7.0 (API 24) ou mais novo (`flutter.minSdkVersion`) |
| Backend | Firebase Auth + Firestore (padrão). Nenhuma flag `USE_API_*`: Spring/MongoDB desligado |
| Flags | só `GALERIA_FOTOS=true` |
| Imagens | Cloudinary, envio sem assinatura (preset público, sem segredo no app) |
| Toolchain | Flutter 3.47.0 (stable), Dart 3.13.0 |

O caminho, o tamanho, o SHA-256 do APK e a impressão do certificado ficam
na seção "Registro do build", preenchida depois de gerar.

## Assinatura

`android/app/build.gradle.kts` lê `android/key.properties`. Sem esse
arquivo, o build de release **falha**: ele não sai mais assinado com a
chave de debug. Verificado com `gradlew :app:signingReport`: o release usa
a configuração `release`, e a debug continua com
`~/.android/debug.keystore`.

O arquivo de chave (`.jks`) e o `key.properties` ficam **só no computador
do proprietário**:
- os dois já estão no `android/.gitignore`;
- nunca vão para o Git, o CI, o chat ou a PR;
- o Claude não lê o conteúdo deles.

### Passo a passo (proprietário, no próprio terminal)

1. Criar a pasta da chave, fora do repositório:
   ```powershell
   New-Item -ItemType Directory -Force "$env:USERPROFILE\.petconnect"
   ```
2. Gerar a chave de upload. O `keytool` pede as senhas e o nome; digite
   direto no terminal:
   ```powershell
   & "C:\Program Files\Android\Android Studio1\jbr\bin\keytool.exe" -genkeypair -v -keystore "$env:USERPROFILE\.petconnect\upload-keystore.jks" -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
3. Criar `android/key.properties` num editor de texto (por exemplo, o Bloco
   de Notas), com as senhas que você escolheu:
   ```properties
   storePassword=<senha do arquivo>
   keyPassword=<senha da chave>
   keyAlias=upload
   storeFile=C:/Users/<seu usuário do Windows>/.petconnect/upload-keystore.jks
   ```
   Use barras normais (`/`) no caminho.
4. **Backup:** duas cópias do `.jks` e das senhas em lugares separados, por
   exemplo um gerenciador de senhas e um pendrive guardado. Sem essa chave,
   não dá para atualizar o app instalado pelos testadores.

## Segurança antes de distribuir

- **Regras do Firestore:** deployadas em 2026-10-27
  (`docs/security/firestore-rules-deployed.md`).
  - **Bloqueio:** distribuir só depois de o proprietário confirmar no
    Console que não existe `match /{document=**}`.
  - O texto só pode aparecer no comentário do topo.
- **Dados:**
  - os testadores usam e-mail de teste ou alias e pets fictícios;
  - nada de dados clínicos reais;
  - nada de fotos com pessoas ou com a casa.
- **Galeria:**
  - as fotos vão para o Cloudinary real;
  - excluir uma foto apaga o registro, mas o arquivo fica;
  - em Android 7 a 9 o original pode guardar a localização GPS (G17,
    ainda não verificado). Orientar os testadores a desligar a localização
    da câmera ou a usar fotos sem localização.
- **Consentimento:** cada testador sabe que é uma versão de teste, que os
  dados ficam no Firebase e no Cloudinary do projeto e que serão apagados
  ao fim do teste.
- **Distribuição:** só para os testadores combinados.
  - Não postar o APK em grupos públicos.
  - Não é Play Store: o Android pede para permitir a instalação de fonte
    desconhecida.

### Limpeza depois do teste (proprietário)

1. Cada testador pode excluir a própria conta no app (Configurações →
   excluir conta), o que apaga o perfil, os pets e os registros da galeria.
   Consultas, localizações e eventos do Memorial ainda ficam (tarefa em
   andamento).
2. O que sobrar sai pelo Console do Firebase: Authentication e Firestore,
   filtrando pelos e-mails de teste.
3. Os arquivos das fotos saem pelo Media Library do Cloudinary.

## Gerar o APK

Quality gates do CI:

```bash
dart format --output=none --set-exit-if-changed lib test
```

```bash
flutter analyze
```

```bash
flutter test test/core/ test/features/pet/ test/features/auth/ test/features/usuario/ test/android/ --exclude-tags=e2e
```

Build, com o `key.properties` no lugar:

```bash
flutter build apk --release --dart-define=GALERIA_FOTOS=true
```

Saída: `build/app/outputs/flutter-apk/app-release.apk`. Conferir:

```bash
certutil -hashfile build/app/outputs/flutter-apk/app-release.apk SHA256
```

O APK fica fora do Git. Não versionar o `.apk` sem decisão explícita; para
guardar, usar uma Release privada do GitHub, se aprovado.

## Registro do build

### 0.1.1

```text
Commit: feaaa65 (branch chore/apk-0.1.1)
Data: 2026-10-30 10:29 (-03)
Arquivo: build/app/outputs/flutter-apk/app-release.apk
Cópia entregue: Downloads/PetConnect-0.1.1-teste.apk (mesmo SHA-256)
Tamanho: 68.776.679 bytes (65,6 MB)
SHA-256 do APK: 03f441e327ad40d1829c589d9d7b6a32afd020a950f76ae18892715c8269eab8
Certificado (SHA-256, público): 8123e0f9b1c1015c1dc4988f53b6f6d10aafd8c3ed12a43d6e9894003bf9dbef
Assinatura: chave de upload (a mesma da 0.1.0)
Pacote: com.petconnect.pet_connect, versionCode 2, versionName 0.1.1
SDK: minSdk 24 (Android 7.0), targetSdk 36
ABIs: arm64-v8a, armeabi-v7a, x86_64 (universal)
Variante / flags: release, universal, GALERIA_FOTOS=true
Instalação testada em: pendente (proprietário)
```

Permissões no manifesto final (`aapt2 dump permissions`): `INTERNET`,
`ACCESS_NETWORK_STATE`, `USE_BIOMETRIC`, `USE_FINGERPRINT`,
`READ_GSERVICES` e a permissão interna do receiver do próprio app. **Sem
`AD_ID` nem `ACCESS_ADSERVICES_*`**, que vinham do SDK do Facebook
(removido).

### 0.1.0

```text
Commit: 3aa2a90 (branch build/apk-testes-externos)
Data: 2026-10-27 21:49 (-03)
Arquivo: build/app/outputs/flutter-apk/app-release.apk
Cópia entregue: Downloads/PetConnect-0.1.0-teste.apk (mesmo SHA-256)
Tamanho: 61.401.984 bytes (58,6 MB)
SHA-256 do APK: e4c7b330e450d27f9de4152b98c6b54633077b470673ebf3981296871493810c
Certificado (SHA-256, público): 8123e0f9b1c1015c1dc4988f53b6f6d10aafd8c3ed12a43d6e9894003bf9dbef
Assinatura: chave de upload (alias upload), APK Signature Scheme v2 (apksigner verify OK)
Pacote: com.petconnect.pet_connect, versionCode 1, versionName 0.1.0
SDK: minSdk 24 (Android 7.0), targetSdk 36
ABIs: arm64-v8a, armeabi-v7a, x86_64 (universal)
Variante / flags: release, universal, GALERIA_FOTOS=true
Instalação testada em: pendente (proprietário)
```

Permissões no manifesto final (`aapt2 dump badging`):
- **Rede:** `INTERNET` e `ACCESS_NETWORK_STATE`.
- **Biometria:** `USE_BIOMETRIC` e `USE_FINGERPRINT`, que vêm das
  dependências; o app não usa biometria.
- **Identificador de anúncios:** `AD_ID` e `ACCESS_ADSERVICES_*`, que entram
  pelas dependências, provavelmente o SDK do Facebook
  (`flutter_facebook_auth`). O app não mostra anúncios.
  - Revisar na Fase 3 (login social) e antes da Play Store, que pede
    declaração de uso do ID de publicidade.
  - **Atualização (2026-10-27):** com a remoção do `flutter_facebook_auth`
    na Fase 3, o próximo APK é conferido de novo com `aapt2 dump badging`
    (`docs/features/login-social.md`).
  - Para remover, basta `tools:node="remove"` no manifesto, se não forem
    necessárias.

## Instruções para os testadores

Ver `docs/validation/apk-testes-externos.md`, com instalação, roteiro de
smoke test e como reportar bugs.

## Rollback

- **Build:** reverter esta branch. O `build.gradle.kts` volta a assinar o
  release com a chave de debug.
- **Para quem instalou:** desinstalar o app.
