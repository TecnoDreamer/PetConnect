# ADR 0002 — Arquivamento lógico de pets falecidos

- **Status:** proposta (PR `feat/memorial-pet`, aguardando aceite)
- **Data:** 2026-10-25

## Contexto

Tutores precisam registrar o falecimento de um pet e manter um memorial,
sem perder vacinas, consultas, histórico, QR code ou fotos. Também
precisam poder corrigir uma marcação feita por engano. A fonte de dados
padrão do app é o Firestore. A API Spring (atrás de flags) já tem
`status: DECEASED`, mas expõe esse status na página pública do QR.

## Decisão

1. **Estado explícito no documento do pet** (`situacao: ATIVO |
   FALECIDO`). A ausência do campo equivale a `ATIVO`, então a mudança é
   aditiva e não exige migração.
2. **Arquivamento lógico, nunca físico:** nenhum registro é apagado ao
   registrar o falecimento. Ocultar é responsabilidade da UI e das rotas.
3. **Transição única e auditada** por `PetRepository.alterarSituacao`
   (transação + evento em `eventosSituacao`). `Pet.toMap()` não carrega
   a situação, então nenhuma outra escrita a altera por acidente.
4. **Proteção na rota** (`PetSituacaoGuard`), não só nos botões.
5. **Memorial desligado no modo API** até o backend parar de expor o
   status publicamente.

## Alternativas descartadas

- **Apagar os registros clínicos** para "aliviar" o perfil: irreversível,
  impede a correção e não tem ganho de custo medido.
- **Mover o pet para outra coleção:** quebra referências (subcoleções, QR,
  fotos) e cria duas fontes de verdade.
- **Booleano `falecido`:** pouco extensível. A API já usa enum de status,
  e um enum deixa espaço para outros estados sem nova migração.
- **Habilitar já no modo API com `status: DECEASED`:** exporia
  "Falecido" na página pública do QR.

## Consequências

- Pets legados continuam funcionando sem nenhuma escrita.
- Rollback simples: a versão anterior ignora o campo novo.
- O bloqueio de escrita clínica no servidor (regras do Firestore e
  backend) fica pendente de aprovação, porque envolve deploy em produção.
