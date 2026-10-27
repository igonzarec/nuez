extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var source = load("res://scenes/grass_terrain.tscn").instantiate()
	var terrain = source.get_node("Terrain3D")
	var effect = source.get_node("Terrain3D/TreeColors")
	effect._terrain = terrain
	effect._sync()
	var view := SubViewport.new()
	view.size = Vector2i(1100, 800)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.own_world_3d = true
	root.add_child(view)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.2, 0.24)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.65
	environment.environment = env
	view.add_child(environment)
	var bounds := AABB(Vector3(-3,0,-5),Vector3(6,4,10))
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = terrain.assets.get_mesh_asset(0).get_mesh()
	multi.instance_count = 3
	for i in 3:
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3((i-1)*2.0, 0, -[45.0,75.0,105.0][i])))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	view.add_child(instance)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_energy = 1.2
	view.add_child(sun)
	var camera := Camera3D.new()
	view.add_child(camera)
	camera.position = bounds.get_center() + Vector3(2, 1.2, 5)
	camera.look_at(bounds.get_center(), Vector3.UP)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.2
	camera.position = Vector3(0,2,0)
	camera.look_at(Vector3(0,2,-1), Vector3.UP)
	camera.size = 7.0
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://../tmp/tree_fade_multimesh.png")
	for asset in terrain.assets.get_mesh_list():
		var mesh = asset.get_mesh()
		var material = mesh.surface_get_material(0)
		print(asset.name, " fade mode=", material.distance_fade_mode, " start=", material.distance_fade_max_distance, " end=", material.distance_fade_min_distance, " original cutoff=", asset.get_lod_range(asset.last_lod))
	effect.fade_enabled = false
	effect._sync()
	print("Fade off: ", terrain.assets.get_mesh_asset(0).get_mesh().surface_get_material(0).distance_fade_mode)
	effect.enabled = false
	effect._sync()
	print("Restored: ", terrain.assets.get_mesh_asset(0).get_mesh().surface_get_material(0).resource_name)
	source.free()
	quit()