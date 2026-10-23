@tool
extends Node3D
## Pincel conjunto: cobertura propia + textura opcional de Terrain3D.
const PaintData = preload("res://scripts/surface_details/paint_data.gd")
const Meshes = preload("res://scripts/surface_details/detail_meshes.gd")
const PLACE = preload("res://shaders/surface_details/place.gdshader")
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
@export_group("Pincel conjunto")
## Capa que pinta la herramienta Pincel de superficies. Cambiarla no altera cobertura existente.
@export_enum("Nieve", "Hojas", "Tierra", "Pasto") var paint_layer := 0
## Pinta también la textura asociada al perfil, en la misma operación de deshacer. Activado por defecto. Borrar partículas nunca borra textura.
@export var paint_texture_underneath := true
## Radio del pincel en metros. Mayor cubre más y aumenta trabajo por pincelada. Próxima pincelada.
@export_range(0.25, 32.0, 0.25, "suffix:m") var brush_radius := 3.0
## Intensidad por pasada de 0 a 1. Más alto llena/borra antes. Próxima pincelada.
@export_range(0.01, 1.0, 0.01) var brush_strength := 0.35
## Dureza del pincel. 0 borde amplio suave, 1 disco duro. Próxima pincelada.
@export_range(0.0, 1.0, 0.01) var brush_hardness := 0.3
@export_group("Perfiles editables")
## Grumos de nieve, desde granulares suaves a facetados. Expandir para colores, tamaños, realismo, densidad, textura y toon. En vivo; geometría agrupada.
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
## Fracción exterior del radio donde los elementos se encogen. Mayor reduce la aparición brusca. En vivo.
@export_range(0.01, 0.8, 0.01) var distance_fade := 0.25
## Máximo total de partículas cercanas entre todas las capas. Mayor permite más densidad; coste GPU/CPU al preparar posiciones. En vivo.
@export_range(1000, 200000, 1000) var max_particles := 60000
## Permite sombras de los elementos. Costoso para nieve y hierba densas. En vivo; por defecto apagado.
@export var cast_shadows := false

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
var _before_controls: Dictionary = {}
var _stroke_active := false
var _stroke_layer := 0
var _stroke_texture := -1
var _stroke_paint_base := false
var _changed_regions: Dictionary = {}
var _quota := 1

func profiles() -> Array:
	return [snow, leaves, dirt, grass]

func _ready() -> void:
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
	if _clock > 0.18:
		_clock = 0.0
		var signature := hash([draw_distance,max_particles,cast_shadows])
		for profile in profiles():
			if profile: signature = hash([signature,profile.signature()])
		if signature != _last_signature:
			_last_signature = signature
			_meshes.clear()
			_dirty = true
		_sync_visible(camera.global_position)
	_update_materials(camera.global_position)
	if not _jobs.is_empty():
		var job: Vector3i = _jobs.pop_front()
		if _needed.has(job):
			_build_emitter(job)

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
			if occupied: needed[Vector3i(key.x,key.y,layer)] = true
	var quota := maxi(1, max_particles/maxi(1,needed.size()))
	if quota != _quota:
		_quota = quota
		_dirty = true
	for key in _emitters.keys():
		if not needed.has(key):
			_emitters[key].queue_free()
			_emitters.erase(key)
	_needed = needed
	for key: Vector3i in needed:
		if (_dirty or not _completed.has(key)) and not _jobs.has(key):
			_jobs.append(key)
	for key in _completed.keys():
		if not needed.has(key): _completed.erase(key)
	_dirty = false

