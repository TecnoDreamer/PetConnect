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
        Web-)API: POST /events {"type":"qr_page_opened"} (sem coordenada, sem esperar)
        API->>Mongo: qr_access_events (pet e hora, TTL 90 dias)
    end
```

### Visitante relata o avistamento e o tutor vê (RF31, RF32, RF52)

Adicionado em 2026-11-03 (issue #37). Desde 2026-11-04, a localização é
pedida assim que a página mostra o pet e, com a permissão, vai sozinha uma
vez.

```mermaid
sequenceDiagram
    actor Visitante
    participant Nav as Navegador (Geolocation)
    participant Web as Página pública
    participant API as API Spring
    participant Mongo as MongoDB (locations, qr_access_events)
    actor Tutor
    participant App

    Web->>Nav: getCurrentPosition ao mostrar o pet (alta precisão, 15 s)
    Nav-->>Visitante: "Permitir que o site use sua localização?"
    alt permissão negada ou sem sinal
        Nav-->>Web: erro
        Web-->>Visitante: "descreva onde viu o pet" + Tentar enviar a localização
    else permitido
        Nav-->>Web: latitude, longitude, precisão
        Web->>API: POST /sightings {coordenada, accuracyMeters, clientRequestId}
        API->>Mongo: locations (positionSource decidido pelo servidor; mesmo clientRequestId não duplica)
        API-->>Web: 201 sem corpo
        Web-->>Visitante: "Localização enviada ao tutor, precisão de cerca de X m"
    end
    opt relato em texto
        Visitante->>Web: escreve e toca em Avisar o tutor
        Web->>API: POST /sightings {texto, coordenada?, outro clientRequestId}
        API-->>Web: 201 sem corpo
    end
    Tutor->>App: abre Localização do pet
    App->>API: GET /legacy-pets/{id}/qr-activity (token)
    API->>Mongo: relatos e acessos do pet (dono conferido no Firestore)
    API-->>App: sightings + recentAccesses + accessesLast30Days
    App-->>Tutor: relatos com precisão e "Abrir no mapa"; acessos à parte
```

### Aviso ao tutor por push (RF53)

Adicionado em 2026-11-03 (issue #36). O push sai depois de gravar o evento,
fora da requisição da página.

```mermaid
sequenceDiagram
    participant Web as Página pública
    participant API as API Spring
    participant Mongo as MongoDB (push_devices, tutor_notifications)
    participant FCM as Firebase Cloud Messaging
    participant App
    actor Tutor

    App->>API: PUT /me/push-devices {token} (depois do login e da permissão)
    Web->>API: POST /events (qr_page_opened) ou POST /sightings
    API-->>Web: 202 / 201 (sem esperar o push)
    API->>API: preferências do pet (acesso: avisa a cada abertura)
    API->>Mongo: tutor_notifications PENDING
    API->>FCM: título + ids do pet (canal qr_avisos, visibilidade privada)
    alt token inválido
        FCM-->>API: UNREGISTERED
        API->>Mongo: apaga o token; FAILED
    else entregue ao FCM
        FCM-->>API: ok
        API->>Mongo: SENT
        FCM-)App: notificação
        Tutor->>App: toca na notificação
        App-->>Tutor: login (se preciso) e aba Localização do pet
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
