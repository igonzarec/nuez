extends SceneTree
func _initialize() -> void:
	for m in ClassDB.class_get_method_list("Terrain3DMeshAsset", true):
		if "range" in m.name or "fade" in m.name: print(m)
	quit()
