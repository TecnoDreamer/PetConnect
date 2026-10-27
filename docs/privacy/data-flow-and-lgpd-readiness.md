# Mapa de Fluxo de Dados e Prontidão para LGPD

> Documento **técnico**, não jurídico — subsídio para quem for escrever a
> política de privacidade final. Não define base legal (isso é decisão
> jurídica/de produto, não técnica) — onde uma decisão jurídica é
> necessária, está marcada explicitamente como **decisão pendente**.

---

## Mapa de dados

| Dado | Finalidade | Onde nasce | Onde trafega | Onde fica | Quem acessa | Retenção | Exclusão | Risco | Controle técnico |
|---|---|---|---|---|---|---|---|---|---|
| Nome, e-mail, telefone, data de nascimento, gênero do tutor | Identificação da conta, contato do achador do pet (telefone, opcional) | Formulário de cadastro/edição de perfil | App → API Spring (HTTPS) → MongoDB | MongoDB (`users`); Firebase Auth guarda e-mail/uid separadamente | O próprio tutor (via API), backend (leitura de servidor) | Enquanto a conta existir | `DELETE /api/v1/me` remove o documento + a conta no Firebase Auth (cascata) | Médio (PII direta) | Firestore Rules + Firebase Auth Token verificado no backend; nunca exposto no endpoint público |
| Foto do tutor | Personalização do perfil | Upload de imagem | App → Cloudinary (direto, upload assinado) | Cloudinary (URL armazenada em `users.photoUrl`) | Qualquer um com a URL (Cloudinary não tem controle de acesso por padrão nas URLs geradas) | Enquanto a conta existir; exclusão só quando o tutor troca/exclui manualmente (ver limitação abaixo) | `DELETE /api/v1/uploads` (posse verificada, FASE atual) | Baixo-médio (foto pessoal, mas URL não é adivinhável — usa hash aleatório do Cloudinary) | Posse verificada por pasta assinada (`users/<tutorId>/...`) |
| Dados do pet (nome, espécie, raça, data de nascimento, foto) | Identificação do pet, achado/perdido | Formulário de pet | App → API → MongoDB | MongoDB (`pets`) | Tutor + qualquer um que escaneie o QR (nome/espécie/foto, nunca o resto) | Enquanto o pet existir no perfil | `DELETE /api/v1/pets/{id}` (cascata) | Baixo (dado do animal, não da pessoa, exceto o vínculo ao tutor) | Isolamento por `tutorId` em toda a API |
| Localização/avistamento (coordenadas, descrição, quem viu) | Ajudar a recuperar o pet perdido | Formulário do tutor OU relato anônimo via QR público | App/página pública → API → MongoDB | MongoDB (`locations`) | Tutor do pet (lista completa); quem reporta não se identifica (endpoint anônimo) | Enquanto o pet existir | Cascata na exclusão do pet | Médio (coordenada geográfica é dado sensível de localização) | Endpoint de relato é anônimo de propósito (RF31) — não guarda IP nem identidade de quem reporta, só a coordenada e descrição textual |
| Histórico médico + anexos (exames, laudos) | Carteira de saúde do pet | Formulário do tutor | App → API → MongoDB (+ anexos no Cloudinary) | MongoDB (`medical_records`) + Cloudinary | Só o tutor (nunca exposto no endpoint público) | Enquanto o registro existir | `DELETE .../medical-records/{id}` + cascata na exclusão do pet | Médio-alto (dado de saúde, mesmo sendo do animal — pode conter nome de clínica/veterinário, potencialmente identificável) | Nunca acessível sem autenticação; não aparece em nenhum endpoint público |
| Vacinas, consultas | Carteira de saúde, agenda | Formulário do tutor | App → API → MongoDB | MongoDB (`vaccines`, `appointments`) | Só o tutor | Enquanto o registro existir | Baixo-médio | Idem histórico médico |
| Firebase UID + ID Token | Identidade/autenticação | Firebase Auth (login) | App → Firebase Auth SDK; App → API (header `Authorization`) | Firebase Auth (gerenciado pelo Google); nunca persistido pela API além do `firebaseUid` de referência | Firebase (Google) + backend (verificação) | Enquanto a conta existir no Firebase Auth | Exclusão de conta remove o usuário do Firebase Auth também | Baixo (token de curta duração, não é senha) | Nunca logado (verificado nesta auditoria — `05-security-review.md`) |
| Logs de aplicação | Diagnóstico/operação | Requisições à API | Backend → stdout do container | Onde o container roda (hoje: só localhost) | Quem tem acesso ao host/logs | Não configurado (sem rotação/retenção definida ainda) | Baixo hoje (sem PII nos logs, verificado) | `include-stacktrace: never`; nenhuma PII logada, confirmado por auditoria de código |

---

## Minimização de dados — avaliação

