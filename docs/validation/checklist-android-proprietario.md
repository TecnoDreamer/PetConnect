# Checklist Android — validação pelo proprietário

> Reutilizável a cada build que vai para o celular ou para a loja. Feito à
> mão no aparelho; o que não for testado fica `PENDENTE — validação do
> proprietário`. Nenhum item abaixo foi marcado por mim sem evidência.

## Identificação

```text
Aparelho / Android:          (ex.: Motorola Edge 60 Fusion / Android 16)
Build (commit / versão):
Tipo de build:               debug | release
dart-defines usados:
Tema(s) testado(s):
Data:
Testado por:
```

## Casos

Resultado: `PASS`, `FAIL` (descrever), `BLOCKED` (motivo) ou
`PENDENTE — validação do proprietário`.

| ID | Caso | Resultado | Evidência |
|---|---|---|---|
| A01 | Instalar por cima da versão anterior sem perder dados (login continua, pets aparecem) | PENDENTE — validação do proprietário | |
| A02 | Nome **PetConnect** e ícone corretos no launcher e em Configurações → Apps | PENDENTE — validação do proprietário | |
| A03 | Splash nativa sem uma segunda tela de abertura do Flutter | PENDENTE — validação do proprietário | |
| A04 | Login e Cadastro estáticos, com as cores originais nos três temas | PENDENTE — validação do proprietário | |
| A05 | Logout e novo login sem cores trocadas (com o tema em Escuro) | PENDENTE — validação do proprietário | |
| A06 | Tema Claro com fundo branco; Padrão e Escuro coerentes | PENDENTE — validação do proprietário | |
| A07 | Lista de pets, detalhes do pet e Memorial corretos | PENDENTE — validação do proprietário | |
| A08 | Tutor A não abre nem altera dados do tutor B (duas contas de teste) | PENDENTE — validação do proprietário | |
| A09 | Vacinas, consultas, histórico e localização carregam nos três temas | PENDENTE — validação do proprietário | |
| A10 | Pet falecido não aceita novos registros clínicos | PENDENTE — validação do proprietário | |
| A11 | QR: escanear abre a página; regenerar; o novo abre e o antigo mostra "pet não encontrado" (`USE_API_QR=true`, pet sem coleira impressa) | PENDENTE — validação do proprietário | |
| A12 | Fonte do sistema no maior tamanho sem cortes em "Meus Pets" | PENDENTE — validação do proprietário | |
| A13 | Teclado não cobre campos nem faz a tela pular | PENDENTE — validação do proprietário | |
| A14 | Sem travamentos, engasgos visíveis ou carregamentos repetidos | PENDENTE — validação do proprietário | |
| A15 | Sem internet: o app avisa e volta a funcionar quando a conexão volta | PENDENTE — validação do proprietário | |

Só para build de **release**:

| ID | Caso | Resultado | Evidência |
|---|---|---|---|
| R01 | App abre e carrega dados (confirma INTERNET e R8 no release) | PENDENTE — validação do proprietário | |
| R02 | Fotos sobem e aparecem (Cloudinary) | PENDENTE — validação do proprietário | |
| R03 | Excluir conta (com conta de teste) apaga a conta e volta ao Login | PENDENTE — validação do proprietário | |

Plano de publicação: `docs/release/plano-publicacao-android.md`.
