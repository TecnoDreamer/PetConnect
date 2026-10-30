# Plano de publicação Android (Fase 4)

> **Plano.** Nenhuma conta ou ficha foi criada no Play Console e nenhum AAB
> foi enviado. Cada passo que mexe em credencial, assinatura ou loja exige
> aprovação do proprietário. Levantamento feito em 2026-10-27 sobre o
> commit `cad18ca`.
>
> **Revisto em 2026-10-30** sobre `4438844`. Desde a primeira versão:
> - a assinatura com a chave de upload foi feita (D2, D3);
> - o login com Google entrou, e o Facebook saiu do escopo (D4);
> - as regras de isolamento e da galeria foram publicadas;
> - entraram a galeria, o cartaz de pet desaparecido e o app em português.
>
> Continuam abertas as decisões D1 e D5 a D8.

## 1. Estado atual (auditoria)

| Item | Valor hoje | Onde | Observação |
|---|---|---|---|
| Nome exibido | PetConnect | `android/app/src/main/res/values/strings.xml` | ok |
| applicationId / namespace | `com.petconnect.pet_connect` | `android/app/build.gradle.kts:22` | **Não muda.** Na Play Store o nome do pacote é permanente. |
| Versão | `0.1.0+1` (APK para testadores) | `pubspec.yaml:4` | Os APKs de teste sobem o número de build; a primeira versão da loja continua em aberto (seção 5). |
| minSdk / targetSdk | 24 / 36 (padrão do Flutter) | manifesto mesclado do build | Conferir no Play Console o target mínimo exigido na data do envio. |
| Assinatura do release | **chave de upload** do proprietário, lida de `android/key.properties`; sem o arquivo, o build de release falha | `android/app/build.gradle.kts` | ✅ Feito em 2026-10-27 (`docs/release/apk-testes-externos.md`). Certificado conferido com `apksigner` em cada APK. |
| `key.properties`, `*.jks`, `*.keystore` | só no computador do proprietário, fora do repositório; ignorados pelo Git | `android/.gitignore` | ok |
| Permissões do release | `INTERNET`, `ACCESS_NETWORK_STATE`, `USE_BIOMETRIC`, `USE_FINGERPRINT`, `READ_GSERVICES` e a permissão interna do receiver do próprio app | APK de release, `aapt2 dump permissions` (2026-10-30) | Vêm do Firebase, do Google Sign-In e da biometria. **Sem `AD_ID`**, desde que o SDK do Facebook saiu. Conferir de novo no AAB antes de enviar. |
| Login social | **Google** implementado (RF04-A, PR #87) e testado no APK de release; Facebook fora do escopo, sem SDK | `lib/features/auth/`, `docs/features/login-social.md` | ✅ D4 resolvida. O resto do roteiro do Google (LS02–LS12) está pendente com o proprietário. |
| URL da API | padrão `http://10.0.2.2:8090` (emulador) | `lib/core/config/app_config.dart:17-20` | Um release sem `--dart-define=API_BASE_URL=...` aponta para o emulador e usa HTTP. Ver D5. |
| Flags `USE_API_*` | todas desligadas por padrão (modo Firestore) | `lib/core/config/app_config.dart` | Decidir o modo da primeira versão (D5). |
| Shrinker (R8) | sem configuração própria; o Flutter liga no release | — | Testar o release com R8 antes do envio. |
| Crash reporting | nenhum | — | Ver D7. |
| Idioma | português do Brasil em tudo, inclusive calendários e textos do Flutter (PR #91) | `lib/core/config/idioma.dart` | Ficha da loja em português (Brasil). |
| Galeria de fotos | atrás da flag `GALERIA_FOTOS` (desligada por padrão; ligada nos APKs de teste) | `docs/features/galeria-fotos-pet.md` | Ligar para todos é decisão do proprietário (ADR 0005). |
| Splash e ícone | nativos, já validados | `docs/branding/icone-e-splash-android.md`, ADR 0003 | ok |
| Links profundos | nenhum; o QR abre a página web, não o app | `public/index.html` | Nada a configurar agora. |
| Política de privacidade | não existe (issue #28 aberta) | `docs/privacy/data-flow-and-lgpd-readiness.md` | Obrigatória na ficha da loja. |
| Exclusão de conta | existe no app | `lib/features/usuario/` | A Play também pede um link **web** para pedir a exclusão. |
| Regras do Firestore | isolamento por dono e galeria **publicados** pelo proprietário no Console em 2026-10-27 | `docs/security/firestore-rules-deployed.md` | Falta confirmar que a regra antiga `match /{document=**}` saiu (exige `firebase login`). As regras das PRs #81 e #82 (exclusão de conta e de pet em cascata) **ainda não foram publicadas**: sem elas, essas exclusões falham no meio. |

## 2. Assinatura (sem gerar nada sem aprovação)

Recomendação: **Play App Signing** com uma **chave de upload** separada.

- O Google guarda a chave que assina o app instalado. O proprietário guarda só
  a chave de upload, que assina o pacote enviado ao Play Console.
- Se a chave de upload vazar ou se perder, o Google permite trocá-la, depois
  de um pedido do proprietário. A chave de assinatura do app nunca sai do Google.

Situação (2026-10-30):

1. ✅ O proprietário gerou a chave de upload no próprio computador
   (`keytool`), **fora** da pasta do repositório.
2. ✅ `android/key.properties` (ignorado pelo Git) aponta para o arquivo da
   chave, com as senhas. Esse arquivo nunca vai para o Git, para o CI nem
   para o chat.
3. ✅ `build.gradle.kts` lê `key.properties` e usa a chave de upload no
   `release`. Sem o arquivo, o build de release **falha**, em vez de cair
   para a chave de debug.
4. **A confirmar pelo proprietário:** backup em duas cópias da chave e das
   senhas, em lugares separados (por exemplo, um gerenciador de senhas e um
   pendrive guardado).
5. Rotação: só se a chave vazar, pelo pedido de troca no Play Console.

**Login com Google na versão da loja:** a impressão SHA-1 da chave de upload
já está no Firebase, porque o login funciona no APK de release. Quando o
Play App Signing for ativado, a SHA-1 da **chave de assinatura do app**
(mostrada no Play Console) também precisa ser cadastrada no Firebase. Sem
isso, o login funciona nos APKs de teste e falha na versão da loja.

## 3. Checklist de envio

**Antes do primeiro build de release**
- [ ] Decisões D1 e D5 a D8 aprovadas (seção 6). D2, D3 e D4 já estão resolvidas.
- [x] Deploy das regras de isolamento e da galeria (2026-10-27).
- [ ] Confirmar que a regra antiga `match /{document=**}` saiu de produção.
- [ ] Deploy das regras das PRs #81 e #82, junto com o merge delas.
- [ ] Política de privacidade publicada numa URL pública (#28).
- [ ] Página web para pedir a exclusão de conta.
- [x] Assinatura de release configurada (seção 2).
- [ ] Backup da chave de upload confirmado pelo proprietário.
- [ ] Versão da loja definida no `pubspec.yaml` (seção 5).

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
- [ ] Declaração de ID de publicidade: "não usa" (sem `AD_ID` no release; conferir no AAB).
- [ ] Acesso para a revisão: conta de teste com pets (e-mail e senha), para o revisor entrar.
- [ ] SHA-1 da chave de assinatura do Play App Signing cadastrada no Firebase (login com Google).
- [ ] Teste interno, depois teste fechado. Contas pessoais novas precisam de
      um teste fechado com testadores durante um período mínimo antes da
      produção; conferir no Play Console a regra em vigor.
- [ ] Produção com lançamento gradual (por exemplo 10%, 50%, 100%).

## 4. Segurança de dados (rascunho para a ficha)

| Dado | Quem fornece | Para quê | Compartilhado | Observação |
|---|---|---|---|---|
| Nome, e-mail, telefone, foto do tutor | tutor | conta e contato | Firebase/Google, Cloudinary, API no Render/MongoDB Atlas (operadores) | |
| Nome e e-mail da conta Google | Google, quando o tutor entra com Google | conta | Firebase Authentication | Só no login com Google (RF04-A). |
| Dados e fotos do pet, inclusive a galeria | tutor | perfil e galeria do pet | os mesmos | Galeria privada: só o dono vê. |
| Vacinas, consultas, histórico | tutor | saúde do pet | os mesmos | |
| Nome do pet e contato na página pública do QR | tutor | encontrar pet perdido | **visível a quem escanear** | Ligado à issue #35 (contato público). |
| Localização do avistamento | quem encontra o pet, pela página web | avisar o tutor | tutor do pet | Coletada no navegador de quem escaneia, não pelo app. |
| Cartaz de pet desaparecido (telefone autorizado, textos, fotos) | tutor | divulgar o desaparecimento | **ninguém pelo app**: o cartaz é gerado no celular e só sai quando o tutor compartilha | Não vai para servidor. |

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
| D2 | Assinatura | Play App Signing + chave de upload; chave própria sem Play App Signing | ✅ **Decidido e feito (2026-10-27):** chave de upload do proprietário; Play App Signing ao criar o app no Play Console | Perder a chave sem Play App Signing impede atualizar o app para sempre | Proprietário | Feita |
| D3 | Onde fica a chave de upload | só no computador do proprietário; também em segredo do GitHub Actions para build automático | ✅ **Em vigor:** só no computador do proprietário. Rever só se quiser build automático | Segredo no CI amplia quem pode assinar | Proprietário | Feita |
| D4 | Login social | remover os dois; esconder os botões; implementar | ✅ **Resolvida:** Google implementado (PR #87) e testado no release; Facebook fora do escopo, sem SDK e sem botão | — | — | Feita |
| D5 | Modo da 1ª versão | Firestore (flags desligadas); API em tudo (`USE_API_*` + URL do Render); só QR pela API | Firestore + `USE_API_QR`, com `API_BASE_URL` do Render | API no plano gratuito do Render dorme e demora ~2 min no primeiro acesso | Proprietário | Sim |
| D6 | Hospedagem da API para produção | Render gratuito; Render pago; outro | Render pago (sem hibernação), se a API for usada | Plano gratuito: primeira tela lenta e timeouts de 15 s no app | Proprietário | Sim (custo) |
| D7 | Crash reporting | Firebase Crashlytics; nenhum | Crashlytics, declarado na ficha e na política | Sem ele, falhas em produção ficam invisíveis | Claude implementa | Sim |
| D8 | Política de privacidade e exclusão web | página no Firebase Hosting (já usado pelo QR); site à parte | Firebase Hosting, junto da página do QR | Texto jurídico é responsabilidade do proprietário | Proprietário (texto); Claude (página) | Sim |

## 7. Ordem sugerida e estimativas

| Etapa | Depende de | Quem | Estimativa |
|---|---|---|---|
| ~~Deploy das regras de isolamento e da galeria~~ | — | Proprietário | ✅ 2026-10-27 |
| ~~Login social (D4) e build de release com R8~~ | D4 | Claude | ✅ PR #87; APKs de release testados |
| ~~Assinatura de release no Gradle~~ | D2 | Claude | ✅ 2026-10-27 |
| Confirmar a ausência do catch-all e publicar as regras das PRs #81 e #82 | — | Proprietário (Claude compara o texto) | 1 h |
| Política de privacidade e página de exclusão | D8, #28 | Proprietário + Claude | 1 a 2 dias |
| Crashlytics | D7 | Claude | 0,5 dia |
| Primeiro AAB (a chave já existe) | D1, D5 | Proprietário | 1 h |
| Ficha, capturas, classificação, segurança de dados | todas acima | Proprietário (Claude ajuda nos textos) | 1 dia |
| Teste interno e teste fechado | ficha | Proprietário + testadores | período mínimo da Play |
| Produção gradual | teste fechado | Proprietário | 1 semana acompanhando |
