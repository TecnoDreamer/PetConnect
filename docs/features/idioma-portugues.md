# App em português do Brasil (RNF24)

> Branch: `feat/app-em-portugues` (2026-10-29), a pedido do proprietário:
> "transforme todos os calendários no modelo brasileiro, inclusive a
> linguagem do aplicativo".

## Antes e depois

As telas do PetConnect já eram escritas em português. O que vinha do
próprio Flutter, não: o app não definia idioma, então botões de diálogo,
dicas, o menu de copiar e colar e os calendários e relógios saíam em
inglês. Só o calendário do cartaz de pet desaparecido tinha um ajuste
próprio.

Agora o app inteiro usa **português do Brasil (`pt_BR`)**, qualquer que
seja o idioma do celular.

| Onde | Antes | Agora |
|---|---|---|
| Botões dos diálogos e calendários | Cancel, OK | Cancelar, OK |
| Dica do botão de voltar (leitor de tela, toque longo) | Back | Voltar |
| Menu de texto | Copy, Paste, Select all | Copiar, Colar, Selecionar tudo |
| Calendário | Meses em inglês; semana a partir do domingo, com S M T W T F S | Meses em português ("outubro de 2026"); semana a partir do domingo, com D S T Q Q S S |
| Data digitada no calendário (ícone de lápis) | mm/dd/yyyy | dd/mm/aaaa |
| Relógio | 12 h, com AM/PM | 24 h |
| Título da tela de entrada (texto do app) | Login | Entrar |

Calendários do app afetados: vacina, consulta (data e horário), histórico
médico, localização, cadastro do pet, registro de falecimento, Editar
perfil e "Visto por último" no cartaz.

## Como funciona

- `lib/core/config/idioma.dart` (`IdiomaDoApp`) define o idioma, a lista
  de idiomas suportados (só `pt_BR`) e os `GlobalMaterialLocalizations`
  do `flutter_localizations`, pacote do próprio SDK do Flutter.
- `lib/app.dart` passa esses valores ao `MaterialApp.router`.
- O calendário do cartaz deixa de ter um ajuste próprio e segue o app.
- **iOS:** `CFBundleLocalizations` com `pt-BR` no `Info.plist`, para os
  textos do sistema dentro do app (por exemplo, pedidos de permissão)
  também saírem em português. **Não foi testado em iOS.**
- As datas salvas não mudam: o banco continua com `dd/MM/yyyy`
  (`lib/core/utils/br_date.dart`) e a API, com ISO 8601.

## Fora desta mudança

- **Folha de compartilhamento e seletor de fotos do Android:** são telas do
  sistema e seguem o idioma do celular.
- **Outros idiomas:** o app não oferece tradução; um celular em inglês vê
  o app em português.

## Testes

- `test/core/idioma_test.dart` (3):
  - o `PetConnectApp` real abre em `pt_BR` com o celular em inglês, com
    os textos e a dica "Voltar";
  - calendário: semana a partir do domingo, `dd/mm/aaaa`, meses em
    português e data digitada em `dd/mm/aaaa`;
  - relógio em 24 h, sem AM/PM.
- Os testes de tela do cartaz usam o mesmo idioma do app e passam a voltar
  pelo botão com a dica "Voltar".

## Como conferir no aparelho

1. Abra Vacinas → nova vacina → data: o calendário mostra o mês em
   português, a semana a partir do domingo e os botões "Cancelar" e "OK".
2. No calendário, toque no lápis e digite `05/11/2026`: a data é aceita.
3. Consultas → nova consulta → horário: o relógio é de 24 h.
4. Num campo de texto, toque e segure: o menu mostra "Copiar" e "Colar".
5. Com o celular em inglês, o app continua em português.
