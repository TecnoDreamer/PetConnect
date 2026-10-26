# Ícone, nome e splash do Android

> Branch: `fix/android-icone-inicializacao-petconnect`. Fonte:
> `prompt_opus_icone_inicializacao_petconnect.md` e o vídeo
> `screen-20261026-123216.mp4` (launcher com o ícone do Flutter e o rótulo
> `pet_connect`).

## Diagnóstico (comprovado no repositório)

| Sintoma | Causa |
|---|---|
| Rótulo `pet_connect` no launcher | `android:label="pet_connect"` no `AndroidManifest.xml`, herança do template do `flutter create`. |
| Ícone do Flutter no launcher | `mipmap-*/ic_launcher.png` **idênticos byte a byte** ao template do Flutter SDK (`packages/flutter_tools/templates/app/android.tmpl`), sem adaptive icon. |
| Ícone do Flutter ao abrir (Android 12+) | O sistema monta a splash com o ícone do launcher. O `LaunchTheme` não personalizava nada (fundo branco ou preto do tema). |
| Segunda "tela de abertura" | `SplashScreen` do Flutter com gradiente, logo e texto, e **2,5 s fixos** (`Future.delayed`) depois do bootstrap de sessão. |

O vídeo só mostra o efeito. As causas acima foram confirmadas no código e
nos arquivos. Tempos de abertura não foram medidos (ver
`docs/validation/android-icone-inicializacao.md`).

## Fonte do logo

- **Arquivo:** `assets/images/logo.png`, o mesmo da tela de login (marcador
  com cachorro e gato). PNG RGBA de 376×423 px; o desenho ocupa 311×405 px.
- **Não há versão vetorial** no repositório. Para os ícones do launcher a
  resolução basta, porque o logo só é reduzido: até 432 px no xxxhdpi, com
  o desenho a cerca de 240 px. A imagem da splash é ampliada cerca de 1,07×
  no xxhdpi e 1,42× no xxxhdpi, uma perda de nitidez pequena. **Recomendado:**
  obter o SVG ou um PNG de pelo menos 1024 px do logo e regerar.

## Cores

| Uso | Cor | Origem |
|---|---|---|
| Fundo do ícone | gradiente `#3E2415 → #7A5137` (diagonal) | `AppColors.brandGradient`, o mesmo do cabeçalho do login |
| Fundo da splash (nativa e Flutter) | `#5C3A24` | `AppColors.brandMedium` / `@color/splash_fundo` |

O fundo é marrom, e não creme, porque o marcador do logo é creme e
desapareceria sobre um fundo claro. No marrom, o logo aparece exatamente
como o usuário o vê no login.

## Adaptive icon (Android 8+)

`mipmap-anydpi-v26/ic_launcher.xml`:

- **background:** `drawable/ic_launcher_background.xml` (gradiente
  vetorial, nítido em qualquer densidade);
- **foreground:** `mipmap-*/ic_launcher_foreground.png`, quadro de 108dp
  com o logo a **56% da altura**. A zona segura das máscaras é um círculo de
  66dp, e a essa escala o marcador inteiro (topo arredondado e ponta) cabe
  nela. Conferido com máscara circular e squircle;
- **monochrome** (ícones temáticos, Android 13+):
  `mipmap-*/ic_launcher_monochrome.png`, a silhueta do marcador com o
  cachorro vazado, derivada do próprio logo (pixels escuros do cachorro
  ficam transparentes).

**Ícone legado** (Android 7.x, já que o `minSdk` é 24):
`mipmap-*/ic_launcher.png`, quadrado arredondado com o gradiente e o logo
a 68% da altura.

## Splash

- **Android 12+** (`values-v31` e `values-night-v31`): a splash é do
  sistema e não pode ser removida. É personalizada com
  `windowSplashScreenBackground = @color/splash_fundo` e
  `windowSplashScreenAnimatedIcon = @drawable/splash_logo` (quadro de
  288dp, logo a 50%, dentro do círculo visível de 192dp).
- **Até o Android 11:** `drawable(-v21)/launch_background.xml` com a mesma
  cor e o mesmo bitmap, centralizado.
- **Flutter:** `SplashScreen` com a mesma cor e o mesmo logo, a 144dp de
  altura de desenho, centralizado na tela inteira. Ela só fica visível
  enquanto a sessão é resolvida (ver `docs/arquitetura.md`, "Sequência de
  inicialização").

## Como regerar

```bash
python tool/branding/gerar_icones_android.py
```

Requer Python 3 e Pillow (`pip install pillow`). O script lê
`assets/images/logo.png` e reescreve todos os PNGs listados acima. Os XML
(adaptive icon, gradiente e temas) são fixos e versionados. iOS e Web não
foram alterados.

## Não alterado (de propósito)

`applicationId` e namespace (`com.petconnect.pet_connect`), o pacote
Kotlin, a assinatura, o Firebase (`google-services.json`) e os deep links.
Trocar o nome visível não exige mexer em nada disso, e mudar o
`applicationId` criaria outro app, impedindo a atualização do que já está
instalado.
