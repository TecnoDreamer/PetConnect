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
| Localização/avistamento (coordenadas com precisão, descrição, contato opcional de quem viu) | Ajudar a recuperar o pet perdido | Formulário do tutor OU relato anônimo via QR público; a coordenada é pedida ao navegador assim que a página mostra o pet, com o texto de finalidade ao lado, e vai sozinha se o visitante permitir (RF31; desde 2026-11-04, antes dependia do botão "Compartilhar local" e da confirmação no envio — mudança a confirmar na revisão jurídica #28) | App/página pública → API → MongoDB | MongoDB (`locations`, com `accuracyMeters`, `positionSource` e `clientRequestId`) | Tutor do pet (aba Localização, RF32); quem reporta não se identifica (endpoint anônimo) | Enquanto o pet existir; política de visibilidade e eliminação pendente de revisão jurídica (#28, fase 5 #38) | Exclusão do pet ou da conta, inclusive com os pets no Firestore (relatos pelo id do Firestore). Ver "Exclusão de pet e de conta" abaixo | Médio (coordenada geográfica é dado sensível de localização) | Anônimo de propósito: não guarda IP nem identidade; um ponto por envio, sem rastreamento contínuo; limite por pet e por IP. Ver `docs/features/qr-avistamentos.md` |
| Acessos à página do QR (`qr_page_opened`, RF52) | Avisar o tutor de que o QR foi aberto, sem confundir com avistamento | Página pública, depois de mostrar um pet válido | Página → API → MongoDB | MongoDB (`qr_access_events`: pet e hora) | Tutor do pet (contagem e último acesso) | 90 dias (índice TTL) | Exclusão do pet ou da conta (também com os pets no Firestore); TTL | Baixo (sem dado de quem abriu) | Sem IP, user-agent nem coordenada; no máximo 30 gravados por pet por hora |
| Token do aparelho para push e preferências de aviso (RF53) | Avisar o tutor de acessos e relatos do QR | App, depois do login e da permissão de notificação | App → API (HTTPS, token no corpo) → MongoDB; API → Firebase Cloud Messaging | MongoDB: `push_devices` (token, dono, plataforma), `pet_notification_preferences` e `tutor_notifications` (status do envio, sem token nem texto) | Só a API; o Google (FCM) recebe o token e o texto da notificação para entregar | Token até sair da conta, excluir a conta ou o FCM invalidar; histórico de envios 30 dias (TTL) | Sair da conta; excluir a conta; desligar os avisos; excluir o pet apaga as preferências e o histórico de envios dele | Baixo (identificador do aparelho) | Payload sem dado do relato; visibilidade privada na tela bloqueada; token fora de URL e log. Ver `docs/features/qr-notificacoes.md` |
| Histórico médico + anexos (exames, laudos) | Carteira de saúde do pet | Formulário do tutor | App → API → MongoDB (+ anexos no Cloudinary) | MongoDB (`medical_records`) + Cloudinary | Só o tutor (nunca exposto no endpoint público) | Enquanto o registro existir | `DELETE .../medical-records/{id}` + cascata na exclusão do pet | Médio-alto (dado de saúde, mesmo sendo do animal — pode conter nome de clínica/veterinário, potencialmente identificável) | Nunca acessível sem autenticação; não aparece em nenhum endpoint público |
| Galeria de fotos do pet (imagens + legenda) | Guardar lembranças do pet, inclusive no Memorial | Seletor de fotos do sistema | App → Cloudinary (arquivo) + Firestore `Pets/{id}/fotos` (metadados) | Cloudinary + Firestore | Só o tutor dono (regras do Firestore); a URL do arquivo abre para quem a tiver | Enquanto a foto existir; excluir apaga o registro, e o arquivo só com upload assinado (`USE_API_UPLOAD`) | Excluir no visualizador; cascata na exclusão do pet e da conta (só registros) | Médio (pode mostrar pessoas, a casa, rotina; EXIF com GPS no original em Android 7–9) | Privada por padrão; interface só exibe versões sem metadados; nome original do arquivo não é enviado |
| Vacinas, consultas | Carteira de saúde, agenda | Formulário do tutor | App → API → MongoDB | MongoDB (`vaccines`, `appointments`) | Só o tutor | Enquanto o registro existir | Baixo-médio | Idem histórico médico |
| Firebase UID + ID Token | Identidade/autenticação | Firebase Auth (login) | App → Firebase Auth SDK; App → API (header `Authorization`) | Firebase Auth (gerenciado pelo Google); nunca persistido pela API além do `firebaseUid` de referência | Firebase (Google) + backend (verificação) | Enquanto a conta existir no Firebase Auth | Exclusão de conta remove o usuário do Firebase Auth também | Baixo (token de curta duração, não é senha) | Nunca logado (verificado nesta auditoria — `05-security-review.md`) |
| Cartaz de pet desaparecido (telefone autorizado, textos livres, 3 fotos) | Divulgar o desaparecimento, por decisão do tutor (RF43–RF49) | Cadastro do tutor e do pet; textos e fotos escolhidos no editor | Só no aparelho; sai apenas quando o tutor compartilha ou salva | Rascunho em `shared_preferences` (textos, data, período e local de "Visto por último", recompensa, cor, referências às fotos do Cloudinary, ajuste das fotos; **sem** telefone, consentimento nem fotos do celular). Arquivo temporário no cache, apagado depois de compartilhar | O tutor; depois de compartilhado, quem receber o cartaz | Rascunho até o tutor descartar ou excluir o pet; o arquivo compartilhado sai do controle do app | Descartar rascunho; excluir o pet; cartaz já compartilhado **não** pode ser recolhido (o app avisa) | Médio (telefone público por escolha do tutor) | Consentimento explícito por número e por sessão; sem e-mail, endereço, GPS ou dados clínicos; PNG gerado dos pixels (sem metadados das fotos); nome do arquivo sem dado pessoal; nada em log. Ver `docs/features/cartaz-pet-desaparecido.md` |
| Página pública do QR: configuração e consentimento (RF51) | Mostrar a quem acha o pet só o que o tutor autorizou | Tela "Compartilhamento via QR Code" do pet | App → API (HTTPS) → MongoDB; a página lê pela API | MongoDB: `pet_public_sharing` (campos marcados, nome de exibição, telefone da página, datas e versão do consentimento) e `public_sharing_consent_events` (histórico sem telefone nem nome). Nome, foto e demais dados do pet **não** são copiados: a API lê no Firestore a cada acesso | Tutor; qualquer pessoa com o QR vê só os campos marcados | Enquanto a página estiver ativa; o histórico de consentimento fica depois da exclusão do pet e da conta, como prova do consentimento (prazo a definir) | Desativar (apaga telefone e nome); excluir o pet ou a conta (apaga a configuração) | Médio (telefone público por escolha do tutor) | Desligado por padrão, allowlist de campos, versão do texto, `no-store`, posse conferida no Firestore. Revisão jurídica do texto pendente (#28). Ver `docs/features/qr-compartilhamento-publico.md` |
| QR code exportado (PNG e PDF) | Imprimir o QR na coleira (RF50) | Gerado no aparelho a partir do QR exibido | Só no aparelho; sai quando o tutor salva ou compartilha | Arquivo temporário no cache, apagado depois de compartilhar; a cópia salva fica na galeria do tutor | O tutor e quem receber ou escanear o impresso | Até o tutor apagar o arquivo; regenerar o QR (RF19) invalida o impresso | Apagar o arquivo; regenerar o QR | Baixo (só a URL pública, que já estava no QR, e o nome do pet no PDF) | Sem telefone, endereço, e-mail nem dados de saúde; nome do arquivo sem dado pessoal (SHA-256 do `publicId`). Ver `docs/features/qr-exportacao.md` |
| Dados do login com Google (nome e e-mail) | Criar o perfil do tutor no primeiro login (RF04-A) | Google Sign-In, com a escolha de conta na tela do Google | Provedor → App → Firebase Auth; App → Firestore `Usuarios/{uid}` (ou API `GET /me`) | Firebase Auth + `Usuarios` | Só o próprio tutor | Enquanto a conta existir | Exclusão de conta; sair encerra também a sessão do Google | Baixo (só autenticação, sem escopos extras; foto do Google não é copiada) | Tokens do provedor nunca gravados nem logados; ver `docs/features/login-social.md` |
| Logs de aplicação | Diagnóstico/operação | Requisições à API | Backend → stdout do container | Onde o container roda (hoje: só localhost) | Quem tem acesso ao host/logs | Não configurado (sem rotação/retenção definida ainda) | Baixo hoje (sem PII nos logs, verificado) | `include-stacktrace: never`; nenhuma PII logada, confirmado por auditoria de código |

---

## Exclusão de pet e de conta: o que sai da API

Com os pets no Firestore e a API ligada para o QR (`USE_API_QR=true`, o
modo atual), a API guarda, por pet (chave `fs:<id do documento>`): a
configuração da página pública (`pet_public_sharing`, com o telefone e o
nome de exibição), os acessos ao QR (`qr_access_events`), os relatos e
avistamentos (`locations`, com coordenada e o contato de quem achou), as
preferências de aviso (`pet_notification_preferences`) e o histórico de
envios (`tutor_notifications`). Se a migração já levou o pet ao MongoDB,
há ainda a cópia em `pets` com vacinas, consultas e histórico.

Antes de 2026-11-07, excluir o pet no app só desligava a página pública;
o resto ficava na API. A partir daí:

| Caminho | O que a API apaga | Quando a API está fora |
|---|---|---|
| Excluir o pet no app | Antes de apagar no Firestore, o app chama `DELETE /api/v1/legacy-pets/{id}/qr-data` (só o dono, conferido no Firestore): página pública, acessos, relatos, preferências, avisos e a cópia migrada do mesmo tutor | A exclusão no Firestore segue (prazo de 8 s). O pedido fica guardado no aparelho (só o id do pet, por conta) e é repetido a cada abertura do app com sessão; a API aceita a repetição com o pet já fora do Firestore se nada lá apontar outro dono. Além disso, o primeiro acesso ao QR de um pet excluído apaga tudo isso sem login |
| Excluir a conta no app | Para cada pet, a mesma rota; no fim, `DELETE /api/v1/me`: aparelhos do push, páginas públicas, preferências, avisos, acessos e relatos dos pets do tutor, a cópia migrada dos pets, e o usuário no Firebase Auth | Depois do primeiro pedido sem resposta, o app deixa de chamar a API e exclui só no Firebase. **Não há nova tentativa**: a conta deixa de existir e não há login para repetir. Ficam na API os dados de conta (abaixo) até o TTL ou a limpeza no acesso ao QR |
| Excluir o pet com os pets na API (`USE_API_PETS`) | `DELETE /api/v1/pets/{id}` apaga em cascata, pelas duas chaves do pet (`api:` e `fs:`) | O app mostra erro e o pet não é excluído |

O que fica de propósito ou ainda fica:

- **Histórico de consentimento** (`public_sharing_consent_events`): quando o
  tutor aceitou, alterou ou revogou e quais campos, sem telefone nem nome.
  Fica como prova do consentimento. **Decisão pendente:** prazo de guarda.
- **Documento do tutor em `users` na API**: a exclusão de conta pela API faz
  *soft delete* (marca `deletedAt`) e mantém nome e e-mail. **Pendente:**
  apagar ou anonimizar esses campos.
- **Exclusão de conta com a API fora**: ficam o token do push
  (`push_devices`) e o documento em `users`; a página pública e os dados
  do QR de cada pet saem no próximo acesso ao QR ou pelo TTL (acessos 90
  dias, avisos 30 dias); preferências e relatos de pets cujo QR nunca mais
  for aberto ficam sem prazo. **Pendente:** rotina no servidor que apague
  dados de contas e pets que não existem mais no Firestore.
- **Aviso em andamento**: um push disparado segundos antes da exclusão pode
  gravar um registro em `tutor_notifications` depois dela; sai pelo TTL de
  30 dias.
- **Migração**: rodar de novo a migração com um export do Firestore
  anterior à exclusão recriaria a cópia do pet no MongoDB.

---

## Minimização de dados — avaliação

| Prática | Estado |
|---|---|
| Coleta só o necessário pra cada funcionalidade | ✅ Nenhum campo "extra" identificado sem uso — todos os campos de `User`/`Pet`/etc. são exibidos/editados em alguma tela |
| Contato do tutor na página pública é opt-in | ✅ Consentimento por campo na página pública (RF51): nada aparece sem o tutor marcar e consentir; o telefone da página é separado do telefone do perfil e é apagado ao revogar |
| Fotos da galeria na página pública são opt-in (fase 2, #103) | ✅ Só as duas fotos que o tutor escolhe, com a caixa "Mais duas fotos da galeria" marcada e o consentimento. A API guarda só os ids e lê a foto na galeria a cada acesso: foto apagada da galeria sai da página na hora. Revogar apaga a escolha. O botão do WhatsApp só aparece com o telefone autorizado e não envia nada sozinho. |
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
3. **Galeria de fotos (EXIF e arquivos órfãos)** — no Android 7 a 9 o
   arquivo original enviado pode conter a localização GPS da foto; a
   interface só exibe versões transformadas (sem metadados), mas o
   original fica no Cloudinary. No modo de upload padrão, excluir uma
   foto, um pet ou a conta apaga os registros, não os arquivos. Ver
   `docs/features/galeria-fotos-pet.md` e ADR 0005 (D2, D3).
4. **Exclusão depende da API estar no ar** — com os pets no Firestore, a
   API só apaga os dados do QR de um pet excluído quando o app consegue
   falar com ela (na hora ou numa nova tentativa) ou quando o QR é aberto
   de novo. Na exclusão de conta não há nova tentativa. Ver "Exclusão de
   pet e de conta" acima.
5. **Sem política de retenção/expiração** — dado de tutores que
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

## Exclusão de pet e de conta no modo Firestore (flags `USE_API_*` desligadas)

O mapa acima descreve a API/MongoDB. No modo Firestore, as exclusões são
feitas pelo app. As duas começam pela mesma cascata
(`apagarSubcolecoesDoPet`, em `lib/features/pet/data/exclusao_de_pet.dart`):
apaga, um documento por vez, `vacinas`, `consultas`, `historicoMedico`,
`localizacoes` e `fotos` (só os registros da galeria; os arquivos no
Cloudinary seguem o item 3 acima).

- **Excluir pet** (`FirebasePetRepository.deletePet`): a cascata acima;
  depois, num lote atômico, os eventos de situação do Memorial
  (`eventosSituacao`) e o pet.
- **Excluir conta** (`FirebaseUsuarioRepository.deleteAccount`):
  1. A cascata acima para cada pet do tutor (`Pets where userId == uid`).
  2. Num lote atômico: apaga os eventos de situação do Memorial
     (`eventosSituacao`) de cada pet, os pets e o perfil `Usuarios/{uid}`.
  3. Apaga o usuário do Firebase Auth.

| Dado | Apagado? |
|---|---|
| Perfil, pets | ✅ Sim |
| Vacinas, histórico médico | ✅ Sim (na exclusão de um pet sozinho, antes desta correção ficavam órfãos) |
| Consultas, localizações/avistamentos do pet | ✅ Sim (antes desta correção ficavam órfãos, nas duas exclusões) |
| Registros da galeria (`fotos`) | ✅ Sim (os arquivos no Cloudinary, não — ver acima) |
| Eventos de situação do Memorial (`eventosSituacao`: `atorId` = UID, mudança de situação, motivo, horário) — exclusão de conta | ✅ Sim. Decisão do proprietário (2026-10-27): a auditoria é imutável, exceto na exclusão de conta, quando o dono pode apagá-la no mesmo lote do perfil. Detalhes em `docs/security/firestore-isolamento-por-dono.md` ("Decisão: `eventosSituacao` é apagado na exclusão de conta") |
| Eventos de situação do Memorial — exclusão de um pet sozinho | ✅ Sim. Decisão do proprietário (2026-10-28): excluir um pet apaga de vez tudo dele. Ver "Decisão: `eventosSituacao` sai também ao excluir um pet" no mesmo documento |
| Documentos já órfãos de pets e contas excluídos antes desta correção | ❌ Não tratados — limpeza exige Admin SDK e decisão à parte |

Depende do deploy de `firestore.rules`: com as regras antigas no ar, a
exclusão de conta para no passo 2, e a exclusão de um pet com eventos para
antes de apagar o pet.

## Decisões pendentes (jurídicas/de produto, não técnicas)

- Base legal para cada categoria de dado (provavelmente "execução de
  contrato"/"legítimo interesse" para a maioria, mas isso precisa de
  uma pessoa qualificada — não vou inventar isso).
- Prazo de retenção após inatividade da conta.
- Se e quando lançar publicamente, escrever a Política de Privacidade
  formal (este documento é insumo técnico pra ela, não a substitui).
- Nome do encarregado de dados (DPO), se a operação crescer a ponto de
  exigir um.
