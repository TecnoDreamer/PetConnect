# Handoff — estado da migração e próximos passos

> Documento vivo para retomar o trabalho (por mim numa próxima sessão ou por outra pessoa).
> Atualizado em 2026-09-11, FASE 11 fechada (rate limiting + Firestore Rules passos 1 e 2, todos deployados e verificados em produção).
> Estado-base de 2026-10-26 (depois das entregas de UI, Memorial e Android): ver [seção 8](#8-estado-base-em-2026-10-26).

---

## 1. Onde estamos

| Fase | Estado |
|---|---|
| 0 — Backup + auditoria + decisões | ✅ |
| 1 — Esqueleto do backend Spring | ✅ |
| 2 — Auth Firebase + `/api/v1/me` | ✅ verificada e2e |
| 3 — Migração de dados (`users`/`pets`/`locations`) | ✅ rodada real: 11 users, 21 pets, 64 locations |
| 4 — Feature **Tutor** via API | ✅ verificada e2e (flag `USE_API_USUARIO`) |
| 5 — Feature **Pets** via API | ✅ verificada e2e (flag `USE_API_PETS`) |
| 6 — Feature **Vacinas** | ✅ verificada e2e (flag `USE_API_VACINAS`) |
| 7 — Feature **Consultas** | ✅ verificada e2e (flag `USE_API_CONSULTAS`) |
| 8 — Feature **Histórico Médico** | ✅ verificada e2e (flag `USE_API_HISTORICO`) |
| 9 — QR + página pública | ✅ **parcial** — API pública ok (flag `USE_API_LOCALIZACAO` no lado autenticado); página web + URL real do QR pendentes de hospedagem (usuário: "só local por enquanto") |
| 10 — Upload assinado (Cloudinary) | ✅ **código pronto e testado** (flag `USE_API_UPLOAD`); round-trip real pendente da API Secret do usuário |
| **11 — Endurecer Firestore Rules + rate limiting** | ✅ **fechada** — rules passos 1 e 2 deployados/verificados + rate limiting nos endpoints públicos (ver seção 5). Endurecimento final de `Usuarios`/`Pets` deliberadamente adiado (gated em uso real) |
| **12 — Settings + validação total** | 🚧 **em andamento** — settings já migrado (era um sub-produto da FASE 4) e `auth_flow_test.dart` reescrito contra emulador+API (ver seção 6); resto depende de staging/uso real/decisão do usuário |
| 13 | pendente (ver seção 6) |

Todas as flags default **off** — sem `--dart-define`, o app roda 100% Firebase, como sempre.

**Repositórios**
- App Flutter: `C:\Users\Aleksander\Projetos\Mobile - Flutter\PetConnect` — `github.com/AleksGustavo/PetConnect`, branch `feature/backend-spring-mongodb-migration`.
- Backend: `C:\Users\Aleksander\Projetos\Mobile - Flutter\PetConnect-API` — `github.com/AleksGustavo/PetConnect-API` (privado), branch `main`.

**Docs da migração** (repo do app, `docs/`): `audit/current-state.md` · `database/{firestore-current-schema,firestore-data-report,mongodb-target-schema}.md` · `migration/firestore-to-spring-mongodb.md` (plano mestre, fonte da verdade fase a fase) · `security/firestore-rules-deployed.md` · este `handoff.md`.

---

## 2. Como subir o ambiente

Pré-requisito: **Docker** (a API não sobe via `mvn spring-boot:run` direto nesta máquina — ver seção 3).

```bash
cd "C:/Users/Aleksander/Projetos/Mobile - Flutter/PetConnect-API"
docker compose up -d --build        # mongo (27018) + api (8090)
docker compose logs -f api
curl http://localhost:8090/api/v1/ping
```

Depois de mudar código do backend: `docker compose up -d --build api` (se o build falhar por
tropeço de download do Maven, é transiente — repetir).

| Serviço | Endereço |
|---|---|
| API | `http://localhost:8090` (Swagger em `/swagger-ui.html`) |
| MongoDB | `mongodb://localhost:27018/petconnect` |

**Rodar o app com a API:**
```bash
cd "C:/Users/Aleksander/Projetos/Mobile - Flutter/PetConnect"
adb reverse tcp:8090 tcp:8090   # celular por USB
flutter run \
  --dart-define=API_BASE_URL=http://localhost:8090 \
  --dart-define=USE_API_USUARIO=true --dart-define=USE_API_PETS=true \
  --dart-define=USE_API_VACINAS=true --dart-define=USE_API_CONSULTAS=true \
  --dart-define=USE_API_HISTORICO=true --dart-define=USE_API_LOCALIZACAO=true \
  --dart-define=USE_API_UPLOAD=true
```
- Emulador Android: `--dart-define=API_BASE_URL=http://10.0.2.2:8090` (sem `adb reverse`).
- Sem nenhum `--dart-define`: 100% Firebase.

**Testes**
```bash
# backend (JDK 21 + Maven, Mongo embarcado): 72 testes
cd "…/PetConnect-API" && mvn -q -B test
# app: flutter analyze + 25 testes
cd "…/PetConnect"     && flutter analyze && flutter test test/core/ test/features/pet/
```

**Re-rodar a migração** (idempotente):
```bash
cd "…/PetConnect-API"
MONGODB_URI="mongodb://localhost:27018/petconnect" \
  mvn -q -B spring-boot:run -Dspring-boot.run.profiles=dev,migration \
  "-Dspring-boot.run.arguments=--petconnect.migration.source=C:/Users/Aleksander/Documents/backup-firestore/firestore_backup.json"
```

**e2e contra a API real** (padrão usado em todas as fases — molde em
`C:\Users\ALEKSA~1\AppData\Local\Temp\claude\...\scratchpad\e2e-fase*.js`, que não sobrevive
entre sessões — recriar quando precisar): script Node usando `firebase-admin` (o mesmo
`node_modules` de `C:\Users\Aleksander\Documents\backup-firestore\`) pra mintar um custom token
de um uid, trocar por ID token real via `identitytoolkit.googleapis.com`, e bater na API com
`fetch`. Rodar sempre **de dentro** da pasta com `node_modules` (copiar o script pra lá
temporariamente e apagar depois).

---

## 3. Fatos e armadilhas

- **Loopback / NIO Selector:** nesta máquina `Selector.open()` falha (`Unable to establish loopback connection`, AF_UNIX). Quebra (a) init do `firebase-admin` — contornado com `NetHttpTransport` no `FirebaseConfig` — e (b) start do Tomcat — contornado rodando a API em **container Linux** (`CloudinaryHttpClient` também usa `SimpleClientHttpRequestFactory` por cautela, embora dentro do container isso não seja necessário). `flutter run` para device **funciona** (só o APK de release e servidor Java direto no Windows são afetados). Também quebra o **Firestore Emulator** (é Java) — só o **Auth Emulator** (Node.js) funciona sem contorno nesta máquina.
- **`flutter test --platform=chrome` não funciona direto nesta máquina (achado na FASE 12):** falha mesmo num smoke test trivial, sem relação com nenhum teste específico — `Connection closed before test suite loaded.`, às vezes trava sem erro nenhum por vários minutos (CPU do processo Dart fica parada, não é só lento). Mesma família do bug de loopback do Windows.
  - **Tentativa de contorno via container Linux (`tool/web-test/Dockerfile`):** resolve o travamento acima — Flutter+Chrome dentro de um container Ubuntu compilam e o teste chega a carregar no navegador (progresso real, confirmado). Achado no caminho: o Chrome trava silenciosamente sem `--no-sandbox --disable-dev-shm-usage` (sandbox do Chrome precisa de privilégios de namespace que o container não tem por padrão) — corrigido com um wrapper (`CHROME_EXECUTABLE=/usr/local/bin/chrome-no-sandbox`) que já está no Dockerfile.
  - **Novo bloqueio, ainda sem solução:** com o sandbox corrigido, `setUpAll` (que faz `Firebase.initializeApp` + `useAuthEmulator`) trava até o timeout de 12 minutos do próprio `flutter test`, sem lançar nenhuma exceção — mesmo com conectividade container→host confirmada por `curl` (a `curl http://host.docker.internal:9099/...` de dentro do mesmo container responde 200 normalmente). Ou seja, o `curl` bruto funciona, mas o SDK JS do Firebase dentro do Chrome fica pendurado — suspeita (não confirmada) é o SDK do Firebase Auth para Web esperando por algo relacionado a `IndexedDB`/armazenamento persistente que se comporta diferente num Chrome rodando `--no-sandbox` como root sem perfil normal. Não investigado mais a fundo — diminishing returns pra uma sessão.
  - **Conclusão prática:** o `Dockerfile` fica no repo (é progresso real e documentado, não descartado), mas `auth_flow_test.dart` continua **não executado com sucesso** em lugar nenhum ainda. O caminho mais provável de dar certo sem mais esforço de infra: **CI real (GitHub Actions, `ubuntu-latest`)** — milhares de projetos Flutter rodam `flutter test --platform=chrome` exatamente assim, sem as camadas extras de container-dentro-de-container que este contorno precisou empilhar.
- **Portas:** 8080/27017 do host costumam estar ocupadas → API em **8090**, Mongo em **27018**.
- **Firebase Storage morto** (billing encerrado): 18 imagens legadas viraram `photoUrl: null` + aviso `storage-image-lost`. Só sobrevivem URLs Cloudinary (2 users, 3 pets).
- **Credencial Firebase:** `C:\Users\Aleksander\Documents\pet-connect-c53f1-firebase-adminsdk-t8ctg-326661da99.json` (fora dos repos). Montada read-only no container via `.env` (`FIREBASE_SA_PATH`).
- **Credencial Cloudinary (nova, FASE 10):** falta `CLOUDINARY_API_KEY`/`CLOUDINARY_API_SECRET` — pegar em https://console.cloudinary.com → Dashboard. Adicionar no `.env`/`compose.yaml` do backend (mesmo padrão da chave do Firebase — nunca no git). Sem isso, `/api/v1/uploads/**` responde 503 `UPLOAD_NOT_CONFIGURED` (verificado, não quebra o resto da API).
- **Firestore Rules**: endurecidas na FASE 11 (catch-all/`Pets`/`Localizacoes` exigem login; `Localizacoes` write travado de vez). `Usuarios`/`Pets` ainda **não** foram travados (`if false`) — o app antigo, usado pelos 18 usuários reais, ainda lê essas coleções direto do Firestore. Texto completo + histórico em `docs/security/firestore-rules-deployed.md`, seção 5 abaixo.
- **Pegadinha de regras do Firestore (aprendida na FASE 11 passo 2):** blocos `match` se somam por OR, não por especificidade — um `if false` num bloco específico não vence um `if true`/`auth != null` mais permissivo de um catch-all que também casa o mesmo caminho. Pra excluir um caminho do catch-all, indexar `request.path[N]` (tipo `path` do Firestore não tem `.size()` — dá erro de tipo silencioso, tratado como `false`, o que bloquearia TUDO se usado sem querer no catch-all). Sempre verificar via REST direto depois de deployar, não só confiar no exit code do `firebase deploy`.
- **Web API key** (trocar custom token → ID token em e2e): `AIzaSyARaspdC-wNqVESmfVuJqPCg9wAbomoQrc`.
- **Feature flags** (`lib/core/config/app_config.dart`): `USE_API_USUARIO`, `USE_API_PETS`, `USE_API_VACINAS`, `USE_API_CONSULTAS`, `USE_API_HISTORICO`, `USE_API_LOCALIZACAO`, `USE_API_UPLOAD` — todas default `false`. Mais `API_BASE_URL`, `USE_API_QR` (QR regenerável) e `GALERIA_FOTOS` (galeria de fotos, só modo Firestore; ligar só depois do deploy das regras).
- **`publicId` do pet** é determinístico na migração (`UUID.nameUUIDFromBytes("pet:" + legacyFirestoreId)`) — não muda entre re-execuções da migração.
- **Contas borderline mantidas:** "Marcola" (`VW9SSk…`) e "registro" (`4nMLz8…`). Remover = adicionar em `LegacyMigrationService.EXCLUDED_USER_IDS` e re-rodar a migração.
- **Nota de segurança residual (FASE 10):** `DELETE /api/v1/uploads` não verifica posse do arquivo — qualquer usuário autenticado pode pedir a exclusão de qualquer URL Cloudinary da conta. Antes disso ninguém conseguia excluir nada; agora exige pelo menos login. Uma tabela de "quem subiu o quê" resolveria de vez — não implementada (escopo maior que o da fase).

---

## 4. Padrões estabelecidos (copiar nas próximas fases)

- **Repositório de API** (app): `watch*` = `Stream.fromFuture` (a API não tem stream); a tela invalida o provider (`ref.invalidate(xProvider(id))`) depois de criar/editar/excluir; listas com pull-to-refresh (`RefreshIndicator` + `AlwaysScrollableScrollPhysics`, inclusive no estado vazio).
- **Mapeamento**: `dd/MM/yyyy` ↔ ISO via `brToIso`/`isoToBr` (`lib/core/utils/br_date.dart`); `HH:mm` ↔ `HH:mm:ss` (`LocalTime` do Jackson); rótulos PT ↔ enum via `Map` estático no repositório.
- **Backend, sub-recurso do pet**: `@RequestMapping("/api/v1/pets/{petId}/<recurso>")`; todo método do `Service` começa chamando `petService.get(tutorId, petId)` (404 se o pet não é do tutor) + um `ownedOr404(petId, subId)` próprio pro sub-recurso. DTO de request com Bean Validation. `@DeleteMapping` → 204. Cascata em `PetService.delete` (nem todo sub-recurso tem `DELETE` próprio — ex.: consultas, cancelar é status).
- **Endpoint público** (sem auth): path sob `/api/v1/public/**`; entra em **dois** lugares — `SecurityConfig.PUBLIC_PATHS` **e** `FirebaseTokenAuthenticationFilter.shouldNotFilter` (senão um `Bearer` inválido enviado por engano derruba a rota com 401 antes do controller). Resposta é sempre um DTO mínimo — nunca `tutorId`/e-mail/telefone pessoal.
- **Módulo sem entidade própria** (ex.: `upload/`): só `web/`+`application/`, sem `domain/`+`infrastructure/`. Chamada de saída de verdade (Cloudinary, etc.) isolada atrás de uma interface (`CloudinaryClient`) pra poder mockar em teste de controller.
- **Segredo novo → `503` gracioso**: uma feature que depende de credencial externa ainda não configurada nunca deve 500 nem vazar detalhe — `props.isConfigured()` + `ApiException` com um código específico (`UPLOAD_NOT_CONFIGURED`) e HTTP `503`.
- **`GlobalExceptionHandler`** cobre `HttpRequestMethodNotSupportedException`→405, `NoHandlerFoundException`/`NoResourceFoundException`→404, além do `ApiException`/validação/auth já cobertos desde a FASE 2.
- **Teste de controller**: `@SpringBootTest @AutoConfigureMockMvc` + `@MockitoBean FirebaseTokenVerifier` (rotas autenticadas — omitir em rotas públicas) + `@MockitoBean` de qualquer client externo (`CloudinaryClient`); usuários/pets salvos direto no repositório no `@BeforeEach`; `com.jayway.jsonpath.JsonPath.read(body, "$.id")` pra pegar ids de uma resposta.
- **Teste unitário puro** (sem `@SpringBootTest`, mais rápido) para lógica sem I/O — ex. `CloudinarySignerTest`/`CloudinaryUrlParserTest`. Vetores de referência conferidos rodando a mesma conta num script Node (`crypto.createHash`) antes de hard-codar no teste Java.
- **e2e**: sempre contra a API rodando de verdade (container), nunca só os testes automatizados — pegar um tutor migrado (`gjSwRiTU8wgjSCFBViyPjJqevAE3`, pet "Felícia" tem 5 avistamentos migrados) ou criar um usuário de teste efêmero, e sempre limpar no final.

---

## 5. FASE 11 — Endurecer Firestore Rules + rate limiting (✅ fechada)

Diferente das fases anteriores, esta mexe no **Firestore**, não no backend novo — é a fase
onde o risco de quebrar o app antigo (que os 18 usuários reais ainda usam) é real. Por isso:
antes de cada mudança, parei e confirmei com o usuário; depois de deployar, verifiquei via
REST (anônimo vs. autenticado) em vez de só confiar que "deve ter funcionado".

### 5.1 Passo 1 — ✅ feito e verificado (2026-09-11)
- `firestore.rules` criado na raiz do repo do app + referenciado em `firebase.json` (antes só
  existia como texto colado no console/chat).
- Catch-all, `Pets` e `Localizacoes` passaram a exigir `request.auth != null` — fechou só o
  acesso **sem nenhum login**; nada que já exigia auth mudou de comportamento.
- **Antes de mexer em `Localizacoes` write**, perguntei ao usuário se ainda havia algum fluxo
  público real (página/Cloud Function) escrevendo lá — confirmado que não, então já fechei a
  escrita também (não só a leitura).
- Deploy: `firebase deploy --only firestore:rules --project pet-connect-c53f1` (CLI já estava
  autenticado nesta máquina). **Só rodei depois de confirmação explícita do usuário** — é uma
  mudança em produção, diferente de tudo que veio antes (containers/testes locais).
- Verificação pós-deploy (script no scratchpad, sem precisar do app): `GET` anônimo em
  `Pets`/`Localizacoes` → `403 PERMISSION_DENIED` (antes: 200); com um ID Token real → `200`
  continua igual (leitura do próprio `Usuarios`, query em `Pets`).
- Histórico completo (regra antiga vs. nova, análise) em `docs/security/firestore-rules-deployed.md`.

### 5.2 Rate limiting nos endpoints públicos — ✅ feito e verificado (2026-09-11)
- Backend: `RateLimiter` (componente em memória, janela deslizante) + `RateLimitProperties`
  (`petconnect.rate-limit.{public-read,public-write}-per-minute`, default 30/10) +
  `PublicEndpointRateLimitFilter` (`OncePerRequestFilter`, só age em `/api/v1/public/**`,
  chave = IP + read/write, 429 `RATE_LIMITED` no envelope padrão de erro).
- Registrado em `SecurityConfig` via `addFilterBefore`. Config de teste com limites bem
  generosos (1000/min) pra não interferir nos testes existentes; teste dedicado
  (`PublicEndpointRateLimitFilterTest`, 4 casos) usa `@TestPropertySource` com limites baixos
  (3/2) pra exercitar o 429 de verdade — contexto Spring separado, não contamina o resto.
  **72/72 testes passando** (68 de antes + 4 novos).
- Verificado ao vivo contra o container Docker reconstruído: 33 requisições seguidas em
  `GET /api/v1/public/pets/x` → as 30 primeiras passam (404, pet não existe, mas prova que o
  filtro roda antes do controller), as 3 seguintes voltam `429`; mesmo padrão pro `POST
  .../sightings` (10/min). Corpo do 429 confirmado como o `ApiError` padrão.
- Não distribuído (limitação documentada no código) — se algum dia rodar mais de um pod/réplica
  da API, precisa virar contador compartilhado (Redis, por ex.).

### 5.3 Passo 2 — `Localizacoes` write travado de vez — ✅ feito e verificado (2026-09-11)
- Mudança: `Localizacoes` (coleção raiz) → `allow write: if false` (leitura autenticada
  continua liberada, é só histórico).
- **Achado durante a verificação (não durante o code review — só apareceu testando de
  verdade):** o primeiro deploy pareceu ter funcionado (CLI sem erro), mas um teste real via
  REST mostrou que a escrita autenticada **ainda passava**. Causa: regras do Firestore se
  somam por OR entre blocos `match` — o catch-all `/{document=**}` também casa
  `Localizacoes/{docId}` e concedia `write: if request.auth != null`, que vencia por cima do
  `if false` mais específico (Firestore não tem "mais específico vence"). Corrigido excluindo
  `Localizacoes` do catch-all.
- **Segundo problema, também achado testando:** a primeira tentativa de exclusão usava
  `document.size()` (`document` = variável do wildcard `{document=**}`, tipo `path`) — `path`
  não tem `.size()`, erro de tipo silencioso que o Firestore avalia como `false`, o que
  **derrubaria a escrita de QUALQUER coleção**, não só `Localizacoes` (confirmado: um POST
  autenticado numa coleção de teste não-relacionada voltou 403 inesperado). Corrigido
  indexando `request.path[3]` (posição fixa do nome da coleção raiz: 0=databases, 1=db,
  2=documents, 3=coleção) em vez da variável do wildcard — sem warning de tipo no `firebase
  deploy`, testado e confirmado: `Localizacoes` write → 403; coleção não-relacionada → volta a
  200; subcoleção real `Pets/{petId}/localizacoes` (usada pelo app antigo) → não afetada.
- Todos os documentos de teste criados durante a verificação (2 em `Localizacoes`, 1 numa
  coleção de scratch, 1 na subcoleção `Pets/x/localizacoes`) foram apagados via Admin SDK
  logo em seguida.
- **Lição geral:** deploy sem erro ≠ regra funcionando como esperado. Regras do Firestore não
  têm precedência por especificidade — sempre testar o efeito real via REST (autenticado E
  anônimo, no caminho que mudou E num caminho não-relacionado) antes de dar como fechado.

### 5.4 O que falta (deliberadamente não feito — sem urgência)
1. **Endurecimento final:** `allow read, write: if false` em `Usuarios`/`Pets` (as coleções
   que já têm equivalente 100% funcional na API). Gated em uso real validado das FASES 4–10
   (não só e2e) — os 18 usuários reais ainda rodam o app antigo com as flags `USE_API_*` off
   por padrão, que lê essas coleções direto do Firestore. Fechar agora quebraria o app pra
   eles. Só fazer depois de uso real validado com as flags ligadas, ou na FASE 13.
2. App Check / reforço de auth — avaliar junto com o item 1.
3. CORS/headers de segurança adicionais no backend — CORS básico já existe desde a FASE 2
   (`CorsProperties`/`SecurityConfig`), isto seria endurecimento extra, não coberto ainda.

### 5.5 Lição pra próxima vez que mexer em regras de produção
Sempre: (a) confirmar com o usuário a suposição de que "nada real depende disso" antes de
restringir algo que hoje é público — não presumir; (b) pedir confirmação explícita antes do
`firebase deploy` em si, separada da confirmação de "seguir com a fase"; (c) verificar
depois via requisição real (autenticada e anônima, no caminho que mudou **e** num caminho
não-relacionado — para pegar efeitos colaterais no catch-all), não só "deployou sem erro";
(d) lembrar que blocos `match` do Firestore se somam por OR, nunca por especificidade.

---

## 6. FASE 12 — Settings + validação total (🚧 em andamento)

### 6.1 Settings — ✅ nada a fazer (2026-09-11)
Checado antes de escrever qualquer código: `ConfiguracoesScreen`/`EditarPerfilScreen` já usam
`usuarioRepositoryProvider` desde a FASE 4 (branch pela flag `USE_API_USUARIO`), e `grep -rl
cloud_firestore lib` só acha os `Firebase*Repository` (mantidos de propósito até a FASE 13) +
o provider que expõe `firestoreProvider`. Não existiam preferências "soltas" (tema,
notificações etc.) fora do que cada fase já migrou junto com sua feature.

### 6.2 `auth_flow_test.dart` reescrito — ✅ feito, ⚠️ não executado nesta máquina (2026-09-11)
Antes: `Firebase.initializeApp` contra o projeto **real**, criava um usuário de Auth de
verdade a cada rodada (por isso fora do CI). Agora:
- `FirebaseAuth.instance.useAuthEmulator('localhost', 9099)` — auth fala com o **Auth
  Emulator** local, nunca com produção.
- Teste roda com `--dart-define=USE_API_USUARIO=true` — o perfil do tutor vai pra API+Mongo
  reais (`ApiUsuarioRepository`), não pro Firestore. Não precisa do Firestore Emulator (que é
  Java e esbarraria no mesmo bug de loopback que afeta o Tomcat nesta máquina — seção 3).
- `tearDownAll` limpa os dois lados: `DELETE /api/v1/me` (via `http`, com o ID token do
  usuário) + `user.delete()` no emulador.

**Validado nesta sessão, isoladamente, antes de reescrever o teste:**
1. `firebase emulators:start --only auth` sobe e responde nesta máquina (Node.js, não JVM —
   não pega o bug de loopback).
2. Um usuário criado via REST do emulador (`identitytoolkit.googleapis.com` local) gera um ID
   Token que a API real (`FIREBASE_AUTH_EMULATOR_HOST=host.docker.internal:9099` no
   container) **aceita de verdade**: `GET /api/v1/me` provisionou o usuário no Mongo, `DELETE
   /api/v1/me` removeu — confirmado via `curl`, não só lido no código do Admin SDK.
3. `flutter analyze` no arquivo reescrito: sem problemas.

**Não validado — tentado o contorno via container, chegou mais longe mas ainda não passa**
(detalhe completo na seção 3): `flutter test --platform=chrome` não roda direto nesta máquina
(mesma família do bug de loopback do Windows). Tentei o contorno óbvio — rodar dentro de um
container Linux, como já fizemos pra API — em `tool/web-test/Dockerfile`: resolve o
travamento original (Flutter+Chrome compilam e o navegador abre), achou e corrigiu um
problema real no caminho (sandbox do Chrome precisa de `--no-sandbox` dentro de container),
mas esbarrou num novo bloqueio — `setUpAll` trava 12 minutos sem erro, com conectividade
container→host confirmada por `curl` mas o SDK JS do Firebase preso em algo (suspeita:
IndexedDB/storage num Chrome `--no-sandbox` como root). Não investigado mais a fundo.
**Ação:** reverti tudo que toquei pra estado normal (parei o Auth Emulator, tirei
`FIREBASE_AUTH_EMULATOR_HOST` do container — confirmado que a API voltou a aceitar token
real) antes de encerrar; o `Dockerfile` fica no repo como progresso real documentado, não
descartado. O teste em si está pronto e a lógica foi validada peça por peça; falta confirmar
rodando de verdade — o caminho mais provável de dar certo é um CI real (GitHub Actions
`ubuntu-latest`), sem as camadas de container-dentro-de-container que o contorno local
precisou empilhar.

### 6.3 O que falta (fora do meu alcance sozinho)
1. **E2E por feature contra staging** — não há staging hoje (depende de hospedagem, já listado
   nas pendências gerais).
2. **Período de observação em produção com as flags ligadas** — precisa do usuário rodando o
   app novo de verdade por um tempo. Não dá pra simular isso numa sessão.
3. **Checklist RF01–RF32 assinado** — posso montar o mapeamento RF → implementação/teste
   quando pedido, mas "assinar" é decisão do usuário depois de validar em uso real.

---

## 6b. FASE 13 — Remover Firestore (resumo — detalhe no plano mestre)

Só depois de tudo validado em produção por um tempo: tirar `cloud_firestore` do
`pubspec.yaml`, apagar `firebase_*_repository.dart` e as flags (tudo passa a usar só
`Api*Repository`). `firebase_auth` **fica** (é a fonte de identidade pra sempre).

---

## 7. Pendências abertas

- **FASE 9:** página pública + URL real do QR — precisa de hospedagem (domínio/host).
- **FASE 10:** `CLOUDINARY_API_KEY`/`CLOUDINARY_API_SECRET` reais — sem isso o round-trip de upload assinado não foi testado contra o Cloudinary de verdade (só o código + os 503 graciosos).
- **FASE 11:** fechada. Único item deliberadamente adiado: endurecimento final (`Usuarios`/`Pets` → `if false`), que espera uso real validado das flags `USE_API_*` (não só e2e) — ver seção 5.4.
- **CI do backend:** não há GitHub Actions ainda. Sugerido: workflow `mvn -B test`.
- **Hospedagem staging:** MongoDB Atlas M0 + host free — só quando for testar fora do localhost.
- **Validação amostral manual** da FASE 3: 1 spot-check feito (Nymeria/Aleksander OK); conferir mais alguns.
- **Contas borderline** "Marcola"/"registro": confirmar remoção com o usuário.
- **`auth_flow_test.dart`** ainda bate no Firebase real, fora do CI — reescrever na FASE 12.
- **APK de release** (loopback) segue sem solução no Windows; não bloqueia a migração (`flutter run` pra device funciona).
- **Validação no device**: nenhuma das flags foi testada de verdade no celular do usuário ainda — só e2e via script contra a API. Vale rodar com todas ligadas numa sessão e comparar com o Firestore.

---

## 8. Estado-base em 2026-10-26

Registrado na Fase 0 do plano de próximos passos (organização, sem mudança funcional).

**Repositório.** O repositório canônico agora é `TecnoDreamer/PetConnect`; o remote
local `AleksGustavo/PetConnect` redireciona para ele. Base de todas as PRs:
`feature/backend-spring-mongodb-migration` (o default do GitHub continua `main`,
parado em 2026-08-19). Base em `aa483d1` (merge da PR #71).

**Entregue e mesclado desde a seção 7** (PRs para a base, todas com CI verde):

| PR | Entrega | Doc |
|---|---|---|
| #62 | Confirmação ao cancelar consulta (fecha #26) | `docs/features/confirmacao-cancelamento-consulta.md` |
| #66 | Card do Login estável | `docs/features/login-layout-static-fix.md` |
| #68 | Cadastro estático, card na frente do cabeçalho (fecha #65) | `docs/features/cadastro-layout-estatico.md` |
| #69 | Telas de autenticação com identidade fixa (ADR 0001) | `docs/features/auth-theme.md` |
| #70 | Memorial do Pet, só modo Firestore (ADR 0002, fecha #40) | `docs/features/memorial-pet.md` |
| #71 | Home: linha "Meus Pets" sem overflow com fonte ampliada | — |
| #72 | Login com altura distribuída (`ComposicaoCabecalhoPainel`) | `docs/features/login-layout-distribuido.md` |
| #73 | Nome "PetConnect", ícone oficial e splash nativa (ADR 0003) | `docs/branding/icone-e-splash-android.md` |
| #74 | Tema Claro como principal, fundo branco | `docs/features/theme-and-settings-menu.md` |

Quality gates na base (`dart format`, `flutter analyze`, `flutter test test/core/
test/features/pet/ test/features/auth/ test/features/usuario/ test/android/
--exclude-tags=e2e`): verdes, 261 testes, rodados localmente em 2026-10-26.

**Pendências, em ordem de prioridade:**

1. **Segurança do Firestore (#31) — crítica.** No `firestore.rules` versionado (igual
   ao deployado em 2026-09-11, segundo `docs/security/firestore-rules-deployed.md`),
   o catch-all `match /{document=**}` com `allow write: if request.auth != null`
   também casa `Usuarios/{id}` e `Pets/{id}`. Como blocos `match` somam por OR, as
   condições de dono (`request.auth.uid == resource.data.userId`/`uid`) **não têm
   efeito**: qualquer usuário logado consegue alterar ou apagar perfis e pets de
   outros tutores, além das subcoleções. Leitura de `Usuarios` e `Pets` também é
   aberta a qualquer usuário logado. A análise de 2026-09-11 em
   `firestore-rules-deployed.md` e os docs do Memorial tratavam essas regras de dono
   como efetivas; foram corrigidos nesta data. A proposta em
   `docs/security/memorial-pet.md` (não deployada) só excluía as subcoleções do
   catch-all. Conclusão pela leitura das regras, não testada contra produção.
   Correção planejada na Fase 1, sem deploy sem aprovação. Atenção à seção 5.4: o app antigo dos usuários reais lê essas
   coleções direto do Firestore, então isolamento por dono precisa ser compatível
   com ele (não é o mesmo que `if false`).
   **Andamento:** regras de isolamento por dono e testes no emulador (CI) prontos em
   `firestore.rules` e `tool/firestore-rules/`; deploy pendente de aprovação. Ver
   `docs/security/firestore-isolamento-por-dono.md`.
2. **Tema nas telas restantes (#56).** Vacinas, consultas, histórico e localização
   ainda usam `AppColors` fixo. O título da issue cita Login e Cadastro, mas essas
   telas têm identidade fixa por decisão (ADR 0001) e saem do escopo.
   **Andamento:** feito na PR #77 (mesclada em 2026-10-27).
3. **QR regenerável (#29)**, depois **privacidade/contato público (#35)**.
   **Andamento:** implementado no app e na API (`feat/qr-regeneravel` nos dois
   repositórios), desligado por padrão (`USE_API_QR`) até a API ser publicada.
   Ver `docs/features/qr-regeneravel.md` e ADR 0004.
4. **Publicação (#28 e assinatura):** release assinado com a chave de debug, sem
   política de privacidade. Só planejamento por enquanto.
5. **Validação no aparelho (#33)** — no Project está "In review"; checklists em
   `docs/validation/`.
6. Itens da seção 7 que continuam valendo: hospedagem/staging, credenciais reais do
   Cloudinary, CI do backend, APK de release no Windows (loopback).

**Branches já mescladas que ainda existem no GitHub** (nenhuma protegida; apagar
só com autorização do proprietário): `feat/memorial-pet`,
`fix/android-icone-inicializacao-petconnect`, `fix/auth-tema-identidade-original`,
`fix/cadastro-sobreposicao-layout-estatico`, `fix/home-overflow-fonte-grande`,
`fix/login-layout-distribuido`, `fix/tema-claro-padrao-fundo-branco`,
`fix/qr-code-pet-publico` (PR #19). A `fix/cadastro-tela-estatica-sem-scroll`
(PR #64, fechada sem merge, substituída pela #68) tem 6 commits fora da base:
apagá-la descarta esse trabalho, que não é usado.
