# Cartaz de pet desaparecido (RF43–RF49)

> Branch: `feat/cartaz-pet-desaparecido` (2026-10-29). Pedido em
> `prompt_opus_cartaz_pet_desaparecido_petconnect.md`. Decisão de
> arquitetura em `docs/decisions/0007-cartaz-gerado-no-aparelho.md`.
> Roteiro de aparelho em `docs/validation/cartaz-pet-desaparecido.md`.
>
> Ajustes depois do primeiro teste no aparelho (2026-10-29, pedido do
> proprietário): ponto de foco e "Foto inteira" nas fotos; fora do cartaz
> as linhas Espécie/Raça, Cor e Desapareceu em; observações em destaque;
> recompensa com máscara de reais; "Visto por último" num campo só, com
> calendário; cor do cartaz (preto, vermelho ou azul).

O tutor monta um cartaz "Procura-se" com os dados reais do pet, três fotos e
o telefone que autorizar, confere a prévia e salva ou compartilha em PNG ou
PDF. **O cartaz é gerado no celular.** Nada é publicado no app, nada vai
para o Firestore ou o Cloudinary, e o cadastro do pet não muda.

## Estado

| Parte | Situação |
|---|---|
| Código e testes automatizados | Prontos (branch acima, PR aberta, sem merge) |
| Banco, regras e backend | **Sem mudança.** Nenhuma coleção, campo, regra ou endpoint novo |
| Permissões Android | **Sem mudança.** Conferido no APK de release (`aapt2 dump permissions`) |
| Teste no aparelho | Pendente com o proprietário: `docs/validation/cartaz-pet-desaparecido.md` |

## Jornada

1. Perfil de um pet ativo → **Pet desaparecido** (primeiro item das ações
   secundárias, acima de Fotos e Localização).
2. O editor explica o que é o cartaz, mostra o pet (foto, nome, espécie e
   raça, do cadastro) e as três posições: **Foto principal**, **Foto 2** e
   **Foto 3**.
3. Cada posição abre a escolha da foto:
   - galeria do pet, quando ligada (`GALERIA_FOTOS`);
   - a foto do perfil;
   - uma foto do celular, pelo seletor do sistema.
   Uma foto já usada em outra posição aparece marcada e não pode ser
   escolhida de novo. Logo depois da escolha abre o **ajuste da foto**
   (ver "Fotos"); ele também fica no botão "Ajustar" abaixo da miniatura e
   no menu da posição, junto com trocar, mover para outra posição e
   remover.
4. Informações, todas revisáveis:
   - **Características**, que começa com uma sugestão do cadastro (sexo e
     porte);
   - **Observações** (opcional), em destaque no cartaz;
   - **Visto por último** (opcional): a data no calendário, o período do
     dia (madrugada, manhã, tarde ou noite) ou um horário exato, e o local.
     Vira uma linha só, por exemplo "29/10/2026, à tarde — Perto da praça";
   - **Recompensa** (opcional): em dinheiro, com a máscara `R$ 1.234,56`, ou
     outra, em texto ("um vale-presente").
5. **Contato:** o telefone do cadastro do tutor, ou o contato do QR code do
   pet quando for outro número. O tutor precisa marcar "Autorizo mostrar
   este telefone no cartaz". Sem telefone válido, o editor avisa e leva a
   Editar perfil.
6. **Ver cartaz** abre a prévia, que é o próprio cartaz, com zoom. Nela o
   tutor escolhe a **cor do cartaz** (preto, vermelho ou azul), usada no
   cabeçalho "PROCURA-SE", na borda da faixa do nome, no rodapé "CONTATO" e
   na barra das observações. Enquanto faltar algo, a prévia lista o que
   falta e os botões ficam desligados.
7. **Compartilhar imagem** (PNG), **Salvar imagem** (galeria de fotos) ou
   **Gerar PDF** (A4, pela folha de compartilhamento). Nada sai do aparelho
   sem um desses toques.

