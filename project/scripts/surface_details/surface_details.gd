@tool
extends Node3D
## Pincel de detalle independiente de las texturas de Terrain3D.
const PaintData = preload("res://scripts/surface_details/paint_data.gd")
const Meshes = preload("res://scripts/surface_details/detail_meshes.gd")
const ScatterRenderer = preload("res://scripts/surface_details/scatter_renderer.gd")
const LEAVES = preload("res://shaders/surface_details/leaves.gdshader")
const SURFACE = preload("res://shaders/surface_details/surface.gdshader")
const FOOTPRINT_SHADER = preload("res://shaders/snow_footprint.gdshader")
const EDITOR_ZONE_SHADER = preload("res://shaders/surface_details/editor_zone.gdshader")

@export_group("Terreno y pintura")
## Terrain3D que recibe el detalle. Vacío usa el padre. Cambiarlo requiere reabrir/reiniciar la escena; la cobertura usa coordenadas mundiales X/Z.
@export var terrain_path: NodePath = NodePath("..")
## Cobertura independiente de texturas. Guardar escena también guarda este recurso. Hacer único antes de compartir con otro mapa. No editar sus tiles a mano.
@export var paint_data: Resource = preload("res://resources/surface_details/grass_paint.res")
## Pintura independiente de nieve profunda. Su canal rojo conserva la cobertura; guardar la escena también guarda el recurso. En vivo.
@export var deep_snow_data: Resource = preload("res://resources/surface_details/deep_snow_paint.tres")
## Activa nieve, hojas y tierra sin borrar cobertura. El pasto original tiene su propio Enabled. En vivo.
@export var enabled := true
## Muestra hojas, tierra y zonas de nieve en el editor. Pasto usa su propio Editor Preview. Apagar ahorra GPU sin afectar al juego. En vivo.
@export var editor_preview := true
@export_group("Pincel de detalles")
## Capa que pinta la herramienta Pincel de superficies. Cambiarla no altera cobertura existente.
@export_enum("Nieve", "Hojas", "Tierra", "Pasto", "Nieve profunda") var paint_layer := 0
## Radio del pincel en metros. Mayor cubre más y aumenta trabajo por pincelada. Próxima pincelada.
@export_range(0.25, 32.0, 0.25, "suffix:m") var brush_radius := 3.0
## Intensidad por pasada de 0 a 1. Más alto llena/borra antes. Próxima pincelada.
@export_range(0.01, 1.0, 0.01) var brush_strength := 0.35
## Dureza del pincel. 0 borde amplio suave, 1 disco duro. Próxima pincelada.
@export_range(0.0, 1.0, 0.01) var brush_hardness := 0.3
@export_group("Perfiles editables")
## Comportamiento de nieve ligera sobre la textura Terrain3D que pintes. Huellas y contacto en vivo; no genera malla.
@export var snow: Resource = preload("res://resources/surface_details/snow.tres")
## Comportamiento de nieve profunda. Se pinta aparte y prevalece sobre nieve ligera. Editar en vivo; no genera malla.
@export var deep_snow: Resource = preload("res://resources/surface_details/deep_snow.tres")
## Hojas caídas curvas en tonos otoñales. Expandir para apariencia, textura, viento y toon. En vivo.
@export var leaves: Resource = preload("res://resources/surface_details/leaves.tres")
## Piedritas y terrones del camino. Expandir para apariencia, textura y toon. En vivo.
@export var dirt: Resource = preload("res://resources/surface_details/dirt.tres")
## Perfil anterior de pasto, conservado para cargar escenas existentes. La apariencia pintada usa GrassParticles original.
@export_storage var grass: Resource = preload("res://resources/surface_details/grass.tres")
@export_group("Vista de autoría")
## Color de la zona de nieve ligera en el editor. Alfa controla opacidad; nunca se muestra durante el juego. En vivo.
@export var snow_editor_color := Color(0.32, 0.72, 1.0, 0.42)
## Color de la zona de nieve profunda en el editor. Alfa controla opacidad; nunca se muestra durante el juego. En vivo.
@export var deep_snow_editor_color := Color(0.08, 0.24, 1.0, 0.55)
## Muestra los colores de zonas pintadas al editar. Apagar no borra pintura y reduce trabajo del editor. En vivo.
@export var show_snow_zones := true
@export_group("Pasto original")
## Nodo GrassParticles original cuyos controles abre Editar apariencia al seleccionar Pasto. Vacío desactiva ese acceso directo; en vivo.
@export var grass_particles_path: NodePath = NodePath("../GrassParticles")
@export_group("Alcance y rendimiento")
## Radio de hojas y tierra alrededor de la cámara, metros. El azul de nieve se muestra en todo el mapa y el pasto tiene su propio alcance. En vivo.
@export_range(8.0, 150.0, 1.0, "suffix:m") var draw_distance := 40.0
## Fracción exterior del radio donde se desvanecen hojas y tierra. Mayor suaviza la desaparición. En vivo.
@export_range(0.01, 0.8, 0.01) var distance_fade := 0.25
## Máximo de instancias dispersas cercanas de hojas y tierra. Pasto y nieve tienen sus propios presupuestos. Mayor cuesta CPU/GPU. En vivo.
@export_range(1000, 200000, 1000) var max_particles := 60000
## Permite sombras de hojas y tierra. El pasto tiene su propio control. En vivo; por defecto apagado.
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

