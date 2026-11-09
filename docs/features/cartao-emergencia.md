# Cartão de Emergência do pet

> Branch: `feat/41-cartao-emergencia-pet`. Issue #41. Decisão:
> `docs/decisions/0009-cartao-emergencia-privado.md`. Roteiro no aparelho:
> `docs/validation/cartao-emergencia.md`.

## Objetivo

Deixar à mão, dentro do app, o que um veterinário precisa saber numa
urgência: alergias, medicamentos em uso, condições clínicas, tipo sanguíneo,
observações e o contato do veterinário de confiança e do tutor.

**Versão 1: privada.** Nada vai para a página pública do QR, para a API, para
links ou para compartilhamento automático.

## Onde fica no app

| Situação do pet | Entrada | O que dá para fazer |
|---|---|---|
| Ativo | Perfil do pet > card **Cartão de Emergência**, abaixo dos quatro cards | Ler e editar |
| No Memorial | Memorial > Configurações > **Cartão de Emergência** | Só ler |

**Rotas:**
- `/pet/:id/emergencia`: leitura, pet ativo ou no Memorial, só do dono.
- `/pet/:id/emergencia/editar`: edição, só pet ativo, só do dono.

**Flag:** `--dart-define=CARTAO_EMERGENCIA=true`, desligado por padrão. Só
vale no modo Firestore; com `USE_API_PETS`, fica oculto, como a galeria. Ver
"Liberação" abaixo.

## Regras de produto

- **"Não informado" não é "Não possui".** Alergias, medicamentos e condições
  têm três situações:
  - `NAO_INFORMADO`: ninguém disse nada. A tela mostra "Não informado".
  - `NENHUMA_DECLARADA`: o tutor declarou que não há. A tela mostra
    "Nenhuma conhecida (declarado pelo tutor)".
  - `INFORMADA`: há itens.
- **Nada é deduzido.** Documento antigo, campo ausente ou valor desconhecido
  vira "Não informado". "Informada" sem item válido também.
- **Tipo sanguíneo:** texto livre, sem lista universal, porque os sistemas de
  cães e gatos são diferentes. Só é gravado quando o tutor marca que o tipo
  veio de exame ou do veterinário.
- **Dose:** texto do tutor, com a unidade ("5 mg"). O app não sugere, não
  calcula e não confere dose.
- **Peso:** fora do cartão. O peso do cadastro não tem data, então não dá
  para dizer se está atual.
- **Contato do tutor:** vem do perfil, na hora da leitura. Não é copiado
  para o cartão. O tutor escolhe se ele aparece.
- **Ligar:** abre o discador com o número. Quem liga é a pessoa.
- **Aviso fixo:** "Informações fornecidas pelo tutor; confirme com o
  veterinário." e "Atualizado em …" quando houver data.

## Modelo de dados

`Pets/{petId}/emergencia/cartao`, um documento por pet:

| Campo | Tipo | Observação |
|---|---|---|
| `versaoEsquema` | int | Sempre `1` nesta versão |
| `situacaoAlergias`, `situacaoMedicamentos`, `situacaoCondicoes` | string | `NAO_INFORMADO`, `NENHUMA_DECLARADA` ou `INFORMADA` |
| `alergias` | lista (até 20) | `{id, substancia, reacao?, observacao?}` |
| `medicamentos` | lista (até 20) | `{id, nome, dose?, frequencia?, via?, observacao?}` |
| `condicoes` | lista de texto (até 20) | |
| `tipoSanguineo` | string (até 40) | Vazio sem confirmação |
| `tipoSanguineoConfirmado` | bool | |
| `observacoes` | string (até 1000) | |
| `veterinario` | mapa | `{nome?, clinica?, telefone?}`, telefone em E.164 |
| `mostrarContatoDoTutor` | bool | |
| `revisao` | int | Sobe 1 a cada gravação |
| `atualizadoEm` | timestamp | Horário do servidor |

**Limites do texto** (`LimitesDoCartao`): nomes 80, textos curtos 120,
médios 200, observações 1000. O formulário corta na digitação, e a gravação
tira caracteres de controle e espaços nas pontas.

**Por que não no documento do pet:** a API lê o documento do pet no
Firestore para montar a página pública do QR (ADR 0008). Com o cartão fora
dele, os dados de saúde nunca passam pela API. Ver ADR 0009.

**Migração:** nenhuma. Pets antigos não têm o documento e o cartão abre vazio.

## Gravação e conflito

`FirebaseCartaoEmergenciaRepository.salvar` grava numa transação:

1. Lê a `revisao` atual (0 se o documento não existe).
2. Se for diferente da revisão com que o formulário abriu, para e lança
   `CartaoAlteradoEmOutroLugar`. A tela avisa e **nada é gravado**.
3. Senão, grava o cartão com `revisao + 1` e `atualizadoEm` do servidor.

As regras do Firestore exigem a mesma regra da revisão (`revisao` = anterior
+ 1, ou 1 na criação), então a proteção vale mesmo fora do app.

## Rede

