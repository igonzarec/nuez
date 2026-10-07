"""Genera la tarjeta de hojas de pasto con canal alfa para el Instancer de Terrain3D.

Dibuja un grupo de hojas de perfil sobre fondo transparente. El alfa se recorta
limpio porque la silueta se dibuja como poligono, no se extrae de una foto.
Se supermuestrea 4x y se reduce para suavizar los bordes finos.

Uso, desde la raiz del repositorio:

    python tools/build_grass_card.py
"""

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "project/assets/textures/grass_card.png"
SIZE = 512
SS = 4  # factor de supermuestreo
BLADES = 46
SEED = 7

# Misma gama que la paleta de GrassCarpet3D, de mas oscuro a mas claro.
PALETTE = [(61, 102, 36), (77, 117, 46), (92, 128, 56), (108, 142, 66)]


def blade_polygon(x0, width, height, lean, curve, samples=14):
    """Silueta de una hoja: espina curvada que se afila hasta la punta."""
    left, right = [], []
    for i in range(samples + 1):
        t = i / samples
        # La espina se desplaza con la inclinacion y se curva hacia la punta.
        x = x0 + lean * t + curve * t * t
        y = 1.0 - t
        # El ancho se afila con una potencia suave: base gruesa, punta fina.
        w = width * (1.0 - t) ** 0.7
        left.append((x - w, y))
        right.append((x + w, y))
    return left + right[::-1]


def main() -> None:
    rng = random.Random(SEED)
    w = h = SIZE * SS
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    blades = []
    for i in range(BLADES):
        # Reparte las bases por todo el ancho, con algo de ruido.
        base = (i + 0.5) / BLADES + rng.uniform(-0.35, 0.35) / BLADES
        blades.append({
            "x0": base,
            "width": rng.uniform(0.012, 0.022),
            "height": rng.uniform(0.55, 1.0),
            "lean": rng.uniform(-0.18, 0.18),
            "curve": rng.uniform(-0.10, 0.10),
            "color": rng.choice(PALETTE),
            "shade": rng.uniform(0.82, 1.12),
        })
    # Dibuja las hojas bajas primero para que las altas queden delante.
    blades.sort(key=lambda b: b["height"])

    for b in blades:
        poly = blade_polygon(b["x0"], b["width"], b["height"], b["lean"], b["curve"])
        # Normaliza a pixeles: y=0 es la base (abajo), y=1 la punta.
        pts = []
        for x, y in poly:
            px = x * w
            py = h - (1.0 - y) * b["height"] * h
            pts.append((px, py))
        c = tuple(min(255, int(v * b["shade"])) for v in b["color"])
        draw.polygon(pts, fill=c + (255,))

    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT)
    alpha = img.split()[3]
    covered = sum(1 for p in alpha.getdata() if p > 8) / (SIZE * SIZE)
    print(f"Saved {OUT.name}  cobertura alfa {covered:.0%}")


if __name__ == "__main__":
    main()