## Cantidad de bloques de color de nieve mostrados en el editor. Sólo lectura; cero durante el juego.
@export var active_snow_tiles: int:
	get:
		return _editor_zones.size()
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
var _prints: Array[MeshInstance3D] = []
var _print_ages: Array[float] = []
var _next_print := 0
var _editor_zones: Dictionary = {}
var _zone_dirty := true
var _zone_style_signature := 0
var _editor_brush_focus := Vector3.ZERO
var _editor_brush_focus_active := false

func set_editor_brush_focus(point: Vector3, active: bool) -> void:
	_editor_brush_focus = point
	_editor_brush_focus_active = active

func profiles() -> Array:
	return [snow, leaves, dirt, grass, deep_snow]

func _ready() -> void:
	add_to_group("snow_surface_receivers")
	terrain = get_node_or_null(terrain_path) as Terrain3D
	if paint_data == null:
		paint_data = PaintData.new()
	if not paint_data.changed.is_connected(_invalidate):
		paint_data.changed.connect(_invalidate)
	if deep_snow_data == null:
		deep_snow_data = preload("res://scripts/surface_details/paint_data.gd").new()
	if not deep_snow_data.changed.is_connected(_invalidate):
		deep_snow_data.changed.connect(_invalidate)
	if terrain and terrain.data and not terrain.data.maps_edited.is_connected(_maps_edited):
		terrain.data.maps_edited.connect(_maps_edited)
	set_process(true)

func _maps_edited(_area: AABB) -> void:
	_invalidate()

func _invalidate() -> void:
	_dirty = true
	_zone_dirty = true

func _process(delta: float) -> void:
	if snow: snow.repair_missing_values()
	if deep_snow: deep_snow.repair_missing_values()
	if not Engine.is_editor_hint(): _advance_footprints(delta)
	if terrain == null or terrain.data == null:
		return
	if not enabled or (Engine.is_editor_hint() and not editor_preview):
		_clear_emitters()
		if Engine.is_editor_hint(): _clear_editor_zones()
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
			_dirty = true
		_sync_visible(preview_position)
		if Engine.is_editor_hint(): _sync_editor_zones()
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
		for layer in [1, 2]:
			var profile: Resource = profiles()[layer]
			if profile == null or not profile.enabled: continue
			var occupied := false
			for offset in range(layer, bytes.size(), 4):
				if bytes[offset] > 0:
					occupied = true
					break
			if occupied:
				needed[Vector3i(key.x,key.y,layer)] = true
	# Reserva por cuadrado visible máximo: no cambia al cruzar límites de tiles.
	var scatter_layers := 0
	for layer in [1, 2]:
		var profile: Resource = profiles()[layer]
		if profile and profile.enabled: scatter_layers += 1
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
	var material_key: Variant = key.z
	if not _materials.has(material_key):
		var material := ShaderMaterial.new()
		_materials[material_key] = material
	_materials[material_key].shader = LEAVES if profile.kind == 1 else SURFACE
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
	var global_toon := false
	if not Engine.is_editor_hint():
		var rig := get_tree().get_first_node_in_group("surface_detail_toon_source")
		if rig: global_toon = rig.toon_enabled
	for material_key in _materials:
		var layer: int = material_key
		var profile: Resource = profiles()[layer]
		if profile == null: continue
		var material: ShaderMaterial = _materials[material_key]
		for parameter in ["color_a","color_b","color_variation","realism","grain_strength","toon_softness","kind"]:
			material.set_shader_parameter(parameter,profile.get(parameter))
		material.set_shader_parameter("base_roughness",profile.roughness)
		material.set_shader_parameter("specular_amount",profile.specular)
		material.set_shader_parameter("toon_enabled",profile.shading == 2 or (profile.shading == 0 and global_toon))
		material.set_shader_parameter("wind_strength",profile.wind_strength if profile.wind_enabled else 0.0)
		material.set_shader_parameter("wind_speed",profile.wind_speed)
		material.set_shader_parameter("wind_direction",Vector2.from_angle(deg_to_rad(profile.wind_direction)))
		material.set_shader_parameter("camera_position",position)
		material.set_shader_parameter("draw_distance",draw_distance)
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

