@tool
class_name CliffFoldsGenerator
extends Node3D
## Convierte las paredes empinadas esculpidas en Terrain3D en una malla plegada (estilo B del laboratorio).
## Lee las alturas sin modificarlas, abre agujeros de Terrain3D solo bajo la malla generada y crea colision por chunk.
## Flujo: esculpir -> Regenerar cliffs. Para re-esculpir una pared: Restaurar terreno, esculpir, Regenerar.
## Hornear guarda malla/material/colision en un PackedScene. Runtime solo instancia ese recurso, sin generar.

@export_group("Generacion")
## Terrain3D del que se leen las alturas y donde se abren los agujeros. Debe estar en la misma escena.
## Coste: ninguno por si mismo; cambiarlo requiere Regenerar.
@export var terrain: Terrain3D
## Solo en editor y sin bake: genera una vista previa al abrir. Si hay bake, carga ese recurso. Nunca reconstruye al iniciar el juego.
## Coste: generacion CPU solo en editor cuando falta bake. Apagado requiere pulsar Regenerar u Hornear.
@export var rebuild_on_ready := true
## Regenera automaticamente al cambiar parametros de este nodo (no al esculpir). Agrupa cambios con Preview Delay.
## Coste alto en terrenos grandes: cada cambio reconstruye mallas, colisiones y agujeros de forma sincrona y puede pausar el editor. Apagado por defecto.
@export var live_preview := false
## Segundos sin cambios antes de regenerar con Live Preview. Se aplica en vivo.
## Coste: no cambia el coste de cada reconstruccion; solo cuantas veces ocurre mientras arrastras sliders.
@export_range(0.1, 3.0, 0.05, "suffix:s") var preview_delay := 0.6
## Lee el terreno actual, detecta paredes y reconstruye malla, colision y agujeros desde cero. Nunca acumula deformaciones.
## Coste: reconstruccion completa y sincrona. El resumen de vertices y tiempo aparece en la salida.
@export_tool_button("Regenerar cliffs") var rebuild_button: Callable = regenerate
## Genera B y guarda malla/material/colision en Bake Path y los datos de Terrain3D. Guarda la escena con Ctrl+S despues para conservar la referencia.
## Coste de generacion y escritura solo en editor. Runtime carga el recurso sin reconstruir. No ejecuta optimizacion de colision.
@export_tool_button("Hornear y guardar B") var bake_button: Callable = bake
## Copia pliegues, resolucion y angulos de mezcla desde cliff_playground.tscn. Sobrescribe esos controles solo al pulsar este boton.
## Coste bajo de lectura; requiere regenerar/hornear despues. Sirve para comparar con los ajustes exactos del B guardado.
@export_tool_button("Copiar ajustes del B de referencia") var reference_button: Callable = copy_reference_settings
## Recurso horneado que carga el juego. Lo asigna Hornear y guardar B; sin bake no se genera geometria al iniciar el juego.
## Coste runtime de cargar/dibujar mallas y colision, sin ruido ni reconstruccion. Tras editar hay que hornear otra vez y guardar la escena.
@export var baked_scene: PackedScene
## Archivo exclusivo para este generador. Usa una ruta distinta para cada instancia que tenga otra escultura.
## Coste de disco solo al hornear; guarda recursos binarios. No cambia al regenerar la vista previa.
@export_file("*.scn") var bake_path := "res://terrain_data/automatic_cliff/cliffs_baked.scn"
## Elimina la malla generada y cierra solo los agujeros que abrio este nodo (los que pintaste a mano se conservan). Usalo antes de re-esculpir una pared.
## Coste: bajo; actualiza el mapa de control y la colision de Terrain3D.
@export_tool_button("Restaurar terreno") var restore_button: Callable = restore_terrain

