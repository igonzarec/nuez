extends SceneTree

# Conversion de formato y empaquetado de datos para Terrain3D.
# Ejecutar con --headless --path project --script ../tools/pack_playground_snow.gd.
func _initialize() -> void:
	var folder := "res://assets/textures/snow_playground/"
	var color := Image.load_from_file(folder + "snow_albedo.png")
	if color == null:
		quit(1)
		return
	color.resize(1024, 1024, Image.INTERPOLATE_LANCZOS)
	color.convert(Image.FORMAT_RGBA8)
	var normal := Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
	normal.fill(Color(0.5, 0.5, 1.0, 1.0))
	var roughness := Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
	roughness.fill(Color(0, 0, 0, 1))
	var height := Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
	height.fill(Color(0.5, 0.5, 0.5, 1))
	var outputs := {
		"snow_normal.png": normal,
		"snow_roughness.png": roughness,
		"snow_height.png": height,
		"snow_albedo_height.png": Terrain3DUtil.pack_image(color, height, false, false, false, 0),
		"snow_normal_roughness.png": Terrain3DUtil.pack_image(normal, roughness, false, false, false, 0),
	}
	for filename: String in outputs:
		var img: Image = outputs[filename]
		if img.save_png(folder + filename) != OK:
			quit(2)
			return
		print(filename, " ", img.get_size(), " RGBA8")
	# Comprobacion puntual de continuidad del color en los bordes.
	var edge_max := 0.0
	for i in 1024:
		var a := color.get_pixel(0, i)
		var b := color.get_pixel(1023, i)
		var c := color.get_pixel(i, 0)
		var d := color.get_pixel(i, 1023)
		edge_max = maxf(edge_max, maxf(absf(a.r-b.r), maxf(absf(a.g-b.g), absf(a.b-b.b))))
		edge_max = maxf(edge_max, maxf(absf(c.r-d.r), maxf(absf(c.g-d.g), absf(c.b-d.b))))
	print("Maximum opposite-edge RGB difference: ", edge_max)
	quit()
