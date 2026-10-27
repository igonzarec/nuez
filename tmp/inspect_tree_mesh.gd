extends SceneTree
func _initialize() -> void:
	var scene = load("res://scenes/grass_terrain.tscn").instantiate()
	var terrain = scene.get_node("Terrain3D")
	for asset in terrain.assets.get_mesh_list():
		var mesh = asset.get_mesh()
		print(asset.name, " ", mesh, " path=", mesh.resource_path)
		for i in mesh.get_surface_count(): print(i, " ", mesh.surface_get_material(i).resource_name)
	scene.free()
	quit()
