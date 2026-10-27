# Plano de publicação Android (Fase 4)

> **Só plano.** Nada aqui foi executado: nenhuma chave gerada, nenhum build
> de release assinado, nenhuma conta ou ficha criada no Play Console.
> Cada passo que mexe em credencial, assinatura ou loja exige aprovação do
> proprietário. Levantamento feito em 2026-10-27 sobre o commit `cad18ca`.

## 1. Estado atual (auditoria)

| Item | Valor hoje | Onde | Observação |
|---|---|---|---|
| Nome exibido | PetConnect | `android/app/src/main/res/values/strings.xml` | ok |
| applicationId / namespace | `com.petconnect.pet_connect` | `android/app/build.gradle.kts:22` | **Não muda.** Na Play Store o nome do pacote é permanente. |
| Versão | `0.1.0` (sem número de build → versionCode 1) | `pubspec.yaml:4` | Definir a primeira versão da loja (seção 5). |
| minSdk / targetSdk | 24 / 36 (padrão do Flutter) | manifesto mesclado do build | Conferir no Play Console o target mínimo exigido na data do envio. |
| Assinatura do release | **chave de debug** (`signingConfigs.getByName("debug")`) | `android/app/build.gradle.kts:35-41` | A Play não aceita. Ver seção 2. |
| `key.properties`, `*.jks`, `*.keystore` | não existem; já ignorados | `android/.gitignore:14-16` | ok |
| INTERNET | só nos manifestos `debug` e `profile`; no release vem das bibliotecas (Firebase) | `android/app/src/*/AndroidManifest.xml` | Confirmar no manifesto mesclado **do release** antes de enviar. |
| Permissões extras no manifesto mesclado | `AD_ID`, `ACCESS_ADSERVICES_*`, `USE_BIOMETRIC`, `USE_FINGERPRINT`, install referrer | build de debug | Vêm de dependências, não do app. A `AD_ID` obriga a declarar ID de publicidade na ficha de segurança de dados. Ver D4. |
| Login social | `google_sign_in` e `flutter_facebook_auth` no `pubspec.yaml`, mas os botões Google e Facebook **não fazem nada** (TODO) | `lib/features/auth/presentation/screens/login_screen.dart:281-293` | Botão sem função costuma reprovar na revisão. O Facebook também não tem o `ApplicationId` no manifesto. Ver D4. |
| URL da API | padrão `http://10.0.2.2:8090` (emulador) | `lib/core/config/app_config.dart:17-20` | Um release sem `--dart-define=API_BASE_URL=...` aponta para o emulador e usa HTTP. Ver D5. |
| Flags `USE_API_*` | todas desligadas por padrão (modo Firestore) | `lib/core/config/app_config.dart` | Decidir o modo da primeira versão (D5). |
| Shrinker (R8) | sem configuração própria; o Flutter liga no release | — | Testar o release com R8 antes do envio. |
| Crash reporting | nenhum | — | Ver D7. |
| Splash e ícone | nativos, já validados | `docs/branding/icone-e-splash-android.md`, ADR 0003 | ok |
| Links profundos | nenhum; o QR abre a página web, não o app | `public/index.html` | Nada a configurar agora. |
| Política de privacidade | não existe (issue #28 aberta) | `docs/privacy/data-flow-and-lgpd-readiness.md` | Obrigatória na ficha da loja. |
| Exclusão de conta | existe no app | `lib/features/usuario/` | A Play também pede um link **web** para pedir a exclusão. |
| Regras do Firestore | isolamento por dono mesclado, **deploy pendente** | `docs/security/firestore-isolamento-por-dono.md` | Não publicar com as regras antigas (qualquer logado altera dados de outros). |

## 2. Assinatura (sem gerar nada sem aprovação)

Recomendação: **Play App Signing** com uma **chave de upload** separada.

- O Google guarda a chave que assina o app instalado. O proprietário guarda só
  a chave de upload, que assina o pacote enviado ao Play Console.
- Se a chave de upload vazar ou se perder, o Google permite trocá-la, depois
  de um pedido do proprietário. A chave de assinatura do app nunca sai do Google.

Como fica no projeto, quando aprovado:

1. O proprietário gera a chave de upload no próprio computador (`keytool`),
   **fora** da pasta do repositório.
2. `android/key.properties` (já ignorado pelo Git) aponta para o arquivo da
   chave, com as senhas. Esse arquivo nunca vai para o Git, para o CI aberto
   nem para o chat.
3. `build.gradle.kts` passa a ler `key.properties` e usa a chave de upload no
   `release`. Se o arquivo não existir, o build de release **falha**, em vez de
   cair para a chave de debug. Essa mudança de código pode ser feita e testada
   sem chave nenhuma.
4. Backup: duas cópias da chave e das senhas em lugares separados, por exemplo
   um gerenciador de senhas e um pendrive guardado.
5. Rotação: só se a chave vazar, pelo pedido de troca no Play Console.

Se o Google Sign-In for ligado no futuro, as impressões SHA-1 da chave de
upload **e** da chave do Play App Signing precisam ser cadastradas no Firebase.
Sem isso, o login do Google funciona no debug e falha na versão da loja.

## 3. Checklist de envio

**Antes do primeiro build de release**
- [ ] Decisões D1 a D8 aprovadas (seção 6).
- [ ] Deploy das regras do Firestore feito e validado.
- [ ] Política de privacidade publicada numa URL pública (#28).
- [ ] Página web para pedir a exclusão de conta.
- [ ] Assinatura de release configurada (seção 2).
- [ ] Versão definida no `pubspec.yaml` (seção 5).

**Build**
- [ ] `flutter build appbundle --release` com os `--dart-define` da D5.
- [ ] Manifesto mesclado do release com INTERNET e sem permissões não declaradas.
- [ ] App de release instalado no Motorola e checklist
      `docs/validation/checklist-android-proprietario.md` completo.

**Play Console**
- [ ] Conta de desenvolvedor (pessoal ou organização) e verificação de identidade.
- [ ] Ficha da loja: nome, descrição curta e longa, ícone 512×512, imagem de
      destaque 1024×500, pelo menos 2 capturas de tela de celular.
- [ ] Classificação etária (questionário IARC).
- [ ] Público-alvo: não é para crianças.
- [ ] Segurança de dados (seção 4).
- [ ] Declaração de ID de publicidade (depende da D4).
- [ ] Acesso para a revisão: conta de teste com pets, para o revisor entrar.
- [ ] Teste interno, depois teste fechado. Contas pessoais novas precisam de
      um teste fechado com testadores durante um período mínimo antes da
      produção; conferir no Play Console a regra em vigor.
- [ ] Produção com lançamento gradual (por exemplo 10%, 50%, 100%).

## 4. Segurança de dados (rascunho para a ficha)

| Dado | Quem fornece | Para quê | Compartilhado | Observação |
|---|---|---|---|---|
| Nome, e-mail, telefone, foto do tutor | tutor | conta e contato | Firebase/Google, Cloudinary, API no Render/MongoDB Atlas (operadores) | |
| Dados e fotos do pet | tutor | perfil do pet | os mesmos | |
| Vacinas, consultas, histórico | tutor | saúde do pet | os mesmos | |
| Nome do pet e contato na página pública do QR | tutor | encontrar pet perdido | **visível a quem escanear** | Ligado à issue #35 (contato público). |
| Localização do avistamento | quem encontra o pet, pela página web | avisar o tutor | tutor do pet | Coletada no navegador de quem escaneia, não pelo app. |
| ID de publicidade | SDK do Facebook | nenhum uso pelo app | — | Some se a D4 remover o SDK. |

Criptografia em trânsito: sim (HTTPS). Exclusão de dados: sim, no app e
(após a página web) por pedido.

## 5. Versionamento e rollback

- Formato `X.Y.Z+N` no `pubspec.yaml`: `X.Y.Z` vira o versionName e `N` o
  versionCode. Proposta para a primeira versão da loja: `1.0.0+1`.
- O versionCode **sempre sobe**, e um número já enviado não pode ser reusado,
  nem em teste interno.
- A Play não permite voltar para uma versão anterior. Rollback é:
  1. interromper o lançamento gradual (quem ainda não atualizou fica na versão anterior);
  2. publicar uma versão nova, com versionCode maior, feita do código anterior.
- Quem já tem o app instalado por `flutter run` ou APK está com a assinatura de
  debug. A versão da loja tem outra assinatura, então essas pessoas precisam
  desinstalar antes, o que apaga só o cache local (os dados estão no
  Firebase/API).
- Tag no Git para cada versão enviada (`v1.0.0`), apontando para o commit do build.

## 6. Decisões

| # | Decisão | Opções | Recomendação | Risco | Responsável | Aprovação necessária |
|---|---|---|---|---|---|---|
| D1 | Conta do Play Console | pessoal; organização (exige D-U-N-S) | Pessoal, se não houver empresa | Conta pessoal exige teste fechado antes da produção | Proprietário | Sim (pagamento e identidade são do proprietário) |
| D2 | Assinatura | Play App Signing + chave de upload; chave própria sem Play App Signing | Play App Signing + chave de upload | Perder a chave sem Play App Signing impede atualizar o app para sempre | Proprietário gera a chave; Claude prepara o `build.gradle.kts` | Sim |
| D3 | Onde fica a chave de upload | só no computador do proprietário; também em segredo do GitHub Actions para build automático | Só no computador por enquanto | Segredo no CI amplia quem pode assinar | Proprietário | Sim |
| D4 | Login social | remover `google_sign_in`, `flutter_facebook_auth` e os botões; esconder os botões e manter as dependências; implementar os dois | Remover agora; implementar depois (RF04-A/B) | Mexe na tela de Login (ADR 0001 trata só do tema). Manter o Facebook exige declarar ID de publicidade e configurar o app no Facebook. | Claude implementa; proprietário decide | Sim |
| D5 | Modo da 1ª versão | Firestore (flags desligadas); API em tudo (`USE_API_*` + URL do Render); só QR pela API | Firestore + `USE_API_QR`, com `API_BASE_URL` do Render | API no plano gratuito do Render dorme e demora ~2 min no primeiro acesso | Proprietário | Sim |
| D6 | Hospedagem da API para produção | Render gratuito; Render pago; outro | Render pago (sem hibernação), se a API for usada | Plano gratuito: primeira tela lenta e timeouts de 15 s no app | Proprietário | Sim (custo) |
| D7 | Crash reporting | Firebase Crashlytics; nenhum | Crashlytics, declarado na ficha e na política | Sem ele, falhas em produção ficam invisíveis | Claude implementa | Sim |
| D8 | Política de privacidade e exclusão web | página no Firebase Hosting (já usado pelo QR); site à parte | Firebase Hosting, junto da página do QR | Texto jurídico é responsabilidade do proprietário | Proprietário (texto); Claude (página) | Sim |

## 7. Ordem sugerida e estimativas

| Etapa | Depende de | Quem | Estimativa |
|---|---|---|---|
| Deploy das regras do Firestore e validação | — | Proprietário | 1 h |
| D4 (remover login social) e build de release com R8 | D4 | Claude | 0,5 dia |
| Assinatura de release no Gradle, sem chave | D2 | Claude | 2 h |
| Política de privacidade e página de exclusão | D8, #28 | Proprietário + Claude | 1 a 2 dias |
| Crashlytics | D7 | Claude | 0,5 dia |
| Gerar a chave de upload e o primeiro AAB | D2, D3 | Proprietário | 1 h |
| Ficha, capturas, classificação, segurança de dados | todas acima | Proprietário (Claude ajuda nos textos) | 1 dia |
| Teste interno e teste fechado | ficha | Proprietário + testadores | período mínimo da Play |
| Produção gradual | teste fechado | Proprietário | 1 semana acompanhando |
