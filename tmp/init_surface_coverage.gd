extends SceneTree
func _initialize() -> void:
	var data = load("res://scripts/surface_details/paint_data.gd").new()
	var result = ResourceSaver.save(data,"res://resources/surface_details/grass_paint.res",ResourceSaver.FLAG_COMPRESS)
	print("Created empty coverage: ", error_string(result))
	quit(int(result))