@export_group("Deteccion de paredes")
## Inclinacion en grados (0 = plano, 90 = vertical) a partir de la cual una zona se convierte en cliff plegado. Mayor: solo paredes casi verticales.
## Coste: bajarlo amplia el area reemplazada; mas celdas = mas vertices, colision y agujeros.
@export_range(30.0, 89.0, 1.0, "suffix:degrees") var minimum_slope := 60.0
## Banda angular en la que el pliegue pasa de 0 a su intensidad completa. Mayor suaviza la entrada del efecto.
## Coste: no cambia el area reemplazada (esta empieza en Minimum Slope); no agrega geometria.
@export_range(1.0, 25.0, 1.0, "suffix:degrees") var slope_transition := 10.0
## Radio en celdas usado para medir la pendiente. Mayor ignora irregularidades pequenas del esculpido y da direcciones de pliegue mas estables; demasiado alto ensancha la mascara.
## Coste: despreciable.
@export_range(1, 6, 1) var normal_radius := 2
## Valor antiguo conservado para migracion. No se utiliza; ahora la transicion se mide en metros desde cima/pie.
@export_storage var edge_fade_cells := 2

@export_group("Pliegues")
## Semilla reproducible del patron. Otra semilla redistribuye los pliegues con los mismos ajustes.
## Coste: igual entre semillas.
@export var pattern_seed: int = 27
## Tamano de las formas en metros. Mayor: grandes formaciones; menor: arrugas finas (puede requerir bajar Mesh Step).
## Coste: no cambia el numero de vertices.
@export_range(0.5, 10.0, 0.1, "suffix:m") var fold_size := 3.5
## Metros que se hunden las hendiduras, perpendicular a la pared.
## Coste: no agrega geometria; valores grandes pueden producir autointersecciones y contactos de escalada irregulares.
@export_range(0.0, 3.0, 0.05, "suffix:m") var indentation := 0.5
## Metros que sobresalen los salientes, perpendicular a la pared.
## Coste: no agrega geometria; salientes grandes pueden atravesar la cima o el suelo cercanos.
@export_range(0.0, 3.0, 0.05, "suffix:m") var protrusion := 0.5
## Exponente del patron: menor ensancha los pliegues, mayor concentra las crestas.
## Coste: no agrega geometria; crestas muy estrechas pueden requerir bajar Mesh Step.
@export_range(0.4, 4.0, 0.05) var fold_sharpness := 3.0
## Estira el patron verticalmente; mayor produce surcos verticales mas largos.
## Coste: ninguno.
@export_range(0.25, 5.0, 0.05) var vertical_stretch := 1.8