func _sync_editor_zones() -> void:
	if not show_snow_zones:
		_clear_editor_zones()
		return
	var signature := hash([snow_editor_color,deep_snow_editor_color])
	if signature != _zone_style_signature:
		_zone_style_signature = signature
		_zone_dirty = true
	var wanted := {}
	for data in [paint_data,deep_snow_data]:
		if data == null: continue
		for key: Vector2i in data.tiles:
			if wanted.has(key): continue
			var image: Image = data.get_tile(key)
			if image == null: continue
			var bytes := image.get_data()
			for offset in range(0,bytes.size(),4):
				if bytes[offset] >= 10:
					wanted[key] = true
					break
	for key in _editor_zones.keys():
		if not wanted.has(key) or _zone_dirty:
			if is_instance_valid(_editor_zones[key]): _editor_zones[key].queue_free()
			_editor_zones.erase(key)
	for key: Vector2i in wanted:
		if _editor_zones.has(key): continue
		var mesh := _build_zone_mesh(key)
		if mesh == null: continue
		var node := MeshInstance3D.new()
		node.name = "EditorSnowZone_%d_%d" % [key.x,key.y]
		node.mesh = mesh
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = EDITOR_ZONE_SHADER
		node.material_override = material
		add_child(node)
		_editor_zones[key] = node
	_zone_dirty = false

func _clear_editor_zones() -> void:
	for node in _editor_zones.values():
		if is_instance_valid(node): node.queue_free()
	_editor_zones.clear()

func _build_zone_mesh(key: Vector2i) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var origin: Vector2 = Vector2(key)*PaintData.TILE_SIZE
	for z in range(0,PaintData.SIDE,2):
		for x in range(0,PaintData.SIDE,2):
			var center := origin+(Vector2(x,z)+Vector2.ONE)*PaintData.PIXEL_SIZE
			var light: float = paint_data.coverage(center,0) if paint_data else 0.0
			var deep: float = deep_snow_data.coverage(center,0) if deep_snow_data else 0.0
			if maxf(light,deep) < 0.04: continue
			var center_height: float = terrain.data.get_height(Vector3(center.x,0,center.y))
			if not is_finite(center_height): continue
			var tint := deep_snow_editor_color if deep > 0.01 else snow_editor_color
			tint.a *= smoothstep(0.0,0.5,maxf(light,deep))
			var base := vertices.size()
			for corner in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				var xz: Vector2 = origin+Vector2(x,z)*PaintData.PIXEL_SIZE+corner*PaintData.PIXEL_SIZE*2.0
				var world := Vector3(xz.x,0,xz.y)
				var height: float = terrain.data.get_height(world)
				if not is_finite(height): height = center_height
				vertices.append(Vector3(xz.x,height+0.035,xz.y))
				colors.append(tint)
			indices.append_array(PackedInt32Array([base,base+1,base+2,base,base+2,base+3]))
	if vertices.is_empty(): return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

func snow_contact(point: Vector3) -> Dictionary:
	if not enabled or terrain == null or terrain.data == null: return {}
	if not terrain.data.has_regionp(point) or terrain.data.get_control_hole(point): return {}
	var height := terrain.data.get_height(point)
	if not is_finite(height): return {}
	var xz := Vector2(point.x,point.z)
	var deep_coverage: float = deep_snow_data.coverage(xz,0) if deep_snow_data else 0.0
	var light_coverage: float = paint_data.coverage(xz,0) if paint_data else 0.0
	var profile: Resource = deep_snow if deep_coverage > 0.01 and deep_snow and deep_snow.enabled else snow
	if profile == null or not profile.enabled or profile.kind != 0: return {}
	if absf(point.y-height) > profile.snow_contact_tolerance: return {}
	var normal := terrain.data.get_normal(point)
	if not normal.is_finite() or normal.y < cos(deg_to_rad(profile.maximum_slope)): return {}
	var coverage: float = deep_coverage if profile == deep_snow else light_coverage
	var cosine := cos(deg_to_rad(profile.maximum_slope))
	coverage *= smoothstep(cosine,minf(1.0,cosine+0.06),normal.y) if cosine < 0.9999 else float(normal.y >= 0.9999)
	if coverage <= 0.01: return {}
	var fullness := smoothstep(0.0,0.65,coverage)
	var depth: float = profile.snow_depth * fullness
	var sink: float = minf(profile.snow_sink_max,depth*profile.snow_sink_ratio*(1.0-profile.snow_compaction))
	return {"depth":depth,"sink":sink,"visual_height":-sink if profile.snow_sink_enabled else 0.0,
		"response":profile.snow_sink_response,"coverage":coverage,"profile":profile}

