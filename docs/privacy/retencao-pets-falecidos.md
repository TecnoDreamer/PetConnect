# Retenção e exclusão futura — pets falecidos (planejamento)

> Documento de planejamento. **Nada aqui foi implementado.** A entrega do
> Memorial (`docs/features/memorial-pet.md`) não apaga nenhum dado.

## Finalidade

Os dados de um pet falecido (perfil, fotos, vacinas, consultas, histórico,
QR e avistamentos) continuam servindo à finalidade original: a gestão do
pet pelo tutor, agora como memória. O tutor também pode precisar deles
depois (por exemplo, histórico clínico para um veterinário ou para
documentação).

## Questões a decidir antes de qualquer exclusão

1. **Base legal / consentimento:** a mesma da conta do tutor, ou é preciso
   um aviso ou opção específicos para manter dados de um pet falecido por
   tempo indeterminado?
2. **Prazo de retenção:** indefinido enquanto a conta existir, ou um prazo
   (ex.: N anos sem acesso ao memorial) com aviso prévio?
3. **Exportação:** oferecer exportação (PDF do histórico, fotos) antes de
   qualquer exclusão.
4. **Anonimização × exclusão:** registros clínicos podem ser anonimizados
   (sem vínculo com o tutor) em vez de apagados, se houver interesse
   estatístico legítimo.
5. **Integridade referencial:** a exclusão precisa cobrir subcoleções
   (`vacinas`, `consultas`, `historicoMedico`, `localizacoes`,
   `eventosSituacao`), anexos no Cloudinary e o `publicId` do QR, sem
   deixar órfãos.
6. **Backups:** definir por quanto tempo os dados excluídos persistem em
   backups (`tools/firestore-backup`) e documentar isso na política de
   privacidade.

## Custos

Não há medição de quanto os pets falecidos ocupam no Firestore e no
Cloudinary. **Não prometer redução de custo com exclusão antes de medir o
uso real.** Documentos de pet e registros clínicos são pequenos; o volume
relevante, se houver, está nas imagens.

## Próximos passos (quando priorizado)

Medir o uso, decidir os itens 1 a 6 com o responsável pelo produto e
jurídico, escrever um ADR e só então implementar a exclusão ou
anonimização, sempre com confirmação explícita do tutor.
