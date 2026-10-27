# Validação manual — Galeria de fotos por pet

> Branch: `feat/galeria-fotos-pets`. Detalhes em
> `docs/features/galeria-fotos-pet.md`. **Não executado por mim** —
> preencher no aparelho. Usar contas e pets de teste: as fotos vão para o
> Cloudinary real.

```bash
flutter run -d 0089368537 --dart-define=GALERIA_FOTOS=true
```

## Identificação

```text
Aparelho / Android:
Tema(s) testado(s):
Build (commit):
Data:
Testado por:
```

## Casos

Resultado: `PASS`, `FAIL` (descrever), `BLOCKED` (motivo) ou
`PENDENTE — validação do proprietário`.

| ID | Caso | Resultado | Evidência |
|---|---|---|---|
| G01 | Perfil do pet ativo mostra "Fotos" (acima de Localização); vacinas, consultas, histórico e QR continuam | PENDENTE — validação do proprietário | |
| G02 | Pet sem fotos: "Nenhuma foto ainda" e "Adicionar primeira foto" | PENDENTE — validação do proprietário | |
| G03 | Adicionar: o seletor do sistema abre sem pedir permissão de acesso a todas as fotos | PENDENTE — validação do proprietário | |
| G04 | Escolher 3 fotos, pôr legenda numa, publicar: progresso aparece e as 3 entram no topo da grade | PENDENTE — validação do proprietário | |
| G05 | Modo avião no meio de um envio de várias: as já enviadas ficam, as outras mostram erro; "Tentar de novo" com a rede de volta envia só elas | PENDENTE — validação do proprietário | |
| G06 | "Cancelar envio" no meio: as seguintes não sobem | PENDENTE — validação do proprietário | |
| G07 | Tocar duas vezes rápido em "Publicar" não duplica fotos | PENDENTE — validação do proprietário | |
| G08 | Visualizador: abre na foto tocada, zoom por pinça, deslizar entre fotos, legenda e data, voltar do sistema fecha | PENDENTE — validação do proprietário | |
| G09 | Excluir: confirmação; cancelar mantém; confirmar remove da grade | PENDENTE — validação do proprietário | |
| G10 | Mais de 30 fotos: a grade carrega mais ao rolar, sem repetir | PENDENTE — validação do proprietário | |
| G11 | Dois pets: as fotos de um nunca aparecem no outro | PENDENTE — validação do proprietário | |
| G12 | Pet no Memorial: seção "Fotos" com as recentes, "Ver todas" e "Adicionar fotos"; recursos clínicos continuam ocultos | PENDENTE — validação do proprietário | |
| G13 | Adicionar foto a um pet no Memorial funciona | PENDENTE — validação do proprietário | |
| G14 | Outra conta (depois do deploy das regras): não vê as fotos do pet da primeira | PENDENTE — validação do proprietário | |
| G15 | Temas Padrão, Claro e Escuro e fonte do sistema no máximo: sem cortes | PENDENTE — validação do proprietário | |
| G16 | Foto de perfil e capa do pet continuam as mesmas depois de publicar na galeria | PENDENTE — validação do proprietário | |
| G17 | Privacidade: tirar uma foto com localização ligada, publicar, baixar a URL **original** do Cloudinary (campo `url` no Firestore) e conferir se tem GPS (ex.: exiftool) | PENDENTE — validação do proprietário | |
| G18 | Formato HEIC (se a câmera gerar): publica e aparece na grade | PENDENTE — validação do proprietário | |

Atenção ao G14: com as regras **antigas** ainda em vigor, a outra conta
**consegue** ler — é exatamente o motivo de a galeria ficar desligada até o
deploy.
