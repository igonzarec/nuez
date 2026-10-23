extends SceneTree
func _initialize() -> void:
	preview.call_deferred()
func preview() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var source = load("res://scenes/grass_terrain.tscn").instantiate()
	var terrain := Terrain3D.new()
	terrain.region_size = 64
	terrain.assets = source.get_node("Terrain3D").assets
	terrain.material = Terrain3DMaterial.new()
	terrain.material.world_background = 0
	scene.add_child(terrain)
	terrain.data.add_region_blank(Vector2i.ZERO)
	for z in 64:
		for x in 64:
			terrain.data.set_height(Vector3(x,0,z),0.0)
	terrain.data.update_maps(Terrain3DRegion.TYPE_HEIGHT)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.4,0.6,0.75)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.75,0.82,0.9)
	environment.environment.ambient_light_energy = 0.35
	scene.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42,-35,0)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	scene.add_child(sun)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(18,10,31)
	camera.look_at(Vector3(16,0,12))
	camera.make_current()
	terrain.set_camera(camera)
	var details = load("res://scripts/surface_details/surface_details.gd").new()
	details.paint_data = load("res://scripts/surface_details/paint_data.gd").new()
	for field in ["snow","leaves","dirt","grass"]:
		details.set(field,details.get(field).duplicate())
	terrain.add_child(details)
	var centers := [Vector3(15,0,12),Vector3(27,0,15),Vector3(27,0,5),Vector3(5,0,5)]
	for layer in 4:
		details.paint_layer = layer
		details.brush_radius = 8.0 if layer == 0 else 3.5
		details.brush_strength = 1.0
		details.brush_hardness = 0.6
		details.begin_stroke(false)
		details.dab(centers[layer],false)
		details.end_stroke()
	for i in 120: await process_frame
	var player = load("res://scenes/player.tscn").instantiate()
	scene.add_child(player)
	player.global_position = Vector3(15,3,18)
	await create_timer(1.5).timeout
	Input.action_press("move_forward")
	await create_timer(2.0).timeout
	Input.action_release("move_forward")
	await create_timer(0.3).timeout
	print("Player ground=",player.is_on_floor()," position=",player.global_position," snow lift=",player.model.snow_visual_height," footprint tiles=",details._footprints.tiles.size())
	await shot("surface_revision_overview")
	print("Before camera move: ",details._emitters[Vector3i(1,0,1)].get_instance_id())
	for i in 90:
		camera.position.x = 18.0 + sin(float(i)/89.0*PI)*18.0
		camera.look_at(Vector3(16,0,12))
		await process_frame
	print("After camera move: ",details._emitters[Vector3i(1,0,1)].get_instance_id())
	camera.position = Vector3(15,2.4,18)
	camera.look_at(Vector3(15,0,12))
	for i in 30: await process_frame
	await shot("surface_revision_snow")
	details.snow.shading = 2
	for i in 30: await process_frame
	await shot("surface_revision_snow_toon")
	details.snow.shading = 1
	camera.position = Vector3(27,1.3,18)
	camera.look_at(Vector3(27,0,15))
	for i in 30: await process_frame
	await shot("surface_revision_leaves")
	details.paint_layer = 0
	details.paint_texture_underneath = false
	details.brush_radius = 3.0
	details.begin_stroke(false)
	details.dab(Vector3(38,0,12),false)
	details.end_stroke()
	camera.position = Vector3(38,2.5,18)
	camera.look_at(Vector3(38,0,12))
	for i in 60: await process_frame
	await shot("surface_revision_snow_without_base")
	print("Render nodes: ",details._emitters.size()," scatter instances: ",details.active_particles)
	for key in details._emitters:
		print(key," ",details._emitters[key].get_class())
	source.free()
	quit()
func shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../tmp/"+file+".png")
