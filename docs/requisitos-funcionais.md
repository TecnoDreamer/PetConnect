# Requisitos Funcionais — PetConnect

Convenção: `RFxx` — identificador único, usado também para rastrear casos de teste (`docs/casos-de-teste.md`) e referenciar em Pull Requests.

## Autenticação e conta

| ID | Requisito |
|----|-----------|
| RF01 | O sistema deve permitir que um visitante crie uma conta de tutor com nome, e-mail e senha. |
| RF02 | O sistema deve validar formato de e-mail e força mínima de senha no cadastro. |
| RF03 | O sistema deve impedir cadastro com e-mail já existente, informando erro claro. |
| RF04 | O sistema deve permitir login com e-mail e senha. |
| RF04-A | O sistema deve permitir login/cadastro via Google (Firebase Auth + Google Sign-In). Conta com o mesmo e-mail por senha só é vinculada depois de o tutor entrar nela (ADR 0006). Firebase configurado em 2026-10-27; validação no aparelho em `docs/validation/login-social.md`. Testes: `login_social_repository_test.dart`, `provedores_sociais_test.dart`, `login_social_screen_test.dart`, CT04-A, CT04-C. |
| RF04-B | ~~Login/cadastro via Facebook.~~ **Fora do escopo** por decisão do proprietário (2026-10-27). Ver `docs/features/login-social.md`. |
| RF05 | O sistema deve permitir recuperação de senha via e-mail ("Esqueci minha senha"). |
| RF06 | O sistema deve manter a sessão do tutor autenticado entre aberturas do app. |
| RF07 | O sistema deve permitir logout. |
| RF08 | O sistema deve permitir que o tutor edite os dados da própria conta (nome, foto, telefone). |
| RF09 | O sistema deve permitir que o tutor exclua a própria conta, com confirmação explícita. |

## Gestão de pets

| ID | Requisito |
|----|-----------|
| RF10 | O sistema deve permitir que um tutor cadastre um ou mais pets (nome, espécie, raça, data de nascimento, foto). |
| RF11 | O sistema deve listar, na tela inicial do tutor, todos os pets vinculados à sua conta. |
| RF12 | O sistema deve exibir apenas os pets pertencentes ao tutor autenticado — nenhum outro tutor pode ver ou editar esses pets. |
| RF13 | O sistema deve permitir editar os dados de um pet já cadastrado. |
| RF14 | O sistema deve permitir excluir um pet, com confirmação explícita. |
| RF15 | Ao abrir o perfil de um pet, o sistema deve mostrar apenas as informações daquele pet específico. |

## QR Code

| ID | Requisito |
|----|-----------|
| RF16 | O sistema deve gerar um QR code único para cada pet cadastrado, exibido no perfil do pet. |
| RF17 | Ao ser escaneado por qualquer pessoa, o QR code deve abrir uma página web pública com informações do pet destinadas à sua identificação e devolução (nome, foto, espécie/raça, contato do tutor). |
| RF18 | A página pública do QR code não deve exibir histórico médico completo nem dados de contato além do necessário para a devolução do pet. |
| RF19 | O sistema deve permitir ao tutor regenerar o QR code de um pet (ex: em caso de suspeita de uso indevido do código anterior). |

## Carteira de vacina

| ID | Requisito |
|----|-----------|
| RF20 | O sistema deve permitir registrar vacinas aplicadas a um pet (nome da vacina, data de aplicação, data da próxima dose, veterinário/clínica). |
| RF20-A | O perfil do pet deve indicar de forma simples e direta se ele está vacinado ou não (campo `vacinado`, booleano). |
| RF21 | O sistema deve listar as vacinas de um pet em ordem cronológica. |
| RF22 | O sistema deve permitir editar e excluir um registro de vacina. |
| RF23 | O sistema deve alertar o tutor quando a próxima dose de uma vacina estiver próxima ou vencida. |

## Histórico médico

| ID | Requisito |
|----|-----------|
| RF24 | O sistema deve permitir registrar entradas de histórico médico (data, descrição, veterinário, anexos como exames). |
| RF25 | O sistema deve listar o histórico médico de um pet em ordem cronológica. |
| RF26 | O sistema deve permitir editar e excluir uma entrada do histórico médico. |

## Agendamento de consultas

| ID | Requisito |
|----|-----------|
| RF27 | O sistema deve permitir agendar uma consulta veterinária para um pet (data/hora, veterinário/clínica, motivo). |
| RF28 | O sistema deve listar consultas agendadas, distinguindo futuras, concluídas e canceladas. |
| RF29 | O sistema deve permitir editar, cancelar e marcar uma consulta como realizada. |
| RF30 | O sistema deve notificar o tutor sobre consultas agendadas próximas. |

