# Roteiro de teste — Página pública do QR com consentimento

> Issue #35. Nada deste roteiro foi executado ainda. Marque cada item ao
> testar, com aparelho, navegador e data.

**Pré-requisitos:**
1. API publicada com a PR da fase 1, e a credencial do Render lendo o
   Firestore (ver `docs/features/qr-compartilhamento-publico.md`, "Para ir
   ao ar").
2. Página nova publicada no Hosting.
3. APK gerado com `USE_API_QR=true` e
   `API_BASE_URL=https://petconnect-api-rxr9.onrender.com`.
4. Um segundo celular para escanear o QR.

## App

- [ ] Configurações do pet mostra "QR Code > Compartilhamento via QR Code".
- [ ] Na primeira vez, nenhuma caixa vem marcada, a prévia mostra "cadastrado
      no PetConnect" e "Publicar" fica desabilitado.
- [ ] Marcar um dado sem o consentimento não habilita "Publicar".
- [ ] O telefone vem do perfil, formatado. Um número inválido mostra o erro.
- [ ] Mudar o telefone aqui não muda o telefone do perfil (conferir em
      Editar perfil).
- [ ] Publicar mostra "Página pública ativada" e a data do consentimento.
- [ ] Ao reabrir a tela, os dados marcados continuam marcados e o
      consentimento vem desmarcado.
- [ ] "Desativar página pública" pede confirmação e volta para "desativada".
- [ ] Sem internet, aparece a mensagem de conexão e nada muda.
- [ ] Nos três temas, com fonte grande e com o leitor de tela (TalkBack),
      as caixas são lidas com o nome do dado.

## Página (escanear com outro celular)

- [ ] Pet sem publicação: só "Este pet está cadastrado no PetConnect" e o
      formulário, sem nome nem foto.
- [ ] Pet publicado: só os dados marcados.
- [ ] Desmarcar um dado e salvar: ele some ao recarregar a página.
- [ ] Desativar: ao recarregar, volta para o mínimo neutro.
- [ ] A caixa "Incluir minha localização" vem desmarcada.
- [ ] Enviar o formulário mostra "Seu relato foi registrado".
- [ ] Pet criado depois da última migração: publicar e escanear abre a
      página com os dados.
- [ ] QR regenerado: o QR antigo mostra "não encontramos".
- [ ] Excluir o pet no app: o QR passa a mostrar "não encontramos".
- [ ] Testar no Chrome do Android e no navegador do leitor de QR do
      fabricante. Se houver iPhone, testar no Safari.

## Resultado

| Item | Aparelho / navegador | Data | Resultado |
|---|---|---|---|
| | | | |
