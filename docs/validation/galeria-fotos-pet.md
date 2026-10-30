# Validação manual — Galeria de fotos por pet

> Branch: `feat/galeria-fotos-pets`. Detalhes em
> `docs/features/galeria-fotos-pet.md`. Usar contas e pets de teste: as
> fotos vão para o Cloudinary real.
>
> **1ª rodada (2026-10-27):** feita pelo proprietário no aparelho, depois do
> deploy das regras. Os resultados abaixo são o que ele relatou; o Claude
> instalou o app e não tocou na tela. Os casos que não fizeram parte do
> roteiro curto daquela rodada continuam `PENDENTE`.

```bash
flutter run -d 0089368537 --dart-define=GALERIA_FOTOS=true
```

## Identificação

```text
Aparelho / Android: motorola edge 60 fusion (0089368537) / Android 16
Tema(s) testado(s): não registrado
Build (commit): 8440091 (merge da PR #80), debug, --dart-define=GALERIA_FOTOS=true
Data: 2026-10-27
Testado por: proprietário (duas contas de teste)
```

## Casos

Resultado: `PASS`, `PARCIAL` (o que faltou conferir), `FAIL` (descrever),
`BLOCKED` (motivo) ou `PENDENTE — validação do proprietário`.

| ID | Caso | Resultado | Evidência |
|---|---|---|---|
| G01 | Perfil do pet ativo mostra "Fotos" (acima de Localização); vacinas, consultas, histórico e QR continuam | PARCIAL | 2026-10-27: entrada "Fotos" usada para chegar à galeria. Não conferido nesta rodada: posição e os demais recursos |
| G02 | Pet sem fotos: "Nenhuma foto ainda" e "Adicionar primeira foto" | PENDENTE — validação do proprietário | |
| G03 | Adicionar: o seletor do sistema abre sem pedir permissão de acesso a todas as fotos | PENDENTE — validação do proprietário | |
| G04 | Escolher 3 fotos, pôr legenda numa, publicar: progresso aparece e as 3 entram no topo da grade | PASS | 2026-10-27: 2 a 3 fotos publicadas com legenda |
| G05 | Modo avião no meio de um envio de várias: as já enviadas ficam, as outras mostram erro; "Tentar de novo" com a rede de volta envia só elas | PENDENTE — validação do proprietário | |
| G06 | "Cancelar envio" no meio: as seguintes não sobem | PENDENTE — validação do proprietário | |
| G07 | Tocar duas vezes rápido em "Publicar" não duplica fotos | PENDENTE — validação do proprietário | |
| G08 | Visualizador: abre na foto tocada, zoom por pinça, deslizar entre fotos, legenda e data, voltar do sistema fecha | PARCIAL | 2026-10-27: tela cheia, zoom e deslizar OK. Não registrado: voltar do sistema |
| G09 | Excluir: confirmação; cancelar mantém; confirmar remove da grade | PARCIAL | 2026-10-27: excluir com confirmação OK. Não registrado: "Cancelar" mantém a foto |
| G10 | Mais de 30 fotos: a grade carrega mais ao rolar, sem repetir | PENDENTE — validação do proprietário | |
| G11 | Dois pets: as fotos de um nunca aparecem no outro | PENDENTE — validação do proprietário | |
| G12 | Pet no Memorial: seção "Fotos" com as recentes, "Ver todas" e "Adicionar fotos"; recursos clínicos continuam ocultos | PARCIAL | 2026-10-27: seção "Fotos" e botão "Adicionar fotos" OK. Não registrado: "Ver todas" e recursos clínicos ocultos |
| G13 | Adicionar foto a um pet no Memorial funciona | PENDENTE — validação do proprietário | |
| G14 | Outra conta (depois do deploy das regras): não vê as fotos do pet da primeira | PASS | 2026-10-27: segunda conta, criada no app, sem pets nem fotos da primeira; de volta à primeira, fotos intactas. Bloqueio fora do app: testes de regras no emulador (CI da PR #80) |
| G15 | Temas Padrão, Claro e Escuro e fonte do sistema no máximo: sem cortes | PENDENTE — validação do proprietário | |
| G16 | Foto de perfil e capa do pet continuam as mesmas depois de publicar na galeria | PENDENTE — validação do proprietário | |
| G17 | Privacidade: tirar uma foto com localização ligada, publicar, baixar a URL **original** do Cloudinary (campo `url` no Firestore) e conferir se tem GPS (ex.: exiftool) | PENDENTE — validação do proprietário | |
| G18 | Formato HEIC (se a câmera gerar): publica e aparece na grade | PENDENTE — validação do proprietário | |

Atenção ao G14: com as regras **antigas**, a outra conta **conseguia** ler.
Por isso a galeria ficou desligada até o deploy de 2026-10-27. Pela tela,
o G14 confere só o que o app mostra; o bloqueio de quem tenta ler por fora
do app é garantido pelas regras e coberto pelos testes no emulador.

## Ainda falta

- **Pendentes:** G02, G03, G05, G06, G07, G10, G11, G13, G15, G16, G17 e
  G18.
- **Parciais:** completar o que ficou sem registro em G01, G08, G09 e G12.
- **Antes de liberar a galeria (decisão D4 do ADR 0005):**
  - o G17 (GPS no original), que decide a D3;
  - o G05 e o G06 (falha e cancelamento no envio).
