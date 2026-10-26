# Validação manual — ícone, nome e abertura no Android

> Branch: `fix/android-icone-inicializacao-petconnect`. Detalhes em
> `docs/branding/icone-e-splash-android.md`.

## Identificação

```text
Aparelho / versão do Android:
Launcher (ex.: One UI, Pixel, Motorola):
Tipo de build (debug / profile / release):
Commit:
Data:
```

## Instalação

1. **Atualização:** instale por cima do app já instalado, sem desinstalar
   (`flutter run` ou `adb install -r`). Os dados e a conta precisam
   continuar.
2. **Instalação limpa:** desinstale e instale de novo.

Se o launcher continuar mostrando o ícone antigo depois da atualização,
reinicie o launcher ou o aparelho. É cache do launcher, não do app.

## Medição de abertura (opcional, recomendado em build profile/release)

```bash
adb shell am force-stop com.petconnect.pet_connect
adb shell am start -W -n com.petconnect.pet_connect/.MainActivity
```

`TotalTime` é o tempo até a primeira tela. Faça 5 aberturas a frio (com
`force-stop` antes de cada uma) e 5 a quente (voltar para a Home do
Android e abrir de novo) e registre a mediana. Em debug os tempos são bem
maiores e não servem de comparação.

## Checklist

```text
[ ] Launcher mostra "PetConnect" (não "pet_connect")
[ ] Lista de apps e Configurações > Apps mostram "PetConnect"
[ ] Ícone = logo do login (marcador com cachorro e gato) sobre o marrom, sem corte nem deformação
[ ] Ícone correto após atualizar o app existente, sem perder dados
[ ] Ícone correto após instalação limpa
[ ] Máscara circular / squircle do launcher sem cortar o logo
[ ] Ícones temáticos (Android 13+, se o launcher suportar): silhueta do marcador com o cachorro vazado
[ ] Android 12+: splash do sistema marrom com o logo PetConnect (nenhum logo do Flutter)
[ ] Nenhuma segunda tela de abertura com texto, nenhuma espera fixa
[ ] Troca da splash para o Login sem flash branco ou preto
[ ] Abertura a frio e a quente sem flash
[ ] Login com identidade original mesmo após usar o tema Escuro e sair
[ ] Login, logout, Esqueci senha e Cadastro funcionando
[ ] Sem internet: o app abre e chega ao Login (não fica preso na splash)
[ ] Status bar com ícones claros na splash e escuros no Login
```

## Resultado

```text
Medições (mediana, ms): frio ___  quente ___   (antes: frio ___  quente ___)
Resultado geral: [ ] Aprovado  [ ] Reprovado
Observações / evidências:
```
