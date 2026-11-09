# Roteiro de teste — Cartão de Emergência (#41)

> Nada deste roteiro foi executado no aparelho. Marque cada item ao testar,
> com aparelho e data. Ver `docs/features/cartao-emergencia.md`.

**Pré-requisitos:**
1. Regras do Firestore publicadas com o bloco `emergencia`.
2. APK com `--dart-define=CARTAO_EMERGENCIA=true` (e os flags de sempre).
3. Duas contas de teste (A e B), cada uma com um pet. Dados fictícios.

## Leitura e edição

- [ ] Perfil do pet ativo: o card **Cartão de Emergência** aparece abaixo
      dos quatro cards, sem mexer neles.
- [ ] Pet sem cartão: aparece "Preencher cartão" e o aviso de que nada vai
      para a página do QR.
- [ ] Salvar sem preencher nada: o cartão mostra "Não informado" em tudo.
- [ ] Alergias em "Nenhuma conhecida": o cartão mostra "Nenhuma conhecida
      (declarado pelo tutor)".
- [ ] Preencher uma alergia, um medicamento, observações e o veterinário;
      salvar, sair e voltar: tudo igual, com "Atualizado em" certo.
- [ ] Tipo sanguíneo sem marcar a confirmação: o app não salva.
- [ ] "Ligar para o veterinário" abre o discador com o número, sem ligar.
- [ ] Desligar "Mostrar meu telefone": o contato do tutor some do cartão.
- [ ] Voltar com alterações: aparece "Descartar alterações?".

## Rede e concorrência

- [ ] Modo avião com o cartão já aberto antes: abre com o aviso "Sem
      conexão: mostrando a última versão salva".
- [ ] Modo avião e salvar: "Sem conexão. Nada foi salvo" em até 20 s, com o
      formulário intacto.
- [ ] Dois aparelhos na mesma conta abrem o formulário; o primeiro salva e
      o segundo tenta salvar: aparece "O cartão mudou" e nada é sobrescrito.

## Privacidade e acesso

- [ ] Escanear o QR do pet: a página pública não mostra nada do cartão.
- [ ] Conta B não vê o pet nem o cartão da conta A.
- [ ] Registrar o falecimento: o cartão abre pelo Memorial, só para leitura.
- [ ] Sair da conta e entrar com outra: o cartão anterior não aparece.
- [ ] Excluir o pet: o cartão some do Firestore (conferir no console).

## Acessibilidade

- [ ] Fonte do sistema no máximo: cartão e formulário sem cortes, salvar
      alcançável com o teclado aberto.
- [ ] TalkBack: seções lidas como cabeçalho; botões com nome.
- [ ] Temas Padrão, Claro e Escuro.

## Resultado

| Item | Aparelho | Data | Resultado |
|---|---|---|---|
| | | | |
