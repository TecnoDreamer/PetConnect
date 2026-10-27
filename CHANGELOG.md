# Changelog

Mudanças relevantes do app PetConnect. Nenhuma versão foi publicada nas
lojas ainda; as entradas abaixo estão agrupadas por entrega.

## [Não publicado]

### Segurança

- Regras do Firestore para a galeria de fotos (`Pets/{petId}/fotos`): só o
  dono lê, publica e exclui; criação validada campo a campo; sem edição.
  Testes no emulador, no CI. Deployadas com as de isolamento em 2026-10-27.
- Regras do Firestore com isolamento por dono (deployadas em 2026-10-27): cada
  tutor só lê e escreve o próprio perfil, os próprios pets e os registros
  deles; pet falecido não aceita novos registros clínicos; eventos do
  Memorial ficam imutáveis. Corrige a regra genérica que deixava qualquer
  usuário logado alterar dados de outros. Testes no Firestore Emulator, no
  CI. Ver `docs/security/firestore-isolamento-por-dono.md`.

### Alterado

- Vacinas, consultas, histórico e localização seguem o tema escolhido
  (Padrão, Claro ou Escuro), como o resto do app; no Escuro deixam de
  aparecer com fundo branco e texto marrom. Ver
  `docs/features/theme-and-settings-menu.md`.
- O tema **Claro** passa a ser o tema principal: quem não escolheu um tema
  abre o app nele, com fundo sempre branco (campos e cartões em cinza bem
  claro para continuarem visíveis). As telas de vacinas, consultas,
  histórico e localização, que tinham fundo bege fixo, também ficam com
  fundo branco. Ver `docs/features/theme-and-settings-menu.md`.

### Adicionado

- Galeria de fotos por pet: em "Fotos", no perfil do pet, o tutor vê as
  fotos em grade de 3 colunas (mais recentes primeiro, em páginas), abre
  em tela cheia com zoom, publica até 10 por vez com legenda e progresso,
  e exclui com confirmação. Pet no Memorial continua recebendo fotos, sem
  reativar recursos clínicos. Privada (só o dono, pelas regras do
  Firestore). Desligada por padrão (`GALERIA_FOTOS`) até a liberação; regras
  deployadas em 2026-10-27 e 1ª rodada no aparelho feita. Ver
  `docs/features/galeria-fotos-pet.md`.
- QR code regenerável: em "QR Code do Pet", o tutor pode gerar um novo QR
  (com confirmação); o anterior para de funcionar na hora. Depende da API
  com os endpoints novos publicada e fica desligado até lá
  (`USE_API_QR`). Ver `docs/features/qr-regeneravel.md`.
- Memorial do Pet: o tutor pode registrar o falecimento de um pet (com
  confirmação), que vira um memorial privado com fotos, informações
  básicas e homenagem; recursos clínicos ficam ocultos e bloqueados, sem
  apagar nenhum dado, e a marcação pode ser corrigida. Disponível no modo
  Firestore. Ver `docs/features/memorial-pet.md`.

### Corrigido

- Login: Google, Facebook e "Cadastre-se" ficam logo abaixo do card, em vez
  de isolados na base da tela. Ver
  `docs/features/login-espacamento-acoes-sociais.md`.
- Consultas: os botões "Marcar realizada" e "Cancelar" não estouram mais
  a largura em telas estreitas com fonte ampliada.
- Home: a linha "Meus Pets" com o botão "Adicionar pet" não estoura mais
  em telas estreitas com fonte ampliada; o rótulo do botão quebra dentro
  da pílula.
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
