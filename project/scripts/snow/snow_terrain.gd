@tool
extends Node3D
## Superficie derivada del GLB. La nieve desplaza geometría real y su colisión coincide.
## GLB original del relieve; los cambios de esta herramienta se generan en una copia.
@export var source: PackedScene
## Material usado por la opción Original, conservado para comparar.
## Recurso usado cuando Material Style es Original. Sus cambios se ven directamente en el editor.
@export var snow_material: ShaderMaterial:
	set(value):
		snow_material = value
		_request_rebuild()
## Recurso usado por Grano visible. Al editarlo, el cambio se ve inmediatamente.
@export var grain_material: ShaderMaterial = preload("res://materials/terrain_snow_grain.tres"):
	set(value):
		grain_material = value
		_request_rebuild()
## Recurso usado por Nieve en polvo. Al editarlo, el cambio se ve inmediatamente.
@export var powder_material: ShaderMaterial = preload("res://materials/terrain_snow_powder.tres"):
	set(value):
		powder_material = value
		_request_rebuild()
## Original usa Snow Material. Las otras opciones resaltan detalle en superficies planas.
@export_enum("Original", "Grano visible", "Nieve en polvo") var material_style := 0:
	set(value):
		material_style = value
		_request_rebuild()
## Contraste del grano mediano en las tres variantes, incluido Original. No controla la luz.
@export_range(0.0, 1.0, 0.01) var flat_detail_strength := 0.0
## Brillo del material de nieve: 1 conserva su color; 0,8 lo oscurece un 20% antes de iluminarlo.
@export_range(0.1, 1.5, 0.01) var snow_brightness := 1.0
## Brillo adicional sólo en superficies horizontales. 0,85 reduce un poco el blanco de los planos.
@export_range(0.1, 1.5, 0.01) var flat_brightness := 1.0
## Actívalo si el GLB tiene sus caras hacia abajo. No modifica el archivo fuente.
@export var flip_source_faces := true
@export_group("Cobertura")
## Activa cobertura y espesor de nieve sobre el terreno.
@export var snow_enabled := true
## Cobertura general de 0 a 1. Usa 0 para depender únicamente de zonas manuales.
@export_range(0.0, 1.0, 0.05) var base_coverage := 1.0
## Altura local Y a partir de la cual empieza la cobertura automática.
@export var snow_line := -5.0
## Metros verticales de transición desde Snow Line hasta cobertura completa.
@export_range(0.1, 100.0, 0.5) var height_transition := 3.1
## Inclinación máxima con nieve; 90 permite nieve en casi todas las paredes.
@export_range(0.0, 90.0, 1.0) var slope_limit := 68.0
## Margen en grados donde la nieve desaparece gradualmente al acercarse a Slope Limit.
@export_range(0.1, 90.0, 0.5) var slope_transition := 0.1
@export_group("Volumen")
## Espesor uniforme de la capa de nieve, en metros.
@export_range(0.0, 10.0, 0.01, "or_greater") var blanket_depth := 0.0
## Ondulación: altura de pequeñas variaciones del espesor. 0 deja una capa uniforme.
@export_range(0.0, 5.0, 0.01, "or_greater") var undulation := 0.0
## Escala horizontal de las ondulaciones, en metros. Mayor valor crea ondas más amplias.
@export_range(0.1, 100.0, 0.5, "or_greater") var undulation_size := 8.0
## Cada nivel multiplica por cuatro los triángulos; añade resolución, no redondea el relieve.
@export_range(0, 3) var subdivision_levels := 0
## Pasadas de suavizado del relieve base en una copia. 0 conserva exactamente tu diseño.
@export_range(0, 20, 1) var rounding_iterations := 3
## Fuerza por pasada. Suaviza alturas y pliegues; mantiene X/Z y el perímetro.
@export_range(0.0, 1.0, 0.05) var rounding_strength := 1.0
## Suaviza la nieve DESPUÉS de añadir los montículos; reduce picos de la superficie final.
@export_range(0, 20, 1) var snow_rounding_iterations := 2
## Fuerza del suavizado final. Prueba 0,25 y 2–4 pasadas. También ajusta la colisión.
@export_range(0.0, 1.0, 0.05) var snow_rounding_strength := 0.25
@export_group("Editor")
## Muestra la superficie generada en el editor; al jugar siempre se muestra.
@export var preview_enabled := true
@export_tool_button("Reconstruir terreno y nieve") var rebuild_action = refresh_source
var _mesh: MeshInstance3D
var _body: StaticBody3D
var _shape: CollisionShape3D
var _signature := 0
var _elapsed := 0.0
var _zones: Array[Node] = []
var _source_faces := PackedVector3Array()
var _normals: Dictionary = {}
var _loaded_source: PackedScene
var _loaded_flip := false
var _loaded_rounding := -1
var _active_material: ShaderMaterial
var _material_signature := 0
var triangle_count := 0
var _surface_arrays: Array = []

