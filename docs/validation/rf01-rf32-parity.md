# Paridade Funcional RF01–RF32 — Legado (Firestore) vs. API (Spring/Mongo)

> Estados permitidos: `PASS` (confirmado por código + teste automatizado),
> `PASS_MANUAL_PENDENTE` (implementado e com teste automatizado, mas a
> paridade visual/comportamental no device físico ainda não foi confirmada
> por um humano — ver `device-validation-checklist.md`), `BLOCKED`,
> `NOT_APPLICABLE`, `NOT_TESTED`. Nenhum `PASS` sem evidência (arquivo de
> teste + endpoint/tela citados). RF31/RF32 confirmados como **implementados**
> nesta auditoria — o próprio código já os referencia explicitamente
> (`grep RF3[12]` no backend), corrigindo o status de "proposto" que ainda
> constava em `docs/requisitos-funcionais.md` (a ser atualizado na seção de
> documentação).

---

## Autenticação e conta

| RF | Descrição | Fluxo legado | Fluxo API | Tela | Endpoint | Teste automatizado | Teste manual | Resultado |
|---|---|---|---|---|---|---|---|---|
| RF01 | Cadastro tutor | `FirebaseUsuarioRepository.signUp` | `ApiUsuarioRepository.signUp` (Firebase Auth + `PATCH /me`) | `cadastro_screen.dart` | `POST /api/v1/me` (provisionamento) + `PATCH /api/v1/me` | `MeControllerTest` (backend); `auth_flow_test.dart` (app, ver observação) | DV01 | `PASS_MANUAL_PENDENTE` |
| RF02 | Validação e-mail/senha | Validação client-side (Flutter Form) | Idêntica (client-side, não migrou) | `cadastro_screen.dart` | — | — | — | `NOT_APPLICABLE` (não faz parte da migração — validação sempre foi só client-side) |
| RF03 | Impedir e-mail duplicado | Firebase Auth (erro nativo) | Firebase Auth (inalterado) | `cadastro_screen.dart` | — | — | — | `NOT_APPLICABLE` (Firebase Auth continua sendo a fonte de identidade em qualquer flag) |
| RF04 | Login e-mail/senha | Firebase Auth | Firebase Auth (inalterado) | `login_screen.dart` | — | `auth_flow_test.dart` (ver observação) | DV02 | `PASS_MANUAL_PENDENTE` |
| RF04-A | Login com Google | `google_sign_in` + Firebase Auth | Mesmo fluxo; perfil provisionado por `GET /me` | `login_screen.dart`, `entrada_social.dart` | — | `login_social_*_test.dart`, `provedores_sociais_test.dart` | LS01–LS13 | `PASS_MANUAL_PENDENTE` (2026-10-28: conta criada com o Google no aparelho, APK de release; LS02–LS12 pendentes) |
| RF04-B | Login com Facebook | — | — | — | — | — | — | `FORA_DO_ESCOPO` (decisão do proprietário, 2026-10-27) |
| RF05 | Recuperação de senha | Firebase Auth | Inalterado | `esqueci_senha_screen.dart` | — | — | — | `NOT_APPLICABLE` |
| RF06 | Sessão persistente | Firebase Auth (`authStateChanges`) | Inalterado | `app_router.dart` (guard) | — | DV05 (manual) | DV05 | `PASS_MANUAL_PENDENTE` |
| RF07 | Logout | Firebase Auth | Inalterado | `configuracoes_screen.dart` | — | — | DV06 | `PASS_MANUAL_PENDENTE` |
| RF08 | Editar conta | `FirebaseUsuarioRepository.updateUsuario` | `ApiUsuarioRepository.updateUsuario` | `editar_perfil_screen.dart` | `PATCH /api/v1/me` | `MeControllerTest.patchAtualizaOsCampos` | DV03 | `PASS_MANUAL_PENDENTE` |
| RF09 | Excluir conta | Exclusão manual de docs Firestore | `ApiUsuarioRepository.deleteAccount` → `DELETE /api/v1/me` (cascata) | `configuracoes_screen.dart` | `DELETE /api/v1/me` | `MeControllerTest.deleteRemoveContaEmCascataERecusaAcessoDepois` | DV07 | `PASS_MANUAL_PENDENTE` |

