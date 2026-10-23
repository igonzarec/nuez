extends SceneTree
func _initialize() -> void:
	var asset = load("res://assets/textures/snow_powder/snow_powder_terrain3d.tres")
	if asset == null:
		quit(1)
		return
	print("Loaded ", asset.get_class(), " / ", asset.name)
	for texture in [asset.albedo_texture, asset.normal_texture]:
		if texture == null or texture.get_width() != 1024 or texture.get_height() != 1024:
			quit(2)
			return
		print(texture.resource_path, " ", texture.get_size())
	quit()
