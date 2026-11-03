# Diagramas de Sequência — PetConnect

> ⚠️ **Legado**: as sequências abaixo mostram o app falando direto com
> o Firestore — válido só para quando as feature flags (`USE_API_*`)
> estão desligadas. Com a flag ligada, o passo "Firestore" abaixo é
> substituído por "API Spring Boot → MongoDB" (ver
> `docs/diagramas/arquitetura.md`); a sequência de interação (usuário →
> tela → repositório) não muda, só o que está atrás do repositório.

## 1. Login do tutor (RF04, RF06)

```mermaid
sequenceDiagram
    actor Tutor
    participant App as App (Flutter)
    participant Auth as Firebase Auth
    participant Store as Firestore

    Tutor->>App: informa e-mail e senha
    App->>Auth: signInWithEmailAndPassword()
    alt credenciais válidas
        Auth-->>App: uid + token
        App->>Store: busca users/{uid}
        Store-->>App: dados do tutor
        App-->>Tutor: navega para Home (lista de pets)
    else credenciais inválidas
        Auth-->>App: erro de autenticação
        App-->>Tutor: exibe "e-mail ou senha inválidos"
    end
```

Login com Google (RF04-A), incluindo a vinculação de conta existente:
diagramas em `docs/features/login-social.md`.

## 2. Cadastro de pet e geração de QR code (RF10, RF16)

```mermaid
sequenceDiagram
    actor Tutor
    participant App as App (Flutter)
    participant Store as Firestore
    participant QR as Gerador de QR (qr_flutter)

    Tutor->>App: preenche dados do pet e confirma
    App->>App: valida campos obrigatórios
    App->>Store: cria documento em pets/{petId} (tutorId = uid)
    Store-->>App: petId gerado
    App->>QR: gera QR code apontando para URL pública do pet (com petId)
    QR-->>App: imagem do QR code
    App->>Store: salva referência do QR code no documento do pet
    App-->>Tutor: exibe perfil do pet com QR code
```

## 3. Visitante escaneia o QR code (RF17, RF18, RF51)

Atualizado em 2026-11-02 (issue #35). A página é estática no Firebase
Hosting e lê os dados pela API Spring; não há Cloud Function.

```mermaid
sequenceDiagram
    actor Visitante
    participant Camera as Câmera / leitor de QR
    participant Web as Página pública (Hosting)
    participant API as API Spring (Render)
    participant Mongo as MongoDB (pets, pet_public_sharing)
    participant Store as Firestore (Admin SDK, leitura)

    Visitante->>Camera: escaneia o QR code do pet
    Camera->>Web: abre /pet/{publicId}
    Web->>API: GET /api/v1/public/pets/{publicId}
    API->>Mongo: pet pelo publicId (ou publicId determinístico da configuração)
    alt QR inexistente ou revogado
        API-->>Web: 404
        Web-->>Visitante: "não encontramos esse pet"
    else pet encontrado
        API->>Store: lê Pets/{id} (existe? Memorial? dono?)
        alt excluído ou no Memorial
            API-->>Web: 404
        else sem consentimento ativo
            API-->>Web: {"shared": false} (no-store)
            Web-->>Visitante: "cadastrado no PetConnect" + formulário
        else consentimento ativo
            API-->>Web: só os campos marcados (no-store)
            Web-->>Visitante: dados autorizados + formulário
        end
    end
```

### Tutor publica ou revoga (RF51)

```mermaid
sequenceDiagram
    actor Tutor
    participant App
    participant API as API Spring
    participant Store as Firestore (Admin SDK, leitura)
    participant Mongo as MongoDB

    Tutor->>App: marca campos e o consentimento, toca em Publicar
    App->>API: PUT /legacy-pets/{id}/public-sharing (token)
    API->>Store: lê Pets/{id}; userId = UID do token?
    alt outro dono ou pet inexistente
        API-->>App: 404
    else dono
        API->>Mongo: salva pet_public_sharing e grava o evento ACCEPTED/UPDATED
        API-->>App: configuração ativa
    end
    Tutor->>App: Desativar página pública
    App->>API: PUT {"enabled": false}
    API->>Mongo: revoga, apaga telefone e nome, grava REVOKED
    API-->>App: desativada (vale no acesso seguinte)
```

## Galeria de fotos do pet (RF37–RF42)

Publicar, listar e excluir, com o tratamento de falha parcial: ver
`docs/features/galeria-fotos-pet.md` ("Arquitetura").

## Cartaz de pet desaparecido (RF43–RF49)

Prévia, captura em PNG, PDF e compartilhamento: ver
`docs/features/cartaz-pet-desaparecido.md` ("Arquitetura").