@export_group("Malla")
## Distancia maxima en metros desde el contorno medio para encontrar cima y pie. Mayor admite paredes mas tendidas.
## Coste CPU de busqueda durante generacion; no afecta runtime. Si no encuentra ambos, conserva la cubierta anterior y muestra un error.
@export_range(1.0, 64.0, 0.5, "suffix:m") var profile_search_distance := 16.0
## Valor antiguo conservado para cargar escenas. La construccion por contornos de B esta siempre activa.
@export_storage var reconstruct_surface := true
## Pasadas de suavizado del contorno y las lineas de cima/pie, antes de construir la malla regular. 0 conserva dientes del muestreo.
## Mayor redondea detalles, limitado por Smoothing Limit. CPU proporcional a pasadas y columnas, solo al regenerar/hornear.
@export_range(0, 40, 1) var surface_smoothing := 16
## Desviacion horizontal maxima respecto a la escultura, en metros, antes de los pliegues. 0 desactiva el suavizado.
## Mayor permite eliminar escalones mas grandes, pero puede estrechar detalles. No modifica Terrain3D. Mismo coste; regenerar.
@export_range(0.0, 2.0, 0.05, "suffix:m") var smoothing_limit := 0.5
## Metros verticales desde cima/pie para desvanecer los pliegues, como B. Tambien protege extremos de paredes abiertas.
## Mayor deja una franja mas lisa. No reduce vertices ni coste runtime; requiere regenerar/hornear.
@export_range(0.1, 10.0, 0.1, "suffix:m") var edge_fade_meters := 2.0
## Banda extra sobre el terreno alrededor de la pared, en metros. Cubre la union ante cambios de LOD sin abrir mas agujeros.
## Mayor agrega geometria plana y colision; no resuelve LOD arbitrariamente lejanos. Modo reconstruido; regenerar.
@export_range(0.0, 8.0, 0.25, "suffix:m") var seam_overlap := 2.0
## Elevacion de la cubierta en metros para evitar parpadeo donde coincide con Terrain3D. Mayor puede crear un escalon visible.
## 0 puede causar z-fighting. Coste nulo; modo reconstruido, regenerar. El faldon cierra el borde exterior.
@export_range(0.0, 0.1, 0.005, "suffix:m") var seam_lift := 0.02
## Separacion objetivo en metros alrededor del contorno Y a lo alto de la pared. Menor da pliegues mas detallados.
## Coste alto: reducir a la mitad multiplica aproximadamente por cuatro geometria, memoria y colision. Regenerar/hornear.
@export_range(0.1, 2.0, 0.05, "suffix:m") var mesh_step := 0.5
## Valor antiguo conservado para migracion; no limita la malla B.
@export_storage var max_subdivisions := 6
## Tamano en metros de cada chunk de malla y colision. Menor mejora el descarte por camara; mayor reduce el numero de nodos.
## Coste: no cambia el total de triangulos; chunks muy pequenos aumentan draw calls.
@export_range(4.0, 64.0, 1.0, "suffix:m") var chunk_size := 16.0
## Faldon que baja desde el borde de la malla para tapar rendijas con los LOD lejanos de Terrain3D. 0 lo desactiva.
## Coste: bajo (una tira de triangulos por borde, sin colision).
@export_range(0.0, 2.0, 0.05, "suffix:m") var skirt_depth := 0.3
## Valor antiguo conservado para cargar escenas. No se aplica: ocultar una malla dejaria visibles sus agujeros permanentes.
@export_storage var visibility_range := 0.0

@export_group("Aspecto y colision")
## ID de textura de Terrain3D para zonas suaves de la malla (soft-grass).
## Coste: ninguno extra.
@export_range(0, 31, 1) var grass_texture_id := 0
## ID de textura de Terrain3D para paredes de la malla (soft-cliff).
## Coste: ninguno extra.
@export_range(0, 31, 1) var cliff_texture_id := 1
## Angulo en grados donde empieza a verse roca sobre la malla. Mayor conserva hierba en pendientes mas fuertes.
## Coste: ninguno extra (triplanar con seis lecturas de textura por pixel).
@export_range(0.0, 85.0, 1.0, "suffix:degrees") var rock_start_angle := 45.0
## Grados de transicion hasta roca completa. Menor: borde mas nitido; puede mostrar dientes a distancia.
## Coste: ninguno extra.
@export_range(1.0, 30.0, 1.0, "suffix:degrees") var rock_blend_angle := 10.0
## Activa el Auto Shader de Terrain3D (mismas texturas por pendiente) en el resto del terreno. Lo que pintes a mano en Terrain3D tiene prioridad.
## Coste: el del Auto Shader de Terrain3D; no afecta a la malla.
@export var terrain_auto_shader := true
## Parametro auto_slope de Terrain3D: mayor hace que la roca aparezca antes en pendientes moderadas del terreno. No es un angulo; ajustalo a ojo para que coincida con Rock Start Angle en la union con la malla.
## Coste: ninguno; se aplica al material de Terrain3D al regenerar.
@export_range(0.0, 10.0, 0.1) var terrain_auto_slope := 1.0
## Colision triangular por chunk que sigue los pliegues (grupo climbable, capas 1 y 3). Colision de blockout; no es un proxy simplificado.
## Coste alto: construir y consultar trimesh por chunk. Apagado: los agujeros dejan caer al personaje a traves de las paredes.
@export var collision_enabled := true