Voltar funciona em todas as telas sem fechar o app: editor → perfil,
prévia → editor, ajuste da foto → editor (sem mudar o ajuste anterior).

## Regras

| Regra | Como funciona | Onde |
|---|---|---|
| Só o tutor dono, só pet ativo | As rotas `/pet/:id/cartaz` e `/pet/:id/cartaz/previa` usam `PetSituacaoGuard` (`SituacaoPet.ativo`): pet no Memorial mostra o aviso do Memorial, e pet de outra conta mostra "Pet não encontrado". As telas conferem o dono de novo | `pet_routes.dart`, telas |
| Título pela espécie | "GATO DESAPARECIDO", "CACHORRO DESAPARECIDO" ou, para qualquer outra espécie ou espécie vazia, "PET DESAPARECIDO". Aceita variações (cão, cadela, gata, felino, caixa e acentos) sem alterar o cadastro | `TituloCartaz.daEspecie` |
| Dados do cadastro | O nome vem do `Pet`, e o título, da espécie. Espécie/raça e cor não têm linha no cartaz (pedido do proprietário); o tutor pode escrevê-las em Características. O telefone vem do `Usuario` (ou `Pet.telefone`) | `ConteudoCartaz.de` |
| Exatamente 3 fotos | A prévia aceita rascunho incompleto (espaço vazio com o nome da posição); a exportação exige as 3 | `problemasDoCartaz` |
| Fotos independentes do perfil | Escolher uma foto não muda a foto de perfil nem a galeria | — |
| Campos vazios somem | Sem rótulo vazio, sem "null"; recompensa vazia (ou R$ 0,00) tira a linha inteira, e observações vazias tiram a caixa | `ConteudoCartaz.de` |
| Linhas do cartaz | Nome, Características, Visto por último e Recompensa, nessa ordem; Observações numa caixa abaixo, da largura toda, com letra maior | `ConteudoCartaz`, `CartazProcuraSe` |
| Visto por último | Um campo só, para data e local não se contradizerem. Data entre hoje e 365 dias atrás, no calendário em português; período ou horário exato (escolher um tira o outro); local em texto livre. Não há GPS nem permissão de localização | `VistoPorUltimo` |
| Recompensa | Em dinheiro: só números, que entram pela direita (2, 0, 0, 0, 0 → `200,00`), até R$ 999.999,99, e no cartaz `R$ 200,00`. Outra: texto livre. Só a escolhida vai para o cartaz | `Recompensa`, `MascaraDeReais` |
| Cor | Preto `#111111`, vermelho `#C62828` ou azul `#1565C0`, todas com contraste acima de 5:1 com o texto branco | `CorDoCartaz` |
| Telefone válido | Brasileiro, com DDD (10 ou 11 dígitos, `+55` opcional). Número de outro país, incompleto ou com DDD inválido é recusado. Mostrado como `(11) 90000-0000` | `telefoneDoCartaz` |
| Consentimento específico | Vale para o número autorizado: trocar o número pede de novo. Não é salvo no rascunho. Sem ele, o cartaz mostra o espaço do contato vazio e não exporta | `RascunhoCartaz.telefoneAutorizado` |
| Sem e-mail nem endereço | Nunca entram no cartaz | — |
| Nada muda no pet | Gerar e exportar não grava no Firestore e não lê vacinas, consultas, histórico nem localização | `cartaz_telas_test.dart` |
| Repetir não duplica | Exportar de novo gera outro arquivo local; não há registro nem upload | — |
| Limites de texto | Características 80, local de "Visto por último" 60, Observações 150, recompensa em texto 30 (contador no campo) | `LimitesCartaz` |

**Fora do escopo nesta entrega** (ver ADR 0007):
- estado "desaparecido" no pet e "Declarar desaparecido";
- aviso "ENCONTRADO";
- publicação no app, feed, mapa, link ou QR público;
- notificações;
- recompensa paga.

## Layout

Referência: o modelo minimalista "Procura-se" enviado pelo proprietário
(2026-10-29). O cartaz moderno citado como referência secundária não foi
recebido.

