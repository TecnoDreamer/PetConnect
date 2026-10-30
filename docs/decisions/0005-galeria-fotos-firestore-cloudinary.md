# ADR 0005 — Galeria de fotos: metadados no Firestore, arquivos no Cloudinary

- **Status:** proposta (PR `feat/galeria-fotos-pets`, aguardando aceite)
- **Data:** 2026-10-27

## Contexto

O tutor quer uma galeria particular por pet, inclusive para pets no
Memorial (`docs/features/galeria-fotos-pet.md`). Hoje:

- os pets ficam no Firestore no modo padrão; no modo API (`USE_API_PETS`),
  no MongoDB, que não tem galeria;
- fotos de perfil e capa vão ao Cloudinary pelo preset unsigned, ou com a
  assinatura da API (`USE_API_UPLOAD`), que também permite excluir;
- as regras do Firestore com isolamento por dono estão mescladas, mas o
  deploy está pendente; as regras em vigor deixam qualquer conta logada
  ler e escrever tudo.

## Decisão

1. **Metadados em `Pets/{petId}/fotos/{fotoId}`**, com `petId`, `userId`,
   `url`, `publicId`, dimensões, legenda e `criadoEm` do servidor. Regras
   próprias: só o dono, inclusive de pet falecido; criação validada campo a
   campo; sem edição.
2. **Arquivos no Cloudinary pelo `AnexoRepository` já existente**, no
   endpoint de imagem (`image/upload`), com progresso e cancelamento. O modo
   de upload (unsigned ou assinado) continua decidido por `USE_API_UPLOAD`.
3. **Ordem de escrita:** arquivo primeiro, registro depois; se o registro
   falhar, remove o arquivo (quando o modo permite). Na exclusão, arquivo
   primeiro, registro depois; se o arquivo falhar, nada muda. As duas
   etapas são idempotentes, então repetir é seguro.
4. **Flag `GALERIA_FOTOS`, desligada por padrão**, até o deploy das regras
   (feito em 2026-10-27) e a decisão D4.
5. **Só modo Firestore.** No modo API a galeria fica oculta, como o
   Memorial.

## Alternativas descartadas

- **Galeria na API (MongoDB) já agora:** daria exclusão segura do arquivo e
  uma fonte única, mas o app em uso é o modo Firestore e o escopo dobraria
  (contrato, endpoints, migração). Fica como decisão D1 abaixo.
- **Upload direto ao Firebase Storage:** o projeto não tem plano pago; foi
  abandonado antes (ver `anexo_providers.dart`).
- **Lista de URLs no documento do pet:** sem paginação, documento crescendo
  sem limite e uma corrida a cada publicação simultânea.
- **Excluir o arquivo pelo app com a API secret:** a secret ficaria no APK.

## Consequências

- No modo padrão (unsigned), excluir uma foto apaga o registro mas **não o
  arquivo**, que fica órfão no Cloudinary — a mesma limitação das fotos de
  perfil hoje. Com `USE_API_UPLOAD` e as credenciais da API configuradas,
  o arquivo é apagado.
- O preset unsigned aceita envio de qualquer um que conheça o nome dele;
  o risco (abuso de cota) já existia e não aumenta com a galeria.
- URLs do Cloudinary abrem para quem tiver o link.

## Decisões pendentes do proprietário

| # | Decisão | Opções | Recomendação |
|---|---|---|---|
| D1 | Galeria no modo API | implementar na API agora; depois, com a migração dos pets | Depois, junto com a migração |
| D2 | Upload assinado em produção | configurar `CLOUDINARY_API_KEY`/`SECRET` no Render e ligar `USE_API_UPLOAD`; manter unsigned | Configurar: resolve a exclusão do arquivo e restringe o envio à pasta do tutor |
| D3 | Remover metadados na entrada | transformação no preset unsigned; na assinatura da API; nenhuma | Na assinatura da API (com D2), depois de checar no aparelho se o original tem GPS |
| D4 | Ligar a galeria | depois do deploy das regras; antes | Só depois do deploy e do checklist do aparelho |