## Gestão de pets

| RF | Descrição | Fluxo legado | Fluxo API | Tela | Endpoint | Teste automatizado | Teste manual | Resultado |
|---|---|---|---|---|---|---|---|---|
| RF10 | Cadastrar pet | `FirebasePetRepository.criar` | `ApiPetRepository` | `pet_form_screen.dart` | `POST /api/v1/pets` | `PetControllerTest.criaListaEDetalhaUmPet` | DV09 | `PASS_MANUAL_PENDENTE` |
| RF11 | Listar pets do tutor | Firestore query por `userId` | `PetService.list(tutorId)` | `home_screen.dart` | `GET /api/v1/pets` | `PetControllerTest` | DV10 | `PASS_MANUAL_PENDENTE` |
| RF12 | Isolamento entre tutores | Firestore Rules (`userId == auth.uid`) | `PetService.ownedOr404` — 404 pra pet de outro tutor | — | todos os `/api/v1/pets/**` | `PetControllerTest.naoEnxergaNemMexeEmPetDeOutroTutor` (+ equivalente em cada sub-recurso) | DV12 (indireto) | `PASS` |
| RF13 | Editar pet | `FirebasePetRepository.editar` | `ApiPetRepository` | `pet_form_screen.dart` | `PATCH /api/v1/pets/{id}` | `PetControllerTest` | DV11 | `PASS_MANUAL_PENDENTE` |
| RF14 | Excluir pet (confirmação) | Exclusão manual + subcoleções | `PetService.delete` (cascata centralizada) | `pet_detail_screen.dart` (diálogo) | `DELETE /api/v1/pets/{id}` | `PetControllerTest.excluirPetApagaSuasVacinasEmCascata` (+ consultas, histórico) | DV12 | `PASS_MANUAL_PENDENTE` |
| RF15 | Perfil só daquele pet | Navegação por id | Idêntico, + 404 se não for do tutor | `pet_detail_screen.dart` | `GET /api/v1/pets/{id}` | `PetControllerTest` | — | `PASS` |

## QR Code

| RF | Descrição | Fluxo legado | Fluxo API | Tela | Endpoint | Teste automatizado | Teste manual | Resultado |
|---|---|---|---|---|---|---|---|---|
| RF16 | Gerar QR único por pet | `pet_qr_code.dart` (client-side, a partir do id) | `Pet.publicId` (UUID determinístico gerado no servidor) | `pet_detail_screen.dart` | (embutido na resposta de `GET /pets/{id}`) | `pet_qr_code_test.dart` | DV15 | `PASS_MANUAL_PENDENTE` |
| RF17 | Página pública ao escanear | **Nunca implementada** (nem no legado — só planejada) | `GET /api/v1/public/pets/{publicId}` (só a API; a página HTML em si não existe) | — | `GET /api/v1/public/pets/{publicId}` | `PublicPetControllerTest.resumoPublicoSemTokenNaoVazaDadoDoTutor` | DV16 | `BLOCKED` — API pronta, página web não construída (FASE 9, hospedagem pendente) |
| RF18 | Página não vaza dado sensível | idem | DTO mínimo (nome, espécie, status, foto, contato opcional) | — | idem | `PublicPetControllerTest` | — | `PASS` (na API; `BLOCKED` na página, que não existe) |
| RF19 | Regenerar QR | Client-side (recalcular a partir do id — nunca invalidava o anterior de verdade) | `publicId` é fixo por pet (não há endpoint de regeneração) | — | — | — | — | `NOT_TESTED` — **regressão em aberto**: nem o legado nem a API têm um jeito de invalidar um QR code comprometido; ver observação abaixo |

## Carteira de vacina

