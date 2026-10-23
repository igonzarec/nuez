extends SceneTree

# Conversión técnica; conserva la imagen generada original.
# La altura estimada por luminancia es un microdetalle, no relieve medido.
const FOLDER := "res://assets/textures/snow_powder_v2/"
const SIZE := 1024

func _initialize() -> void:
	var albedo := Image.load_from_file(FOLDER + "snow_source.png")
	if albedo == null:
		quit(1)
		return
	albedo.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	albedo.convert(Image.FORMAT_RGBA8)
	var height := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var normal := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var packed_color := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var packed_normal := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var c := albedo.get_pixel(x, y)
			var luminance := c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
			var h := clampf(0.5 + (luminance - 0.85) * 2.0, 0.1, 0.9)
			height.set_pixel(x, y, Color(h, h, h, 1.0))
			packed_color.set_pixel(x, y, Color(c.r, c.g, c.b, h))
	for y in SIZE:
		for x in SIZE:
			var dx := height.get_pixel((x + 1) % SIZE, y).r - height.get_pixel(posmod(x - 1, SIZE), y).r
			var dy := height.get_pixel(x, (y + 1) % SIZE).r - height.get_pixel(x, posmod(y - 1, SIZE)).r
			var n := Vector3(-dx * 2.0, dy * 2.0, 1.0).normalized()
			var c := Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5, 1.0)
			normal.set_pixel(x, y, c)
			c.a = 0.9
			packed_normal.set_pixel(x, y, c)
	var outputs := {"snow_albedo.png": albedo, "snow_height.png": height,
		"snow_normal.png": normal, "snow_albedo_height.png": packed_color,
		"snow_normal_roughness.png": packed_normal}
	for filename: String in outputs:
		var img: Image = outputs[filename]
		if img.save_png(FOLDER + filename) != OK:
			quit(2)
			return
		print("Saved ", filename, " ", img.get_size(), " RGBA8")
	var edge_max := 0.0
	for i in SIZE:
		for pair in [[albedo.get_pixel(0, i), albedo.get_pixel(SIZE - 1, i)],
				[albedo.get_pixel(i, 0), albedo.get_pixel(i, SIZE - 1)]]:
			var a: Color = pair[0]
			var b: Color = pair[1]
			edge_max = maxf(edge_max, maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))))
	print("Maximum opposite-edge RGB difference: ", edge_max)
	quit()

