# 0007 — Cartaz de pet desaparecido gerado no aparelho

- **Data:** 2026-10-29
- **Status:** proposta (implementada em `feat/cartaz-pet-desaparecido`, PR
  sem merge)
- **Contexto:** RF43–RF49, `docs/features/cartaz-pet-desaparecido.md`

## Contexto

O tutor precisa divulgar rapidamente que um pet sumiu, com fotos, dados do
pet e um telefone. Pontos de partida:

- **O pet não tem estado "desaparecido":** a situação é só `ATIVO` ou
  `FALECIDO`.
- **Divulgação em público** (página, mapa, feed) depende da página pública
  do QR (RF17–RF19), ainda bloqueada.
- **O telefone do tutor é dado pessoal:** o cadastro não autoriza
  divulgá-lo.

## Decisões

1. **Cartaz gerado e exportado no aparelho.**
   - Sem coleção, campo, regra do Firestore, endpoint ou upload novos.
   - As fotos já estão no Cloudinary do pet ou chegam do seletor do
     sistema.
   - O PNG é a captura do próprio widget da prévia, e o PDF usa esse PNG.
2. **Sem estado "desaparecido" nesta entrega.**
   - Gerar o cartaz não muda nada no pet.
   - "Declarar desaparecido" e o aviso "ENCONTRADO" exigem campo, regras,
     auditoria e transição com o Memorial, então ficam para uma decisão
     própria.
3. **Rascunho só local** (`shared_preferences`, por tutor e pet).
   - Guarda textos, referências às fotos do Cloudinary e o enquadramento.
   - Não guarda o telefone, que é lido do cadastro na hora, nem o
     consentimento ou as fotos do celular.
4. **Consentimento por número e por sessão.** O tutor autoriza o número
   que vai no cartaz. Trocar o número, ou reabrir o editor, pede de novo.
5. **Sem permissões novas.**
   - A gravação na galeria usa MediaStore (`gal`), que dispensa permissão
     no Android 10 ou mais novo.
   - No Android 9 ou anterior, o app orienta a usar "Compartilhar imagem",
     em vez de pedir acesso ao armazenamento.
6. **Dependências:** `share_plus`, `pdf` e `gal`, mantidas, com licenças
   BSD-3 e Apache-2.0 e sem permissões no manifest. `path_provider` passa a
   ser direta (já vinha como indireta).

## Consequências

- **Para o tutor:** nada a configurar e nenhum deploy, e o recurso funciona
  sem conta de outro serviço. Não há como "recolher" um cartaz já
  compartilhado, e o app avisa isso.
- **Rascunho:** não sincroniza entre aparelhos.
- **Divulgação pública** (QR ou link no cartaz, mapa, feed) continua fora,
  à espera da página pública e de consentimento próprio.
- **Revisão:** se o estado "desaparecido" for criado, o cartaz pode passar
  a mostrar e alterar esse estado.
  - Mostrar e alterar devem ser ações separadas, para o tutor não declarar
    o pet desaparecido sem querer.
  - O estado precisa ser incompatível com `FALECIDO`.