func _request_rebuild() -> void:
	_signature = 0
	if is_inside_tree():
		rebuild()

func refresh_source() -> void:
	_loaded_source = null
	rebuild()

func _ready() -> void:
	_watch_materials()
	rebuild()

func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_watch_materials()
	_refresh_active_material()
	_elapsed += delta
	# La detección es deliberadamente breve para que el resultado de un deslizador
	# aparezca durante la edición, sin reconstruir en cada frame.
	if _elapsed < 0.1:
		return
	_elapsed = 0.0
	var config: Array = [source, snow_material, grain_material, powder_material, flip_source_faces, snow_enabled, base_coverage, snow_line,
		height_transition, slope_limit, slope_transition, blanket_depth, undulation,
		undulation_size, subdivision_levels, rounding_iterations, rounding_strength,
		material_style, flat_detail_strength, snow_brightness, flat_brightness,
		snow_rounding_iterations, snow_rounding_strength, preview_enabled, global_transform]
	var zones_root := get_node_or_null("SnowZones")
	if zones_root:
		for zone in zones_root.get_children():
			if zone.has_method("configuration"):
				config.append(zone.configuration())
	var signature := hash(config)
	if signature != _signature:
		_signature = signature
		rebuild()

func _collect(node: Node, parent_transform: Transform3D) -> void:
	var pose := parent_transform
	if node is Node3D:
		pose *= node.transform
	if node is MeshInstance3D and node.mesh:
		for vertex in node.mesh.get_faces():
			_source_faces.append((pose * vertex).snapped(Vector3.ONE * 0.0001))
	for child in node.get_children():
		_collect(child, pose)

func rebuild() -> void:
	if not is_inside_tree() or not source:
		return
	if not is_instance_valid(_mesh):
		_mesh = MeshInstance3D.new()
		_mesh.name = "GeneratedSnowSurface"
		add_child(_mesh)
	_mesh.visible = preview_enabled or not Engine.is_editor_hint()
	if not _mesh.visible:
		return
	_zones.clear()
	if has_node("SnowZones"):
		for zone in get_node("SnowZones").get_children():
			if zone.has_method("weight_at"):
				_zones.append(zone)
	var rounding_signature := hash([rounding_iterations, rounding_strength])
	if _loaded_source != source or _loaded_flip != flip_source_faces or _loaded_rounding != rounding_signature or _source_faces.is_empty():
		_source_faces.clear()
		_normals.clear()
		var imported := source.instantiate()
		_collect(imported, Transform3D.IDENTITY)
		imported.free()
		_loaded_source = source
		_loaded_flip = flip_source_faces
		_loaded_rounding = rounding_signature
		_round_source()
		if flip_source_faces:
			for i in range(0, _source_faces.size(), 3):
				var saved := _source_faces[i + 1]
				_source_faces[i + 1] = _source_faces[i + 2]
				_source_faces[i + 2] = saved
		for i in range(0, _source_faces.size(), 3):
			var normal := (_source_faces[i + 2] - _source_faces[i]).cross(_source_faces[i + 1] - _source_faces[i]).normalized()
			for j in 3:
				var vertex := _source_faces[i + j]
				_normals[vertex] = _normals.get(vertex, Vector3.ZERO) + normal
		for vertex in _normals:
			_normals[vertex] = Vector3(_normals[vertex]).normalized()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, _source_faces.size(), 3):
		var a := _source_faces[i]
		var b := _source_faces[i + 1]
		var c := _source_faces[i + 2]
		_triangle(surface, a, b, c, _normals[a], _normals[b], _normals[c], subdivision_levels)
	surface.index()
	surface.generate_normals()
	_mesh.mesh = surface.commit()
	_smooth_snow_surface()
	var selected: ShaderMaterial = (grain_material if material_style == 1 else powder_material) if material_style != 0 else snow_material
	# Se conserva el recurso seleccionado: sus Shader Parameters son exactamente
	# los que ve y edita la persona en Inspector.
	_active_material = selected
	if _active_material:
		_active_material.set_shader_parameter("flat_detail_strength", flat_detail_strength)
		_active_material.set_shader_parameter("snow_brightness", snow_brightness)
		_active_material.set_shader_parameter("flat_brightness", flat_brightness)
	_mesh.material_override = _active_material
	_surface_arrays = _mesh.mesh.surface_get_arrays(0)
	triangle_count = _mesh.mesh.get_faces().size() / 3
	if not Engine.is_editor_hint():
		if not is_instance_valid(_body):
			_body = StaticBody3D.new()
			_body.name = "TerrainCollision"
			# Capa 1 para la ardilla; capa 3 (valor 4) para Camera Blocker.
			_body.collision_layer = 1 | 4
			add_child(_body)
			_shape = CollisionShape3D.new()
			_body.add_child(_shape)
		_shape.shape = _mesh.mesh.create_trimesh_shape()
		print("Snow terrain: ", triangle_count, " triangles; collision generated.")

