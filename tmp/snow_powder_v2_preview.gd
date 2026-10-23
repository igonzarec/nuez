extends SceneTree
func _initialize() -> void:
	var source := Image.load_from_file("res://assets/textures/snow_powder_v2/snow_albedo.png")
	var preview := Image.create(1536, 1536, false, Image.FORMAT_RGBA8)
	source.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	for y in 3:
		for x in 3:
			preview.blit_rect(source, Rect2i(0, 0, 512, 512), Vector2i(x * 512, y * 512))
	preview.save_png("res://../tmp/snow_powder_v2_repeat.png")
	quit()
