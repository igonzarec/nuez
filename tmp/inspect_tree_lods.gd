extends SceneTree
func _initialize() -> void:
	for c in ["ArrayMesh","Terrain3DData","Terrain3DRegion"]:
		for m in ClassDB.class_get_method_list(c, true):
			if "lod" in m.name or "region" in m.name or "instances" in m.name: print(c," ",m.name," ",m.args)
	var source = load("res://scenes/grass_terrain.tscn").instantiate()
	for asset in source.get_node("Terrain3D").assets.get_mesh_list():
		var mesh = asset.get_mesh()
		for i in mesh.get_surface_count():
			print(asset.name," s=",i," vertices=",mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX].size()," indices=",mesh.surface_get_arrays(i)[Mesh.ARRAY_INDEX].size()," lods=",RenderingServer.mesh_get_surface(mesh.get_rid(),i).get("lods",[]))
	source.free()
	quit()