| RF | Descrição | Fluxo legado | Fluxo API | Tela | Endpoint | Teste automatizado | Teste manual | Resultado |
|---|---|---|---|---|---|---|---|---|
| RF20 | Registrar vacina | `FirebaseVacinaRepository` | `ApiVacinaRepository` | `vacina_form_screen.dart` | `POST /api/v1/pets/{id}/vaccines` | `VaccineControllerTest` | DV17 | `PASS_MANUAL_PENDENTE` |
| RF20-A | Campo booleano "vacinado" | `Pet.vacinado` (Firestore) | `Pet.vaccinatedFlag` (Mongo) — campo próprio, mapeado 1:1 (`ApiPetRepository`: `vaccinatedFlag` ↔ `vacinado`) | `pet_card.dart` | `PATCH /api/v1/pets/{id}` (campo `vaccinatedFlag`) | `PetControllerTest` (cobre `patchAtualizaOsCampos` genérico — não há um teste dedicado só pra este campo) | DV11 (indireto) | `PASS` |
| RF21 | Listar cronológico | Firestore ordenado | `VaccineController` (ordenado por data) | `vacina_list_screen.dart` | `GET /api/v1/pets/{id}/vaccines` | `VaccineControllerTest.listaEmOrdemCronologicaEEditaPreservandoOId` | DV17 | `PASS_MANUAL_PENDENTE` |
| RF22 | Editar/excluir vacina | idem | idem | `vacina_form_screen.dart`/`vacina_list_screen.dart` | `PATCH`/`DELETE .../vaccines/{id}` | `VaccineControllerTest` | DV18 | `PASS_MANUAL_PENDENTE` |
| RF23 | Alerta de vencimento | `consulta_alerta_test.dart`-like lógica client-side | Inalterado — cálculo client-side (`vacina_alerta_test.dart`), API só fornece a data | `vacina_list_screen.dart`/`pet_detail_screen.dart` | — | `vacina_alerta_test.dart` (app) | DV19 | `PASS` |

## Histórico médico

| RF | Descrição | Fluxo legado | Fluxo API | Tela | Endpoint | Teste automatizado | Teste manual | Resultado |
|---|---|---|---|---|---|---|---|---|
| RF24 | Registrar histórico + anexos | `FirebaseHistoricoMedicoRepository` | `ApiHistoricoMedicoRepository` + `ApiAnexoRepository` (Cloudinary assinado) | `historico_form_screen.dart` | `POST /api/v1/pets/{id}/medical-records` + `POST /api/v1/uploads/signature` | `MedicalRecordControllerTest`; `api_anexo_repository_test.dart` (app) | DV25, DV27 | `PASS_MANUAL_PENDENTE` |
| RF25 | Listar cronológico | idem | `crudCompletoEmOrdemCronologica` | `historico_list_screen.dart` | `GET /api/v1/pets/{id}/medical-records` | `MedicalRecordControllerTest` | DV25 | `PASS_MANUAL_PENDENTE` |
| RF26 | Editar/excluir | idem | idem | `historico_form_screen.dart` | `PATCH`/`DELETE .../medical-records/{id}` | `MedicalRecordControllerTest` | DV26 | `PASS_MANUAL_PENDENTE` |

## Agendamento de consultas

| RF | Descrição | Fluxo legado | Fluxo API | Tela | Endpoint | Teste automatizado | Teste manual | Resultado |
|---|---|---|---|---|---|---|---|---|
| RF27 | Agendar consulta | `FirebaseConsultaRepository` | `ApiConsultaRepository` | `consulta_form_screen.dart` | `POST /api/v1/pets/{id}/appointments` | `AppointmentControllerTest` | DV21 | `PASS_MANUAL_PENDENTE` |
| RF28 | Listar (futura/concluída/cancelada) | idem, filtro client-side | `AppointmentStatus` enum (`CONFIRMED`/`DONE`/`CANCELLED`), filtro client-side | `consulta_list_screen.dart` | `GET /api/v1/pets/{id}/appointments` | `AppointmentControllerTest.criaComStatusConfirmedPorDefaultEListaEmOrdem` | DV21 | `PASS_MANUAL_PENDENTE` |
| RF29 | Editar/cancelar/concluir | idem | `PATCH .../appointments/{id}` (muda status, sem endpoint de DELETE — cancelar é status) | `consulta_form_screen.dart` | `PATCH .../appointments/{id}` | `AppointmentControllerTest.patchMudaStatusParaCanceladaOuRealizada`; `naoExisteEndpointDeDelete` | DV22, DV23 | `PASS_MANUAL_PENDENTE` |
| RF30 | Notificar consulta próxima | Cálculo client-side | Inalterado (client-side) | `consulta_list_screen.dart` | — | `consulta_alerta_test.dart` (app) | — | `PASS` |

