# Validação manual — Cartaz de pet desaparecido

> Branch: `feat/cartaz-pet-desaparecido`. Detalhes em
> `docs/features/cartaz-pet-desaparecido.md`.
>
> - **Build:** APK de release desta branch, com `GALERIA_FOTOS=true`, para
>   a galeria do pet aparecer no seletor.
> - **Dados:** use um pet de teste. Não poste o cartaz em grupos reais:
>   compartilhe com você mesmo (por exemplo, uma conversa do WhatsApp só
>   sua) ou salve no celular.

## Identificação

```text
Aparelho / Android: motorola edge 60 fusion (0089368537) / Android 16
Build (commit): a1a8421 (primeira versão) e 960f511 (com os ajustes), release, GALERIA_FOTOS=true
Data: 2026-10-29
Testado por: proprietário
```

## Casos

| ID | Caso | Resultado |
|---|---|---|
| CP01 | Perfil de um pet ativo → "Pet desaparecido" abre o editor com foto, nome, espécie e raça do pet | |
| CP02 | Voltar do editor volta ao perfil; voltar do perfil continua funcionando (o app não fecha) | |
| CP03 | Foto principal → escolher da galeria do pet; Foto 2 → foto do perfil; Foto 3 → "Escolher do celular" (o seletor do sistema abre sem pedir acesso a todas as fotos) | |
| CP04 | Uma foto já usada aparece marcada e não pode ser escolhida de novo | |
| CP05 | Escolher uma foto abre "Ajustar"; tocar no rosto do pet na foto inteira move a parte clara; zoom; Pronto; a miniatura e a prévia mostram o rosto no centro, sem cortar | |
| CP06 | Mover uma foto para outra posição e remover uma foto | |
| CP07 | Características vem sugerida (sexo, porte) e pode ser editada; campos opcionais vazios não aparecem na prévia; o cartaz não tem Espécie/Raça, Cor nem Desapareceu em | |
| CP08 | Prévia sem marcar a autorização: o contato fica vazio e os botões ficam desligados, com "Confirme que o telefone…" | |
| CP09 | Marcar a autorização: o telefone aparece formatado e os botões ligam | |
| CP10 | Compartilhar imagem → a folha do sistema abre; enviar para você mesmo no WhatsApp; a imagem chega nítida e legível | |
| CP11 | Salvar imagem → "Cartaz salvo na galeria de fotos."; o cartaz aparece no app de fotos | |
| CP12 | Gerar PDF → compartilhar ou salvar em Arquivos/Drive; o PDF abre num leitor, em A4, sem cortes | |
| CP13 | Prévia com zoom (pinça): textos e fotos nítidos | |
| CP14 | Sair do editor com foto do celular pede confirmação; ao voltar, textos e fotos da galeria continuam, e a foto do celular e a autorização, não | |
| CP15 | Modo avião com fotos da galeria ainda não abertas → exportar → "Uma das fotos não carregou…", sem travar | |
| CP16 | Tema Escuro e fonte grande do Android: o editor continua usável; o cartaz não muda | |
| CP17 | Pet no Memorial: não há "Pet desaparecido" | |
| CP18 | Depois de tudo: o perfil do pet, vacinas, galeria e QR continuam iguais | |
| CP19 | "Descartar rascunho" (menu ⋮ do editor) limpa as fotos e os textos | |
| CP20 | "Ajustar" → "Foto inteira": a foto aparece toda, com fundo desfocado nas sobras, na prévia e no PNG | |
| CP21 | Visto por último: "Escolher a data" abre o calendário em português, sem dias futuros; escolher "Tarde" e depois "Horário exato" (um tira o outro); escrever o local; o cartaz mostra uma linha só, por exemplo "29/10/2026, à tarde — Em casa" | |
| CP22 | Recompensa em dinheiro: digitar 20000 mostra `R$ 200,00` no campo e no cartaz; apagar tudo tira a linha; "Outra" aceita texto | |
| CP23 | Observações com 2 ou 3 linhas: caixa em destaque abaixo dos dados, legível no PNG | |
| CP24 | Na prévia, trocar a cor para vermelho e azul: cabeçalho, faixa e rodapé mudam; o PNG e o PDF saem na cor escolhida | |
| CP25 | Um rascunho feito antes desta versão (ex.: recompensa "200 R$") abre com R$ 200,00 e o local mantido | |

Marcar `OK`, `PARCIAL: <o que faltou conferir>`, `FALHOU: <o que aconteceu>`
ou `BLOQUEADO: <motivo>`. Em branco: ainda não testado.

## Resultado (2026-10-29)

O proprietário testou os fluxos principais nos dois APKs e aprovou o
merge da PR #89:

- **Primeira versão (`a1a8421`):** montou cartazes de dois pets, um gato e
  um cachorro, com fotos reais e o telefone autorizado, e gerou as imagens.
  Desse teste vieram os ajustes da segunda versão.
- **Segunda versão (`960f511`):** testou os ajustes (foto, campos,
  recompensa, "Visto por último" e cor) e disse que funcionou.

Os casos não foram registrados um a um, então a tabela fica em branco. O
roteiro completo (CP01–CP25) continua disponível para uma conferência
caso a caso.
