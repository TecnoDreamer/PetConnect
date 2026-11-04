# Acessos e avistamentos do QR Code

Fase 3 do épico #102 (issue #37), adiantada a pedido do proprietário em
2026-11-03. A fase 2 (#103, carrossel e WhatsApp) fica para depois; esta não
depende dela. A API correspondente está em AleksGustavo/PetConnect-API
(branch `feat/qr-eventos-avistamento`).

## Problema

- **Página pública:**
  - A caixa "Incluir minha localização" pedia a permissão do navegador só no
    envio e mandava a coordenada sem mostrar antes, sem precisão.
  - A abertura da página não era registrada.
- **App:** em modo Firestore, o app lê os registros em
  `Pets/{id}/localizacoes`, mas os relatos da página ficam no MongoDB. O
  tutor nunca via os relatos.

O QR não diz onde foi escaneado. A única localização possível é a do
navegador de quem escaneou, e nenhuma página web consegue lê-la sem a
permissão dessa pessoa: o navegador sempre pergunta antes.

## O que muda

### Página pública (`public/index.html`)

1. **Acesso:** depois de mostrar um pet válido, a página envia
   `qr_page_opened` sem esperar resposta e sem coordenada.
2. **Localização automática** (pedido do proprietário de 2026-11-04, que
   substitui o botão "Compartilhar local onde vi o pet"):
   - **Pedido ao abrir:** logo depois de mostrar o pet, a página pede a
     localização ao navegador (`getCurrentPosition`, alta precisão, 15 s),
     sem esperar clique. Ao lado, o texto explica para que serve e que ela
     vai uma única vez. Não existe acompanhamento contínuo: é um ponto, não
     rastreamento.
   - **Envio sozinho:** se a pessoa permitir, a página envia o ponto e a
     precisão na hora, sem botão de envio, e mostra "Localização enviada ao
     tutor, com precisão de cerca de X m" e "Conferir no mapa". Acima de
     500 m, avisa que a precisão está baixa.
   - **Sem localização:** permissão negada, sem sinal ou navegador sem
     suporte mostram "Tentar enviar a localização" e não impedem o relato
     em texto.
   - **Falha de rede:** o mesmo botão reenvia o mesmo ponto com o mesmo
     `clientRequestId`, sem duplicar.
3. **Relato em texto:** continua opcional e é outro envio, com outro
   `clientRequestId`. Exige o texto e leva o ponto já obtido, se houver.

### API

| Evento | Rota | Coleção |
|---|---|---|
| `qr_page_opened` | `POST /api/v1/public/pets/{publicId}/events` | `qr_access_events`: pet e hora, sem IP nem user-agent. TTL de 90 dias |
| `sighting_location_shared` (ou relato em texto) | `POST /api/v1/public/pets/{publicId}/sightings` | `locations`, com `accuracyMeters`, `positionSource` e `clientRequestId` |
| leitura do tutor | `GET /api/v1/legacy-pets/{id}/qr-activity` (ou `/pets/{id}/qr-activity`) | relatos e acessos, separados |

O servidor decide `positionSource`: `BROWSER_GEOLOCATION` com coordenada,
`NONE` sem. Nenhum dos dois é verificado.

### App: aba Localização

- **Lista:** junta os registros do tutor (Firestore) com os relatos do QR
  (API), por data.
- **Relato do QR:**
  - "Local onde o QR Code foi escaneado" para o envio automático (só ponto,
    sem texto); "Avistamento pelo QR Code" para o relato com texto;
  - data e hora no fuso do aparelho;
  - "Localização do celular de quem escaneou", com a precisão, ou "Sem
    localização: relato em texto, não verificado";
  - contato, se quem relatou deixou;
  - "Abrir no mapa", que abre o ponto no app de mapas do aparelho
    (`url_launcher`, link do Google Maps). O mapa dentro do app, com
    provedor de tiles escolhido em ADR, é a fase 5 (#38).
- **Acessos:** um cartão à parte com quantas vezes a página foi aberta nos
  últimos 30 dias e o último acesso. Diz que abrir a página não confirma
  que alguém viu o pet.
- **Atualizar:** puxar para baixo atualiza as duas fontes.
- **Falha da API:** a lista do tutor continua, com "Não foi possível
  carregar os avisos do QR Code" e "Tentar de novo".
- **Sem API configurada** (sem `USE_API_QR` nem `USE_API_PETS`): só os
  registros do tutor, como antes.

## Defesas

- **Limite por IP:** o filtro público continua valendo para leitura e
  escrita.
- **Limite por pet:**
  - até 20 relatos por hora (`429`);
  - até 30 acessos gravados por hora; acima disso, a página segue e o acesso
    não é gravado.
- **Idempotência:** o mesmo `clientRequestId` responde `201` sem criar outro
  relato.
- **Validação:** latitude e longitude juntas, precisão entre 0 e 100 km,
  texto até 1000 caracteres, `clientRequestId` só com letras, números e
  hífen.
- **Pet inválido:** pet excluído, no Memorial ou com QR revogado responde
  `404` para relato e acesso.
- **Leitura:** só o dono do pet, conferido no Firestore; outro tutor recebe
  `404`.

## Privacidade e retenção

- **Acessos:** não guardam nada de quem abriu a página e são apagados em 90
  dias, e também ao excluir o pet pela API.
- **Relatos:** a coordenada é dado de localização de quem escaneou e só o
  tutor vê. Eles não são apagados automaticamente.
- **Pedido ao abrir a página:** a única autorização é a permissão do
  navegador, com o texto de finalidade ao lado. Antes, havia também o
  clique no botão e a confirmação no envio. A mudança foi pedida pelo
  proprietário e precisa entrar na revisão jurídica (#28). A política de
  visibilidade e eliminação (12 h, 24 h, 48 h, "até encontrar") depende de
  revisão jurídica (#28) e fica para a fase 5 (#38).
- **Link "Conferir no mapa" da página:** envia a coordenada ao Google só se
  o visitante tocar nele.

## Compatibilidade

- **QR impresso:** o conteúdo e a URL não mudaram.
- **Página antiga com a API nova:** a caixa antiga mandava a coordenada sem
  precisão. A API aceita: o relato fica com `BROWSER_GEOLOCATION`, sem
  precisão.
- **Relato vazio:** a página antiga deixava enviar o relato vazio; a API nova
  responde `400`. A página nova não deixa enviar vazio.

## Deploy

1. **API:** mesclar a PR da API e esperar o Render publicar. Não há variável
   nova.
2. **Página:** publicar com `firebase deploy --only hosting`, a partir da
   branch com esta PR mesclada.
3. **App:** gerar o APK com `USE_API_QR=true` e `API_BASE_URL` do Render.

## Rollback

- **App e página:** reverter o merge e publicar o Hosting anterior pelo
  histórico de versões.
- **API:** reverter o merge. A coleção `qr_access_events` fica sem uso e se
  esvazia sozinha em 90 dias; os campos novos de `locations` são ignorados
  pela versão anterior.

## Validação

Roteiro de aparelho em `docs/validation/qr-avistamentos.md`.
