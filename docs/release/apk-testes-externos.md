# APK para testadores externos

> Branch: `build/apk-testes-externos` (2026-10-27). Fase 2 de
> `prompt_opus_memorial_apk_login_social_petconnect.md`. O APK **não** é
> publicado nem enviado automaticamente: o proprietário distribui.

## Decisões do proprietário (2026-10-27)

| Tema | Decisão |
|---|---|
| Assinatura | **Chave de upload** própria, gerada pelo proprietário. Os próximos APKs atualizam sem desinstalar, e a mesma chave serve depois para a Play Store (Play App Signing, `docs/release/plano-publicacao-android.md`, PR #79). |
| Ambiente | **Firebase atual** (`pet-connect-c53f1`), com contas de teste e dados fictícios. Sem projeto de staging. |
| Galeria de fotos | **Ligada** neste APK (`--dart-define=GALERIA_FOTOS=true`). |

Login com Google e Facebook **não** entra: é a Fase 3. Os botões continuam
na tela de login, mas ainda não fazem nada.

## O que entra no APK

| Item | Valor |
|---|---|
| Código | base `feature/backend-spring-mongodb-migration` com a correção do Memorial (PR #85) + esta branch |
| Variante | `release`, APK universal (todas as ABIs), assinado com a chave de upload |
| Versão | `0.1.0` (versionCode `1`), de `pubspec.yaml` |
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

```text
Commit:
Data:
Arquivo: build/app/outputs/flutter-apk/app-release.apk
Tamanho:
SHA-256 do APK:
Certificado (SHA-256, público):
Variante / flags: release, universal, GALERIA_FOTOS=true
Instalação testada em:
```

## Instruções para os testadores

Ver `docs/validation/apk-testes-externos.md`, com instalação, roteiro de
smoke test e como reportar bugs.

## Rollback

- **Build:** reverter esta branch. O `build.gradle.kts` volta a assinar o
  release com a chave de debug.
- **Para quem instalou:** desinstalar o app.
