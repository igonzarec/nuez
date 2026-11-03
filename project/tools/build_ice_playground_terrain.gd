extends SceneTree
## Genera los datos Terrain3D de scenes/ice_terrain.tscn: pradera con una pista
## de hielo pintada (slot 1) y una rampa helada suave. Sobrescribe la carpeta
## terrain_data/ice_playground; no toca otros terrenos.
## Uso: godot --headless --path project --script res://tools/build_ice_playground_terrain.gd

const DATA_DIR := "res://terrain_data/ice_playground"
const SPACING := 0.5
const GRASS_ID := 0
const ICE_ID := 1
const RINK_CENTER := Vector2(64.0, 64.0)
const RINK_RADII := Vector2(22.0, 16.0)
## Rampa helada al oeste de la pista: sube hacia -X.
const RAMP_MIN := Vector2(18.0, 54.0)
const RAMP_MAX := Vector2(42.0, 74.0)
const RAMP_HEIGHT := 2.5
const EDGE := 1.2

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DATA_DIR))
	for file in DirAccess.get_files_at(DATA_DIR):
		if file.begins_with("terrain3d"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(DATA_DIR + "/" + file))
	var terrain := Terrain3D.new()
	terrain.vertex_spacing = SPACING
	root.add_child(terrain)
	terrain.data_directory = DATA_DIR
	await process_frame
	# Importar imágenes es mucho más rápido que set_height/set_control por vértice.
	var size := 256
	var heights := Image.create_empty(size, size, false, Image.FORMAT_RF)
	var control := Image.create_empty(size, size, false, Image.FORMAT_RF)
	var bits := PackedByteArray()
	bits.resize(4)
	for zi in size:
		for xi in size:
			var xz := Vector2(xi * SPACING, zi * SPACING)
			heights.set_pixel(xi, zi, Color(_height(xz), 0.0, 0.0))
			var blend := int(round(_ice_amount(xz) * 255.0))
			# Formato de control Terrain3D: base <<27, overlay <<22, mezcla <<14.
			bits.encode_u32(0, (GRASS_ID << 27) | (ICE_ID << 22) | (blend << 14))
			control.set_pixel(xi, zi, Color(bits.decode_float(0), 0.0, 0.0))
	terrain.data.import_images([heights, control, null], Vector3.ZERO, 0.0, 1.0)
	terrain.data.save_directory(DATA_DIR)
	print("Ice playground terrain saved to ", DATA_DIR)
	quit()

func _ramp_weight(xz: Vector2) -> float:
	var inside_z := smoothstep(RAMP_MIN.y - 2.0, RAMP_MIN.y, xz.y) * (1.0 - smoothstep(RAMP_MAX.y, RAMP_MAX.y + 2.0, xz.y))
	return inside_z * clampf((RAMP_MAX.x - xz.x) / (RAMP_MAX.x - RAMP_MIN.x), 0.0, 1.0)

func _height(xz: Vector2) -> float:
	# Lomas suaves en el borde del mapa para cerrar la vista.
	var rim := smoothstep(48.0, 62.0, xz.distance_to(RINK_CENTER)) * 3.0
	var ramp := smoothstep(0.0, 1.0, _ramp_weight(xz)) * RAMP_HEIGHT
	return maxf(rim, ramp)

func _ice_amount(xz: Vector2) -> float:
	var d := ((xz - RINK_CENTER) / RINK_RADII).length()
	var rink := 1.0 - smoothstep(1.0 - EDGE / RINK_RADII.y, 1.0, d)
	var lane := 0.0
	if xz.x >= RAMP_MIN.x - 1.0 and xz.x <= RAMP_MAX.x + 4.0:
		lane = smoothstep(RAMP_MIN.y - EDGE, RAMP_MIN.y, xz.y) * (1.0 - smoothstep(RAMP_MAX.y, RAMP_MAX.y + EDGE, xz.y))
	return maxf(rink, lane)
