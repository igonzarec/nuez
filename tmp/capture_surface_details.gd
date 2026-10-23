extends SceneTree
func _initialize() -> void:
	capture.call_deferred()
func capture() -> void:
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
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.4,0.6,0.75)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.75,0.82,0.9)
	environment.environment.ambient_light_energy = 0.25
	scene.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50,-35,0)
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	scene.add_child(sun)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(8,10,21)
	camera.look_at(Vector3(8,0,8))
	camera.make_current()
	terrain.set_camera(camera)
	var details = load("res://scripts/surface_details/surface_details.gd").new()
	details.paint_data = load("res://scripts/surface_details/paint_data.gd").new()
	terrain.add_child(details)
	var centers := [Vector3(4,0,4),Vector3(12,0,4),Vector3(4,0,12),Vector3(12,0,12)]
	for layer in 4:
		details.paint_layer = layer
		details.brush_radius = 3.1
		details.brush_strength = 1.0
		details.brush_hardness = 0.6
		details.begin_stroke(false)
		details.dab(centers[layer],false)
		var stroke: Dictionary = details.end_stroke()
		print("Layer ",layer," coverage tiles=",stroke.after_tiles.size()," ground vertices=",stroke.after_controls.size())
		var point: Vector3 = centers[layer]
		var painted: int = terrain.data.get_control(point)
		details.apply_snapshot(stroke.before_tiles,stroke.before_controls)
		print("Undo layer ",layer," coverage=",details.paint_data.coverage(Vector2(point.x,point.z),layer)," control_changed=",terrain.data.get_control(point)!=painted)
		details.apply_snapshot(stroke.after_tiles,stroke.after_controls)
		print("Redo layer ",layer," coverage=",details.paint_data.coverage(Vector2(point.x,point.z),layer)," control_restored=",terrain.data.get_control(point)==painted)
	for i in 40: await process_frame
	await create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../tmp/surface_details_overview.png")
	print("Emitters ",details._emitters.size())
	ResourceSaver.save(details.paint_data,"res://../tmp/surface_coverage_roundtrip.res",ResourceSaver.FLAG_COMPRESS)
	var reloaded = ResourceLoader.load("res://../tmp/surface_coverage_roundtrip.res","",ResourceLoader.CACHE_MODE_IGNORE)
	print("Reloaded coverage tiles=",reloaded.tiles.size()," snow=",reloaded.coverage(Vector2(4,4),0))
	for key in details._emitters:
		print("Layer ",key.z," particles ",details._emitters[key].amount)
	camera.position = Vector3(4,1.4,6.6)
	camera.look_at(Vector3(4,0,4))
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../tmp/surface_snow_close.png")
	for profile in details.profiles(): profile.shading = 2
	details.snow.realism = 0.0
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../tmp/surface_snow_toon.png")
	details.paint_layer = 0
	details.paint_texture_underneath = false
	var before_ground: int = terrain.data.get_control(Vector3(22,0,8))
	details.begin_stroke(false)
	details.dab(Vector3(22,0,8),false)
	var only: Dictionary = details.end_stroke()
	print("PARTICLES ONLY base_unchanged=",terrain.data.get_control(Vector3(22,0,8))==before_ground," ground_edits=",only.after_controls.size())
	var painted_ground: int = terrain.data.get_control(Vector3(4,0,4))
	details.begin_stroke(true)
	details.dab(Vector3(4,0,4),true)
	var erased: Dictionary = details.end_stroke()
	print("ERASER keeps_base=",terrain.data.get_control(Vector3(4,0,4))==painted_ground," coverage=",details.paint_data.coverage(Vector2(4,4),0))
	details.apply_snapshot(erased.before_tiles,erased.before_controls)
	source.free()
	quit()