## Celdas (x, z en pixeles globales de Terrain3D) cuyos agujeros abrio este nodo. Se guarda con la escena para poder restaurarlos.
@export_storage var owned_holes := PackedInt32Array()

const EPSILON := 0.001
var _noise := FastNoiseLite.new()
var _generated: Node3D
var _building := false
var _observed_parameters: Array = []
var _preview_wait := -1.0
# Grid snapshot of the terrain covering all regions.
var _spacing := 1.0
var _origin := Vector2i.ZERO
var _w := 0
var _d := 0
var _heights := PackedFloat32Array()
var _normals := PackedVector3Array()
var _mask := PackedFloat32Array()
var _amplitude := PackedFloat32Array()
var _subdivisions := 1
var _positions := {}
var _surface_candidate
var _last_build_ok := false

func _preview_parameters() -> Array:
	return [minimum_slope, slope_transition, normal_radius, pattern_seed,
		fold_size, indentation, protrusion, fold_sharpness, vertical_stretch, mesh_step,
		profile_search_distance, surface_smoothing, smoothing_limit, edge_fade_meters, seam_overlap, seam_lift,
		chunk_size, skirt_depth, visibility_range, grass_texture_id,
		cliff_texture_id, rock_start_angle, rock_blend_angle, terrain_auto_shader, terrain_auto_slope, collision_enabled]

func _ready() -> void:
	_observed_parameters = _preview_parameters()
	if baked_scene != null:
		_load_baked()
	elif Engine.is_editor_hint() and rebuild_on_ready:
		_rebuild_when_ready.call_deferred()
	elif not Engine.is_editor_hint():
		push_error("CliffFolds: falta el bake. Abre la escena y pulsa Hornear y guardar B.")
	if not Engine.is_editor_hint():
		set_process(false)

func _rebuild_when_ready() -> void:
	# Terrain3D creates its data after entering the tree; wait for it instead of failing.
	for i in 10:
		if is_instance_valid(terrain) and terrain.data != null:
			regenerate()
			return
		await get_tree().process_frame
	push_warning("CliffFoldsGenerator: asigna un Terrain3D con datos para generar cliffs.")

func _process(delta: float) -> void:
	if _building or not live_preview:
		_preview_wait = -1.0
		return
	var parameters := _preview_parameters()
	if parameters != _observed_parameters:
		_observed_parameters = parameters
		_preview_wait = preview_delay
		return
	if _preview_wait >= 0.0:
		_preview_wait -= delta
		if _preview_wait <= 0.0:
			_preview_wait = -1.0
			regenerate.call_deferred()

func regenerate() -> void:
	if _building or not is_inside_tree():
		return
	if not is_instance_valid(terrain) or terrain.data == null:
		push_warning("CliffFoldsGenerator: falta el Terrain3D o sus datos.")
		return
	_building = true
	_last_build_ok = false
	var start := Time.get_ticks_msec()
	_observed_parameters = _preview_parameters()
	_noise.seed = pattern_seed
	_noise.frequency = 1.0 / fold_size
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.fractal_octaves = 2
	_read_terrain()
	_build_mask()
	var cells := _cliff_cells()
	if not _prepare_contours():
		_building = false
		return
	_apply_terrain_material()
	_clear_generated()
	var stats := _build_reconstructed_meshes(cells)
	var holes_changed := _sync_holes()
	if holes_changed:
		_refresh_terrain()
	_heights = PackedFloat32Array()
	_normals = PackedVector3Array()
	_mask = PackedFloat32Array()
	_amplitude = PackedFloat32Array()
	_positions.clear()
	_building = false
	_last_build_ok = true
	update_configuration_warnings()
	var mode := "B: %d paredes, paso %.2f m" % [_surface_candidate.wall_count, mesh_step]
	print("Cliff folds: %d celdas, %d chunks, %d vertices, %s, %d ms." % [
		cells.size(), stats.x, stats.y, mode, Time.get_ticks_msec() - start])

