"""Port de tools/build_grass_textures.gd a Python (Pillow + NumPy).

Genera los mismos mapas derivados que el script de Godot a partir de
grass_source.png, para poder reconstruirlos sin abrir el editor ni depender
del binario de Godot. La altura es una aproximacion artistica derivada de la
luminancia, no una medicion fisica.

Uso, desde la raiz del repositorio:

    python tools/build_grass_textures.py
"""

from pathlib import Path

import numpy as np
from PIL import Image

FOLDER = Path(__file__).resolve().parent.parent / "project/assets/textures/grass_carpet"
SIZE = 1024


def main() -> None:
    source = Image.open(FOLDER / "grass_source.png").convert("RGB")
    source = source.resize((SIZE, SIZE), Image.LANCZOS)
    rgb = np.asarray(source).astype(np.float64) / 255.0

    # Misma luminancia que el script de Godot (Rec. 709).
    h = rgb[:, :, 0] * 0.2126 + rgb[:, :, 1] * 0.7152 + rgb[:, :, 2] * 0.0722

    # Derivadas con envoltura toroidal para que el normal tambien repita.
    dx = np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)
    dy = np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)
    n = np.stack([-dx * 2.0, dy * 2.0, np.ones_like(h)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    n = n * 0.5 + 0.5

    neutral = np.clip(0.85 + (h - 0.5) * 0.5, 0.0, 1.0)

    def to_u8(a):
        return np.clip(np.rint(a * 255.0), 0, 255).astype(np.uint8)

    opaque = np.ones_like(h)
    outputs = {
        "grass_albedo.png": np.dstack([rgb, opaque]),
        "grass_height.png": np.dstack([h, h, h, opaque]),
        "grass_normal.png": np.dstack([n, opaque]),
        "grass_albedo_height.png": np.dstack([rgb, h]),
        "grass_normal_roughness.png": np.dstack([n, np.full_like(h, 0.9)]),
        "grass_neutral_albedo_height.png": np.dstack([neutral, neutral, neutral, h]),
    }
    for filename, data in outputs.items():
        Image.fromarray(to_u8(data), "RGBA").save(FOLDER / filename)
        print("Saved", filename)


if __name__ == "__main__":
    main()
