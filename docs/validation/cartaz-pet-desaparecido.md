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
Aparelho / Android:
Build (commit):
Data:
Testado por:
```

## Casos

| ID | Caso | Resultado |
|---|---|---|
| CP01 | Perfil de um pet ativo → "Pet desaparecido" abre o editor com foto, nome, espécie e raça do pet | |
| CP02 | Voltar do editor volta ao perfil; voltar do perfil continua funcionando (o app não fecha) | |
| CP03 | Foto principal → escolher da galeria do pet; Foto 2 → foto do perfil; Foto 3 → "Escolher do celular" (o seletor do sistema abre sem pedir acesso a todas as fotos) | |
| CP04 | Uma foto já usada aparece marcada e não pode ser escolhida de novo | |
| CP05 | Tocar numa foto escolhida → Ajustar enquadramento: arrastar, zoom e controles; Pronto; a prévia mostra o recorte | |
| CP06 | Mover uma foto para outra posição e remover uma foto | |
| CP07 | Características vem sugerida (sexo, porte) e pode ser editada; campos opcionais vazios não aparecem na prévia | |
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

Marcar `OK`, `PARCIAL: <o que faltou conferir>`, `FALHOU: <o que aconteceu>`
ou `BLOQUEADO: <motivo>`. Em branco: ainda não testado.
