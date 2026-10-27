extends SceneTree

# Authoring conversion for the three user-selected albedo images. Never run at runtime.
const ROOT := "res://assets/textures/clay_terrain/"
const SIZE := 1024
const MATERIALS := {
	"grass_clean": {"roughness": 0.9},
	"cliff_winter": {"roughness": 0.88},
	"cliff_sculpted": {"roughness": 0.88},
	"dirt_sandy": {"roughness": 0.9},
}

func _initialize() -> void:
	var selected := OS.get_cmdline_user_args()
	for name: String in MATERIALS:
		if not selected.is_empty() and not selected.has(name):
			continue
		if not _build(name, MATERIALS[name].roughness):
			quit(1)
			return
	quit()

func _build(name: String, roughness: float) -> bool:
	var folder := ROOT + name + "/"
	var albedo := Image.load_from_file(folder + "source.png")
	if albedo == null:
		push_error("Missing source: " + folder)
		return false
	albedo.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	albedo.convert(Image.FORMAT_RGBA8)
	var height := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var normal := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var packed_color := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var packed_normal := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var color := albedo.get_pixel(x, y)
			var center := _luma(color)
			var nearby := 0.0
			for oy in range(-2, 3):
				for ox in range(-2, 3):
					nearby += _luma(albedo.get_pixel(posmod(x + ox, SIZE), posmod(y + oy, SIZE)))
			var detail := center - nearby / 25.0
			var h := clampf(0.5 + detail * 1.8, 0.0, 1.0)
			height.set_pixel(x, y, Color(h, h, h, 1.0))
			packed_color.set_pixel(x, y, Color(color.r, color.g, color.b, h))
	for y in SIZE:
		for x in SIZE:
			var dx := height.get_pixel((x + 1) % SIZE, y).r - height.get_pixel(posmod(x - 1, SIZE), y).r
			var dy := height.get_pixel(x, (y + 1) % SIZE).r - height.get_pixel(x, posmod(y - 1, SIZE)).r
			var direction := Vector3(-dx * 3.0, dy * 3.0, 1.0).normalized()
			var pixel := Color(direction.x * 0.5 + 0.5, direction.y * 0.5 + 0.5, direction.z * 0.5 + 0.5, 1.0)
			normal.set_pixel(x, y, pixel)
			pixel.a = roughness
			packed_normal.set_pixel(x, y, pixel)
	var outputs := {
		"albedo.png": albedo,
		"height.png": height,
		"normal.png": normal,
		"albedo_height.png": packed_color,
		"normal_roughness.png": packed_normal,
	}
	for filename: String in outputs:
		if outputs[filename].save_png(folder + filename) != OK:
			push_error("Could not save " + folder + filename)
			return false
	print("Built ", name, " (", SIZE, "x", SIZE, ")")
	return true

func _luma(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
