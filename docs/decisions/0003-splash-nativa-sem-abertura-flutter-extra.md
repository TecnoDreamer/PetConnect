# ADR 0003 — Splash nativa da marca, sem abertura Flutter extra

- **Status:** proposta (PR `fix/android-icone-inicializacao-petconnect`)
- **Data:** 2026-10-26

## Contexto

O Android 12+ sempre mostra uma splash do sistema, montada com o ícone do
app, e um app comum não pode removê-la. O PetConnect usava o ícone padrão
do Flutter e, depois disso, uma `SplashScreen` Flutter com outro visual
(gradiente, logo e texto) e 2,5s fixos de espera. Eram duas aberturas
diferentes e a primeira tinha a marca errada.

## Decisão

1. Personalizar a splash nativa (Android 12+ e anteriores) com a cor da
   marca e o logo oficial.
2. Manter a rota `/` (`SplashScreen`) só enquanto a sessão é resolvida,
   porque o bootstrap que exige login a cada abertura não pode ser pulado,
   **com o visual idêntico ao da splash nativa** e sem tempo mínimo.
3. Não usar `flutter_native_splash` nem a API `SplashScreen` do AndroidX
   (`setKeepOnScreenCondition`): manteriam a splash nativa na tela até o
   fim do bootstrap, mas acrescentariam dependências e código nativo para
   um ganho visual igual ao da continuação em Flutter.

## Consequências

- Uma única abertura visual: marrom com o logo, depois o Login.
- O tempo de abertura passa a ser o tempo real de inicialização mais o
  bootstrap, sem espera fixa.
- Ícones e splash são regerados por script a partir do logo
  (`tool/branding/gerar_icones_android.py`).
