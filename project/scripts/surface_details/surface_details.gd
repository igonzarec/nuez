@tool
extends Node3D
## Pincel de detalle independiente de las texturas de Terrain3D.
const PaintData = preload("res://scripts/surface_details/paint_data.gd")
const Meshes = preload("res://scripts/surface_details/detail_meshes.gd")
const SnowSurface = preload("res://scripts/surface_details/snow_surface.gd")
const Footprints = preload("res://scripts/surface_details/snow_footprints.gd")
const ScatterRenderer = preload("res://scripts/surface_details/scatter_renderer.gd")
const SNOW = preload("res://shaders/surface_details/snow.gdshader")
const LEAVES = preload("res://shaders/surface_details/leaves.gdshader")
const SURFACE = preload("res://shaders/surface_details/surface.gdshader")

@export_group("Terreno y pintura")
## Terrain3D que recibe el detalle. Vacío usa el padre. Cambiarlo requiere reabrir/reiniciar la escena; la cobertura usa coordenadas mundiales X/Z.
@export var terrain_path: NodePath = NodePath("..")
## Cobertura independiente de texturas. Guardar escena también guarda este recurso. Hacer único antes de compartir con otro mapa. No editar sus tiles a mano.
@export var paint_data: Resource = preload("res://resources/surface_details/grass_paint.res")
## Activa todo el detalle sin borrar cobertura. En vivo.
@export var enabled := true
## Muestra el resultado en el editor. Apagar ahorra GPU mientras esculpes; no afecta al juego. En vivo.
@export var editor_preview := true
@export_group("Pincel de detalles")
## Capa que pinta la herramienta Pincel de superficies. Cambiarla no altera cobertura existente.
@export_enum("Nieve", "Hojas", "Tierra", "Pasto") var paint_layer := 0
## Radio del pincel en metros. Mayor cubre más y aumenta trabajo por pincelada. Próxima pincelada.
@export_range(0.25, 32.0, 0.25, "suffix:m") var brush_radius := 3.0
## Intensidad por pasada de 0 a 1. Más alto llena/borra antes. Próxima pincelada.
@export_range(0.01, 1.0, 0.01) var brush_strength := 0.35
## Dureza del pincel. 0 borde amplio suave, 1 disco duro. Próxima pincelada.
@export_range(0.0, 1.0, 0.01) var brush_hardness := 0.3
@export_group("Perfiles editables")
## Capa continua de nieve. Expandir Nieve: superficie para espesor, ondulaciones, micrograno y dispersión de luz. Reconstrucción agrupada; no cambia colisión.
@export var snow: Resource = preload("res://resources/surface_details/snow.tres")
## Hojas caídas curvas en tonos otoñales. Expandir para apariencia, textura, viento y toon. En vivo.
@export var leaves: Resource = preload("res://resources/surface_details/leaves.tres")
## Piedritas y terrones del camino. Expandir para apariencia, textura y toon. En vivo.
@export var dirt: Resource = preload("res://resources/surface_details/dirt.tres")
## Pasto pintable independiente del sistema antiguo. Expandir para altura, ancho, textura, viento y toon. En vivo.
@export var grass: Resource = preload("res://resources/surface_details/grass.tres")
@export_group("Alcance y rendimiento")
## Radio de detalle alrededor de cámara en metros. Mayor añade tiles y GPU. Fuera se conserva la textura del suelo. En vivo.
@export_range(8.0, 150.0, 1.0, "suffix:m") var draw_distance := 40.0
## Fracción exterior del radio donde se desvanece nieve/hojas y se encogen tierra/pasto. Mayor suaviza la desaparición. En vivo.
@export_range(0.01, 0.8, 0.01) var distance_fade := 0.25
## Máximo de instancias dispersas cercanas (hojas, tierra y pasto). La nieve usa su propia malla. Reparto conservador estable al mover cámara; mayor cuesta CPU/GPU. En vivo.
@export_range(1000, 200000, 1000) var max_particles := 60000
## Permite sombras de los elementos. Costoso para nieve y hierba densas. En vivo; por defecto apagado.
@export var cast_shadows := false
## Contador de instancias dispersas cercanas; no cuenta vértices de la nieve. Nombre conservado por compatibilidad. Sólo lectura.
@export var active_particles: int:
	get:
		var total := 0
		for emitter in _emitters.values():
			if is_instance_valid(emitter): total += int(emitter.get_meta("detail_count",0))
		return total
	set(_value):
		pass