```text
┌──────────────────────────────┐
│ ███████ PROCURA-SE ███████   │  cabeçalho na cor escolhida
│ ╱ [NOME DO PET] ╱            │  faixa branca inclinada (-0,03 rad)
│      CACHORRO DESAPARECIDO   │  título pela espécie
│ ┌───────────┐ ┌──────┐       │
│ │ principal │ │ foto2│       │  mosaico: 62% | 38%
│ │           │ ├──────┤       │
│ │           │ │ foto3│       │
│ └───────────┘ └──────┘       │
│ Nome:            [ ...... ]  │  só os campos preenchidos
│ Características: [ ...... ]  │
│ Visto por último:[ ...... ]  │
│ Recompensa:      [ ...... ]  │
│ ▌OBSERVAÇÕES                 │  caixa em destaque
│ ▌texto maior …               │
│ ██ CONTATO: [ (11) 9....  ]  │  rodapé na cor escolhida
│        Cartaz gerado no app… │  marca discreta
└──────────────────────────────┘
```

- **Tamanho fixo:** 1055 × 1491 lógicos, a proporção do modelo (próxima do
  A4). O cartaz tem cores próprias (a cor escolhida, preto `#111111` no
  texto, branco e cinza `#EDEDED`), que não mudam com o tema do app, e
  ignora o tamanho de fonte do sistema.
- **Fonte:** a do app (Roboto). Não há fonte condensada no projeto; usar a
  do modelo exigiria incluir um arquivo de fonte licenciado, o que fica
  como sugestão.
- **Fotos:** preenchem o espaço sem esticar, com o ponto de foco no
  centro, ou aparecem inteiras sobre um fundo desfocado (ver "Fotos").
- **Textos longos:**
  - o nome encolhe para caber na faixa, numa linha;
  - os dados quebram linha. Se passarem do espaço, encolhem juntos, e as
    fotos mantêm no mínimo 380 px de altura;
  - com a Roboto, o cartaz completo fica em 100% e o caso com todos os
    textos no limite, em 90% (`test/evidencias/cartaz_evidencia_test.dart`);
  - nada é cortado.
- **Prévia e arquivo iguais:** a prévia é o próprio widget
  (`CartazProcuraSe`), reduzido com `FittedBox`. A exportação captura esse
  mesmo widget.

## Exportação

| Saída | Como | Arquivo |
|---|---|---|
| PNG | Captura do `RepaintBoundary` da prévia em 2×: **2110 × 2982 px** | `petconnect_procura-se_<8 hex>_<aaaammdd>.png` |
| PDF | O mesmo PNG numa página A4 em pé, margem de 24 pt, centralizado (`pdf`); cerca de 250 dpi na folha | `....pdf` |
| Compartilhar | Folha do sistema (`share_plus`), com o arquivo e o tipo MIME; o tutor escolhe o app (WhatsApp, e-mail, Drive…) | arquivo temporário no cache do app, apagado depois (ver Privacidade) |
| Salvar imagem | Galeria de fotos (`gal`, MediaStore). No Android 10 ou mais novo não precisa de permissão; no 9 ou anterior o app avisa para usar "Compartilhar imagem" | — |

- **Nome do arquivo:** o identificador é o começo do SHA-256 do id do pet.
  Sem nome, telefone ou id interno.
- **Metadados:** o PNG é gerado a partir dos pixels, então não leva
  metadados das fotos originais. O PDF tem só título ("Procura-se") e
  criador ("PetConnect").
- **Fotos que não carregam** (sem internet, foto apagada da galeria):
  bloqueiam a exportação com aviso. O cartaz nunca sai com um buraco.
- **Avisos:** "Cartaz salvo na galeria de fotos." só aparece depois de
  salvar. Compartilhar não mostra aviso de sucesso, porque o sistema nem
  sempre informa o que o tutor fez.

## Fotos

- **Fotos da galeria e do perfil** usam a versão limitada a 1600 px do
  Cloudinary. A URL é aceita só se for `https://res.cloudinary.com`.