func _watch_materials() -> void:
	for material in [snow_material, grain_material, powder_material]:
		if material and not material.changed.is_connected(_on_material_changed):
			material.changed.connect(_on_material_changed)

func _on_material_changed() -> void:
	# ShaderMaterial normalmente avisa al renderer por sí mismo. También lo
	# re-asignamos diferido: cubre cambios de Inspector y recompilaciones de shader
	# durante una vista @tool sin reconstruir la geometría.
	call_deferred("_apply_active_material")

func _refresh_active_material() -> void:
	var material := _selected_material()
	if not material:
		return
	var signature := hash([
		material, material.get_shader_parameter("grain_enabled"),
		material.get_shader_parameter("grain_scale"),
		material.get_shader_parameter("grain_strength"),
		material.get_shader_parameter("grain_distance_fade"),
		material.get_shader_parameter("broad_scale"),
		material.get_shader_parameter("broad_strength"),
		material.get_shader_parameter("micro_relief"),
		material.get_shader_parameter("flat_detail_strength"),
		material.get_shader_parameter("flat_detail_scale"),
		material.get_shader_parameter("snow_brightness"),
		material.get_shader_parameter("flat_brightness"),
	])
	if signature != _material_signature:
		_material_signature = signature
		_apply_active_material()

func _apply_active_material() -> void:
	if not is_instance_valid(_mesh):
		return
	_active_material = _selected_material()
	_mesh.material_override = _active_material

func _selected_material() -> ShaderMaterial:
	if material_style == 1:
		return grain_material
	if material_style == 2:
		return powder_material
	return snow_material

func _smooth_snow_surface() -> void:
	if snow_rounding_iterations == 0: return
	var arrays := _mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var depths: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var neighbors: Dictionary = {}
	var edges: Dictionary = {}
	for i in range(0, indices.size(), 3):
		for j in 3:
			var a := indices[i + j]
			var b := indices[i + (j + 1) % 3]
			if not neighbors.has(a): neighbors[a] = {}
			if not neighbors.has(b): neighbors[b] = {}
			neighbors[a][b] = true
			neighbors[b][a] = true
			var edge := Vector2i(mini(a, b), maxi(a, b))
			edges[edge] = edges.get(edge, 0) + 1
	var boundary: Dictionary = {}
	for edge in edges:
		if edges[edge] == 1:
			boundary[edge.x] = true
			boundary[edge.y] = true
	var original := vertices.duplicate()
	for iteration in snow_rounding_iterations:
		var next := vertices.duplicate()
		for index in neighbors:
			if boundary.has(index): continue
			var average := 0.0
			for neighbor in neighbors[index]: average += vertices[neighbor].y
			average /= neighbors[index].size()
			next[index].y = lerpf(vertices[index].y, average, snow_rounding_strength * depths[index].x)
		vertices = next
	for i in vertices.size():
		depths[i].y = maxf(0.0, depths[i].y + vertices[i].y - original[i].y)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV2] = depths
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var rebuilt := SurfaceTool.new()
	rebuilt.create_from(mesh, 0)
	rebuilt.generate_normals()
	_mesh.mesh = rebuilt.commit()

func _round_source() -> void:
	if rounding_iterations == 0 or rounding_strength == 0.0:
		return
	var neighbors: Dictionary = {}
	var edges: Dictionary = {}
	for i in range(0, _source_faces.size(), 3):
		for j in 3:
			var a := _source_faces[i + j]
			var b := _source_faces[i + (j + 1) % 3]
			if not neighbors.has(a): neighbors[a] = {}
			if not neighbors.has(b): neighbors[b] = {}
			neighbors[a][b] = true
			neighbors[b][a] = true
			var key := [a, b] if a < b else [b, a]
			edges[key] = edges.get(key, 0) + 1
	var boundary: Dictionary = {}
	for edge in edges:
		if edges[edge] == 1:
			boundary[edge[0]] = true
			boundary[edge[1]] = true
	var heights: Dictionary = {}
	for vertex in neighbors: heights[vertex] = vertex.y
	for iteration in rounding_iterations:
		var next := heights.duplicate()
		for vertex in neighbors:
			if boundary.has(vertex): continue
			var average := 0.0
			for neighbor in neighbors[vertex]: average += heights[neighbor]
			average /= neighbors[vertex].size()
			next[vertex] = lerpf(heights[vertex], average, rounding_strength)
		heights = next
	for i in _source_faces.size():
		var vertex := _source_faces[i]
		_source_faces[i] = Vector3(vertex.x, heights[vertex], vertex.z).snapped(Vector3.ONE * 0.0001)

