extends SceneTree
## Diagnóstico de sólo lectura: muestrea pendientes, no modifica el terreno.
func _initialize() -> void:
	inspect.call_deferred()

func inspect() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.make_current()
	var scene := load("res://scenes/grass_terrain.tscn").instantiate() as Node3D
	var terrain := scene.get_node("Terrain3D") as Node3D
	terrain.call("set_camera", camera)
	root.add_child(scene)
	await process_frame
	var data: Object = terrain.get("data")
	var spacing: float = terrain.get("vertex_spacing")
	var size: int = terrain.get("region_size")
	var steep := 0
	var rough := 0
	var total := 0
	var maximum := 0.0
	var worst := Vector3.ZERO
	for region: Vector2i in data.call("get_region_locations"):
		for z in range(2, size - 2, 8):
			for x in range(2, size - 2, 8):
				var point := Vector3((region.x * size + x) * spacing, 0, (region.y * size + z) * spacing)
				var h: float = data.call("get_height", point)
				var hx: float = data.call("get_height", point + Vector3.RIGHT * spacing)
				var hz: float = data.call("get_height", point + Vector3.BACK * spacing)
				var hxx: float = data.call("get_height", point + Vector3.RIGHT * spacing * 2)
				var hzz: float = data.call("get_height", point + Vector3.BACK * spacing * 2)
				if not is_finite(h + hx + hz + hxx + hzz):
					continue
				var slope := rad_to_deg(atan(Vector2(hx - h, hz - h).length() / spacing))
				var change := maxf(absf(rad_to_deg(atan((hxx - hx) / spacing)) - rad_to_deg(atan((hx - h) / spacing))), absf(rad_to_deg(atan((hzz - hz) / spacing)) - rad_to_deg(atan((hz - h) / spacing))))
				total += 1
				if slope > 48.0:
					steep += 1
					if change > 15.0:
						rough += 1
					if change > maximum:
						maximum = change
						worst = Vector3(point.x, h, point.z)
	print("CLIMB TERRAIN spacing=", spacing, " region_size=", size, " samples=", total, " over48=", steep, " steep_changes_over15=", rough, " max_axis_change=", maximum, " near=", worst)
	scene.queue_free()
	camera.queue_free()
	await process_frame
	quit()
