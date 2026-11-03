extends SceneTree
## Genera las texturas de hielo para Terrain3D (albedo+altura, normal+rugosidad),
## repetibles y a 1024 px como el resto de slots del terreno. Hielo pulido:
## sólo manchas de profundidad suaves, sin grietas ni rayas.
## Uso: godot --headless --path project --script res://tools/generate_ice_textures.gd

const SIZE := 1024
const OUT_DIR := "res://assets/textures/ice/"
const SHALLOW := Color(0.60, 0.80, 0.92)
const DEEP := Color(0.33, 0.57, 0.79)
const ROUGHNESS := 0.3

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	# Dos capas de nubes a escalas distintas evitan que la repetición se note.
	var broad := _noise(0.0022, 11).get_seamless_image(SIZE, SIZE)
	var detail := _noise(0.006, 29).get_seamless_image(SIZE, SIZE)
	var albedo := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var cloud := broad.get_pixel(x, y).r * 0.7 + detail.get_pixel(x, y).r * 0.3
			var color := SHALLOW.lerp(DEEP, smoothstep(0.25, 0.8, cloud) * 0.7)
			albedo.set_pixel(x, y, Color(color.r, color.g, color.b, 0.12))
	# Superficie lisa: normal plana y rugosidad uniforme.
	var normal := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	normal.fill(Color(0.5, 0.5, 1.0, ROUGHNESS))
	albedo.save_png(OUT_DIR + "ice_albedo_height.png")
	normal.save_png(OUT_DIR + "ice_normal_roughness.png")
	print("Ice textures written to ", OUT_DIR)
	quit()

func _noise(frequency: float, noise_seed: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_octaves = 3
	noise.frequency = frequency
	noise.seed = noise_seed
	return noise
