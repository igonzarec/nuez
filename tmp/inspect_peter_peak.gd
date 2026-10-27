extends SceneTree
func _initialize() -> void:
	inspect.call_deferred()
func inspect() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.make_current()
	var terrain := Terrain3D.new()
	terrain.data_directory = "res://terrain_data/terrain_data_grass"
	terrain.set_camera(camera)
	root.add_child(terrain)
	await process_frame
	var data := terrain.data
	var size := terrain.region_size
	var spacing := terrain.vertex_spacing
	var candidates: Array[Vector3] = []
	for region: Vector2i in data.get_region_locations():
		for z in range(8, size - 8, 8):
			for x in range(8, size - 8, 8):
				var p := Vector3((region.x * size + x) * spacing, 0, (region.y * size + z) * spacing)
				p.y = data.get_height(p)
				if not is_finite(p.y) or p.y < 15.0: continue
				var safe := true
				for offset in [Vector3(3,0,0), Vector3(-3,0,0),Vector3(0,0,3),Vector3(0,0,-3)]:
					var q: Vector3 = p + offset
					var h: float = data.get_height(q)
					var n: Vector3 = data.get_normal(q)
					if not is_finite(h) or absf(h-p.y) > 0.7 or n.y < 0.85: safe = false
				if safe: candidates.append(p)
	candidates.sort_custom(func(a: Vector3,b: Vector3): return a.y > b.y)
	print("PETER_PEAKS ", candidates.slice(0,12))
	var visual: Node = load("res://assets/playertest2/playertest2.glb").instantiate()
	for mesh in visual.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var mat = mesh.get_active_material(i)
			print("PETER_MATERIAL ",mesh.name," ",mat.resource_name," ",mat.albedo_color)
	visual.free()
	terrain.queue_free()
	camera.queue_free()
	await process_frame
	quit()