## Cantidad de bloques de nieve cargados cerca de la cámara. Cada bloque mide 16 m de lado; el coste depende de Snow Mesh Spacing y cobertura. Sólo lectura, en vivo.
@export var active_snow_tiles: int:
	get:
		var total := 0
		for instance in _emitters.values():
			if is_instance_valid(instance) and instance is MeshInstance3D: total += 1
		return total
	set(_value):
		pass

func _validate_property(property: Dictionary) -> void:
	if property.name in ["active_particles", "active_snow_tiles"]:
		property.usage = (property.usage | PROPERTY_USAGE_READ_ONLY) & ~PROPERTY_USAGE_STORAGE

var terrain: Terrain3D
var _emitters: Dictionary = {}
var _materials: Dictionary = {}
var _meshes: Dictionary = {}
var _jobs: Array[Vector3i] = []
var _needed: Dictionary = {}
var _completed: Dictionary = {}
var _last_signature := 0
var _clock := 0.0
var _dirty := true
var _before_tiles: Dictionary = {}
var _stroke_active := false
var _stroke_layer := 0
var _changed_regions: Dictionary = {}
var _quota := 1
var _footprints = Footprints.new()
var _snow_noise: FastNoiseLite
var _editor_brush_focus := Vector3.ZERO
var _editor_brush_focus_active := false

func set_editor_brush_focus(point: Vector3, active: bool) -> void:
	_editor_brush_focus = point
	_editor_brush_focus_active = active

func profiles() -> Array:
	return [snow, leaves, dirt, grass]

func _ready() -> void:
	add_to_group("snow_surface_receivers")
	if not is_instance_valid(_footprints):
		_footprints = Footprints.new()
	terrain = get_node_or_null(terrain_path) as Terrain3D
	if paint_data == null:
		paint_data = PaintData.new()
	if not paint_data.changed.is_connected(_invalidate):
		paint_data.changed.connect(_invalidate)
	if terrain and terrain.data and not terrain.data.maps_edited.is_connected(_maps_edited):
		terrain.data.maps_edited.connect(_maps_edited)
	set_process(true)

func _maps_edited(_area: AABB) -> void:
	_invalidate()

func _invalidate() -> void:
	_dirty = true

func _process(delta: float) -> void:
	if snow:
		snow.repair_missing_values()
	# Las huellas sólo avanzan durante el juego. En el editor, una recarga del
	# script @tool puede dejar este objeto sin inicializar durante varios frames.
	if not Engine.is_editor_hint() and snow:
		if not is_instance_valid(_footprints):
			_footprints = Footprints.new()
		_footprints.advance(delta,snow.snow_footprint_lifetime,snow.snow_footprint_tiles)
	if terrain == null or terrain.data == null:
		return
	if not enabled or (Engine.is_editor_hint() and not editor_preview):
		_clear_emitters()
		return
	var camera := terrain.get_camera()
	if camera == null:
		camera = get_viewport().get_camera_3d()
	if camera == null:
		return
	_clock += delta
	var preview_position := _editor_brush_focus if Engine.is_editor_hint() and _editor_brush_focus_active else camera.global_position
	if _clock > 0.18:
		_clock = 0.0
		var signature := hash([draw_distance,max_particles,cast_shadows])
		for profile in profiles():
			if profile: signature = hash([signature,profile.geometry_signature()])
		if signature != _last_signature:
			_last_signature = signature
			_meshes.clear()
			if snow: _snow_noise = SnowSurface.create_noise(snow)
			_dirty = true
		_sync_visible(preview_position)
	_update_materials(preview_position)
	if not _jobs.is_empty():
		var job: Vector3i = _jobs.pop_front()
		if _needed.has(job):
			_build_emitter(job)
			_update_materials(preview_position)

