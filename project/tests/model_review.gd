extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var optimized := "--optimized" in OS.get_cmdline_user_args()
	var scene: Node3D
	if optimized:
		scene = load("res://assets/squirrel/squirrel_visual.scn").instantiate()
	else:
		var error := document.append_from_file("C:/Users/USER/Downloads/model.glb", state)
		assert(error == OK)
		scene = document.generate_scene(state)
	root.add_child(scene)
	var mesh := scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	print("MODEL: ", mesh.get_aabb(), " transform=", mesh.global_transform)
	var bounds := mesh.global_transform * mesh.get_aabb()
	var center := bounds.get_center()
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("596e7a")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.7
	root.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	root.add_child(light)
	var camera := Camera3D.new()
	root.add_child(camera)
	root.size = Vector2i(900, 900)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = bounds.size.y * 1.3
	DirAccess.make_dir_recursive_absolute("res://tests/captures")
	for i in 4:
		camera.position = center + Vector3(sin(i * PI / 2), 0.15, cos(i * PI / 2)) * bounds.size.y * 3
		camera.look_at(center)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/captures/%s_%d.png" % ["repaired" if optimized else "model", i])
	scene.queue_free()
	await process_frame
	quit()
