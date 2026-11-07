# Rede do app em segundo plano ("Sem conexão" ao voltar)

Relato do proprietário em 2026-11-07, no motorola edge 60 fusion: ao abrir
"Compartilhamento via QR Code", a tela mostrou "Sem conexão com o servidor",
com a internet funcionando e a API respondendo em cerca de 1 s a partir de
outra máquina.

## O que se sabe

- **Android corta a rede do app em segundo plano.** O registro de rede do
  sistema (`dumpsys connectivity`) mostrou o app `BLOCKED` quando saiu da
  frente e `UNBLOCKED` quando voltou. Com a tela bloqueada, o app não resolve
  nem o nome do servidor do Firestore.
- **O registro do push falhou** quando o app foi aberto com a tela bloqueada:
  as quatro tentativas caíram dentro do corte
  (`Avisos do QR: aparelho não registrado na API`).
- **Causa da falha na tela de compartilhamento: não confirmada.** A hipótese
  é uma conexão aberta que morreu no corte e foi reaproveitada, fazendo a
  primeira chamada esperar o tempo limite de 15 s. Por isso a correção abaixo
  ataca esse caminho e deixa o motivo de cada falha no log, para confirmar no
  aparelho.
- Não era o Doze profundo: o estado do `deviceidle` ficou `ACTIVE`.

## O que muda

**`ApiClient` (`lib/core/network/api_client.dart`):**
- **Nova tentativa:** falha de rede ou tempo esgotado em **GET, PUT e DELETE**
  ganha mais uma tentativa, depois de 300 ms.
- **POST e PATCH não repetem:** o servidor poderia ter recebido o primeiro
  envio, e repetir duplicaria o efeito.
- **Erro HTTP da API** (404, 409, 500…) não repete: a API respondeu.
- **Conexão nova:** a nova tentativa usa uma conexão nova. A antiga só fecha
  quando as outras chamadas que a usam terminarem.
- **`descartarConexoesAntigas()`:** troca as conexões abertas por novas.

**App (`lib/app.dart`):** `AoVoltarAoPrimeiroPlano` chama
`descartarConexoesAntigas()` toda vez que o app volta ao primeiro plano, para
a primeira chamada não esperar numa conexão morta.

**Log:** cada falha de rede imprime uma linha (também em release), por
exemplo:

```text
API: falha de rede em GET /legacy-pets/:id/public-sharing (SocketException), tentativa 1 de 2.
API: GET /legacy-pets/:id/public-sharing deu certo na tentativa 2.
```

- **O que entra:** o método, a rota e o tipo do erro.
- **O que não entra:** os trechos que não são palavras fixas viram `:id`, e
  query, token e corpo nunca vão para o log.

## Custo e limites

- **Tempo:** uma chamada que cai no tempo limite nas duas tentativas leva até
  30 s para mostrar o erro, em vez de 15 s.
- **Sem garantia:** a nova tentativa ajuda quando o primeiro erro foi de
  conexão. Com a API acordando de verdade (plano gratuito do Render), as duas
  podem esgotar o tempo. O ping de `manter-acordada.yml` na API reduz isso.
- **Push em segundo plano:** o aviso aparece sem o app abrir a rede
  (confirmado no aparelho em 2026-11-07, com a tela ligada e com ela
  bloqueada). O registro do aparelho na API depende de o app estar na frente.

## Testes

- `test/core/api_client_test.dart`:
  - GET repete uma vez e funciona;
  - duas falhas viram `NETWORK`, com duas chamadas só;
  - PUT e DELETE repetem, POST e PATCH não;
  - erro HTTP não repete;
  - tempo esgotado repete;
  - a nova tentativa usa conexão nova e fecha a antiga;
  - descartar troca a conexão, e com chamada em andamento só fecha depois;
  - o log sem ids, token nem query.
- `test/core/ao_voltar_ao_primeiro_plano_test.dart`: chama só ao voltar ao
  primeiro plano e para de ouvir ao sair da tela.
- Roteiro no aparelho: `docs/validation/rede-em-segundo-plano.md`.