func _sync_visible(position: Vector3) -> void:
	var needed: Dictionary = {}
	for key: Vector2i in paint_data.tiles:
		var center := (Vector2(key)+Vector2(0.5,0.5))*PaintData.TILE_SIZE
		if center.distance_to(Vector2(position.x,position.z)) > draw_distance + PaintData.TILE_SIZE*0.71:
			continue
		var bytes: PackedByteArray = paint_data.tiles[key].get_data()
		for layer in 4:
			var profile: Resource = profiles()[layer]
			if profile == null or not profile.enabled: continue
			var occupied := false
			for offset in range(layer, bytes.size(), 4):
				if bytes[offset] > 0:
					occupied = true
					break
			if occupied:
				needed[Vector3i(key.x,key.y,layer)] = true
				# La interpolación de máscara continúa medio texel en tiles vecinos.
				if profile.kind == 0:
					for dz in range(-1,2):
						for dx in range(-1,2):
							var neighbor := key+Vector2i(dx,dz)
							var neighbor_center := (Vector2(neighbor)+Vector2(0.5,0.5))*PaintData.TILE_SIZE
							if neighbor_center.distance_to(Vector2(position.x,position.z)) <= draw_distance+PaintData.TILE_SIZE*0.71:
								needed[Vector3i(neighbor.x,neighbor.y,layer)] = true
	# Reserva por cuadrado visible máximo: no cambia al cruzar límites de tiles.
	var scatter_layers := 0
	for profile in profiles():
		if profile and profile.enabled and profile.kind != 0: scatter_layers += 1
	var tile_span := ceili(2.0 * (draw_distance + PaintData.TILE_SIZE * 0.71) / PaintData.TILE_SIZE) + 1
	var quota := maxi(1, max_particles / maxi(1,tile_span * tile_span * scatter_layers))
	if quota != _quota:
		_quota = quota
		_dirty = true
	for key in _emitters.keys():
		if not needed.has(key):
			_emitters[key].queue_free()
			_emitters.erase(key)
			_materials.erase(key)
	_needed = needed
	for key: Vector3i in needed:
		if (_dirty or not _completed.has(key)) and not _jobs.has(key):
			_jobs.append(key)
	for key in _completed.keys():
		if not needed.has(key): _completed.erase(key)
	_dirty = false

