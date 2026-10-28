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

## 3. Visitante escaneia o QR code (RF17, RF18)

```mermaid
sequenceDiagram
    actor Visitante
    participant Camera as Câmera / leitor de QR
    participant Web as Navegador
    participant Func as Cloud Function (página pública)
    participant Store as Firestore (Admin SDK)

    Visitante->>Camera: escaneia o QR code físico do pet
    Camera->>Web: abre URL pública (contém petId)
    Web->>Func: GET /pet/{petId}
    Func->>Store: busca pets/{petId} com privilégios de admin
    alt pet encontrado
        Store-->>Func: dados do pet
        Func->>Func: filtra apenas campos públicos (nome, foto, espécie/raça, contato do tutor)
        Func-->>Web: HTML/JSON com informações públicas
        Web-->>Visitante: exibe página com dados do pet
    else pet não encontrado ou QR code invalidado
        Store-->>Func: não encontrado
        Func-->>Web: página "pet não encontrado"
        Web-->>Visitante: exibe mensagem de erro amigável
    end
```

## Galeria de fotos do pet (RF37–RF42)

Publicar, listar e excluir, com o tratamento de falha parcial: ver
`docs/features/galeria-fotos-pet.md` ("Arquitetura").
