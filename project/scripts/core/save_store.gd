class_name TrailSave
extends RefCounted

const SAVE_PATH := "user://expedition_v3.json"
const SETTINGS_PATH := "user://settings.json"
const DEFAULT_SETTINGS := {"master": 0.8, "music": 0.45, "sfx": 0.75, "climb_sfx": 0.5, "sensitivity": 1.0, "fullscreen": false, "pixel_size": 2.0, "fast_reset_enabled": true}
var save_path := SAVE_PATH
var settings_path := SETTINGS_PATH

func fresh() -> Dictionary:
	return {"version": 3, "collected": [], "lamps": [], "elapsed": 0.0, "completed": false, "checkpoint": [0.0, 0.0, 22.0]}

func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var value: Variant = JSON.parse_string(file.get_as_text())
	return value if value is Dictionary else {}

func load_progress() -> Dictionary:
	var data := read_json(save_path)
	if data.get("version", 0) != 3 or not data.get("collected") is Array or not data.get("lamps") is Array:
		return {}
	var clean := fresh()
	for id: Variant in data.collected:
		if id is String and id.begins_with("seed_") and id.trim_prefix("seed_").is_valid_int() and int(id.trim_prefix("seed_")) in range(15) and not clean.collected.has(id):
			clean.collected.append(id)
	for id: Variant in data.lamps:
		if id in ["clearing", "pines", "summit"] and not clean.lamps.has(id) and clean.collected.size() >= (clean.lamps.size() + 1) * 3:
			clean.lamps.append(id)
	clean.completed = bool(data.get("completed", false)) and clean.lamps.size() == 3
	clean.elapsed = clampf(float(data.get("elapsed", 0)), 0, 359999)
	var point: Variant = data.get("checkpoint", [])
	if point is Array and point.size() == 3 and (point[0] is float or point[0] is int) and (point[2] is float or point[2] is int):
		if is_finite(float(point[0])) and is_finite(float(point[2])) and absf(float(point[0])) < 30 and absf(float(point[2])) < 32:
			clean.checkpoint = [float(point[0]), 0.0, float(point[2])]
	return clean

func write_json(path: String, data: Dictionary) -> bool:
	# Write a complete temporary file before replacing the previous valid save.
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return DirAccess.rename_absolute(path + ".tmp", path) == OK

func load_settings() -> Dictionary:
	var result := DEFAULT_SETTINGS.duplicate()
	var loaded := read_json(settings_path)
	for key: String in ["master", "music", "sfx", "climb_sfx", "sensitivity"]:
		if loaded.get(key) is float or loaded.get(key) is int:
			result[key] = clampf(float(loaded[key]), 0.2 if key == "sensitivity" else 0.0, 2.5 if key == "sensitivity" else 1.0)
	result.fullscreen = loaded.get("fullscreen", false) == true
	result.pixel_size = clampf(float(loaded.get("pixel_size", 2.0)), 1, 4)
	result.fast_reset_enabled = loaded.get("fast_reset_enabled", true) == true
	result.glide_forward_enabled = loaded.get("glide_forward_enabled", false) == true
	return result