func _build_emitter(key: Vector3i) -> void:
	var profile: Resource = profiles()[key.z]
	var side := maxi(1,int(sqrt(profile.density)*PaintData.TILE_SIZE))
	var budget_probability := minf(1.0,float(_quota)*0.9/float(side*side))
	var spacing := PaintData.TILE_SIZE/side
	var origin := Vector2(key.x,key.y)*PaintData.TILE_SIZE
	var positions: Array[Color] = []
	var orientations: Array[Color] = []
	var cosine := cos(deg_to_rad(profile.maximum_slope))
	for z in side:
		for x in side:
			var cell := Vector2i(key.x*side+x,key.y*side+z)
			var random := _random(cell,profile.random_seed)
			var random2 := _random(cell,profile.random_seed+713)
			var point := origin + (Vector2(x,z)+Vector2(0.1+random*0.8,0.1+random2*0.8))*spacing
			if positions.size() >= _quota: continue
			if _random(cell,profile.random_seed+139) > paint_data.coverage(point,key.z)*budget_probability: continue
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
	if _emitters.has(key):
		_emitters[key].queue_free()
		_emitters.erase(key)
	_completed[key] = true
	if positions.is_empty():
		return
	var width := mini(256,positions.size())
	var height := ceili(float(positions.size())/width)
	var data_position := Image.create(width,height,false,Image.FORMAT_RGBAF)
	var data_orientation := Image.create(width,height,false,Image.FORMAT_RGBAF)
	for index in positions.size():
		data_position.set_pixel(index%width,index/width,positions[index])
		data_orientation.set_pixel(index%width,index/width,orientations[index])
	var process := ShaderMaterial.new()
	process.shader = PLACE
	process.set_shader_parameter("positions",ImageTexture.create_from_image(data_position))
	process.set_shader_parameter("orientations",ImageTexture.create_from_image(data_orientation))
	process.set_shader_parameter("data_width",width)
	if not _meshes.has(key.z): _meshes[key.z] = Meshes.build(profile)
	if not _materials.has(key.z):
		var material := ShaderMaterial.new()
		material.shader = SURFACE
		_materials[key.z] = material
	var emitter := GPUParticles3D.new()
	emitter.set_meta("surface_detail_layer",key.z)
	emitter.name = "Detail_%d_%d_%d" % [key.x,key.y,key.z]
	emitter.amount = positions.size()
	emitter.lifetime = 600.0
	emitter.explosiveness = 1.0
	emitter.local_coords = true
	emitter.fixed_fps = 1
	emitter.process_material = process
	emitter.draw_pass_1 = _meshes[key.z]
	emitter.material_override = _materials[key.z]
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var range_y := terrain.data.get_height_range()
	emitter.visibility_aabb = AABB(Vector3(-2,range_y.x-3,-2),Vector3(20,range_y.y-range_y.x+6,20))
	add_child(emitter)
	emitter.global_position = Vector3(origin.x,0,origin.y)
	emitter.emitting = true
	emitter.preprocess = 0.1
	_emitters[key] = emitter

func _random(cell: Vector2i, seed_value: int) -> float:
	var value := hash(Vector3i(cell.x,cell.y,seed_value)) & 0x7fffffff
	return float(value%1000003)/1000003.0

func _update_materials(position: Vector3) -> void:
	var global_toon := false
	if not Engine.is_editor_hint():
		var rig := get_tree().get_first_node_in_group("surface_detail_toon_source")
		if rig: global_toon = rig.toon_enabled
	for layer in _materials:
		var profile: Resource = profiles()[layer]
		var material: ShaderMaterial = _materials[layer]
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
	_jobs.clear()
	_needed.clear()
	_completed.clear()
	_dirty = true

func begin_stroke(erase: bool) -> void:
	_before_tiles.clear()
	_before_controls.clear()
	_stroke_active = true
	_stroke_layer = paint_layer
	var profile: Resource = profiles()[paint_layer]
	_stroke_texture = profile.texture_id if profile else -1
	_stroke_paint_base = paint_texture_underneath and not erase and _stroke_texture >= 0

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
	if _stroke_paint_base:
		_paint_ground(center)
	paint_data.emit_changed()

func _falloff(distance: float) -> float:
	return 1.0 - smoothstep(minf(brush_hardness,0.999),1.0,distance)

func _paint_ground(center: Vector3) -> void:
	var spacing := terrain.vertex_spacing
	var radius := ceili(brush_radius/spacing)
	var center_cell := Vector2i(roundi(center.x/spacing),roundi(center.z/spacing))
	for z in range(-radius,radius+1):
		for x in range(-radius,radius+1):
			var cell := center_cell+Vector2i(x,z)
			var world := Vector3(cell.x*spacing,0,cell.y*spacing)
			var distance := Vector2(world.x-center.x,world.z-center.z).length()/brush_radius
			if distance >= 1 or not terrain.data.has_regionp(world): continue
			var old := terrain.data.get_control(world)
			if old & 4: continue
			if not _before_controls.has(cell): _before_controls[cell] = old
			var base := (old>>27)&31
			var over := (old>>22)&31
			var blend := float((old>>14)&255)/255.0
			var weight := brush_strength*_falloff(distance)
			if base == _stroke_texture:
				blend = lerpf(blend,0.0,weight)
			elif over == _stroke_texture:
				blend = lerpf(blend,1.0,weight)
			else:
				if blend > 0.5: base = over
				over = _stroke_texture
				blend = weight
			var bits := (old & ~((31<<27)|(31<<22)|(255<<14)|1)) | (base<<27) | (over<<22) | (roundi(blend*255.0)<<14)
			terrain.data.set_control(world,bits)
			var region := terrain.data.get_regionp(world)
			region.modified = true
			region.edited = true
			_changed_regions[region] = true
	_flush_controls()

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
	var after_controls := {}
	for cell: Vector2i in _before_controls:
		after_controls[cell] = terrain.data.get_control(Vector3(cell.x*terrain.vertex_spacing,0,cell.y*terrain.vertex_spacing))
	return {"before_tiles":_before_tiles.duplicate(),"after_tiles":after_tiles,
		"before_controls":_before_controls.duplicate(),"after_controls":after_controls}

func apply_snapshot(tiles: Dictionary, controls: Dictionary) -> void:
	paint_data.restore(tiles)
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