func restore_terrain() -> void:
	if not is_instance_valid(terrain) or terrain.data == null:
		return
	_clear_generated()
	baked_scene = null
	_last_build_ok = false
	if _set_owned_holes(PackedInt32Array()):
		_refresh_terrain()
	print("Cliff folds: terreno restaurado; agujeros propios cerrados.")

func _prepare_contours() -> bool:
	_surface_candidate = preload("res://scripts/terrain/cliff_contour_builder.gd").new()
	if not _surface_candidate.build(_heights, _mask, _w, _d, _spacing, _origin,
			mesh_step, edge_fade_meters, seam_overlap, surface_smoothing, smoothing_limit, profile_search_distance):
		push_error("Cliff B: " + _surface_candidate.error + " Se conserva la cubierta anterior.")
		return false
	var owned := {}
	for i in range(0, owned_holes.size(), 2):
		owned[Vector2i(owned_holes[i], owned_holes[i + 1])] = true
	var coverage := {}
	for t in range(0, _surface_candidate.indices.size(), 3):
		var polygon := PackedVector2Array()
		for k in 3:
			var p: Vector3 = _surface_candidate.vertices[_surface_candidate.indices[t + k]]
			polygon.append(Vector2(p.x, p.z) / _spacing)
		var lo := polygon[0].min(polygon[1]).min(polygon[2]).floor()
		var hi := polygon[0].max(polygon[1]).max(polygon[2]).ceil()
		for z in range(int(lo.y), int(hi.y) + 1):
			for x in range(int(lo.x), int(hi.x) + 1):
				var cell := Vector2i(x, z)
				if not coverage.has(cell) and Geometry2D.is_point_in_polygon(Vector2(cell), polygon):
					coverage[cell] = true
	for cell: Vector2i in coverage:
		if not owned.has(cell) and terrain.data.get_control_hole(_world(cell)):
			push_error("Cliff B: la cubierta cruza un agujero manual. Separa esa zona antes de hornear. Se conserva la cubierta anterior.")
			return false
	for z in _d:
		for x in _w:
			if _mask[z * _w + x] > EPSILON and not coverage.has(Vector2i(x, z) + _origin):
				push_error("Cliff B: la cubierta no cubre toda la pared detectada. Aumenta Seam Overlap o separa la zona compleja. Se conserva la cubierta anterior.")
				return false
	return true

func copy_reference_settings() -> void:
	var reference := load("res://scenes/cliff_playground.tscn") as PackedScene
	if reference == null:
		return
	var node := reference.instantiate()
	for property in ["pattern_seed", "fold_size", "indentation", "protrusion", "fold_sharpness",
			"vertical_stretch", "minimum_slope", "slope_transition", "mesh_step", "rock_start_angle", "rock_blend_angle"]:
		set(property, node.get(property))
	edge_fade_meters = node.get("edge_fade")
	node.free()
	notify_property_list_changed()
	update_configuration_warnings()