func _build_emitter(key: Vector3i) -> void:
	var profile: Resource = profiles()[key.z]
	var origin := Vector2(key.x,key.y)*PaintData.TILE_SIZE
	if profile.kind == 0:
		var mesh := SnowSurface.build(terrain,paint_data,Vector2i(key.x,key.y),profile,key.z)
		var surface: MeshInstance3D
		if mesh:
			surface = MeshInstance3D.new()
			surface.mesh = mesh
		_replace_render_node(key,surface,origin,0)
		return
	var side := maxi(1,int(sqrt(profile.density)*PaintData.TILE_SIZE))
	var spacing := PaintData.TILE_SIZE/side
	var positions: Array[Color] = []
	var orientations: Array[Color] = []
	var priorities: Array[float] = []
	var cosine := cos(deg_to_rad(profile.maximum_slope))
	for z in side:
		for x in side:
			var cell := Vector2i(key.x*side+x,key.y*side+z)
			var random := _random(cell,profile.random_seed)
			var random2 := _random(cell,profile.random_seed+713)
			var point := origin + (Vector2(x,z)+Vector2(0.1+random*0.8,0.1+random2*0.8))*spacing
			if _random(cell,profile.random_seed+139) > paint_data.coverage(point,key.z): continue
			var world := Vector3(point.x,0,point.y)
			if not terrain.data.has_regionp(world) or terrain.data.get_control_hole(world): continue
			var height := terrain.data.get_height(world)
			if not is_finite(height): continue
			var normal := terrain.data.get_normal(world)
			if not normal.is_finite() or normal.y < cosine: continue
			if not profile.align_to_ground: normal = Vector3.UP
			var size := lerpf(minf(profile.size_min,profile.size_max),maxf(profile.size_min,profile.size_max),random2)
			positions.append(Color(point.x-origin.x,height+profile.ground_offset,point.y-origin.y,size))
			orientations.append(Color(normal.x,normal.y,normal.z,random))
			priorities.append(_random(cell,profile.random_seed+983))
	if positions.size() > _quota:
		var order := range(positions.size())
		order.sort_custom(func(a: int,b: int) -> bool: return priorities[a] < priorities[b])
		var selected_positions: Array[Color] = []
		var selected_orientations: Array[Color] = []
		for index in _quota:
			selected_positions.append(positions[order[index]])
			selected_orientations.append(orientations[order[index]])
		positions = selected_positions
		orientations = selected_orientations
	if positions.is_empty():
		_replace_render_node(key,null,origin,0)
		return
	if not _meshes.has(key.z): _meshes[key.z] = Meshes.build(profile)
	var instance := ScatterRenderer.build(_meshes[key.z],positions,orientations,profile,terrain,origin)
	_replace_render_node(key,instance,origin,positions.size())

func _replace_render_node(key: Vector3i, instance: GeometryInstance3D, origin: Vector2, count: int) -> void:
	if _emitters.has(key):
		# Ocultar antes de queue_free: nunca dibujar dos copias en el mismo frame.
		_emitters[key].visible = false
		_emitters[key].queue_free()
		_emitters.erase(key)
	_materials.erase(key)
	_completed[key] = true
	if instance == null: return
	var profile: Resource = profiles()[key.z]
	var material_key: Variant = key if profile.kind == 0 else key.z
	if not _materials.has(material_key):
		var material := ShaderMaterial.new()
		_materials[material_key] = material
	_materials[material_key].shader = SNOW if profile.kind == 0 else (LEAVES if profile.kind == 1 else SURFACE)
	instance.set_meta("surface_detail_layer",key.z)
	instance.set_meta("detail_count",count)
	instance.name = "Detail_%d_%d_%d" % [key.x,key.y,key.z]
	instance.material_override = _materials[material_key]
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	instance.global_position = Vector3(origin.x,0,origin.y)
	_emitters[key] = instance

func _random(cell: Vector2i, seed_value: int) -> float:
	var value := hash(Vector3i(cell.x,cell.y,seed_value)) & 0x7fffffff
	return float(value%1000003)/1000003.0