| Prática | Estado |
|---|---|
| Coleta só o necessário pra cada funcionalidade | ✅ Nenhum campo "extra" identificado sem uso — todos os campos de `User`/`Pet`/etc. são exibidos/editados em alguma tela |
| Contato do tutor na página pública é opt-in | ✅ `publicContactPhone` é um campo separado de `phone` — o tutor decide se aparece na página pública (RF17/18) |
| Relato de avistamento não identifica quem reporta | ✅ Endpoint público não pede/guarda e-mail, nome ou IP de quem reporta (só a coordenada+descrição) |
| Retenção definida por política (não só "para sempre") | ❌ **Decisão pendente** — hoje não há expiração automática de nenhum dado; tudo fica até exclusão manual da conta/pet |
| Anonimização em vez de exclusão física, se aplicável | ❌ Não implementado — exclusão de conta remove os documentos de fato (não anonimiza). Isso é **mais** conservador do ponto de vista de privacidade (dado realmente sai do banco), então não é um problema de LGPD, mas pode ser um problema se o produto quiser manter histórico agregado/anônimo pra métricas no futuro |

---

## Riscos identificados (técnicos, não jurídicos)

1. **URLs do Cloudinary não expiram nem têm controle de acesso** — uma
   URL de foto, uma vez conhecida, é acessível por qualquer um
   indefinidamente (comportamento padrão do Cloudinary sem
   configuração adicional de "signed delivery URLs", que é um recurso
   pago/mais avançado). Risco baixo pra fotos de pet (já são
   parcialmente públicas via QR), mas vale considerar pra foto do
   tutor, que hoje só devia ser visível dentro do app.
2. **Coordenadas de avistamento são dado de localização** — mesmo sem
   identificar quem reportou, revelam onde o pet foi visto, o que
   indiretamente pode revelar padrões de movimento do tutor/pet se
   agregado ao longo do tempo. Mitigação parcial: só o tutor do pet
   vê o histórico completo (RF32); a página pública mostra só o
   resumo do pet, não o histórico de avistamentos.
3. **Sem política de retenção/expiração** — dado de tutores que
   abandonarem o app (não excluírem a conta, só pararem de usar)
   fica para sempre. Comum em produtos early-stage, mas vira
   obrigação sob LGPD depois de um certo volume/tempo de operação.

## Compartilhamento futuro com clínica/ERP (mencionado no plano de execução)

**Não existe hoje** nenhuma integração ou exportação de dados pra
terceiros (clínica veterinária, ERP, etc.). Se isso for implementado no
futuro, precisará de:
- Base legal específica pra esse compartilhamento (decisão jurídica
  pendente).
- Consentimento explícito do tutor, separado do consentimento geral de
  uso do app.
- Um novo mapeamento nesta mesma tabela, com a clínica/ERP como um
  "quem acessa" adicional.

## Exclusão de conta no modo Firestore (flags `USE_API_*` desligadas)

O mapa acima descreve a API/MongoDB. No modo Firestore, a exclusão de conta é
feita pelo app (`FirebaseUsuarioRepository.deleteAccount`), na ordem:

1. Para cada pet do tutor (`Pets where userId == uid`): apaga `vacinas`,
   `consultas`, `historicoMedico` e `localizacoes`.
2. Num lote atômico: apaga os eventos de situação do Memorial
   (`eventosSituacao`) de cada pet, os pets e o perfil `Usuarios/{uid}`.
3. Apaga o usuário do Firebase Auth.

| Dado | Apagado? |
|---|---|
| Perfil, pets, vacinas, histórico médico | ✅ Sim |
| Consultas, localizações/avistamentos do pet | ✅ Sim (antes desta correção ficavam órfãos) |
| Eventos de situação do Memorial (`eventosSituacao`: `atorId` = UID, mudança de situação, motivo, horário) | ✅ Sim. Decisão do proprietário (2026-10-27): a auditoria é imutável, exceto na exclusão de conta, quando o dono pode apagá-la no mesmo lote do perfil. Detalhes em `docs/security/firestore-isolamento-por-dono.md` ("Decisão: `eventosSituacao` é apagado na exclusão de conta") |
| Documentos já órfãos de contas excluídas antes desta correção | ❌ Não tratados — limpeza exige Admin SDK e decisão à parte |

Depende do deploy de `firestore.rules`: com as regras antigas no ar, a
exclusão de conta para no passo 2.

## Decisões pendentes (jurídicas/de produto, não técnicas)


- Base legal para cada categoria de dado (provavelmente "execução de
  contrato"/"legítimo interesse" para a maioria, mas isso precisa de
  uma pessoa qualificada — não vou inventar isso).
- Prazo de retenção após inatividade da conta.
- Se e quando lançar publicamente, escrever a Política de Privacidade
  formal (este documento é insumo técnico pra ela, não a substitui).
- Nome do encarregado de dados (DPO), se a operação crescer a ponto de
  exigir um.
