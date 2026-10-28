# Casos de Teste — PetConnect

Convenção: `CTxx`, referenciando o(s) `RFxx`/`RNFxx` cobertos. Formato: pré-condição, passos, resultado esperado.

## Autenticação

### CT01 — Cadastro com dados válidos (RF01, RF02)
- **Pré-condição**: e-mail ainda não cadastrado.
- **Passos**: abrir tela de cadastro → preencher nome, e-mail válido, senha com 8+ caracteres → confirmar.
- **Resultado esperado**: conta criada, usuário autenticado e redirecionado à Home do tutor.

### CT02 — Cadastro com e-mail já existente (RF03)
- **Pré-condição**: e-mail já cadastrado.
- **Passos**: preencher cadastro com esse e-mail → confirmar.
- **Resultado esperado**: erro específico "este e-mail já está em uso", cadastro não é criado.

### CT03 — Cadastro com senha fraca (RF02)
- **Passos**: preencher senha com menos de 8 caracteres.
- **Resultado esperado**: campo de senha exibe validação antes mesmo de enviar o formulário.

### CT04 — Login com credenciais válidas (RF04)
- **Resultado esperado**: usuário autenticado, redirecionado à Home.

### CT04-A — Login com Google (RF04-A)
- **Passos**: Login → Entrar com Google → escolher a conta; depois sair e entrar de novo com Google.
- **Resultado esperado**: entra na Home; na primeira vez o perfil é criado com nome e e-mail do Google; na segunda, mesma conta e mesmos pets. Cancelar no seletor volta ao Login sem mensagem. Automatizado com fakes (`login_social_repository_test.dart`); real em `docs/validation/login-social.md` (LS01–LS03).

### CT04-B — Login com Facebook (RF04-B)
- **Fora do escopo** (decisão do proprietário, 2026-10-27).

### CT04-C — Mesmo e-mail por senha e Google (RF04-A)
- **Passos**: com conta por e-mail e senha, entrar com Google usando o mesmo e-mail.
- **Resultado esperado**: mesma conta (mesmo UID, mesmos pets). Se o Firebase devolver o conflito, aparece o diálogo "Você já tem uma conta"; com a senha certa o Google é vinculado; senha errada não vincula nada. O app nunca une contas só pelo e-mail. Automatizado (`login_social_screen_test.dart`, `login_social_repository_test.dart`); real: LS05–LS07.

### CT05 — Login com senha incorreta (RF04)
- **Resultado esperado**: erro genérico "e-mail ou senha inválidos" (não revela se o e-mail existe).

### CT06 — Recuperação de senha (RF05)
- **Passos**: tela "Esqueci minha senha" → informar e-mail cadastrado → confirmar.
- **Resultado esperado**: e-mail de redefinição enviado (via Firebase Auth); mensagem de confirmação exibida independentemente de o e-mail existir ou não (evita enumeração de contas).

### CT07 — Sessão persistente (RF06)
- **Passos**: logar → fechar o app completamente → reabrir.
- **Resultado esperado**: usuário continua autenticado, sem precisar logar novamente.

### CT08 — Exclusão de conta (RF09)
- **Passos**: acessar configurações de conta → excluir conta → confirmar no diálogo.
- **Resultado esperado**: conta, pets e subcoleções associadas são removidos (ou marcados para remoção); usuário deslogado e redirecionado ao login.

## Gestão de pets

### CT09 — Criar pet (RF10)
- **Resultado esperado**: pet aparece na lista da Home imediatamente após salvar.

### CT10 — Isolamento entre tutores (RF12)
- **Pré-condição**: dois tutores autenticados em dispositivos/sessões diferentes, cada um com pets próprios.
- **Passos**: tutor A tenta acessar a URL/rota do perfil de um pet do tutor B diretamente (ex: manipulando o ID na rota).
- **Resultado esperado**: acesso negado — nem a UI nem a regra de segurança do Firestore permitem a leitura.

### CT11 — Editar e excluir pet (RF13, RF14)
- **Resultado esperado**: alterações refletidas na lista; exclusão exige confirmação e remove o pet e suas subcoleções.

## QR Code

### CT12 — Geração do QR code (RF16)
- **Resultado esperado**: QR code exibido no perfil do pet, único por pet.

### CT13 — Escaneamento do QR por visitante (RF17, RF18)
- **Pré-condição**: QR code de um pet existente.
- **Passos**: escanear com câmera de outro dispositivo, sem estar logado no app.
- **Resultado esperado**: abre página web pública com nome, foto, espécie/raça e contato do tutor; não mostra histórico médico nem dados sensíveis.

### CT14 — Escaneamento de QR de pet excluído (RF17)
- **Passos**: excluir o pet → escanear um QR code antigo/salvo desse pet.
- **Resultado esperado**: página informa "pet não encontrado", sem erro técnico exposto.

### CT15 — Regeneração do QR code (RF19)
- **Passos**: no perfil do pet, solicitar novo QR code.
- **Resultado esperado**: QR code antigo passa a ser inválido (página pública correspondente não resolve mais); novo QR code funciona.

## Carteira de vacina, histórico médico e consultas

### CT16 — Registrar vacina (RF20, RF21)
- **Resultado esperado**: vacina aparece na lista do pet, ordenada por data.

### CT17 — Alerta de vacina vencida (RF23)
- **Pré-condição**: vacina com data da próxima dose no passado.
- **Resultado esperado**: indicador visual de alerta no perfil do pet.

