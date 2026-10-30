# PetConnect — guia do testador (APK de teste)

> Versão `0.1.1` (2). Build e segurança em
> `docs/release/apk-testes-externos.md`. O proprietário envia este guia
> junto com o APK.

## Antes de começar

- É uma **versão de teste**, fora da Play Store.
- Use um **e-mail de teste**. No Gmail, `seunome+petconnect@gmail.com` cai
  na sua caixa.
- Cadastre **pets fictícios**.
- Não use dados reais de saúde do seu pet.
- Os dados ficam no servidor do projeto e serão apagados ao fim do teste.
- **Fotos:** use fotos sem pessoas e sem a sua casa. Se o celular for
  Android 7, 8 ou 9, desligue a localização na câmera antes de tirar fotos
  para o teste.
- Não repasse o APK para outras pessoas.
- **Entrar com Google:** o app recebe o nome e o e-mail da conta Google
  escolhida. Se preferir, use uma conta Google de teste ou entre com e-mail
  e senha.
- **Cartaz de pet desaparecido:** o cartaz mostra o telefone do seu
  cadastro, se você autorizar. No teste, compartilhe só com você mesmo
  (por exemplo, numa conversa sua no WhatsApp).

## Instalar

1. Abra o arquivo `app-release.apk` no celular.
2. Se o Android pedir, permita "instalar apps desta fonte" para o app usado
   para abrir o arquivo (Arquivos, Chrome, WhatsApp…).
3. Toque em **Instalar**.
   - O Play Protect pode avisar que o app é desconhecido; toque em
     "Instalar mesmo assim".
   - **Já tem o PetConnect instalado por cabo (`flutter run`)?** Desinstale
     antes, porque a assinatura é outra.
4. **Atualizar:** instale o APK novo por cima. Os dados ficam no servidor.
   Quem tem a `0.1.0` instala a `0.1.1` por cima, sem desinstalar.
5. **Desinstalar:** segure o ícone → Desinstalar.

Requer Android 7.0 ou mais novo.

## Roteiro rápido (smoke test)

| # | Passo | Esperado | OK? |
|---|---|---|---|
| S01 | Abrir o app | Splash do PetConnect, depois a tela **Entrar** | |
| S02 | "Cadastre-se" → criar conta com e-mail de teste | Entra na Home | |
| S03 | Sair e entrar de novo com a mesma conta | Volta à Home | |
| S04 | Adicionar um pet fictício com foto | Aparece em "Meus Pets" | |
| S05 | Abrir o pet → vacinas, consultas, histórico: criar um de cada | Salvam e aparecem | |
| S06 | Pet → Fotos → publicar 2 fotos | Aparecem na grade; tocar amplia | |
| S07 | Pet → ⚙ → Registrar falecimento → confirmar | Abre o memorial do pet | |
| S08 | No memorial, **Voltar do celular** (botão ou gesto) | Lista do Memorial, com o pet | |
| S09 | **Voltar** de novo | Home, sem o pet; **o app não fecha** | |
| S10 | Memorial → pet → ⚙ → Corrigir informação de falecimento | Perfil ativo com tudo como antes; Voltar vai para a Home | |
| S11 | QR Code do pet | O QR aparece | |
| S12 | Configurações → tema Claro e Escuro | O app muda de cor; o Login continua igual | |
| S13 | Sair → **Entrar com Google** → escolher a conta | Entra na Home. Se aparecer erro, avise e entre com e-mail | |
| S14 | Pet → **Pet desaparecido** → escolher 3 fotos (no ajuste, tocar no rosto do pet), autorizar o telefone → Ver cartaz → trocar a cor → Compartilhar imagem com você mesmo | O cartaz chega nítido, com o rosto do pet no centro | |
| S15 | Abrir o calendário de uma vacina nova | Mês em português, semana a partir do domingo, botões "Cancelar" e "OK" | |

## Como reportar um problema

Mande ao proprietário:

```text
O que fiz (passo a passo):
O que esperava:
O que aconteceu:
Celular e versão do Android:
Versão do app: 0.1.1 (2)
Print (sem e-mail, telefone ou outros dados pessoais):
```

## Resultados (preenchido pelo proprietário)

| Testador | Celular / Android | Data | S01–S15 | Problemas |
|---|---|---|---|---|
| | | | | |
