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
	var bounds := AABB()
	for i in 3:
		var instance := MeshInstance3D.new()
		instance.mesh = terrain.assets.get_mesh_asset(i).get_mesh()
		instance.position.x = (i - 1) * 1.3
		view.add_child(instance)
		var box := instance.mesh.get_aabb()
		box.position += instance.position
		bounds = bounds.merge(box)
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
	for i in 35: await process_frame
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://../tmp/tree_colors_on.png")
	for asset in terrain.assets.get_mesh_list():
		var mesh = asset.get_mesh()
		print(asset.name, " colors: ", mesh.surface_get_material(0).resource_name, "/", mesh.surface_get_material(1).resource_name, " albedo=", mesh.surface_get_material(0).albedo_texture, "/", mesh.surface_get_material(1).albedo_texture, " triplanar=", mesh.surface_get_material(0).uv1_triplanar, "/", mesh.surface_get_material(1).uv1_triplanar)
	effect.enabled = false
	effect._sync()
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://../tmp/tree_colors_off.png")
	print("Restored: ", terrain.assets.get_mesh_asset(0).get_mesh().surface_get_material(0).resource_name)
	source.free()
	quit()