func record_snow_step(actor: CharacterBody3D, side: float) -> void:
	if not actor.is_on_floor(): return
	var main_contact := snow_contact(actor.global_position)
	if main_contact.is_empty(): return
	var direction := Vector2(actor.velocity.x,actor.velocity.z).normalized()
	if direction.length_squared() < 0.5: return
	var point := actor.global_position
	var profile: Resource = main_contact.profile
	if not profile.snow_footprints_enabled: return
	var right: Vector2 = Vector2(direction.y,-direction.x)*profile.snow_footprint_separation*side
	point += Vector3(right.x,0,right.y)
	point.y = terrain.data.get_height(point)
	var contact := snow_contact(point)
	if contact.is_empty() or contact.depth < profile.snow_footprint_min_depth: return
	_add_footprint(point, direction, profile)

func _add_footprint(point: Vector3, direction: Vector2, profile: Resource) -> void:
	var limit := maxi(1,profile.snow_footprint_tiles * 12)
	var mark: MeshInstance3D
	if _prints.size() < limit:
		mark = MeshInstance3D.new()
		var material := ShaderMaterial.new()
		material.shader = FOOTPRINT_SHADER
		mark.material_override = material
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mark)
		_prints.append(mark)
		_print_ages.append(0.0)
		_next_print = _prints.size() - 1
	else:
		mark = _prints[_next_print]
	var plane := PlaneMesh.new()
	plane.size = Vector2(profile.snow_footprint_width,profile.snow_footprint_length)
	mark.mesh = plane
	mark.material_override.set_shader_parameter("print_color",profile.snow_footprint_color)
	mark.material_override.set_shader_parameter("fade",1.0)
	var normal := terrain.data.get_normal(point)
	var forward := Vector3(direction.x,0,direction.y).slide(normal).normalized()
	var tangent := normal.cross(forward).normalized()
	mark.global_transform = Transform3D(Basis(tangent,normal,forward),point+normal*0.015)
	mark.visible = true
	mark.set_meta("lifetime",profile.snow_footprint_lifetime)
	_print_ages[_next_print] = 0.0
	_next_print = (_next_print + 1) % _prints.size()

func _advance_footprints(delta: float) -> void:
	for index in _prints.size():
		if not is_instance_valid(_prints[index]): continue
		_print_ages[index] += delta
		var lifetime: float = _prints[index].get_meta("lifetime",120.0)
		_prints[index].visible = _print_ages[index] < lifetime
		if _prints[index].visible:
			_prints[index].material_override.set_shader_parameter("fade",1.0-smoothstep(lifetime*0.6,lifetime,_print_ages[index]))

func begin_stroke(_erase: bool) -> void:
	_before_tiles.clear()
	_stroke_active = true
	_stroke_layer = paint_layer

func dab(center: Vector3, erase: bool) -> void:
	if not _stroke_active or terrain == null: return
	var target_data: Resource = deep_snow_data if _stroke_layer == 4 else paint_data
	var channel := 0 if _stroke_layer == 4 else _stroke_layer
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
			if erase and target_data.get_tile(key) == null: continue
			if not _before_tiles.has(key): _before_tiles[key] = target_data.snapshot(key)
			var image: Image = target_data.ensure_tile(key)
			var pixel := Vector2i(posmod(x,PaintData.SIDE),posmod(y,PaintData.SIDE))
			var color := image.get_pixelv(pixel)
			var weight := brush_strength*_falloff(distance)
			color[channel] = maxf(0.0,color[channel]-weight) if erase else lerpf(color[channel],1.0,weight)
			image.set_pixelv(pixel,color)
	target_data.emit_changed()

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
	var target_data: Resource = deep_snow_data if _stroke_layer == 4 else paint_data
	for key in _before_tiles: after_tiles[key] = target_data.snapshot(key)
	return {"before_tiles":_before_tiles.duplicate(),"after_tiles":after_tiles,"layer":_stroke_layer}

func apply_snapshot(tiles: Dictionary, controls: Dictionary = {}, layer: int = 0) -> void:
	var target_data: Resource = deep_snow_data if layer == 4 else paint_data
	target_data.restore(tiles)
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
	for data in [paint_data,deep_snow_data]:
		if data == null or data.resource_path.is_empty() or data.resource_path.contains("::"): continue
		var result := ResourceSaver.save(data,data.resource_path,ResourceSaver.FLAG_COMPRESS)
		if result != OK: return result
	return OK
