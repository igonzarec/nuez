"""Prepare the user-selected Soft Surface images and derived Godot texture maps.

Run from any folder: python tools/build_soft_surface_textures.py --help
Only derived PNGs are regenerated. Existing material settings are preserved.
"""

import argparse
from pathlib import Path
import shutil

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "project/assets/textures/soft_surface"
SOURCES = {
    "grass": ("grass carpet new.png", "Soft Surface Grass"),
    "cliff": ("maybe cliff.png", "Soft Surface Cliff"),
    "grass_semi_realistic": ("grass carpet semi realistic.png", "Soft Surface Grass Semi Realistic"),
    "grass_path_dust": ("soft surface grass path dust.png", "Soft Surface Grass Path Dust"),
    "grass_path_dust_green": ("soft surface grass path dust green.png", "Soft Surface Grass Path Dust Green"),
}


def soften_seams(rgb, width):
    """Match opposite edges inside a narrow band; keep the interior unchanged."""
    result = rgb.copy()
    for axis in (1, 0):
        for offset in range(width):
            weight = 0.5 * (1.0 + np.cos(np.pi * offset / width))
            a, b = [slice(None)] * 3, [slice(None)] * 3
            a[axis], b[axis] = offset, -1 - offset
            a, b = tuple(a), tuple(b)
            first, last = result[a].copy(), result[b].copy()
            average = (first + last) * 0.5
            result[a] = first * (1 - weight) + average * weight
            result[b] = last * (1 - weight) + average * weight
    return result


def periodic_blur(values, radius):
    # Separable box filter with wrap-around so derivatives have no open boundary.
    result = values
    for axis in (0, 1):
        result = sum(np.roll(result, i, axis) for i in range(-radius, radius + 1)) / (2 * radius + 1)
    return result


def save_image(path, values):
    pixels = np.clip(np.rint(values * 255), 0, 255).astype(np.uint8)
    Image.fromarray(pixels).save(path)


def write_new(path, text):
    if not path.exists():
        path.write_text(text, encoding="utf-8")


def import_settings(path, normal=False):
    resource = "res://" + path.relative_to(ROOT / "project").as_posix()
    write_new(path.with_suffix(".png.import"), f'''[remap]
importer="texture"
type="CompressedTexture2D"

[deps]
source_file="{resource}"

[params]
compress/mode=2
compress/high_quality=true
compress/normal_map={1 if normal else 2}
compress/channel_pack=0
mipmaps/generate=true
roughness/mode=0
process/fix_alpha_border=false
process/premult_alpha=false
process/normal_map_invert_y=false
detect_3d/compress_to=0
''')


def materials(folder, key, title, roughness):
    base = "res://assets/textures/soft_surface/" + key
    write_new(folder / (key + "_surface.tres"), f'''[gd_resource type="StandardMaterial3D" load_steps=3 format=3]

[ext_resource type="Texture2D" path="{base}/albedo.png" id="1"]
[ext_resource type="Texture2D" path="{base}/normal.png" id="2"]

[resource]
resource_name = "{title}"
albedo_texture = ExtResource("1")
roughness = {roughness}
normal_enabled = true
normal_scale = 0.6
normal_texture = ExtResource("2")
texture_filter = 5
''')
    write_new(folder / (key + "_terrain3d.tres"), f'''[gd_resource type="Terrain3DTextureAsset" load_steps=3 format=3]

[ext_resource type="Texture2D" path="{base}/albedo_height.png" id="1"]
[ext_resource type="Texture2D" path="{base}/normal_roughness.png" id="2"]

[resource]
name = "{title}"
albedo_texture = ExtResource("1")
normal_texture = ExtResource("2")
normal_depth = 0.6
ao_strength = 0.0
uv_scale = 0.5
''')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--size", type=int, default=1024, help="Square output size; use 1024 to match existing Terrain3D assets")
    parser.add_argument("--normal-strength", type=float, default=3.0, help="Strength baked into derived normals")
    parser.add_argument("--detail-gain", type=float, default=1.8, help="Local luminance contrast used for microheight")
    parser.add_argument("--seam-width", type=int, default=24, help="Pixels blended at opposite edges; 0 disables")
    parser.add_argument("--roughness", type=float, default=0.9, help="Roughness packed in alpha, 0 smooth to 1 matte")
    parser.add_argument("--only", nargs="+", choices=SOURCES, help="Regenerate only these variants; preserve every other variant")
    args = parser.parse_args()
    if args.size < 32 or not 0 <= args.seam_width <= args.size // 4:
        parser.error("size must be >= 32 and seam-width between 0 and size/4")
    if not 0 <= args.roughness <= 1 or args.normal_strength < 0 or args.detail_gain < 0:
        parser.error("roughness must be 0..1, strengths must be nonnegative")
    selected = {key: value for key, value in SOURCES.items() if not args.only or key in args.only}
    preview = Image.new("RGB", (768, len(selected) * 290), "#24272c")
    draw = ImageDraw.Draw(preview)
    for row, (key, (filename, title)) in enumerate(selected.items()):
        folder = OUTPUT / key
        folder.mkdir(parents=True, exist_ok=True)
        source = ROOT / "graphics" / filename
        # Snapshot each selected original once; never overwrite a source snapshot.
        if not (folder / "source.png").exists():
            shutil.copy2(source, folder / "source.png")
        with Image.open(folder / "source.png") as image:
            rgb = np.asarray(image.convert("RGB").resize((args.size, args.size), Image.Resampling.LANCZOS), dtype=np.float64) / 255
        rgb = soften_seams(rgb, args.seam_width)
        luma = rgb @ np.array([0.2126, 0.7152, 0.0722])
        height = np.clip(0.5 + (luma - periodic_blur(luma, 2)) * args.detail_gain, 0, 1)
        dx = np.roll(height, -1, 1) - np.roll(height, 1, 1)
        dy = np.roll(height, -1, 0) - np.roll(height, 1, 0)
        normal = np.stack([-dx * args.normal_strength, dy * args.normal_strength, np.ones_like(height)], -1)
        normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
        normal = normal * 0.5 + 0.5  # OpenGL tangent space (+Y), matching project convention.
        save_image(folder / "albedo.png", rgb)
        save_image(folder / "height.png", height)
        save_image(folder / "normal.png", normal)
        save_image(folder / "albedo_height.png", np.dstack([rgb, height]))
        save_image(folder / "normal_roughness.png", np.dstack([normal, np.full_like(height, args.roughness)]))
        for name in ("albedo", "height", "normal", "albedo_height", "normal_roughness"):
            import_settings(folder / (name + ".png"), normal=name == "normal")
        materials(folder, key, title, args.roughness)
        draw.text((12, row * 290 + 8), title + " | Albedo / Normal / Tiling 2x2", fill="white")
        for col, name in enumerate(("albedo", "normal")):
            with Image.open(folder / (name + ".png")) as image:
                preview.paste(image.resize((256, 256)), (col * 256, row * 290 + 30))
        tile = Image.open(folder / "albedo.png").resize((128, 128))
        for y in range(2):
            for x in range(2):
                preview.paste(tile, (512 + x * 128, row * 290 + 30 + y * 128))
        print(f"Built {title}: {args.size}x{args.size}; normal XY std={normal[..., :2].std():.5f}")
    preview_name = "soft_surface_preview.png" if not args.only else "soft_surface_" + "_".join(selected) + "_preview.png"
    preview.save(OUTPUT / preview_name)


if __name__ == "__main__":
    main()