- **Fotos do celular** vêm do seletor do sistema, que não pede acesso a
  todas as fotos.
  - A cópia é redimensionada para até 2048 px e recomprimida, com a
    orientação corrigida e sem os metadados do original
    (`requestFullMetadata: false`).
  - Passa por `validarImagem`: JPEG, PNG, WebP ou HEIC de até 10 MB.
  - Fica só na memória: não é enviada e não entra no rascunho.
- **Memória:** cada foto é decodificada com no máximo 1400 px de largura,
  e as miniaturas no tamanho exibido.
- **Ajuste da foto** (`EnquadramentoScreen`), aberto logo depois da
  escolha:
  - **Preencher** (padrão): a foto cobre o espaço e as sobras são
    cortadas. O tutor toca (ou arrasta) na foto inteira o **ponto de
    foco**, por exemplo o rosto do pet; um véu escuro mostra o que fica de
    fora. Zoom de 1× a 3×, e controles deslizantes para foco e zoom
    (leitor de tela, teclado).
  - **Foto inteira:** sem cortes; o resto do espaço fica com um fundo
    desfocado da própria foto.
  - **Formato exato:** "Como fica no cartaz" usa o formato real do espaço,
    medido no cartaz atual (montado fora da tela, sem fotos). O formato
    muda um pouco com a quantidade de texto, mas o foco fica sempre no
    centro, até onde a foto permite (`EnquadramentoFoto.areaVisivel`).
  - A miniatura do editor também mostra o foco escolhido.

## Rascunho

- **Onde e com que chave:** fica só no aparelho (`shared_preferences`),
  com a chave `cartaz_rascunho_v1_<uid>_<petId>`.
- **O que guarda:** os textos, a data, o período ou horário e o local de
  "Visto por último", a recompensa, a cor, as fotos que já estão no
  Cloudinary do pet (id e URL) e o ajuste de cada foto (`versao: 2`).
- **O que não guarda:** o telefone (lido do cadastro na hora), o
  consentimento e as fotos do celular.
- **Gravação:** salva 400 ms depois da última mudança e ao sair do editor.
- **Sair com foto do celular** pede confirmação, porque ela não volta.
- **Descartar rascunho** (menu do editor) apaga o rascunho; excluir o pet
  também apaga o dele.
- **Rascunho ilegível** (outra versão, JSON corrompido, URL estranha) vira
  rascunho vazio em vez de erro.
- **Rascunho da versão 1** (antes destes ajustes) é convertido: "Visto por
  último em" vira o local, a recompensa em texto vira valor em reais
  quando dá para ler ("200 R$" → R$ 200,00), e o ajuste antigo vira o
  ponto de foco equivalente. "Desapareceu em", um texto sem data, fica de
  fora.

## Arquitetura

```mermaid
flowchart LR
  Perfil[PetDetailScreen<br/>Pet desaparecido] --> Editor[CartazEditorScreen]
  Editor --> Seletor[escolherFotoDoCartaz<br/>galeria · perfil · celular]
  Editor --> Enq[EnquadramentoScreen]
  Editor --> Previa[CartazPreviaScreen]
  Editor & Previa --> Ctrl[CartazController<br/>cartazControllerProvider]
  Ctrl --> Store[RascunhoCartazStore<br/>shared_preferences]
  Previa --> Cartaz[CartazProcuraSe]
  Previa --> Exp[exportacao_cartaz.dart<br/>PNG · PDF · nome]
  Exp --> Destino[DestinoDoCartaz<br/>share_plus · gal]
  Editor & Previa -. leitura .-> Pet[(petProvider)]
  Editor & Previa -. leitura .-> Usuario[(currentUsuarioProvider)]
  Seletor -. leitura .-> Galeria[(galeriaControllerProvider)]
```

