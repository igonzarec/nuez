extends SceneTree
func _initialize() -> void:
	var source = load("res://scenes/grass_terrain.tscn").instantiate()
	for asset in source.get_node("Terrain3D").assets.get_mesh_list():
		var mesh: ArrayMesh = asset.get_mesh()
		for i in mesh.get_surface_count():
			var lods: Array = RenderingServer.mesh_get_surface(mesh.get_rid(),i).get("lods",[])
			var counts: Array = []
			for lod in lods: counts.append(lod.index_data.size()/2/3)
			print(asset.name," surface=",i," base triangles=",mesh.surface_get_arrays(i)[Mesh.ARRAY_INDEX].size()/3," lod triangles=",counts)
	for c in ["Terrain3DData","Terrain3DInstancer","Terrain3DAssets"]: print(c," signals=",ClassDB.class_get_signal_list(c,true))
	source.free()
	quit()