func bake() -> void:
	regenerate()
	if not _last_build_ok:
		return
	if not bake_path.begins_with("res://") or bake_path.get_extension() != "scn":
		push_error("Cliff B: Bake Path debe ser un archivo res:// terminado en .scn.")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(bake_path.get_base_dir()))
	_set_bake_owners(_generated, _generated)
	_generated.remove_meta("preview_only")
	_generated.set_meta("owned_holes", owned_holes)
	_generated.set_meta("author_parameters", _preview_parameters())
	var packed := PackedScene.new()
	var result := packed.pack(_generated)
	if result == OK:
		result = ResourceSaver.save(packed, bake_path, ResourceSaver.FLAG_COMPRESS)
	if result != OK:
		push_error("Cliff B: no se pudo guardar el bake: " + error_string(result))
		return
	baked_scene = ResourceLoader.load(bake_path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	# The terrain and baked mesh must describe the same holes when exported.
	terrain.data.save_directory(terrain.data_directory)
	update_configuration_warnings()
	print("Cliff B guardado: ", bake_path, ". Guarda la escena con Ctrl+S.")

func _set_bake_owners(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		_set_bake_owners(child, root)

func _load_baked() -> void:
	var old := get_node_or_null("GeneratedCliffs")
	if old != null:
		old.free()
	_generated = baked_scene.instantiate()
	_generated.name = "GeneratedCliffs"
	add_child(_generated)
	_generated.top_level = true
	_generated.global_transform = Transform3D.IDENTITY
	owned_holes = _generated.get_meta("owned_holes", owned_holes)

func _get_configuration_warnings() -> PackedStringArray:
	if baked_scene == null:
		return PackedStringArray(["Falta el bake. Pulsa Hornear y guardar B antes de ejecutar/exportar y guarda la escena."])
	if is_instance_valid(_generated) and _generated.get_meta("preview_only", false):
		return PackedStringArray(["La vista previa no esta horneada. Pulsa Hornear y guardar B y guarda la escena."])
	if is_instance_valid(_generated) and _generated.has_meta("author_parameters"):
		if _generated.get_meta("author_parameters") != _preview_parameters():
			return PackedStringArray(["Los ajustes cambiaron desde el bake. Vuelve a hornear y guarda la escena."])
	return PackedStringArray()

func _clear_generated() -> void:
	if not is_instance_valid(_generated):
		_generated = get_node_or_null("GeneratedCliffs")
	if is_instance_valid(_generated):
		_generated.free()
	_generated = Node3D.new()
	_generated.name = "GeneratedCliffs"
	_generated.set_meta("preview_only", true)
	_generated.top_level = true
	add_child(_generated)
	_generated.global_transform = Transform3D.IDENTITY

func _apply_terrain_material() -> void:
	var material := terrain.material
	if material == null:
		return
	material.auto_shader = terrain_auto_shader
	# Terrain3D convention: overlay covers flat ground and base covers slopes.
	material.set_shader_param("auto_base_texture", cliff_texture_id)
	material.set_shader_param("auto_overlay_texture", grass_texture_id)
	material.set_shader_param("auto_slope", terrain_auto_slope)

func _read_terrain() -> void:
	_spacing = terrain.vertex_spacing
	var size: int = terrain.region_size
	var locations: Array = terrain.data.get_region_locations()
	_w = 0
	_d = 0
	if locations.is_empty():
		return
	var low: Vector2i = locations[0]
	var high: Vector2i = locations[0]
	for location: Vector2i in locations:
		low = low.min(location)
		high = high.max(location)
	_origin = low * size
	_w = (high.x - low.x + 1) * size
	_d = (high.y - low.y + 1) * size
	_heights.resize(_w * _d)
	_heights.fill(NAN)
	for location: Vector2i in locations:
		var region: Terrain3DRegion = terrain.data.get_region(location)
		if region == null or region.is_deleted():
			continue
		var image: Image = region.get_height_map()
		if image.get_format() != Image.FORMAT_RF:
			image = image.duplicate()
			image.convert(Image.FORMAT_RF)
		# Raw heights stay valid under holes, so regeneration never reads its own holes as gaps.
		var values := image.get_data().to_float32_array()
		var base := (location - low) * size
		for z in size:
			var row := (base.y + z) * _w + base.x
			for x in size:
				_heights[row + x] = values[z * size + x]

func _build_mask() -> void:
	_normals.resize(_w * _d)
	_normals.fill(Vector3.UP)
	_mask.resize(_w * _d)
	_mask.fill(0.0)
	var r := normal_radius
	for z in range(r, _d - r):
		for x in range(r, _w - r):
			var i := z * _w + x
			var gx := (_heights[i + r] - _heights[i - r]) / (2.0 * r * _spacing)
			var gz := (_heights[i + r * _w] - _heights[i - r * _w]) / (2.0 * r * _spacing)
			if is_nan(gx) or is_nan(gz) or is_nan(_heights[i]):
				continue
			_normals[i] = Vector3(-gx, 1.0, -gz).normalized()
			var angle := rad_to_deg(atan(sqrt(gx * gx + gz * gz)))
			if angle >= minimum_slope:
				_mask[i] = maxf(EPSILON * 2.0, smoothstep(minimum_slope, minimum_slope + slope_transition, angle))
func _cliff_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for z in _d:
		for x in _w:
			if _mask[z * _w + x] > EPSILON:
				cells.append(Vector2i(x, z))
	return cells
func _sync_holes() -> bool:
	var wanted := PackedInt32Array()
	var owned := {}
	for j in range(0, owned_holes.size(), 2):
		owned[Vector2i(owned_holes[j], owned_holes[j + 1])] = true
	for z in _d:
		for x in _w:
			if _mask[z * _w + x] <= EPSILON:
				continue
			var cell := Vector2i(x, z) + _origin
			# Holes painted by the user are left alone and never become owned.
			if owned.has(cell) or not terrain.data.get_control_hole(_world(cell)):
				wanted.append(cell.x)
				wanted.append(cell.y)
	return _set_owned_holes(wanted)

func _set_owned_holes(wanted: PackedInt32Array) -> bool:
	var keep := {}
	for j in range(0, wanted.size(), 2):
		keep[Vector2i(wanted[j], wanted[j + 1])] = true
	var changed := false
	for j in range(0, owned_holes.size(), 2):
		var cell := Vector2i(owned_holes[j], owned_holes[j + 1])
		if not keep.has(cell) and terrain.data.get_control_hole(_world(cell)):
			terrain.data.set_control_hole(_world(cell), false)
			changed = true
	for cell: Vector2i in keep:
		if not terrain.data.get_control_hole(_world(cell)):
			terrain.data.set_control_hole(_world(cell), true)
			changed = true
	owned_holes = wanted
	return changed

func _refresh_terrain() -> void:
	terrain.data.update_maps(Terrain3DRegion.TYPE_CONTROL, true, false)
	if terrain.get_collision() != null:
		terrain.get_collision().build()

func _world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * _spacing, 0.0, cell.y * _spacing)

func _build_reconstructed_meshes(cells: Array[Vector2i]) -> Vector2i:
	var surface = _surface_candidate
	for i in surface.vertices.size():
		var p: Vector3 = surface.vertices[i]
		var normal: Vector3 = surface.normals[i]
		var angle := rad_to_deg(acos(clampf(normal.y, -1.0, 1.0)))
		var amount := smoothstep(minimum_slope, minimum_slope + slope_transition, angle)
		amount *= surface.relief[i]
		var n := clampf(_noise.get_noise_3d(p.x, p.y / vertical_stretch, p.z) * 1.8, -1.0, 1.0)
		n = signf(n) * pow(absf(n), fold_sharpness)
		surface.vertices[i] = p + normal * n * (protrusion if n >= 0.0 else indentation) * amount + Vector3.UP * seam_lift
	surface.compute_normals()
	# Calculate shared normals before splitting chunks: no lighting seams at chunk borders.
	var chunks := {}
	var edges := {}
	for t in range(0, surface.indices.size(), 3):
		var a: int = surface.indices[t]
		var b: int = surface.indices[t + 1]
		var c: int = surface.indices[t + 2]
		var center: Vector3 = (surface.vertices[a] + surface.vertices[b] + surface.vertices[c]) / 3.0
		var key := Vector2i(floori(center.x / chunk_size), floori(center.z / chunk_size))
		if not chunks.has(key):
			chunks[key] = []
		chunks[key].append_array([a, b, c])
		for pair in [Vector2i(a, b), Vector2i(b, c), Vector2i(c, a)]:
			var edge := Vector2i(mini(pair.x, pair.y), maxi(pair.x, pair.y))
			edges[edge] = edges.get(edge, 0) + 1
	var material := _surface_material()
	var count := 0
	for key: Vector2i in chunks:
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var indices := PackedInt32Array()
		var skirt := PackedInt32Array()
		var local_ids := {}
		for id: int in chunks[key]:
			if not local_ids.has(id):
				local_ids[id] = vertices.size()
				vertices.append(surface.vertices[id])
				normals.append(surface.normals[id])
			indices.append(local_ids[id])
		if skirt_depth > 0.0:
			for t in range(0, chunks[key].size(), 3):
				for side in 3:
					var a: int = chunks[key][t + side]
					var b: int = chunks[key][t + (side + 1) % 3]
					if edges[Vector2i(mini(a, b), maxi(a, b))] != 1:
						continue
					var ia: int = local_ids[a]
					var ib: int = local_ids[b]
					var bottom := vertices.size()
					vertices.append(vertices[ia] + Vector3.DOWN * skirt_depth)
					vertices.append(vertices[ib] + Vector3.DOWN * skirt_depth)
					normals.append(normals[ia])
					normals.append(normals[ib])
					skirt.append_array(PackedInt32Array([ia, ib, bottom, ib, bottom + 1, bottom,
						ia, bottom, ib, ib, bottom, bottom + 1]))
		count += vertices.size()
		_add_chunk(key, vertices, normals, indices, skirt, material)
	return Vector2i(chunks.size(), count)

func _add_chunk(chunk_key: Vector2i, vertices: PackedVector3Array, normals: PackedVector3Array,
		indices: PackedInt32Array, skirt: PackedInt32Array, material: Material) -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var all_indices := indices.duplicate()
	all_indices.append_array(skirt)
	arrays[Mesh.ARRAY_INDEX] = all_indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	var visual := MeshInstance3D.new()
	visual.name = "CliffChunk_%d_%d" % [chunk_key.x, chunk_key.y]
	visual.mesh = mesh
	# Terrain holes persist: culling their replacement by distance would expose the void.
	visual.visibility_range_end = 0.0
	_generated.add_child(visual)
	if not collision_enabled:
		return
	var faces := PackedVector3Array()
	faces.resize(indices.size())
	for i in indices.size():
		faces[i] = vertices[indices[i]]
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var body := StaticBody3D.new()
	body.name = visual.name + "Collision"
	body.collision_layer = 1 | 4
	body.add_to_group("climbable", true)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	_generated.add_child(body)

func _surface_material() -> Material:
	var assets := terrain.assets
	var grass: Terrain3DTextureAsset = assets.get_texture(grass_texture_id) if assets != null else null
	var cliff: Terrain3DTextureAsset = assets.get_texture(cliff_texture_id) if assets != null else null
	if grass == null or cliff == null:
		push_warning("CliffFoldsGenerator: no encuentro las texturas ID %d/%d; uso color plano." % [grass_texture_id, cliff_texture_id])
		var flat := StandardMaterial3D.new()
		flat.albedo_color = Color(0.48, 0.39, 0.29)
		flat.roughness = 1.0
		return flat
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/cliff_slope_surface.gdshader")
	material.set_shader_parameter("grass_texture", grass.albedo_texture)
	material.set_shader_parameter("cliff_texture", cliff.albedo_texture)
	material.set_shader_parameter("grass_tint", grass.albedo_color)
	material.set_shader_parameter("cliff_tint", cliff.albedo_color)
	material.set_shader_parameter("grass_scale", grass.uv_scale)
	material.set_shader_parameter("cliff_scale", cliff.uv_scale)
	material.set_shader_parameter("slope_start", rock_start_angle)
	material.set_shader_parameter("slope_width", rock_blend_angle)
	return material
