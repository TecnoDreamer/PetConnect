# Diagrama de Classes — PetConnect

> ⚠️ **Legado**: reflete o modelo do **Firestore** (nomes de campo em
> português, coleções `Usuarios`/`Pets`). O schema real do MongoDB (que
> a API usa) tem nomes em inglês e campos adicionais (`publicId`,
> `legacyFirestoreId`, `vaccinatedFlag`, etc.) — ver
> `docs/database/mongodb-target-schema.md` para o schema atual, e
> `docs/validation/rf01-rf32-parity.md` para o mapeamento campo a campo
> confirmado entre os dois modelos.

Atualizado para refletir a estrutura real do Firestore já existente (`docs/modelo-dados-firestore.md`) — nomes de classe e campo em português, alinhados às coleções `Usuarios` e `Pets`.

```mermaid
classDiagram
    class Usuario {
        +String id
        +String usuarioID
        +String nome
        +String email
        +String telefone
        +String dataNascimento
        +String genero
        +String? foto
    }

    class Pet {
        +String id
        +String userId
        +String nome
        +String especie
        +String raca
        +String cor
        +String genero
        +String porte
        +String peso
        +String dataNascimento
        +String? dono
        +String? telefone
        +bool vacinado
    }

    class Vacina {
        +String id
        +String petId
        +String nome
        +String dataAplicacao
        +String? proximaDose
        +String? veterinario
        +String? observacoes
    }

    class RegistroMedico {
        +String id
        +String petId
        +String data
        +String descricao
        +String? veterinario
        +List~String~ anexos
    }

    class StatusConsulta {
        <<enumeration>>
        agendada
        realizada
        cancelada
    }

    class Consulta {
        +String id
        +String petId
        +String data
        +String? horario
        +String veterinario
        +String motivo
        +StatusConsulta status
    }

    class Localizacao {
        <<a confirmar>>
        +String id
        +String petId
    }

    class UsuarioRepository {
        <<interface>>
        +signIn(email, senha) Future~Usuario~
        +signUp(nome, email, senha) Future~Usuario~
        +signInWithGoogle() Future~Usuario~
        +signInWithFacebook() Future~Usuario~
        +sendPasswordReset(email) Future~void~
        +signOut() Future~void~
        +currentUser() Stream~Usuario?~
    }

    class PetRepository {
        <<interface>>
        +watchPets(userId) Stream~List~Pet~~
        +getPet(petId) Future~Pet~
        +createPet(pet) Future~String~
        +updatePet(pet) Future~void~
        +deletePet(petId) Future~void~
        +regenerateQrCode(petId) Future~String~
    }

    class VacinaRepository {
        <<interface>>
        +watchVacinas(petId) Stream~List~Vacina~~
        +addVacina(vacina) Future~void~
        +updateVacina(vacina) Future~void~
        +deleteVacina(id) Future~void~
    }

    class RegistroMedicoRepository {
        <<interface>>
        +watchRegistros(petId) Stream~List~RegistroMedico~~
        +addRegistro(registro) Future~void~
    }

    class ConsultaRepository {
        <<interface>>
        +watchConsultas(petId) Stream~List~Consulta~~
        +schedule(consulta) Future~void~
        +updateStatus(id, status) Future~void~
    }

    class FirestorePetRepository {
        -FirebaseFirestore firestore
    }

    Usuario "1" --> "many" Pet : possui
    Pet "1" --> "many" Vacina : tem
    Pet "1" --> "many" RegistroMedico : tem
    Pet "1" --> "many" Consulta : tem
    Pet "1" --> "many" Localizacao : recebe (a confirmar)
    Consulta --> StatusConsulta

    PetRepository <|.. FirestorePetRepository : implementa
    PetRepository ..> Pet
    VacinaRepository ..> Vacina
    RegistroMedicoRepository ..> RegistroMedico
    ConsultaRepository ..> Consulta
    UsuarioRepository ..> Usuario
```

## Notas

- `Usuario.id` é o UID do Firebase Auth (mesmo valor do `docId` em `Usuarios`); `usuarioID` é um campo separado (UUID) já existente no banco — uso ainda a confirmar (ver `docs/modelo-dados-firestore.md`).
- `Pet.dono` existe no banco real mas sua função é redundante com `userId` — mantido no modelo até confirmação, não usado nas regras de negócio por enquanto.
- `Pet.vacinado` é o campo simples adicionado nesta fase. `Vacina` (subcoleção) é a proposta de histórico detalhado, ainda não implementada no banco.
- `Localizacao` entra como classe provisória — estrutura real pendente de confirmação.
- Datas são `String` (formato `dd/MM/yyyy`), seguindo a convenção já usada no banco existente, não `DateTime`/`Timestamp` nativos.
- Repositórios são interfaces (`abstract class` em Dart) na camada `domain`, implementadas na camada `data` com Firestore.

## Galeria de fotos do pet

`FotoPet`, `GaleriaRepository`, `EnvioDeFotos` e `GaleriaController`: ver o
diagrama em `docs/features/galeria-fotos-pet.md` ("Arquitetura").