## Localização

> **Atualizado**: implementado de ponta a ponta na API (`location`
> module, FASE 9 da migração) — deixa de ser proposta. Detalhe completo
> e evidência de teste em `docs/validation/rf01-rf32-parity.md`. A
> experiência de ponta a ponta (achador escaneando um QR e vendo/reportando
> pela página pública) ainda depende da FASE 9 web (hospedagem pendente) —
> o endpoint em si já existe e está testado.

| ID | Requisito |
|----|-----------|
| RF31 | Quando alguém encontra um pet e acessa a página pública do QR code, o sistema permite registrar a localização onde o pet foi visto — `POST /api/v1/public/pets/{publicId}/sightings`, anônimo, com rate limiting. |
| RF32 | O tutor consegue visualizar os registros de localização reportados para seu pet — `GET /api/v1/pets/{id}/locations`, autenticado. |

## Memorial do Pet

Detalhes em `docs/features/memorial-pet.md`.

| ID | Requisito | Testes |
|----|-----------|--------|
| RF33 | O tutor dono pode registrar o falecimento de um pet ativo, a partir das Configurações do Pet, com explicação e confirmação explícita; data do falecimento e homenagem são opcionais. Ao concluir, o app abre o memorial; Voltar leva à lista do Memorial e, dela, à Home, sem fechar o app. | `memorial_flow_test.dart` (Registrar falecimento), `memorial_navegacao_test.dart`, `memorial_repository_test.dart`, CT24 |
| RF34 | Pets falecidos saem da lista principal e aparecem na seção Memorial, privada, sem duplicação. | `memorial_flow_test.dart` (Home), CT25 |
| RF35 | O memorial mostra nome, foto, capa, dados básicos existentes, homenagem e as fotos do próprio pet, e não exibe nem carrega recursos clínicos ou operacionais, inclusive por link direto. | `memorial_flow_test.dart` (Tela do memorial, Proteção de rotas), CT26 |
| RF36 | O tutor pode corrigir um falecimento registrado por engano; o pet volta a ficar ativo com todos os dados preservados. Toda transição é auditada e nenhuma exclui dados. | `memorial_repository_test.dart`, `memorial_flow_test.dart` (Corrigir marcação), `memorial_navegacao_test.dart`, CT27 |

## Galeria de fotos do pet

Detalhes em `docs/features/galeria-fotos-pet.md`. Desligada por padrão
(`GALERIA_FOTOS`). As regras foram deployadas em 2026-10-27; ligar para os
usuários é a decisão D4 do ADR 0005.

| ID | Requisito | Testes |
|----|-----------|--------|
| RF37 | O tutor vê as fotos de cada pet seu numa grade de 3 colunas, mais recentes primeiro, carregada em páginas. | `galeria_telas_test.dart` (Grade), `galeria_repository_test.dart` (listar), CT29 |
| RF38 | O tutor publica até 10 fotos por vez, com prévia e legenda opcional de até 300 caracteres; só JPEG, PNG, WebP e HEIC de até 10 MB. | `galeria_telas_test.dart` (Publicar), `galeria_dominio_test.dart`, CT30 |
| RF39 | O tutor abre uma foto em tela cheia, com zoom e navegação entre as fotos, legenda e data. | `galeria_telas_test.dart` (Visualizador), CT31 |
| RF40 | O tutor exclui uma foto, com confirmação; se a exclusão falhar, a foto continua. | `galeria_telas_test.dart` (Visualizador), `galeria_repository_test.dart` (excluir), CT32 |
| RF41 | Pet no Memorial continua recebendo e mostrando fotos, sem reativar recursos clínicos. | `galeria_telas_test.dart` (Memorial e perfil), `regras.test.js`, CT33 |
| RF42 | Só o tutor dono lista, lê, publica e exclui as fotos de um pet; outra conta e quem não está logado não. | `regras.test.js` (fotos), `galeria_telas_test.dart` (outro tutor), CT34 |

## Fora de escopo nesta fase

- Chat entre tutor e quem encontrou o pet.
- Geolocalização em tempo real do pet.
- Múltiplos tutores compartilhando o mesmo pet (ex: casais, famílias).
- Curtidas, comentários, feed e perfis públicos na galeria de fotos.

Esses itens podem voltar como requisitos futuros, mas não fazem parte da primeira versão.
