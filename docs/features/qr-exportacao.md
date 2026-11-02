# Baixar e imprimir o QR code do pet (RF50)

> Branch: `feat/qr-exportacao-impressao` (2026-11-02). Issue #96. O QR
> regenerável está em `docs/features/qr-regeneravel.md`.

O tutor baixa o QR code do pet para imprimir na coleira ou numa
plaquinha. O arquivo é gerado no celular e nada vai a servidor.

## Onde fica

Perfil do pet → **QR Code** (sheet "QR Code do Pet"). Abaixo do QR:

| Ação | O que faz | Arquivo |
|---|---|---|
| **Baixar QR Code** | Salva o PNG na galeria de fotos (`gal`, MediaStore). Avisa "QR code salvo na galeria de fotos." | PNG |
| **Compartilhar** | Abre a folha de compartilhamento do sistema com o PNG: WhatsApp, e-mail, Drive, impressora… | PNG |
| **PDF para imprimir** | Folha A4 pela folha de compartilhamento; dá para salvar em Arquivos ou mandar para a impressora | PDF |

Abaixo dos botões há uma dica: "imprima em preto sobre branco, com pelo
menos 2 cm de lado, e teste a leitura com a câmera do celular antes de
usar". O aviso de que gerar um novo QR invalida o impresso continua na
confirmação de "Gerar novo QR code".

**Estados:**
- **Gerando:** o botão tocado mostra um indicador, e os outros, inclusive
  "Gerar novo QR code", ficam desligados.
- **Salvo:** aparece a mensagem de salvo. Compartilhar não mostra aviso de
  sucesso, porque o sistema nem sempre informa se o tutor enviou.
