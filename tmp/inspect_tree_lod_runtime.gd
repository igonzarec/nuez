extends SceneTree
func _initialize() -> void:
	call_deferred("inspect")
func inspect() -> void:
	var scene = load("res://scenes/grass_terrain.tscn").instantiate()
	var terrain = scene.get_node("Terrain3D")
	scene.get_node("Terrain3D/GrassParticles").enabled = false
	scene.get_node("Terrain3D/SurfaceDetails").enabled = false
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(0, 20, 20)
	root.add_child(scene)
	for i in 6: await process_frame
	var effect = scene.get_node("Terrain3D/TreeColors")
	effect._sync()
	print("LOD actual regions=", terrain.data.get_region_locations().size(), " batches=", effect._batches.size())
	for asset in terrain.assets.get_mesh_list():
		var near_mesh = asset.get_mesh()
		var far_mesh = effect._far_meshes.get(asset.id)
		var near_tri := 0
		var far_tri := 0
		for s in near_mesh.get_surface_count(): near_tri += near_mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX].size()/3
		if far_mesh:
			for s in far_mesh.get_surface_count(): far_tri += far_mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX].size()/3
		print(asset.name," triangles ",near_tri," -> ",far_tri)
	effect.enabled = false
	effect._sync()
	print("disabled batches=",effect._batches.size()," material=",terrain.assets.get_mesh_asset(0).get_mesh().surface_get_material(0).resource_name)
	quit()
