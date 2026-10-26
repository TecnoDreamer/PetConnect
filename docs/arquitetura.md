# Arquitetura — PetConnect

> ⚠️ **Documento histórico, parcialmente desatualizado** (mantido de
> propósito — não apagar, é o registro do desenho original). Escrito
> antes da decisão de migrar para Spring Boot + MongoDB. O que mudou de
> verdade:
> - **Backend**: não é mais "Firestore direto do client" — é Flutter →
>   API Spring Boot (`/api/v1`) → MongoDB + Cloudinary, com Firebase Auth
>   só como identidade. Ver `docs/migration/firestore-to-spring-mongodb.md`
>   (plano fase a fase) e `docs/diagramas/arquitetura.md` (diagrama
>   atualizado).
> - **Página pública do QR code**: a Cloud Function mencionada abaixo
>   **nunca foi implementada** — o que existe hoje é um endpoint REST na
>   própria API (`GET /api/v1/public/pets/{publicId}`); a página HTML em
>   si ainda não foi construída (decisão de hospedagem pendente).
> - **Upload de imagem**: não é mais Cloudinary com preset "unsigned" —
>   é upload assinado pelo backend (ver `docs/next-stage/05-security-review.md`).
>
> O resto deste documento (organização por feature, `lib/core`,
> `lib/routing`, fluxo de dados dentro do app) **continua válido** — a
> migração não mudou a estrutura interna do Flutter, só de onde os dados
> vêm.

## Stack

- **Flutter** (Android + iOS)
- **Firebase**: Authentication, Firestore, Cloud Functions (página pública do QR code), Hosting (opcional, para servir a página pública)
- **Cloudinary**: upload de fotos (pet, tutor, anexos de histórico médico) — não Firebase Storage, que passou a exigir o plano pago (Blaze) no projeto real
- **Riverpod** para gerenciamento de estado e injeção de dependência
- **go_router** para navegação e deep links (importante para a página/rota que o QR code pode acionar dentro do próprio app, se optarmos por complementar a página web com um deep link)
- **qr_flutter** para geração de QR code no app

## Por que feature-first

O código em `lib/` é organizado por **feature** (auth, usuario, pet), não por tipo técnico (não há uma pasta `screens/` global misturando todas as telas). Cada feature tem:

```
features/<nome>/
├── data/           # implementações concretas (Firestore, Storage)
├── domain/         # modelos e interfaces de repositório (sem depender do Firebase)
└── presentation/
    ├── screens/    # telas (widgets de página completa)
    ├── widgets/    # componentes menores reutilizados dentro da feature
    └── providers/  # providers Riverpod que conectam domain + data à UI
```

Vantagens para este projeto:
- Times/pessoas diferentes podem trabalhar em `auth`, `usuario` e `pet` com baixo conflito de merge.
- A camada `domain` não conhece Firebase — facilita testes com repositórios falsos e uma eventual troca de backend.
- Fica claro onde adicionar algo novo: uma nova tela de pet vai em `features/pet/presentation/screens`, não em uma pasta genérica `screens/` de 30 arquivos.

## `lib/core`

Código compartilhado entre features que não é específico de nenhuma delas: tema visual (`theme/`), constantes (`constants/`), tratamento de erro comum (`errors/`) e widgets genéricos (`widgets/`, ex: botão padrão, loading indicator).

## `lib/routing`

Configuração central do `go_router`: define as rotas (`/login`, `/cadastro`, `/home`, `/pet/:id`, etc.) e os *redirects*/guards que impedem acesso a rotas autenticadas sem sessão ativa (RF06, RNF12).

As rotas de autenticação ficam em `auth_routes.dart`, envolvidas por `AuthThemeScope`: usam sempre o tema da identidade original, independentemente do tema escolhido pelo tutor (ver `docs/features/auth-theme.md` e `docs/decisions/0001-tema-fixo-autenticacao.md`).

## Fluxo de dados

```
UI (screens/widgets)
  ↓ observa
Providers Riverpod (presentation/providers)
  ↓ chama
Repositório (interface em domain/)
  ↑ implementado por
Repositório concreto (data/, usa Firebase SDK)
```

A UI nunca importa o Firebase SDK diretamente — sempre por meio de um repositório, mantendo a camada de apresentação testável e desacoplada.

## Página pública do QR code

É um serviço **separado** do app Flutter mobile: uma Cloud Function (ou app web leve) que roda no Firebase, fora do bundle do app. Ver decisão detalhada em `docs/seguranca.md`. Ela pode viver neste mesmo repositório (ex: pasta `functions/`, criada quando começarmos essa parte) ou em um repositório próprio — a decidir quando chegarmos lá.

## Testes

`test/features/<nome>/` espelha `lib/features/<nome>/`. Prioridade de testes:
1. **Unitários** para regras de negócio em `domain/` (ex: cálculo de alerta de vacina vencida).
2. **Testes de widget** para telas críticas (login, criação de pet).
3. Repositórios têm interface própria justamente para permitir fakes nesses testes, sem precisar de um Firestore real.

## Situação do pet (Memorial do Pet)

Pets têm uma situação (`SituacaoPet.ativo` / `falecido`). As rotas de pet
ficam em `lib/routing/pet_routes.dart`, protegidas por `PetSituacaoGuard`:
rotas operacionais só abrem para pets ativos e as do memorial só para
falecidos, inclusive por link direto. A transição passa sempre por
`PetRepository.alterarSituacao` (transação + auditoria). Ver
`docs/features/memorial-pet.md` e
`docs/decisions/0002-arquivamento-logico-pets-falecidos.md`.

## Sequência de inicialização (Android)

```text
Toque no ícone
  → splash nativa (sistema; Android 12+ via API SplashScreen) — cor da marca + logo
  → main(): Firebase.initializeApp + SharedPreferences (tema) → runApp
  → SplashScreen (Flutter) — mesma cor e logo, sem tempo mínimo
      aguarda sessionBootstrapProvider (signOut: login exigido a cada abertura)
      e a primeira leitura de authStateChanges
  → /login (ou /home, se houver sessão — na prática sempre /login)
```

- Antes de `runApp` ficam só as dependências do primeiro frame: Firebase
  (o router lê o `FirebaseAuth`) e `SharedPreferences` (o tema escolhido).
- A `SplashScreen` do Flutter é a continuação visual da splash nativa, não
  uma segunda abertura. O tempo mínimo artificial de 2,5s foi removido. Ver
  `docs/branding/icone-e-splash-android.md` e
  `docs/decisions/0003-splash-nativa-sem-abertura-flutter-extra.md`.
- Se o `signOut` de bootstrap falhar (ex.: sem rede), o erro é engolido em
  `sessionBootstrapProvider` e a splash segue para o login, sem travar.