- **Falhas:** sem acesso à galeria ("Use Compartilhar e escolha onde
  salvar"), sem espaço, ou erro ao gerar. A mensagem aparece no próprio
  sheet.
- **Sem internet:** funciona, porque o arquivo é gerado no celular.

## Conteúdo: o mesmo QR da tela

- **Dados:** exatamente `publicPetUrl(pet)`, a mesma URL do `QrImageView`
  da tela, montada com o `publicId` atual (`publicIdDoQr`). Para pet
  antigo, é o `publicId` calculado; depois de regenerar, é o novo. Não há
  ID adivinhado nem link diferente.
- **Matriz:** mesmo pacote (`qr`, via `qr_flutter`) e mesmo nível de
  correção (L, o padrão da tela, agora explícito em `nivelDeCorrecaoDoQr`
  nos dois lugares). O teste confere módulo a módulo que a matriz do
  arquivo é a da tela.
- **Exportar na hora:** o arquivo é gerado do pet exibido naquele momento.
  Se o QR foi trocado em outro aparelho, a sincronização ao abrir o sheet
  já atualiza a tela antes.

## Qualidade para impressão

**PNG** (`gerarPngDoQr`):
- pelo menos 1200 px de lado; com a URL atual, sai com 1230 × 1230 px;
- cada módulo com um número inteiro de pixels;
- sem suavização: só preto `#000000` e branco `#FFFFFF`;
- margem branca (*quiet zone*) de 4 módulos, como a norma pede;
- sem logo nem marca sobre o código.

**PDF** (`gerarPdfDoQr`): página A4.
- **Título:** "QR code de identificação" e o nome do pet.
- **Tamanhos:** o QR com 8 cm e, para coleira ou plaquinha, com 4, 3 e
  2 cm, todos **vetoriais**, sem imagem embutida.
- **Instruções:** imprimir em tamanho real (100%) e em preto e branco,
  testar a leitura antes de usar, e o aviso de que regenerar o QR invalida
  o impresso.
- **Fonte:** a padrão do PDF (Helvetica) desenha os acentos do português.
  Outros caracteres do nome, como emojis, ficam de fora no PDF; o QR não
  muda.

O app não promete resistência à água nem durabilidade da etiqueta.

## Nomes de arquivo

`petconnect-qr-<8 hex>-<aaaammdd>.png` ou `.pdf`. O identificador é o
começo do SHA-256 do `publicId` do QR:
- **sem dado pessoal:** não traz o nome do pet, o id do documento nem o
  próprio `publicId`;
- **QR regenerado:** gera outro nome, então o arquivo antigo não se
  confunde com o atual;
- **mesmo nome no mesmo dia:** a galeria do Android renomeia sozinha.

## Plataformas e permissões

- **Android:** o mesmo destino do cartaz de pet desaparecido
  (`DestinoDoCartaz` em `exportacao_cartaz.dart`):
  - **Salvar:** grava pela MediaStore, sem permissão no Android 10 ou mais
    novo. No 9 ou anterior, o app orienta a usar "Compartilhar", porque
    nenhuma permissão de armazenamento foi adicionada;
  - **Compartilhar:** usa um `FileProvider` do `share_plus`, e o arquivo
    temporário próprio é apagado depois.
- **iOS:** os mesmos pacotes (`gal`, `share_plus`) têm implementação iOS.
  **Não foi testado em iOS.**
- **Web:** o app não tem build web.

## Privacidade (LGPD)

- **PNG:** só a URL pública do pet, que já estava no QR da tela e na
  coleira. Nenhum telefone, endereço, e-mail ou dado de saúde.
- **PDF:** acrescenta só o nome do pet, que a página pública já mostra
  (RF17).
- **Página pública:** o que ela mostra a quem escaneia não muda (RF17,
  RF18).
- **Revogação:** ao regenerar o QR (RF19), o impresso deixa de funcionar.
  O app não tenta manter códigos antigos ativos.
- **Logs:** nenhum novo.

## Testes

- **`test/features/pet/qr_exportacao_test.dart` (7):**
  - **PNG:** lido por um decodificador de QR de verdade (`zxing2`, porta
    Dart do ZXing, só nos testes), que devolve a mesma URL da tela, para
    pet antigo e para QR regenerado; quadrado, com pelo menos 1200 px, só
    preto e branco, módulos inteiros, cada módulo no lugar e margem de 4
    módulos;
  - **matriz:** a mesma do caminho do `QrImageView`;
  - **PDF:** uma página A4, vetorial (sem imagem), e nome com emoji e
    caracteres especiais;
  - **nome do arquivo:** sem dado pessoal, e outro nome depois de
    regenerar.
- **`test/features/pet/pet_qr_sheet_test.dart` (+4):**
  - "Baixar QR Code" salva um PNG que decodifica na URL do pet e mostra o
    aviso;
  - "Compartilhar" e "PDF para imprimir" vão pela folha, sem aviso;
  - sem acesso à galeria, orienta a compartilhar;
  - depois de gerar um novo QR, o arquivo traz o novo.
- **`test/evidencias/qr_evidencia_test.dart`** (fora do CI): grava um PNG
  e um PDF de exemplo, com dados fictícios, em `build/evidencias/`.

**Sem teste no aparelho:** a galeria e a folha de compartilhamento reais,
a impressão e a leitura do papel por um celular. Ver "Como conferir".

## Como conferir no aparelho

1. Perfil do pet → QR Code → **Baixar QR Code**: o aviso aparece, e o QR
   está no app de fotos.
2. Aponte a câmera de outro celular para a foto salva: abre a página
   pública do pet.
3. **PDF para imprimir** → salvar em Arquivos e imprimir em tamanho real.
   Escaneie os QRs de 8, 4, 3 e 2 cm no papel.
4. **Compartilhar** para você mesmo no WhatsApp: a imagem chega nítida.
5. Gere um novo QR (se a API estiver ligada): o papel antigo para de
   funcionar, e o arquivo novo tem outro nome.

## Rollback

Reverter o merge. Banco, API e regras não mudam.
