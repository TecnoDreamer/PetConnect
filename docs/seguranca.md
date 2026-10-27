# Segurança — PetConnect

> ⚠️ **Documento histórico, parcialmente desatualizado** (mantido de
> propósito). Escrito antes da migração para Spring Boot + MongoDB. O
> que mudou de verdade — fonte atual: `docs/next-stage/05-security-review.md`
> e `docs/security/firestore-rules-deployed.md`:
> - **Autorização por tutor**: hoje é garantida tanto pelas Firestore
>   Rules (legado) quanto pela API (`petService.get(tutorId, petId)` em
>   todo endpoint) — não é mais só uma "regra a refinar", está
>   implementada e testada nos dois lados.
> - **Página pública do QR code**: a "Cloud Function" descrita abaixo
>   nunca foi implementada — o endpoint real é um controller REST na
>   API (`PublicPetController`), com **rate limiting** (30 leituras/10
>   escritas por minuto por IP) que este documento nem menciona.
> - **Upload de imagem**: não é mais preset "unsigned" — é assinado
>   pelo backend, com posse do arquivo verificada por pasta (ver
>   `docs/next-stage/05-security-review.md`).
> - **Firestore Rules**: endurecidas (FASE 11) — o "esboço" abaixo já
>   foi superado pela versão real em produção, documentada em
>   `docs/security/firestore-rules-deployed.md`.
> - **LGPD**: mapa técnico de dados feito em
>   `docs/privacy/data-flow-and-lgpd-readiness.md` (mais detalhado que
>   a seção abaixo).
>
> App Check e CAPTCHA continuam como recomendação **não implementada** —
> avaliados em `docs/next-stage/05-security-review.md`, decisão de não
> implementar agora (sem problema real observado ainda).

## Autenticação

- Autenticação via **Firebase Authentication** (e-mail/senha, Google, Facebook). Senhas nunca passam pelo nosso código em texto puro — o SDK do Firebase cuida do hashing/transporte.
- Mensagens de erro de login devem ser genéricas ("e-mail ou senha inválidos"), sem indicar se o e-mail existe, para não facilitar enumeração de contas (ver CT05).
- Recuperação de senha (RF05) sempre mostra a mesma mensagem de confirmação, exista ou não o e-mail informado (mesmo motivo).
- Login social (Google/Facebook, RF04-A/RF04-B) usa os SDKs oficiais (`google_sign_in`, `flutter_facebook_auth`) + Firebase Auth — o token do provedor é validado pelo Firebase, nunca confiamos em dados de perfil vindos direto do client sem essa validação.
- Recomenda-se ativar **Firebase App Check** para reduzir abuso automatizado dos endpoints (login, Cloud Functions da página pública).

## Autorização e isolamento de dados (Firestore Security Rules)

Regra central: **um tutor só lê/escreve os próprios documentos**; dados de pet só são acessíveis pelo `userId` proprietário (campo real já existente em `Pets`, ver `docs/modelo-dados-firestore.md`).

Regras implementadas (proposta, aguardando deploy): [`security/firestore-isolamento-por-dono.md`](security/firestore-isolamento-por-dono.md). O dono do perfil é o ID do documento (= Auth UID) e o dono do pet é `userId`; `dono` e `usuarioID` não são usados para autorização.

Esboço original:

```
match /Usuarios/{userId} {
  allow read, update, delete: if request.auth.uid == userId;
  allow create: if request.auth.uid == userId;
}

match /Pets/{petId} {
  allow read, update, delete: if request.auth != null
    && resource.data.userId == request.auth.uid;
  allow create: if request.auth != null
    && request.resource.data.userId == request.auth.uid;

  match /vacinas/{vacinaId} {
    allow read, write: if request.auth != null
      && get(/databases/$(database)/documents/Pets/$(petId)).data.userId == request.auth.uid;
  }
  // mesmo padrão para historicoMedico/{id} e consultas/{id}
}
```

Nenhuma coleção de pet deve ter leitura pública direta pelo SDK do Firestore — ver seção seguinte sobre a página do QR code.

## Página pública do QR code

Como qualquer pessoa (sem login) precisa conseguir ver informações básicas de um pet ao escanear o QR (RF17), duas abordagens foram consideradas:

