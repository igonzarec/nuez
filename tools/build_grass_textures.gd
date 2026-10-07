extends SceneTree

# Technical map conversion: retains the generated source and derives approximate
# micro-height from luminance, not a physically measured height field.
const FOLDER := "res://assets/textures/grass_carpet/"
const SIZE := 1024

func _initialize() -> void:
	var source := Image.load_from_file(FOLDER + "grass_source.png")
	if source == null:
		quit(1)
		return
	source.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	source.convert(Image.FORMAT_RGBA8)
	var height := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var normal := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var albedo_height := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var normal_roughness := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var neutral_height := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var c := source.get_pixel(x, y)
			var h := c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
			height.set_pixel(x, y, Color(h, h, h, 1.0))
			albedo_height.set_pixel(x, y, Color(c.r, c.g, c.b, h))
			var neutral := clampf(0.85 + (h - 0.5) * 0.5, 0.0, 1.0)
			neutral_height.set_pixel(x, y, Color(neutral, neutral, neutral, h))
	for y in SIZE:
		for x in SIZE:
			var dx := height.get_pixel((x + 1) % SIZE, y).r - height.get_pixel(posmod(x - 1, SIZE), y).r
			var dy := height.get_pixel(x, (y + 1) % SIZE).r - height.get_pixel(x, posmod(y - 1, SIZE)).r
			var n := Vector3(-dx * 2.0, dy * 2.0, 1.0).normalized()
			var c := Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5, 1.0)
			normal.set_pixel(x, y, c)
			c.a = 0.9
			normal_roughness.set_pixel(x, y, c)
	var outputs := {"grass_albedo.png": source, "grass_height.png": height,
		"grass_normal.png": normal, "grass_albedo_height.png": albedo_height,
		"grass_normal_roughness.png": normal_roughness, "grass_neutral_albedo_height.png": neutral_height}
	for filename: String in outputs:
		var img: Image = outputs[filename]
		if img.save_png(FOLDER + filename) != OK:
			quit(2)
			return
		print("Saved ", filename)
	quit()