func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, level: int) -> void:
	if level > 0:
		var ab := (a + b) * 0.5
		var bc := (b + c) * 0.5
		var ca := (c + a) * 0.5
		var nab := (na + nb).normalized()
		var nbc := (nb + nc).normalized()
		var nca := (nc + na).normalized()
		_triangle(st, a, ab, ca, na, nab, nca, level - 1)
		_triangle(st, ab, b, bc, nab, nb, nbc, level - 1)
		_triangle(st, ca, bc, c, nca, nbc, nc, level - 1)
		_triangle(st, ab, bc, ca, nab, nbc, nca, level - 1)
		return
	_emit(st, a, na)
	_emit(st, b, nb)
	_emit(st, c, nc)

func snow_at(point: Vector3, normal: Vector3 = Vector3.UP) -> Vector2:
	if not snow_enabled:
		return Vector2.ZERO
	var slope := smoothstep(cos(deg_to_rad(slope_limit)), cos(deg_to_rad(maxf(0.0, slope_limit - slope_transition))), normal.y)
	var coverage := base_coverage * smoothstep(snow_line, snow_line + height_transition, point.y)
	var extra_depth := 0.0
	# Accumulation first, clearings second: node order never changes the result.
	for zone in _zones:
		if zone.operation == 0:
			var weight: float = zone.weight_at(to_global(point))
			coverage = maxf(coverage, weight * zone.coverage)
			extra_depth += weight * zone.depth
	var clear_factor := 1.0
	for zone in _zones:
		if zone.operation == 1:
			clear_factor *= 1.0 - zone.weight_at(to_global(point)) * zone.coverage
	coverage = clampf(coverage * slope * clear_factor, 0.0, 1.0)
	var wave := 0.5 + 0.5 * sin(point.x / undulation_size) * cos(point.z / undulation_size)
	var depth := (blanket_depth + wave * undulation + extra_depth) * coverage
	return Vector2(coverage, depth)

func _emit(surface: SurfaceTool, point: Vector3, normal: Vector3) -> void:
	var snow := snow_at(point, normal)
	var displaced := (point + Vector3.UP * snow.y).snapped(Vector3.ONE * 0.0001)
	surface.set_color(Color(snow.x, 0.0, 0.0))
	surface.set_uv(Vector2(point.x, point.z))
	surface.set_uv2(snow)
	surface.add_vertex(displaced)

## Interpola cobertura/espesor de la misma geometría que recibió el contacto físico.
func sample_hit(hit: Dictionary) -> Vector2:
	if hit.is_empty() or hit.get("collider") != _body or _surface_arrays.is_empty():
		return Vector2.ZERO
	var face: int = hit.get("face_index", -1)
	var indices: PackedInt32Array = _surface_arrays[Mesh.ARRAY_INDEX]
	if face < 0 or face * 3 + 2 >= indices.size():
		return Vector2.ZERO
	var vertices: PackedVector3Array = _surface_arrays[Mesh.ARRAY_VERTEX]
	var samples: PackedVector2Array = _surface_arrays[Mesh.ARRAY_TEX_UV2]
	var ia := indices[face * 3]
	var ib := indices[face * 3 + 1]
	var ic := indices[face * 3 + 2]
	var v0 := vertices[ib] - vertices[ia]
	var v1 := vertices[ic] - vertices[ia]
	var v2 := to_local(hit.position) - vertices[ia]
	var denominator := v0.dot(v0) * v1.dot(v1) - v0.dot(v1) * v0.dot(v1)
	if absf(denominator) < 0.000001:
		return samples[ia]
	var b := (v1.dot(v1) * v2.dot(v0) - v0.dot(v1) * v2.dot(v1)) / denominator
	var c := (v0.dot(v0) * v2.dot(v1) - v0.dot(v1) * v2.dot(v0)) / denominator
	return samples[ia] * (1.0 - b - c) + samples[ib] * b + samples[ic] * c
