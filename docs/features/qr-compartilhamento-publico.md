# Página pública do QR com consentimento

> Fase 1 do épico #102 (issue #35). Branch `feat/qr-consentimento-publico`
> no app e na API (`AleksGustavo/PetConnect-API`). 2026-11-02.

## O que muda

Quem escaneia o QR do pet vê só o que o tutor marcou e consentiu. Sem
consentimento, a página mostra o **mínimo neutro**: "Este pet está
cadastrado no PetConnect" e o formulário para avisar o tutor, sem nome,
foto, espécie, situação ou telefone.

Antes, a página mostrava nome, espécie, situação, foto e, se houvesse, o
telefone de qualquer pet, sem consentimento registrado.

## Diagnóstico (auditoria de 2026-11-02)

| Ponto | Situação encontrada | Referência |
|---|---|---|
| Quem resolve o QR | A API Spring (MongoDB Atlas, Render). A página (`public/index.html`, Firebase Hosting) chama `GET /api/v1/public/pets/{publicId}` | `public/index.html`, `PublicPetController.java` |
| Fonte dos pets no APK de teste | Firestore. As flags de API estão desligadas | `lib/core/config/app_config.dart` |
| Pets novos | Só chegam ao MongoDB pela migração manual; até lá, o QR mostra "não encontrado" | `docs/fixes/qr-public-pet-not-found.md` |
| Dados expostos | Nome, espécie, situação, foto e telefone, sem consentimento | `PublicPetSummaryResponse.java` (antes) |
| Localização | A caixa "Incluir minha localização" vinha marcada | `public/index.html` (antes) |
| Avistamentos | Ficam no MongoDB; o app em modo Firestore não os mostra ao tutor | `LocationService.java`, `firebase_localizacao_repository.dart` |
| Migração | Apaga e recria os pets importados, e cada um ganha um `_id` novo. Os avistamentos gravados pela API guardam esse `_id` e ficam sem pet | `LegacyMigrationService.java` |

**Decisões do proprietário (2026-11-02):**
- **Sem consentimento:** a página mostra o mínimo neutro.
- **Pets que ainda não estão na API:** a API lê o pet no Firestore e confere
  o dono.

## Como funciona

### No app

Em **Configurações do pet > QR Code > Compartilhamento via QR Code**
(`compartilhamento_qr_screen.dart`), o tutor:

1. **Marca os dados**, um por um: nome do pet, espécie, raça, cor, foto de
   perfil, nome do tutor e telefone ou WhatsApp. Nenhuma caixa vem marcada
   numa página nova.
2. **Confere o nome e o telefone:** os dois vêm do perfil e podem ser
   editados ali.
   - O telefone vale só para a página, e mudar aqui não muda o perfil.
   - O formato é validado (DDD válido, celular com 9 na frente). O app não
     afirma que o número tem WhatsApp.
3. **Vê a prévia** do que o visitante vai ver.
4. **Marca o consentimento.** Essa caixa vem desmarcada toda vez que a tela
   abre: cada publicação é um consentimento novo.
5. **Publica.** Depois pode alterar ou desativar; desativar pede
   confirmação.

A opção só aparece quando o app fala com a API: `USE_API_QR=true` com os
pets no Firestore, ou `USE_API_PETS=true`. Sem isso, a página continua com o
mínimo neutro.

Excluir o pet desliga a página antes. Isso é melhor esforço e espera no
máximo 5 s; se falhar, a API apaga a configuração no próximo acesso ao QR.

### Na API

| Rota | Quem | O que faz |
|---|---|---|
| `GET/PUT /api/v1/legacy-pets/{firestoreId}/public-sharing` | tutor | Configuração de pet do Firestore |
| `GET/PUT /api/v1/pets/{id}/public-sharing` | tutor | Configuração de pet da API |
| `GET /api/v1/public/pets/{publicId}` | público | Só os campos autorizados, `Cache-Control: no-store` e `X-Robots-Tag: noindex` |
| `POST /api/v1/public/pets/{publicId}/sightings` | público | Relato anônimo; `201` sem corpo |

**Corpo do `PUT`:**

```json
{
  "enabled": true,
  "consentAccepted": true,
  "consentVersion": "2026-11-02",
  "fields": ["PET_NAME", "PROFILE_PHOTO", "CONTACT_PHONE"],
  "tutorDisplayName": "Ana",
  "contactPhone": "(19) 99999-0000"
}
```

`{"enabled": false}` desativa, revoga e apaga o telefone e o nome de
exibição.

**Respostas:**

| Código | Quando |
|---|---|
| `400` | Sem consentimento, sem campos, telefone ou nome inválido, campo desconhecido |
| `401` | Sem token |
| `404` | Pet inexistente ou de outro tutor |
| `409 CONSENT_VERSION_OUTDATED` | O texto do consentimento mudou |
| `409 PET_IN_MEMORIAL` | Pet no Memorial |
| `503` | A API não conseguiu ler o Firestore |

**Resposta pública:** só os campos marcados. Os outros nem aparecem no JSON.

```json
{ "shared": true, "name": "Rex", "photoUrl": "https://res.cloudinary.com/...", "publicContactPhone": "+5519999990000" }
```

Sem consentimento ativo: `{ "shared": false }`.

**Onde fica:**
- `pet_public_sharing`: uma configuração por pet. Fica fora de `pets` para
  a migração não apagar o consentimento.
- `public_sharing_consent_events`: histórico só de inclusão (aceito,
  atualizado, revogado), com a data, a versão do texto, o escopo e o UID de
  quem fez. Não guarda o telefone nem o nome.

