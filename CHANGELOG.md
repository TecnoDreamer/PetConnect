# Changelog

Mudanças relevantes do app PetConnect. Nenhuma versão foi publicada nas
lojas ainda; as entradas abaixo estão agrupadas por entrega.

## [Não publicado]

### Alterado

- O tema **Claro** passa a ser o tema principal: quem não escolheu um tema
  abre o app nele, com fundo sempre branco (campos e cartões em cinza bem
  claro para continuarem visíveis). As telas de vacinas, consultas,
  histórico e localização, que tinham fundo bege fixo, também ficam com
  fundo branco. Ver `docs/features/theme-and-settings-menu.md`.

### Adicionado

- Memorial do Pet: o tutor pode registrar o falecimento de um pet (com
  confirmação), que vira um memorial privado com fotos, informações
  básicas e homenagem; recursos clínicos ficam ocultos e bloqueados, sem
  apagar nenhum dado, e a marcação pode ser corrigida. Disponível no modo
  Firestore. Ver `docs/features/memorial-pet.md`.

### Corrigido

- Android: o app aparece como **PetConnect** (não `pet_connect`) e usa o
  logo oficial (marcador com cachorro e gato) no launcher, com adaptive
  icon e ícone temático, em vez do ícone padrão do Flutter. A abertura
  mostra só a splash da marca (nativa + continuação idêntica no Flutter),
  sem a espera fixa de 2,5s. Ver `docs/branding/icone-e-splash-android.md`.
- Tela de Login: a altura da tela é distribuída entre o cabeçalho e o
  espaço entre o card e os botões de login social, que ficam ancorados
  embaixo, sem a faixa vazia que sobrava; o slogan deixa de ficar atrás
  do card. Ver `docs/features/login-layout-distribuido.md`.
- Tela Criar conta: o painel de cadastro fica na frente do cabeçalho
  marrom e a tela não rola nem se mexe no estado normal. Ver
  `docs/features/cadastro-layout-estatico.md`.
- Telas de autenticação (Login, Cadastro, Esqueci senha) mantêm a
  identidade visual original em qualquer tema escolhido pelo tutor,
  inclusive logo após sair da conta com o tema Escuro. A preferência de
  tema continua valendo na área logada. Ver `docs/features/auth-theme.md`.
