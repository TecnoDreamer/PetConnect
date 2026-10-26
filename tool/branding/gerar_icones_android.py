"""Gera os ícones e a imagem da splash do Android a partir do logo oficial.

Fonte única: assets/images/logo.png (o mesmo logo da tela de login). Nada é
desenhado à mão — o script só recorta, posiciona e redimensiona o logo.

Uso (da raiz do repositório, com Python 3 + Pillow):

    python tool/branding/gerar_icones_android.py

Gera, para cada densidade (mdpi..xxxhdpi):

- mipmap-*/ic_launcher.png            ícone legado (Android 7.x, sem adaptive)
- mipmap-*/ic_launcher_foreground.png camada da frente do adaptive icon
- mipmap-*/ic_launcher_monochrome.png ícone temático (Android 13+)
- drawable-*/splash_logo.png          logo da splash nativa

Os XML que usam esses arquivos (adaptive icon, fundo em gradiente, temas da
splash) são fixos e ficam versionados em android/app/src/main/res. Ver
docs/branding/icone-e-splash-android.md.
"""

from pathlib import Path

from PIL import Image, ImageDraw

RAIZ = Path(__file__).resolve().parents[2]
LOGO = RAIZ / "assets" / "images" / "logo.png"
RES = RAIZ / "android" / "app" / "src" / "main" / "res"

DENSIDADES = {"mdpi": 1.0, "hdpi": 1.5, "xhdpi": 2.0, "xxhdpi": 3.0, "xxxhdpi": 4.0}

# Gradiente do cabeçalho do login (AppColors.brandGradient).
MARROM_ESCURO = (0x3E, 0x24, 0x15)
MARROM_CLARO = (0x7A, 0x51, 0x37)

# Fração da altura do quadro ocupada pelo logo. No adaptive icon (108dp) a
# zona segura é um círculo de 66dp: com 0,56 o marcador inteiro (topo
# redondo e ponta) fica dentro dele em qualquer máscara (círculo, squircle,
# gota). Na splash (quadro de 288dp, círculo visível de 192dp) a mesma
# conta dá folga com 0,50.
ALTURA_LOGO_ADAPTIVE = 0.56
ALTURA_LOGO_LEGADO = 0.68
ALTURA_LOGO_SPLASH = 0.50

# Pixels do cachorro (azul-marinho) ficam vazados no ícone temático: o
# marcador com a silhueta do cachorro recortada continua reconhecível numa
# cor só.
LIMIAR_CACHORRO = 0.30


def carregar_logo() -> Image.Image:
    logo = Image.open(LOGO).convert("RGBA")
    return logo.crop(logo.getbbox())


def logo_centralizado(logo: Image.Image, lado: int, fracao_altura: float) -> Image.Image:
    altura = round(lado * fracao_altura)
    largura = round(logo.width * altura / logo.height)
    redim = logo.resize((largura, altura), Image.LANCZOS)
    quadro = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    quadro.alpha_composite(redim, ((lado - largura) // 2, (lado - altura) // 2))
    return quadro


def gradiente_diagonal(lado: int) -> Image.Image:
    """Do canto superior esquerdo (escuro) ao inferior direito (claro)."""
    img = Image.new("RGBA", (lado, lado))
    px = img.load()
    total = 2 * (lado - 1) or 1
    for y in range(lado):
        for x in range(lado):
            t = (x + y) / total
            px[x, y] = tuple(
                round(a + (b - a) * t) for a, b in zip(MARROM_ESCURO, MARROM_CLARO)
            ) + (255,)
    return img


def icone_legado(logo: Image.Image, lado: int) -> Image.Image:
    fundo = gradiente_diagonal(lado)
    mascara = Image.new("L", (lado, lado), 0)
    ImageDraw.Draw(mascara).rounded_rectangle(
        (0, 0, lado - 1, lado - 1), radius=round(lado * 0.22), fill=255
    )
    icone = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    icone.paste(fundo, (0, 0), mascara)
    icone.alpha_composite(logo_centralizado(logo, lado, ALTURA_LOGO_LEGADO))
    return icone


def monocromatico(foreground: Image.Image) -> Image.Image:
    saida = Image.new("RGBA", foreground.size, (0, 0, 0, 0))
    src = foreground.load()
    dst = saida.load()
    for y in range(foreground.height):
        for x in range(foreground.width):
            r, g, b, a = src[x, y]
            if a == 0:
                continue
            luminancia = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255
            if luminancia >= LIMIAR_CACHORRO:
                dst[x, y] = (255, 255, 255, a)
    return saida


def salvar(img: Image.Image, caminho: Path) -> None:
    caminho.parent.mkdir(parents=True, exist_ok=True)
    img.save(caminho, optimize=True)
    print(caminho.relative_to(RAIZ))


def main() -> None:
    logo = carregar_logo()
    for densidade, escala in DENSIDADES.items():
        lado_adaptive = round(108 * escala)
        foreground = logo_centralizado(logo, lado_adaptive, ALTURA_LOGO_ADAPTIVE)
        salvar(foreground, RES / f"mipmap-{densidade}" / "ic_launcher_foreground.png")
        salvar(monocromatico(foreground),
               RES / f"mipmap-{densidade}" / "ic_launcher_monochrome.png")
        salvar(icone_legado(logo, round(48 * escala)),
               RES / f"mipmap-{densidade}" / "ic_launcher.png")
        salvar(logo_centralizado(logo, round(288 * escala), ALTURA_LOGO_SPLASH),
               RES / f"drawable-{densidade}" / "splash_logo.png")


if __name__ == "__main__":
    main()