func _update_materials(position: Vector3) -> void:
	if not is_instance_valid(_footprints):
		_footprints = Footprints.new()
	var global_toon := false
	if not Engine.is_editor_hint():
		var rig := get_tree().get_first_node_in_group("surface_detail_toon_source")
		if rig: global_toon = rig.toon_enabled
	# Tras recargar el script @tool pueden quedar materiales de nieve con clave de capa (int); se reconstruyen.
	if snow and snow.kind == 0 and _materials.has(0):
		_clear_emitters()
		return
	for material_key in _materials:
		var layer: int = material_key.z if material_key is Vector3i else material_key
		var profile: Resource = profiles()[layer]
		if profile == null: continue
		var material: ShaderMaterial = _materials[material_key]
		for parameter in ["color_a","color_b","color_variation","realism","grain_strength","toon_softness","kind"]:
			material.set_shader_parameter(parameter,profile.get(parameter))
		material.set_shader_parameter("base_roughness",profile.roughness)
		material.set_shader_parameter("specular_amount",profile.specular)
		if profile.kind == 0:
			for parameter in ["snow_grain_size","snow_scatter","snow_sparkle","snow_albedo_gain","snow_stylized","snow_surface_scale","snow_surface_strength","snow_surface_contrast"]:
				material.set_shader_parameter(parameter,profile.get(parameter))
			var tile := Vector2i(material_key.x,material_key.y)
			material.set_shader_parameter("footprint_mask",_footprints.texture_for(tile) if profile.snow_footprints_enabled else _footprints.empty)
			material.set_shader_parameter("tile_origin",Vector2(tile)*PaintData.TILE_SIZE)
			material.set_shader_parameter("footprint_clock",_footprints.clock)
			material.set_shader_parameter("footprint_lifetime",profile.snow_footprint_lifetime)
		material.set_shader_parameter("toon_enabled",profile.shading == 2 or (profile.shading == 0 and global_toon))
		material.set_shader_parameter("wind_strength",profile.wind_strength if profile.wind_enabled else 0.0)
		material.set_shader_parameter("wind_speed",profile.wind_speed)
		material.set_shader_parameter("wind_direction",Vector2.from_angle(deg_to_rad(profile.wind_direction)))
		material.set_shader_parameter("camera_position",position)
		# Evitar que la capa de nieve alcance el geomorph de los LOD lejanos.
		var surface_distance := draw_distance
		if profile.kind == 0:
			surface_distance = minf(draw_distance,terrain.vertex_spacing*(terrain.mesh_size+4.0+0.55*(terrain.mesh_size-2.0))*0.8)
		material.set_shader_parameter("draw_distance",surface_distance)
		material.set_shader_parameter("fade_fraction",distance_fade)

func _clear_emitters() -> void:
	for emitter in _emitters.values():
		if is_instance_valid(emitter): emitter.queue_free()
	_emitters.clear()
	_materials.clear()
	_jobs.clear()
	_needed.clear()
	_completed.clear()
	_dirty = true

func snow_contact(point: Vector3) -> Dictionary:
	if not enabled or snow == null or not snow.enabled or snow.kind != 0 or terrain == null or terrain.data == null: return {}
	if not terrain.data.has_regionp(point) or terrain.data.get_control_hole(point): return {}
	var height := terrain.data.get_height(point)
	if not is_finite(height) or absf(point.y-height) > snow.snow_contact_tolerance: return {}
	var normal := terrain.data.get_normal(point)
	if not normal.is_finite() or normal.y < cos(deg_to_rad(snow.maximum_slope)): return {}
	var xz := Vector2(point.x,point.z)
	var coverage: float = paint_data.coverage(xz,0)
	var cosine := cos(deg_to_rad(snow.maximum_slope))
	coverage *= smoothstep(cosine,minf(1.0,cosine+0.06),normal.y) if cosine < 0.9999 else float(normal.y >= 0.9999)
	if coverage <= 0.01: return {}
	if _snow_noise == null: _snow_noise = SnowSurface.create_noise(snow)
	var fullness := smoothstep(0.0,0.65,coverage)
	var depth := SnowSurface.depth_at(xz,snow,_snow_noise)*fullness
	var sink := minf(snow.snow_sink_max,depth*snow.snow_sink_ratio*(1.0-snow.snow_compaction))
	var visual_sink := sink if snow.snow_sink_enabled else 0.0
	return {"depth":depth,"sink":sink,"visual_height":maxf(0.0,snow.ground_offset*fullness+depth-visual_sink),"response":snow.snow_sink_response}