### CT18 — Registrar entrada de histórico médico (RF24, RF25)
- **Resultado esperado**: entrada aparece na lista, ordenada por data.

### CT19 — Agendar consulta (RF27, RF28)
- **Resultado esperado**: consulta aparece na lista como "futura".

### CT20 — Cancelar consulta (RF29)
- **Resultado esperado**: status muda para "cancelada", consulta não conta mais como pendente.

## Testes de segurança (ver também `docs/seguranca.md`)

### CT21 — Tentativa de leitura direta no Firestore sem autenticação
- **Passos**: usando um client Firestore não autenticado, tentar ler a coleção `pets`.
- **Resultado esperado**: bloqueado pelas regras de segurança.

### CT22 — Força bruta de login
- **Passos**: múltiplas tentativas de login com senha errada em sequência rápida.
- **Resultado esperado**: bloqueio/limitação temporário (Firebase App Check / rate limiting), sem travar a conta legítima permanentemente.

### CT23 — Enumeração de pets via QR code
- **Passos**: tentar acessar sequencialmente IDs de pet incrementais na URL da página pública.
- **Resultado esperado**: IDs não são sequenciais/previsíveis (ver RNF/segurança), então a tentativa não retorna dados úteis.

## Memorial do Pet

Automatizados em `test/features/pet/memorial_flow_test.dart` e
`test/features/pet/memorial_repository_test.dart`; roteiro de aparelho em
`docs/validation/memorial-pet.md`.

### CT24 — Registrar falecimento (RF33)
- **Passos**: Configurações do Pet → Registrar falecimento → (opcional) data e homenagem → confirmar.
- **Resultado esperado**: abre o memorial; um único evento de auditoria; cancelar no diálogo não altera nada. Voltar (seta, botão ou gesto do Android) leva à lista do Memorial, com o pet, e de novo Voltar leva à Home; o app nunca fecha.

### CT25 — Pet falecido sai da lista principal (RF34)
- **Passos**: após o CT24, voltar à Home.
- **Resultado esperado**: o pet não aparece em "Meus Pets"; aparece uma vez na seção Memorial.

### CT26 — Memorial sem recursos clínicos (RF35)
- **Passos**: abrir o memorial; tentar abrir `/pet/<id>/vacinas`, `/consultas/nova` etc. por link direto.
- **Resultado esperado**: memorial mostra só identidade, dados básicos, homenagem e fotos do pet; as rotas operacionais mostram o aviso "está no Memorial".

### CT27 — Corrigir marcação incorreta (RF36)
- **Passos**: Memorial → Configurações do memorial → Corrigir informação de falecimento → confirmar.
- **Resultado esperado**: perfil ativo com vacinas, consultas e histórico intactos; pet de volta à Home. Voltar no perfil restaurado leva à Home, sem fechar o app.

### CT28 — Outra conta não altera a situação (RF36, RF12)
- **Passos**: com uma segunda conta, tentar atualizar `situacao` do pet de outro tutor.
- **Resultado esperado**: negado pela regra de `update` de `Pets`. ⚠️ Não automatizado (ver `docs/features/memorial-pet.md`, "Testes").

## Galeria de fotos do pet

Automatizados em `test/features/pet/galeria_*_test.dart` e
`tool/firestore-rules/regras.test.js`; roteiro de aparelho em
`docs/validation/galeria-fotos-pet.md`. Rodar com `GALERIA_FOTOS=true`.

### CT29 — Ver a galeria (RF37)
- **Passos**: perfil do pet → Fotos; rolar até o fim com mais de 30 fotos.
- **Resultado esperado**: 3 colunas, mais recentes primeiro, novas páginas ao rolar sem repetir; pet sem fotos mostra "Adicionar primeira foto".

### CT30 — Publicar fotos (RF38)
- **Passos**: Adicionar fotos → escolher 3 → legenda numa → Publicar; repetir com a rede caindo no meio.
- **Resultado esperado**: progresso por foto; as publicadas entram no topo; com falha, "Tentar de novo" envia só as pendentes. GIF/PDF e arquivos acima de 10 MB ficam de fora com aviso.

### CT31 — Visualizador (RF39)
- **Passos**: tocar numa miniatura; pinçar; deslizar; voltar.
- **Resultado esperado**: abre na foto tocada, zoom funciona, desliza entre as fotos, mostra legenda e data, voltar fecha.

### CT32 — Excluir foto (RF40)
- **Passos**: visualizador → Excluir → Cancelar; depois Excluir → Excluir; depois sem rede.
- **Resultado esperado**: cancelar mantém; confirmar remove; sem rede, aviso e a foto continua.

### CT33 — Fotos no Memorial (RF41)
- **Passos**: abrir o memorial de um pet falecido → Adicionar fotos → Ver todas.
- **Resultado esperado**: fotos publicadas e listadas; vacinas, consultas, histórico e localização continuam ocultos.

### CT34 — Outra conta não acessa (RF42)
- **Passos**: com uma segunda conta, tentar listar `Pets/<id do pet da primeira>/fotos` ou abrir `/pet/<id>/fotos`.
- **Resultado esperado**: negado pelas regras (automatizado no emulador, CI) e "Pet não encontrado" na tela. Regras deployadas em 2026-10-27; pela tela, conferido no aparelho (G14 em `docs/validation/galeria-fotos-pet.md`).