```mermaid
sequenceDiagram
  actor Tutor
  participant P as CartazPreviaScreen
  participant C as CartazProcuraSe
  participant E as exportacao_cartaz
  participant D as DestinoDoCartaz
  Tutor->>P: Compartilhar imagem / Salvar / Gerar PDF
  P->>P: confere problemas (3 fotos, telefone, consentimento)
  P->>C: carrega as 3 fotos (precacheImage)
  alt alguma foto não carrega
    P-->>Tutor: "Uma das fotos não carregou…"
  else
    P->>C: captura o RepaintBoundary em 2× (PNG)
    opt PDF
      P->>E: gerarPdfDoCartaz(png)
    end
    P->>D: compartilhar(arquivo) ou salvarNaGaleria(png)
    D-->>Tutor: folha do sistema / galeria
  end
```

| Arquivo | Papel |
|---|---|
| `lib/features/pet/domain/cartaz_desaparecido.dart` | Título, fotos, enquadramento, rascunho (JSON), telefone, campos e problemas |
| `lib/features/pet/data/rascunho_cartaz_store.dart` | Rascunho no aparelho |
| `lib/features/pet/data/exportacao_cartaz.dart` | PDF, nome do arquivo, `DestinoDoCartaz` (compartilhar e galeria) |
| `lib/features/pet/presentation/providers/cartaz_providers.dart` | `CartazController`, store e destino |
| `lib/features/pet/presentation/widgets/cartaz_procura_se.dart` | O cartaz (prévia e exportação) e `FotoEnquadrada` |
| `lib/features/pet/presentation/widgets/cartaz_fotos.dart` | Escolha de foto e `EnquadramentoScreen` |
| `lib/features/pet/presentation/screens/cartaz_editor_screen.dart` | Editor |
| `lib/features/pet/presentation/screens/cartaz_previa_screen.dart` | Prévia, captura e exportação |
| `lib/routing/pet_routes.dart` | Rotas protegidas |
| `lib/features/pet/presentation/widgets/pet_secondary_actions.dart` | Entrada no perfil |
| `lib/features/pet/presentation/screens/pet_settings_screen.dart` | Excluir o pet apaga o rascunho |

**Dependências novas** (licenças conferidas no pacote):

| Pacote | Versão | Licença | Para quê |
|---|---|---|---|
| `share_plus` | ^13.3.1 | BSD-3 | Folha de compartilhamento |
| `path_provider` | ^2.1.6 | BSD-3 | Pasta de cache do arquivo temporário (já vinha como dependência indireta) |
| `pdf` | ^3.13.1 | Apache-2.0 | PDF A4 |
| `gal` | ^2.3.3 | BSD-3 | Salvar na galeria |

Nenhum dos três adiciona permissão ao manifest. O `share_plus` declara só
um `FileProvider` interno (não exportado) e um receiver não exportado.

## Privacidade

- **Telefone:** consentimento explícito, informado e específico para o
  cartaz, ligado ao número. O texto do editor diz que qualquer pessoa que
  receber ou vir o cartaz verá o número.
- **Circulação:** o editor e a prévia avisam que o cartaz, depois de
  compartilhado ou impresso, pode continuar circulando e não dá para
  recolhê-lo.
- **Fora do cartaz:** e-mail, endereço, coordenadas, histórico médico,
  vacinas e ids internos.
- **Logs:** nenhum novo. Telefone, fotos e textos do cartaz não vão para
  log.
- **Fora do app:** nada é enviado a servidor do PetConnect.
- **Arquivos temporários:** o app grava o arquivo em `cache/cartaz/` e o
  apaga assim que a folha de compartilhamento termina. O `share_plus` faz
  a própria cópia em `cache/share_plus/` para o app escolhido ler. Essa
  cópia fica até o próximo compartilhamento (que limpa a pasta) ou até o
  Android limpar o cache.
- Detalhes em `docs/privacy/data-flow-and-lgpd-readiness.md`.

## Testes