**Pets do Firestore:** a API lê `Pets/{id}` no Firestore a cada acesso
(`FirestorePets`, com o Admin SDK). Isso dá três garantias:
- a posse do pet vem da fonte real;
- pets que a migração ainda não levou ao MongoDB funcionam;
- pet excluído ou no Memorial some da página na hora.

O nome, a foto e os demais dados do pet não são copiados para o MongoDB.

**Resolução do QR:** primeiro em `pets`, pelo `publicId`, que pode ter sido
regenerado. Se não achar, procura o `publicId` determinístico de
`pet_public_sharing`, desde que o pet não esteja em `pets`. Um QR regenerado
continua revogando o antigo.

### Na página

- **`shared: false`:** o mínimo neutro e o formulário.
- **`shared: true`:** só o que veio. O telefone aparece como link `tel:`; o
  WhatsApp é a fase 2 (#103).
- **Mudanças nesta fase:**
  - a caixa de localização deixa de vir marcada (o fluxo completo de
    localização é a fase 3, #37);
  - a mensagem de envio deixa de prometer que "o tutor foi avisado", já que
    ainda não há notificação (fase 4, #36).

## Compatibilidade

- **QR impresso:** continua abrindo a página; o conteúdo do QR e a URL não
  mudam.
- **Página antiga com a API nova:**
  - pet sem consentimento: aparece só "Pet" e um selo vazio até a página
    nova ser publicada;
  - pet com consentimento: mostra os campos autorizados, porque os nomes
    `name`, `species`, `photoUrl` e `publicContactPhone` são os mesmos.
- **Página nova com a API antiga:** sem `shared`, mostra o que a API antiga
  manda, como antes.
- **Ordem recomendada de deploy:** API primeiro, página logo depois.

## Ameaças e controles

| Ameaça | Controle |
|---|---|
| Exposição de dados sem consentimento | Allowlist por campo (`PublicField`), consentimento versionado, mínimo neutro por padrão, campos ausentes fora do JSON |
| Telefone na página (golpes, engenharia social) | Opt-in por campo, aviso explícito na tela, número só da página, apagado ao revogar ou excluir |
| Tutor mexendo no pet de outro | Posse conferida no Firestore (`userId` = UID do token) a cada `GET` e `PUT`; outro tutor recebe 404 |
| Enumeração de pets | `publicId` UUID; QR revogado e inexistente respondem igual (404); limite por IP nos endpoints públicos (já existente) |
| Revogação que não vale na hora | Nada é guardado em cache (`no-store`); a resposta é montada a cada acesso |
| Dados clínicos ou internos | A resposta pública não tem id interno, `tutorId`, e-mail, situação nem dado clínico (teste dedicado) |
| Cópia antiga após exclusão | Excluir o pet ou a conta apaga a configuração; pet excluído no Firestore apaga no primeiro acesso ao QR |
| Firestore fora do ar | `503` no `PUT` e na página publicada; nunca mostra dados sem conferir o pet |

**Riscos que continuam:**
- **Telefone já visto:** quem viu o número antes da revogação continua com
  ele.
- **Foto já baixada:** a foto do Cloudinary pode ficar em caches de
  terceiros mesmo depois de revogada.
- **Revisão jurídica:** o texto do consentimento precisa de revisão
  jurídica antes de ir para usuários reais (issue #28).

## Testes

**API (`mvn test`, 125 testes):**
- `PublicSharingControllerTest` (15): 401, 404 entre tutores, validações,
  campos marcados, telefone e nome, revogação e histórico, pet não migrado,
  QR regenerado, Memorial, pet excluído, versão antiga do texto, Firestore
  fora do ar, exclusão da conta, nenhum id interno na resposta.
- `ContactPhoneTest` (21).
- `PublicPetControllerTest` e `PetQrControllerTest` atualizados para o
  mínimo neutro.

**App:**
- `telefone_de_contato_test.dart`: mesmos casos da API.
- `api_compartilhamento_repository_test.dart`: rotas, corpo e erros.
- `compartilhamento_qr_screen_test.dart`:
  - nada marcado, sem consentimento não publica;
  - prévia, telefone do perfil e validação;
  - página ativa, desativar, falha e texto antigo.
- `pet_settings_screen_test.dart`: opção no menu e desligar a página antes
  de excluir o pet.
- `pagina_publica_qr_test.dart`: regras que dá para conferir no arquivo da
  página.

**Sem teste no aparelho nem no navegador real.** Roteiro em
`docs/validation/qr-compartilhamento-publico.md`.

## Para ir ao ar (proprietário)

1. **Credencial do Render:** confirmar que a conta de serviço de
   `FIREBASE_SERVICE_ACCOUNT` lê o Firestore. Se ela foi gerada em
   "Contas de serviço > Gerar nova chave privada", já é a
   `firebase-adminsdk`, que lê. Se for uma conta dedicada, dar o papel
   **Cloud Datastore Viewer** (`roles/datastore.viewer`) no Google Cloud
   Console > IAM.
2. **API:** mesclar a PR e publicar no Render.
3. **Página:** publicar no Hosting:
   ```
   firebase deploy --only hosting
   ```
4. **APK de teste:** gerar com
   `--dart-define=USE_API_QR=true --dart-define=API_BASE_URL=https://petconnect-api-rxr9.onrender.com`
   (mais `GALERIA_FOTOS=true`, como hoje).

## Rollback

- **App:** reverter o merge. A opção some e a página continua com o
  mínimo neutro.
- **API:** reverter o merge e publicar. A página volta a mostrar os dados
  de antes, sem consentimento. As coleções `pet_public_sharing` e
  `public_sharing_consent_events` ficam no banco sem uso; apagar exige
  decisão do proprietário.
- **Página:** publicar a versão anterior do Hosting pelo console
  (Hosting > histórico de versões > reverter).