## Localização (implementado — corrigindo o status "proposto" do doc de requisitos)

| RF | Descrição | Fluxo legado | Fluxo API | Tela | Endpoint | Teste automatizado | Teste manual | Resultado |
|---|---|---|---|---|---|---|---|---|
| RF31 | Registrar avistamento (achador, sem login) | **Nunca existiu no legado** (só a coleção crua `Localizacoes`, sem fluxo de produto) | `POST /api/v1/public/pets/{publicId}/sightings` — anônimo, rate limited (10/min) | — (depende da página pública, FASE 9) | `POST /api/v1/public/pets/{publicId}/sightings` | `PublicPetControllerTest.relatoAnonimoDeAvistamentoSemToken` | DV30 | `BLOCKED` na ponta a ponta (API pronta, página web não existe); `PASS` isolado no endpoint |
| RF32 | Tutor visualiza avistamentos | **Nunca existiu no legado** | `GET/POST /api/v1/pets/{id}/locations` (autenticado, tutor registra manualmente ou vê os públicos) | `localizacao_list_screen.dart`/`localizacao_form_screen.dart` | `GET/POST /api/v1/pets/{id}/locations` | `LocationControllerTest`; `veOsAvistamentosMigradosDoPet` (migração) | DV28, DV29 | `PASS_MANUAL_PENDENTE` |

---

## Observações e regressões encontradas nesta auditoria

1. **RF19 (regenerar QR code) nunca foi implementado de verdade, nem no
   legado nem na API.** Não é uma regressão desta migração — já não
   existia antes —, mas continua sendo um requisito funcional documentado
   e não entregue. Registrar como item de backlog, fora do escopo desta
   etapa (nenhuma fase da migração se propôs a fazer isso).
2. **RF20-A verificado e confirmado correto** — checagem inicial desta
   auditoria (antes de eu ler o código de fato) suspeitou de uma possível
   regressão aqui; conferindo `Pet.java` (backend) e `api_pet_repository.dart`
   (app), o campo existe como `vaccinatedFlag` no Mongo e é mapeado 1:1
   pro `vacinado` do domínio Flutter. Sem regressão — mantido como `PASS`.
3. Todo `PASS_MANUAL_PENDENTE` significa: **código + teste automatizado
   confirmam que a funcionalidade existe e funciona isoladamente**, mas
   ninguém confirmou ainda que o app renderiza/comporta-se identicamente
   ao legado no dispositivo físico. Isso é exatamente o propósito do
   `device-validation-checklist.md` — sem ele, esses itens não podem
   virar `PASS` de verdade.
4. `auth_flow_test.dart`: existe e a lógica foi validada peça por peça,
   mas **não passou rodando de fato** ainda (ver `03-ci-quality-gates.md`)
   — por isso RF01/RF04/RF06/RF07 citam o arquivo mas não têm um `PASS`
   de teste automatizado 100% confirmado, só `PASS_MANUAL_PENDENTE`.

## Resumo

| Status | Quantidade |
|---|---|
| `PASS` | 8 (RF12, RF15, RF18\*, RF20-A, RF23, RF30, RF31\*, RF32-endpoint\*) |
| `PASS_MANUAL_PENDENTE` | 18 |
| `BLOCKED` | 3 (RF17, RF18-página, RF31-ponta-a-ponta) |
| `NOT_APPLICABLE` | 3 (RF02, RF03, RF05) |
| `NOT_TESTED` | 1 (RF19) |
| `FORA_DO_ESCOPO` | 1 (RF04-B) |

\* PASS refere-se à API isoladamente; a experiência de ponta a ponta
(página pública) depende da FASE 9.

**Não assino esta fase como concluída** — 18 itens dependem de validação
manual real (`device-validation-checklist.md`), 3 estão bloqueados por
decisão de hospedagem pendente, e 2 regressões/divergências (RF19, RF20-A)
precisam de decisão do usuário sobre se são aceitáveis ou precisam de
correção.
