# 🐾 PetConnect

App mobile para localização de pets desaparecidos. Cada tutor cadastra seus pets; cada pet tem um perfil com carteira de vacina, histórico médico e agendamento de consultas, além de um **QR code** que abre uma página pública com informações básicas do pet — para ajudar quem o encontrar a devolvê-lo ao tutor.

[![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.22-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore%20%7C%20Storage-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-lightgrey)](#)
[![Status](https://img.shields.io/badge/status-em%20desenvolvimento-yellow)](#status-do-projeto)
[![License: TBD](https://img.shields.io/badge/license-a%20definir-inactive)](#)

## Índice

- [Sobre o projeto](#sobre-o-projeto)
- [Status do projeto](#status-do-projeto)
- [Stack](#stack)
- [Estrutura do projeto](#estrutura-do-projeto)
- [Como rodar](#como-rodar)
- [Documentação](#documentação)
- [Contribuindo](#contribuindo)
- [Roadmap](#roadmap)

## Sobre o projeto

O PetConnect resolve um problema concreto: pets fugidos ou perdidos raramente carregam uma forma confiável de identificação que leve de volta ao tutor. O app permite que qualquer pessoa que encontre um pet cadastrado escaneie o QR code em sua coleira (ou etiqueta) e veja, sem precisar instalar nada, o essencial para devolvê-lo — sem expor dados sensíveis do tutor ou o histórico médico completo do animal.

Além disso, centraliza para o tutor:
- 🐶 **Perfil de cada pet** — nome, espécie, raça, data de nascimento e foto.
- 💉 **Carteira de vacina** — histórico de vacinas aplicadas e alertas de próxima dose.
- 🩺 **Histórico médico** — consultas, exames e anotações por pet.
- 📅 **Agendamento de consultas** — com lembretes.
- 🔗 **QR code** — página pública de identificação, regenerável a qualquer momento.
- 🖼️ **Galeria de fotos** — fotos particulares de cada pet, também no Memorial (desligada por padrão; regras já publicadas, falta liberar).
- 📢 **Cartaz de pet desaparecido** — cartaz "Procura-se" com 3 fotos e o telefone autorizado, gerado no celular, em PNG ou PDF, para compartilhar ou imprimir.

## Status do projeto

> Projeto em desenvolvimento ativo. A tabela abaixo reflete o que já está implementado e funcionando, não apenas planejado.

| Área | Status | Requisitos |
|---|---|---|
| Estrutura, documentação e modelo de dados | ✅ Concluído | — |
| Conexão com Firebase (projeto real `pet-connect-c53f1`) | ✅ Concluído | — |
| Cadastro, login e recuperação de senha (e-mail/senha) | ✅ Concluído | RF01–RF03, RF05 |
| Sessão persistida + rotas protegidas | ✅ Concluído | RF06 |
| Logout | ✅ Concluído | RF07 |
| Login com Google | 🔍 Em revisão — conta criada com o Google no aparelho; falta o resto do roteiro (Facebook fora do escopo) | RF04-A |
| Edição/exclusão da conta do tutor (nome, sobrenome, telefone, nascimento, gênero, foto) | ✅ Concluído | RF08–RF09 |
| Gestão de pets (cadastro, listagem, edição, exclusão) | ✅ Concluído | RF10–RF15 |
| QR code de identificação (exibido no app) | ✅ Concluído | RF16 |
| Página pública do QR code + regeneração | ⬜ Não iniciado | RF17–RF19 |
| Carteira de vacina (registro, listagem, edição, exclusão, alerta visual) | ✅ Concluído | RF20–RF23 |
| Histórico médico (com anexos no Cloudinary) | ✅ Concluído | RF24–RF26 |
| Agendamento de consultas (agendar, listar por status, cancelar, marcar realizada, alerta visual) | ✅ Concluído | RF27–RF30 |
| Localização — tutor registra/visualiza avistamentos | ✅ Concluído | RF32 |
| Memorial do Pet (registrar falecimento, memorial privado, correção) — modo Firestore | 🔍 Em revisão | RF33–RF36 |
| Galeria de fotos por pet (privada, também no Memorial) — modo Firestore, flag `GALERIA_FOTOS` | 🔍 Em revisão | RF37–RF42 |
| Cartaz de pet desaparecido (PNG e PDF, gerado no aparelho) | 🔍 Em revisão — falta validar no aparelho | RF43–RF49 |
| Localização — relato direto por quem encontrou o pet (via QR code) | ⬜ Bloqueado por RF17–RF19 | RF31 |

Veja a lista completa de requisitos em [`docs/requisitos-funcionais.md`](docs/requisitos-funcionais.md).

## Stack

| Camada | Tecnologia |
|---|---|
| App mobile | [Flutter](https://flutter.dev) (Android + iOS) |
| Estado | [Riverpod](https://riverpod.dev) |
| Navegação | [go_router](https://pub.dev/packages/go_router) |
| Backend | [Firebase](https://firebase.google.com) — Authentication, Firestore, Cloud Functions |
| Upload de imagens | [Cloudinary](https://cloudinary.com) (não Firebase Storage — exige plano pago) |
| Identificação do pet | QR code ([qr_flutter](https://pub.dev/packages/qr_flutter)) |

## Estrutura do projeto

Organização **feature-first** — cada funcionalidade tem suas próprias camadas de `data`, `domain` e `presentation`, sem uma pasta `screens/` genérica misturando tudo:

```
lib/
├── core/            # tema, constantes, tratamento de erro e widgets compartilhados
├── features/
│   ├── auth/        # telas de login, cadastro, recuperação de senha
│   ├── usuario/      # conta do tutor (dados, providers de autenticação)
│   └── pet/          # perfil, carteira de vacina, histórico médico (em construção)
└── routing/          # configuração central do go_router
```

Detalhes e justificativa em [`docs/arquitetura.md`](docs/arquitetura.md).

## Como rodar

Pré-requisitos: [Flutter SDK](https://flutter.dev/docs/get-started/install) instalado e configurado (`flutter doctor` sem erros bloqueantes).

```bash
flutter pub get
flutter run
```

O projeto Firebase (`pet-connect-c53f1`) já existe, com as coleções `Usuarios`, `Pets` e `Localizacoes` em uso. É necessário rodar [`flutterfire configure`](https://firebase.flutter.dev/docs/cli) para conectar seu ambiente local a esse projeto — o comando gera `lib/firebase_options.dart`, que **não é versionado** (ver `.gitignore`) por conter identificadores do projeto Firebase.

Upload de fotos (pet, tutor, anexos) usa o Cloudinary, não o Firebase Storage. Configure uma conta gratuita e preencha `lib/core/config/cloudinary_config.dart` — instruções no próprio arquivo.

### Build Android, nome e ícone

O app aparece no aparelho como **PetConnect** (o `applicationId` continua
`com.petconnect.pet_connect`). Ícone e splash vêm do logo oficial
(`assets/images/logo.png`) e são regerados com:

```bash
python tool/branding/gerar_icones_android.py
```

APK de teste: `flutter build apk --debug`. Detalhes em
[`docs/branding/icone-e-splash-android.md`](docs/branding/icone-e-splash-android.md).

APK para testadores (release, assinado com a chave de upload do
proprietário, que fica fora do Git): `flutter build apk --release
--dart-define=GALERIA_FOTOS=true`. Sem `android/key.properties`, o build de
release falha de propósito. Passo a passo da chave, segurança e guia do
testador em
[`docs/release/apk-testes-externos.md`](docs/release/apk-testes-externos.md)
e [`docs/validation/apk-testes-externos.md`](docs/validation/apk-testes-externos.md).

### Rodando os testes

```bash
flutter test
```

## Documentação

Toda a documentação detalhada do projeto está em [`docs/`](docs/):

- [Requisitos funcionais](docs/requisitos-funcionais.md)
- [Requisitos não funcionais](docs/requisitos-nao-funcionais.md)
- [Casos de teste](docs/casos-de-teste.md)
- [Segurança](docs/seguranca.md)
- [Arquitetura](docs/arquitetura.md)
- [Ícone, nome e splash do Android](docs/branding/icone-e-splash-android.md)
- [Modelo de dados (Firestore)](docs/modelo-dados-firestore.md)
- [Galeria de fotos por pet](docs/features/galeria-fotos-pet.md)
- [App em português do Brasil](docs/features/idioma-portugues.md)
- [Cartaz de pet desaparecido](docs/features/cartaz-pet-desaparecido.md) (como testar: [roteiro de aparelho](docs/validation/cartaz-pet-desaparecido.md))
- Diagramas: [caso de uso](docs/diagramas/caso-de-uso.md) · [sequência](docs/diagramas/sequencia.md) · [classes](docs/diagramas/classes.md)

## Contribuindo

Fluxo de branches, convenção de commits e checklist de Pull Request estão descritos em [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Roadmap

Ordem planejada para as próximas entregas, uma feature por Pull Request:

1. ✅ ~~Gestão de pets (RF10–RF15)~~
2. 🔗 QR code: ✅ ~~geração no app (RF16)~~ · página pública + regeneração (RF17–RF19) pendente
3. ✅ ~~Carteira de vacina (RF20–RF23)~~
4. ✅ ~~Histórico médico (RF24–RF26)~~
5. ✅ ~~Agendamento de consultas (RF27–RF30)~~
6. 📍 Localização: ✅ ~~tutor registra/visualiza avistamentos (RF32)~~ · relato direto pelo QR code (RF31) depende do item 2