| Situação | Comportamento |
|---|---|
| Leitura offline, cartão no cache do aparelho | Mostra o cartão e o aviso "Sem conexão: mostrando a última versão salva neste aparelho." |
| Leitura offline, sem cache | "Sem conexão, e o cartão ainda não foi baixado neste aparelho." Não oferece "Preencher cartão", para não sobrescrever um cartão que existe |
| Gravação offline | A transação não grava offline. Depois de até 20 s, a tela diz "Sem conexão. Nada foi salvo" e o formulário fica como estava |

**Limite conhecido:** se a internet voltar depois dos 20 s, o SDK pode
concluir a transação mesmo com a tela já tendo dito que não salvou. Não há
perda de dados: na próxima abertura o cartão mostra a versão gravada, e a
revisão impede sobrescrever em silêncio.

## Estados da tela

- **Carregando**, **vazio** (convite "Preencher cartão" e aviso de que nada
  vai para a página do QR), **parcial**, **completo**.
- **Sem permissão:** "Você não tem acesso a este cartão.", sem dado nenhum.
- **Erro:** mensagem e "Tentar de novo".
- **Memorial:** "No Memorial: somente leitura", sem editar nem preencher.
- **Formulário:**
  - pergunta "Descartar alterações?" ao voltar com mudanças;
  - pede confirmação para remover um item;
  - ignora o segundo toque em "Salvar";
  - mostra o erro de cada campo.

## Segurança e privacidade

**Regras do Firestore** (`match /emergencia/{docId}`):
- Só o dono do pet lê e apaga, e só o documento `cartao`.
- Grava só com o pet ativo (dado clínico, como vacinas; ADR 0002).
- Formato conferido: campos permitidos, tipos, tamanho das listas e dos
  textos de primeiro nível, versão do esquema, horário do servidor e
  revisão.

**O que as regras não conferem:** cada item das listas, porque as regras não
têm laço. O app valida antes de gravar, e o tamanho do documento fica
limitado pelas 20 entradas e pelo limite de 1 MiB do Firestore.

**Na memória do aparelho:** o provider é `autoDispose`, então os dados
saem da memória quando a tela fecha. Ele depende do usuário logado, e
trocar de conta descarta a leitura anterior.

**Logs:** nenhum dado do cartão vai para log. A mensagem do Firestore não
aparece na tela; só o código do erro é usado.

**Permissões Android:** nenhuma nova.

### Ameaças

| Ameaça | Mitigação | Risco que fica |
|---|---|---|
| Outro tutor lê ou altera o cartão (troca de `petId`) | Regras por dono, testadas no emulador | Nenhum conhecido |
| Exposição pública | Documento fora do pet; a API e a página do QR nunca leem o cartão | Nenhum conhecido |
| Edição em dois aparelhos sobrescreve | Revisão na transação e nas regras | Nenhum conhecido |
| Dado errado ou desatualizado | Aviso fixo para confirmar com o veterinário, "Atualizado em" e situação explícita de cada lista | O app não verifica o que o tutor digita |
| Aparelho perdido ou compartilhado | O cartão só abre na tela com a sessão do tutor | O cache do Firestore no aparelho guarda a última leitura; sair da conta não apaga esse cache, só limpar os dados do app |
| Conteúdo malformado | Validação no app, limites nas regras, leitura tolerante | Itens dentro das listas não são conferidos pelas regras |

**LGPD:**
- Os dados são do pet, mas podem revelar hábitos e o contato do tutor.
  Ficam privados e sob controle do tutor.
- Excluir o pet ou a conta apaga o cartão (`apagarCartaoDeEmergencia`, na
  cascata de `exclusao_de_pet.dart`).
- Não há parecer jurídico sobre isso; a revisão da política de privacidade é
  a issue #28.

## Liberação

1. **Deploy das regras** (`firebase deploy --only firestore:rules`), pelo
   proprietário. Sem elas, o Firestore nega tudo em `emergencia`.
2. **APK** com `--dart-define=CARTAO_EMERGENCIA=true`.

**Exclusão antes do deploy:** a exclusão de pet e de conta continua
funcionando sem as regras novas. Nesse caso a negação ao apagar o cartão é
ignorada, porque nenhum cartão pode ter sido gravado sem as regras.

**Rollback:** gerar o APK sem o flag. As regras podem ficar: sem o app, nada
lê nem grava o cartão.

## Testes

| Arquivo | O que cobre |
|---|---|
| `test/features/pet/cartao_emergencia_dominio_test.dart` | Situações das listas, leitura tolerante de documentos antigos e malformados, tipo sanguíneo sem confirmação, limpeza do texto |
| `test/features/pet/cartao_emergencia_repository_test.dart` | Caminho do documento, revisão, conflito, pets que não se misturam, tradução de erros |
| `test/features/pet/cartao_emergencia_telas_test.dart` | Estados da leitura, offline, sem permissão, Memorial, edição, validação, descarte, conflito, toque duplo, três temas, fonte em 200%, semântica, card no perfil |
| `test/features/pet/firebase_pet_repository_exclusao_test.dart`, `test/features/usuario/firebase_usuario_repository_test.dart` | O cartão sai com o pet e com a conta; regras antigas não travam a exclusão |
| `tool/firestore-rules/regras.test.js` | Dono, outro tutor, anônimo, Memorial, pet inexistente, documento único, formato, revisão, cascata |
| `test/evidencias/cartao_emergencia_evidencia_test.dart` | Imagem do cartão vazio, preenchido e do formulário (fora do CI) |