1. **Regra de leitura pública em um campo/coleção específica no Firestore.** Simples, porém arriscado: qualquer ajuste futuro na regra pode acidentalmente expor mais do que o pretendido, e a coleção fica sujeita a enumeração de IDs por clientes Firestore genéricos.
2. **Cloud Function (HTTP) que renderiza a página, lendo o Firestore com privilégios de admin e retornando apenas os campos permitidos.** Escolha recomendada — a superfície pública fica restrita a um endpoint controlado por código, não pelas regras gerais do banco.

**Decisão**: opção 2. A Cloud Function recebe o ID do pet, busca o documento com Admin SDK (sem passar pelas regras de segurança do client) e retorna somente: nome, foto, espécie/raça, e contato do tutor (definido explicitamente por ele como "visível no QR code" — nunca o e-mail/senha, e telefone só se o tutor optar por exibi-lo).

- IDs de pet usados na URL da página pública devem ser **não sequenciais e não adivinháveis** (IDs gerados pelo Firestore já são strings aleatórias — não usar contadores incrementais).
- Se o pet for excluído ou o QR code regenerado (RF19), o endpoint deve responder "não encontrado" para o ID antigo (CT14, CT15).

## Validação de entrada

- Todo formulário (cadastro, criação de pet, vacina, histórico, consulta) valida no client antes de enviar, **e** as regras do Firestore validam tipo/presença dos campos obrigatórios no servidor — nunca confiar somente na validação do app.
- Uploads de imagem (foto de pet, tutor, anexos) têm limite de tamanho (5MB) validado no client antes do envio ao Cloudinary — ver `core/config/cloudinary_config.dart`. O upload usa um preset "unsigned" (sem API secret embutida no app); exclusão de arquivo antigo não é feita (exigiria uma requisição assinada, que precisaria de um backend próprio para não expor o secret) — arquivo substituído/removido fica órfão no Cloudinary, limitação aceita conscientemente.

## Memorial do Pet

A situação de falecimento só pode ser alterada pelo dono (regra de
`update` de `Pets`), com auditoria em `eventosSituacao`, sem exclusão de
dados e sem exposição na página pública do QR. Autorização detalhada,
proposta de regras pendente de aprovação e riscos em
`docs/security/memorial-pet.md`; retenção em
`docs/privacy/retencao-pets-falecidos.md`.

## Dados sensíveis e LGPD

- Dados coletados: nome/e-mail/telefone do tutor, dados do pet, histórico médico. Finalidade: identificação de pets perdidos e gestão de saúde do pet — deve constar em uma política de privacidade (fora do escopo desta fase, mas necessária antes de lançar).
- O tutor decide explicitamente quais dados de contato aparecem na página pública do QR code (RF17/RF18) — nunca expor por padrão o histórico médico completo.
- Exclusão de conta (RF09) deve remover ou anonimizar os dados do tutor e de seus pets, incluindo desativar o(s) QR code(s) associados.

## Segredos e configuração

- Chaves do Firebase (`google-services.json`, `GoogleService-Info.plist`, `firebase_options.dart` gerado por `flutterfire configure`) **não são segredos de altíssima sensibilidade** (a segurança real vem das Security Rules), mas ainda assim não devem ser commitadas com configurações de produção diferentes das de desenvolvimento sem necessidade — ver `.gitignore`.
- Nenhuma credencial de serviço (Admin SDK, usada pela Cloud Function) deve estar no repositório; usar variáveis de ambiente/Secret Manager do Google Cloud.

## Cenários de abuso a considerar

| Cenário | Mitigação |
|---|---|
| Força bruta de login | Firebase Auth já limita tentativas; considerar App Check |
| Enumeração de pets via QR | IDs não sequenciais + Cloud Function controlando o que é exposto |
| Tutor A acessando pet do Tutor B via manipulação de rota no app | Firestore Security Rules bloqueiam no servidor, independente da UI (CT10) |
| QR code fotografado/reutilizado indevidamente após perda de acesso ao pet (ex: pet vendido/doado) | Regeneração de QR code (RF19) invalida o anterior |
| Scraping da página pública para coletar contatos em massa | Rate limiting na Cloud Function; considerar CAPTCHA se abuso for detectado |
