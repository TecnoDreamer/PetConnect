# Validação manual — Memorial do Pet

> **Atualização (2026-10-27):** MP17–MP21 cobrem o Voltar depois do
> registro (`docs/features/memorial-retorno-navegacao.md`). Aparelho de
> referência: Motorola Edge 60 Fusion (Android 16). Repetir também numa tela
> menor e com navegação por 3 botões, se houver.

> Branch: `feat/memorial-pet`. Detalhes em `docs/features/memorial-pet.md`.
> Rodar no modo padrão (Firestore, sem `--dart-define`). No modo API o
> Memorial fica desligado de propósito.

## Identificação

```text
Aparelho / Android:
Navegação (gestos / 3 botões):
Tema testado:
Build (commit):
Data:
Testado por:
```

## Casos

| ID | Caso | Resultado |
|---|---|---|
| MP01 | Perfil do pet → ⚙ → seção Memorial → "Registrar falecimento" abre a explicação | |
| MP02 | "Registrar falecimento" → **Voltar** no diálogo: nada muda, o pet continua na Home | |
| MP03 | Registrar com data e homenagem → abre o memorial com "Em memória de", nome, datas e homenagem | |
| MP04 | Registrar **sem** data → o memorial não mostra data inventada | |
| MP05 | Home: o pet sai da lista e aparece a entrada "Memorial" com a contagem | |
| MP06 | Memorial: capa, foto e Lembranças (só fotos deste pet); toque amplia | |
| MP07 | Memorial não mostra vacinas, consultas, histórico, QR, peso, idade nem "Vacinado" | |
| MP08 | Link antigo / voltar para `/pet/<id>/vacinas` do pet falecido: aparece o aviso + "Abrir memorial" | |
| MP09 | ⚙ do memorial → "Corrigir informação de falecimento" → confirmar → perfil ativo com vacinas, consultas e histórico **como antes** | |
| MP10 | Depois da correção, o pet volta para a Home e a entrada "Memorial" some (se era o único) | |
| MP11 | Tocar duas vezes rápido em "Registrar": só um registro (sem erro, sem duplicar) | |
| MP12 | Sem internet: registrar mostra "Nada foi alterado" e o pet continua ativo | |
| MP13 | Temas Padrão/Claro/Escuro e fonte do sistema ampliada: memorial legível, sem cortes | |
| MP14 | Sair e entrar de novo: o pet continua no Memorial | |
| MP15 | Outra conta (segundo login) não vê o pet nem o memorial | |
| MP16 | Página pública do QR do pet falecido **não** mostra "Falecido" | |
| MP17 | Registrar falecimento → no memorial, **botão Voltar do sistema**: abre a lista do Memorial com o pet; de novo: Home sem o pet. O app **não fecha** | |
| MP18 | Mesmo caminho do MP17 com o **gesto** de voltar (navegação por gestos) | |
| MP19 | Mesmo caminho do MP17 com a **seta da AppBar** | |
| MP20 | Corrigir marcação → no perfil restaurado, Voltar: Home (o app não fecha) | |
| MP21 | Sem internet: registrar mostra "Nada foi alterado"; Voltar retorna às Configurações do Pet | |

Marcar `OK` ou `FALHOU: <o que aconteceu>`.
