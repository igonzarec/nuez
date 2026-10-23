extends SceneTree
func _initialize() -> void:
	var dir := DirAccess.open("res://terrain_data/terrain_data_grass")
	for filename in dir.get_files():
		if not filename.ends_with(".res"):
			continue
		var region = load("res://terrain_data/terrain_data_grass/" + filename)
		var control: Image = region.get_control_map()
		var data := control.get_data()
		var auto_count := 0
		var mixed_count := 0
		var total := 0
		var counts := {}
		for y in range(0, control.get_height(), 8):
			for x in range(0, control.get_width(), 8):
				var bits := data.decode_u32((y * control.get_width() + x) * 4)
				var base := (bits >> 27) & 31
				var over := (bits >> 22) & 31
				var blend := (bits >> 14) & 255
				auto_count += int((bits & 1) != 0)
				mixed_count += int(base != over and blend > 0 and blend < 255)
				var key := "%d/%d" % [base, over]
				counts[key] = counts.get(key, 0) + 1
				total += 1
		print(filename, " spacing=", region.vertex_spacing, " auto=", auto_count, "/", total, " intermediate_mix=", mixed_count, " ids=", counts)
	quit()
