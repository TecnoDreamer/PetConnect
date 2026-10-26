# Changelog

Mudanças relevantes do app PetConnect. Nenhuma versão foi publicada nas
lojas ainda; as entradas abaixo estão agrupadas por entrega.

## [Não publicado]

### Adicionado

- Memorial do Pet: o tutor pode registrar o falecimento de um pet (com
  confirmação), que vira um memorial privado com fotos, informações
  básicas e homenagem; recursos clínicos ficam ocultos e bloqueados, sem
  apagar nenhum dado, e a marcação pode ser corrigida. Disponível no modo
  Firestore. Ver `docs/features/memorial-pet.md`.

### Corrigido

- Tela Criar conta: o painel de cadastro fica na frente do cabeçalho
  marrom e a tela não rola nem se mexe no estado normal. Ver
  `docs/features/cadastro-layout-estatico.md`.
- Telas de autenticação (Login, Cadastro, Esqueci senha) mantêm a
  identidade visual original em qualquer tema escolhido pelo tutor,
  inclusive logo após sair da conta com o tema Escuro. A preferência de
  tema continua valendo na área logada. Ver `docs/features/auth-theme.md`.
