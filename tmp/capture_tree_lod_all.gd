extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var source = load("res://scenes/grass_terrain.tscn").instantiate()
	var terrain = source.get_node("Terrain3D")
	var effect = source.get_node("Terrain3D/TreeColors")
	effect._terrain = terrain
	effect.fade_start = 60.0
	effect.fade_end = 90.0
	effect._sync()
	var view := SubViewport.new()
	view.size = Vector2i(1100,800)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.own_world_3d = true
	root.add_child(view)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16,0.2,0.24)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.65
	environment.environment = env
	view.add_child(environment)
	var bounds := AABB()
	for i in 5:
		for mesh in [terrain.assets.get_mesh_asset(i).get_mesh(),effect._far_meshes[i]]:
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.mesh = mesh
			multi.instance_count = 1
			multi.set_instance_transform(0,Transform3D(Basis.IDENTITY,Vector3((i-2)*1.5,0,0)))
			var instance := MultiMeshInstance3D.new()
			instance.multimesh = multi
			view.add_child(instance)
			var box: AABB = mesh.get_aabb()
			box.position.x += (i-2)*1.5
			bounds = bounds.merge(box)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-30,0)
	sun.light_energy = 1.2
	view.add_child(sun)
	var camera := Camera3D.new()
	view.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8.2
	var target := bounds.get_center()
	var direction := Vector3(2,1.2,5).normalized()
	for state in [["near",45.0],["middle",75.0],["far",110.0],["beyond_old_cutoff",200.0]]:
		camera.position = target + direction * state[1]
		camera.look_at(target,Vector3.UP)
		for material in effect._shader_materials:
			material.set_shader_parameter("camera_valid",true)
			material.set_shader_parameter("fade_camera",camera.global_position)
		for i in 8: await process_frame
		await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png("res://../tmp/tree_lod_all_%s.png" % state[0])
	print("Captured near/middle/far/200m with complementary LOD materials")
	source.free()
	quit()