| Arquivo | O que cobre |
|---|---|
| `test/features/pet/cartaz_dominio_test.dart` (30) | Título (gato, cachorro, outras e variações); telefone (válidos, inválidos, `+55`, outro país, formato, opções do tutor e do pet, escolha); 0 a 3 fotos e rascunho com 4; sem telefone; consentimento por número; linhas e ordem, sem espécie/raça, cor e "Desapareceu em"; vazios somem; sugestão de características; "Visto por último" (texto, período × horário); reais (formato, tipo, leitura de texto antigo); enquadramento (limites, área visível centrada no foco, conversão do formato antigo); troca de posições; JSON sem telefone, consentimento e foto do celular; conversão da versão 1; JSON corrompido e URL de fora; store por tutor e pet; nome do arquivo; PDF A4 de uma página |
| `test/features/pet/cartaz_layout_test.dart` (10) | Composição do modelo (mosaico, ordem vertical, rótulos, observações em destaque); cachorro sem opcionais; nome longo; textos no limite com telefone fixo; foco, zoom e foto inteira; cor vermelha; medida do mosaico igual aos espaços; espaços vazios; fonte do sistema 2× sem efeito; PNG 2110 × 2982. Goldens em `goldens/cartaz_*.png`, com tolerância de 2% (o golden com mais texto deu 1,09% de diferença entre Windows e o Linux do CI) |
| `test/features/pet/cartaz_telas_test.dart` (25) | Entrada pelo perfil e Voltar; Memorial e outro tutor bloqueados; escolher da galeria (com o ajuste logo depois), foto já usada, mover e remover; galeria fora do ar; tocar escolhe o foco e "Foto inteira"; voltar do ajuste; calendário e relógio em português, período e local; máscara de reais e recompensa em texto; sem telefone; consentimento antes do número aparecer; trocar o número pede de novo; cor na prévia; PNG, PDF e salvar (com e sem acesso); foto que não carrega; nada muda no pet nem se leem dados clínicos; rascunho volta sem consentimento; sair com foto do celular; descartar (com rascunho da versão 1); editor em 320 px, tema escuro e fonte 1,5× |
| `test/evidencias/cartaz_evidencia_test.dart` (5, fora do CI) | Com a Roboto do SDK: escala dos dados de pelo menos 75% e PNG e PDF de exemplo (preto, vermelho e azul), com dados fictícios, em `build/evidencias/` |

**Goldens:** no `flutter_test`, o texto sai em blocos (fonte de teste),
então os goldens conferem a composição, não a tipografia. A legibilidade
real é conferida no teste de evidência e no aparelho.

**Sem teste automatizado:**
- o seletor de fotos do sistema e a folha de compartilhamento reais (o
  destino é substituído por um fake nos testes);
- a gravação na galeria;
- HEIC e EXIF de fotos reais.

Esses casos ficam no roteiro de aparelho.

## Limites conhecidos

- **Galeria do pet no seletor:** só aparece com `GALERIA_FOTOS` ligada e no
  modo Firestore. Sem ela, as opções são a foto do perfil e o celular.
- **Foto do perfil antiga:** uma foto de perfil fora do Cloudinary não é
  oferecida.
- **Ajuste da foto:** o formato do espaço é medido com o texto do momento;
  se o tutor escrever mais depois, o espaço fica um pouco mais baixo, com o
  foco ainda no centro. A prévia mostra o resultado final.
- **Android 9 ou anterior:** "Salvar imagem" não funciona sem uma
  permissão de armazenamento, que não foi adicionada. O tutor usa
  "Compartilhar imagem".
- **Rascunho:** não é sincronizado entre aparelhos e some se o app for
  desinstalado.
- **Telefone:** só números brasileiros.

## Extensões futuras (não implementadas)

- **Estado de desaparecimento no pet:** exige campo e regras no Firestore,
  além da transição com o Memorial.
- **Cartaz "ENCONTRADO":** depende do estado acima.
- **QR code ou link público no cartaz:** sob consentimento e só depois da
  página pública (RF17–RF19).
- **Fonte condensada licenciada:** mais fiel ao modelo.
- **Histórico de versões do cartaz e métricas.**
