extends SceneTree
func _initialize() -> void:
	for c in ["Terrain3DMeshAsset", "Terrain3DAssets"]:
		for m in ClassDB.class_get_method_list(c, true):
			if "mesh" in m.name or "material" in m.name: print(c, " ", m)
	quit()