func record_snow_step(actor: CharacterBody3D, side: float) -> void:
	if not actor.is_on_floor() or snow == null or not snow.snow_footprints_enabled: return
	if _footprints == null: _footprints = Footprints.new()
	if snow_contact(actor.global_position).is_empty(): return
	var direction := Vector2(actor.velocity.x,actor.velocity.z).normalized()
	if direction.length_squared() < 0.5: return
	var point := actor.global_position
	var right: Vector2 = Vector2(direction.y,-direction.x)*snow.snow_footprint_separation*side
	point += Vector3(right.x,0,right.y)
	point.y = terrain.data.get_height(point)
	var contact := snow_contact(point)
	if contact.is_empty() or contact.depth < snow.snow_footprint_min_depth: return
	_footprints.stamp(Vector2(point.x,point.z),direction,minf(snow.snow_footprint_depth,contact.sink),snow)

func begin_stroke(_erase: bool) -> void:
	_before_tiles.clear()
	_stroke_active = true
	_stroke_layer = paint_layer

func dab(center: Vector3, erase: bool) -> void:
	if not _stroke_active or terrain == null: return
	var min_cell := Vector2i(((Vector2(center.x,center.z)-Vector2.ONE*brush_radius)/PaintData.PIXEL_SIZE).floor())
	var max_cell := Vector2i(((Vector2(center.x,center.z)+Vector2.ONE*brush_radius)/PaintData.PIXEL_SIZE).ceil())
	for y in range(min_cell.y,max_cell.y+1):
		for x in range(min_cell.x,max_cell.x+1):
			var point := (Vector2(x,y)+Vector2(0.5,0.5))*PaintData.PIXEL_SIZE
			var distance := point.distance_to(Vector2(center.x,center.z))/brush_radius
			if distance >= 1.0: continue
			var world := Vector3(point.x,center.y,point.y)
			if not terrain.data.has_regionp(world) or terrain.data.get_control_hole(world): continue
			var key := Vector2i(floori(float(x)/PaintData.SIDE),floori(float(y)/PaintData.SIDE))
			if not _before_tiles.has(key): _before_tiles[key] = paint_data.snapshot(key)
			var image: Image = paint_data.ensure_tile(key)
			var pixel := Vector2i(posmod(x,PaintData.SIDE),posmod(y,PaintData.SIDE))
			var color := image.get_pixelv(pixel)
			var weight := brush_strength*_falloff(distance)
			color[_stroke_layer] = lerpf(color[_stroke_layer],0.0 if erase else 1.0,weight)
			image.set_pixelv(pixel,color)
	paint_data.emit_changed()

func _falloff(distance: float) -> float:
	return 1.0 - smoothstep(minf(brush_hardness,0.999),1.0,distance)

func _flush_controls() -> void:
	if _changed_regions.is_empty(): return
	terrain.data.update_maps(Terrain3DRegion.TYPE_CONTROL,false)
	for region in _changed_regions:
		region.edited = false
	_changed_regions.clear()

func end_stroke() -> Dictionary:
	_stroke_active = false
	var after_tiles := {}
	for key in _before_tiles: after_tiles[key] = paint_data.snapshot(key)
	return {"before_tiles":_before_tiles.duplicate(),"after_tiles":after_tiles}

func apply_snapshot(tiles: Dictionary, controls: Dictionary = {}) -> void:
	paint_data.restore(tiles)
	# Compatibilidad con acciones de deshacer creadas antes de separar el pincel.
	for cell: Vector2i in controls:
		var point := Vector3(cell.x*terrain.vertex_spacing,0,cell.y*terrain.vertex_spacing)
		if not terrain.data.has_regionp(point): continue
		terrain.data.set_control(point,controls[cell])
		var region := terrain.data.get_regionp(point)
		region.modified = true
		region.edited = true
		_changed_regions[region] = true
	_flush_controls()

func save_paint() -> Error:
	if paint_data == null: return ERR_INVALID_DATA
	# Una copia hecha única puede ser subrecurso: la guarda la propia escena.
	if paint_data.resource_path.is_empty() or paint_data.resource_path.contains("::"): return OK
	# Un archivo binario comprimido evita crecer como texto.
	return ResourceSaver.save(paint_data,paint_data.resource_path,ResourceSaver.FLAG_COMPRESS)
