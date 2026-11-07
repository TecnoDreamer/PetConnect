# 04 — Matriz de Cobertura de Testes

> Complementa `docs/validation/rf01-rf32-parity.md` (que cobre requisito
> → implementação linha a linha). Este documento olha pela ótica inversa:
> **por camada de teste**, quanto cada tipo cobre.

---

## 7.1 Flutter — cobertura por feature

| Feature | Unitário/lógica | Widget (fluxo completo) | Integração (API real) | Estados cobertos |
|---|---|---|---|---|
| Autenticação | — | `auth_flow_test.dart` (não roda ainda, ver `03-ci-quality-gates.md`) | via `auth_flow_test.dart` quando desbloqueado | login, cadastro, logout, senha errada |
| Perfil | — | (dentro de `auth_flow_test.dart`) | — | — |
| Pets | — | `pet_management_test.dart` (cria/edita/exclui, 7 asserções) | `fake_pet_repository.dart` (fake, não API real) | loading/success/empty (ver `06-ux-ui-usability-audit.md`) |
| Vacinas | `vacina_alerta_test.dart` (4 casos: sem alerta, vencida, próxima, distante) | `vacina_management_test.dart` | fake | idem |
| Consultas | `consulta_alerta_test.dart` (6 casos) | `consulta_management_test.dart` (CT19/CT20) | fake | idem |
| Histórico médico | — | `historico_medico_test.dart` | fake | idem |
| Localização | — | `localizacao_management_test.dart` | fake | idem |
| QR Code | — | `pet_qr_code_test.dart` | — | — |
| Upload/anexo | — | `api_anexo_repository_test.dart` (mock HTTP, valida multipart + folder assinado) | mock, não Cloudinary real | erro de upload tratado (`describirErroUpload`) |
| `ApiClient` (núcleo) | `api_client_test.dart` (18 casos: header, erro, 401, rede, 204, nova tentativa, conexão nova e log) | — | — | — |

**Total**: 25 testes rodando em CI (VM, sem Chrome) + 1 bloqueado
(`auth_flow_test.dart`, precisa de Chrome + infra externa).

**Não cobertos por teste automatizado** (candidatos a novo teste, não
implementados nesta etapa por não serem regressão nem bloqueio):
timeout de rede, token expirado em pleno uso (só coberto isoladamente em
`api_client_test.dart`, não num fluxo de tela completo), rotação de tela.

## 7.2 Backend — cobertura por dimensão

| Dimensão | Cobertura | Exemplos de teste |
|---|---|---|
| Happy path | ✅ Todos os 8 módulos (`user`, `pet`, `vaccine`, `appointment`, `medicalrecord`, `location`, `upload`, `migration`) | `criaListaEDetalhaUmPet`, `criaComStatusConfirmedPorDefaultEListaEmOrdem` |
| Validação (400) | ✅ | `postSemCamposObrigatoriosRetorna400` (×3), `patchComPayloadInvalidoRetorna400`, `deleteSemUrlRetorna400` |
| 401 (sem token) | ✅ Todos os controllers autenticados | `semTokenRetorna401` (×7) |
| 403/404 (outro tutor) | ✅ | `naoAcessaXDeOutroTutor` (×4, um por sub-recurso), `naoEnxergaNemMexeEmPetDeOutroTutor`, **novos**: `deleteDeArquivoDeOutroTutorRetorna404ENaoChamaOCloudinary` |
| 404 (recurso não existe) | ✅ | `publicIdInexistenteRetorna404`, `relatoParaPublicIdInexistenteRetorna404` |
| Conflito (409) | ✅ | `idDuplicadoRetorna409` |
| IDs inválidos | ✅ | `vacinaDeOutroPetDoMesmoTutorNaoCasaNaRota` |
| Paginação | `NOT_APPLICABLE` | Nenhum endpoint hoje pagina resultado — listas são pequenas por design (pets/vacinas por tutor) |
| Rate limiting | ✅ | `PublicEndpointRateLimitFilterTest` (4 casos: limite de leitura, escrita, independência entre eles, rota não-pública não afetada) |
| CORS | ⚠️ **configurado, sem teste automatizado dedicado** — verificado manualmente via `CorsConfigurationSource` bean, não há um `*Test.java` que faça uma requisição cross-origin de verdade |
| Token ausente/inválido/expirado | ✅ (ausente/inválido); expirado não simulado (Firebase Admin SDK cuida disso, não é lógica nossa pra testar) |
| Isolamento entre tutores | ✅ | Ver linha 403/404 acima — é o padrão mais testado de todo o projeto |
| Posse de upload | ✅ **novo nesta etapa** | `deleteDeArquivoDeOutroTutorRetorna404ENaoChamaOCloudinary`, `deleteDeArquivoSemPastaDePreMigracaoRetorna404ENaoChamaOCloudinary` |

**Total**: 74 testes (72 antes desta etapa + 2 novos de posse de upload),
todos verdes localmente e no CI real (GitHub Actions).

## 7.3 Regressão

Toda correção de bug nesta etapa ganhou teste de regressão:

| Bug corrigido | Teste de regressão |
|---|---|
| `DELETE /api/v1/uploads` sem verificação de posse | `deleteDeArquivoDeOutroTutorRetorna404ENaoChamaOCloudinary` + `deleteDeArquivoSemPastaDePreMigracaoRetorna404ENaoChamaOCloudinary` |
| `lib/firebase_options.dart` não commitado (build quebrava em checkout limpo) | Coberto indiretamente — o próprio CI (`flutter analyze`) falha se o arquivo for removido de novo |

Nenhum teste foi alterado "pra fazer passar" sem o comportamento estar
de fato correto — as duas alterações de teste existentes
(`UploadControllerTest`) foram pra **exercitar o fluxo real** (descobrir
a pasta assinada via `POST /signature` em vez de assumir um `public_id`
fixo), não pra afrouxar uma asserção.

## CI (cobertura automatizada real, não hipotética)

Ver `03-ci-quality-gates.md` — os dois workflows passam de verdade no
GitHub Actions, verificado via `gh run watch`, com um achado real
(`firebase_options.dart` faltando) corrigido no processo.
