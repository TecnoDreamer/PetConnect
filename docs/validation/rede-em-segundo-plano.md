# Roteiro de teste — Rede do app em segundo plano

> Nada deste roteiro foi executado com a correção. Marque cada item ao testar,
> com aparelho e data. Ver `docs/features/rede-em-segundo-plano.md`.

**Pré-requisitos:**
1. APK com a correção, instalado.
2. Celular na mesma internet, com a conta logada.
3. Para ler o log: cabo e `adb logcat` filtrado por `flutter`.

## No aparelho

- [ ] Abrir o app, apertar **Início**, esperar 1 minuto e voltar ao app.
- [ ] Abrir Configurações do pet > Compartilhamento via QR Code **logo depois
      da volta**: a tela carrega sem "Sem conexão".
- [ ] Repetir com a tela bloqueada por 2 minutos antes de voltar.
- [ ] Se aparecer "Sem conexão", ver no log a linha
      `API: falha de rede em GET … (Tipo), tentativa 1 de 2.` e anotar o tipo.
- [ ] Com a internet desligada de verdade (modo avião), a tela mostra "Sem
      conexão" depois de até 30 s e "Tentar de novo" volta a funcionar com a
      internet ligada.
- [ ] No log não aparecem tokens, ids nem endereços completos.

## Resultado

| Item | Aparelho | Data | Resultado |
|---|---|---|---|
| | | | |
