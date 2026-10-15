@tool
extends MeshInstance3D
## Cinta visual de sendero que sigue un Path3D y consulta la altura de Terrain3D.
## No escribe mapas de Terrain3D ni crea colisión: el jugador continúa caminando sobre el terreno.

@export_group("Referencias")
## Ruta del nodo Terrain3D. Se consulta al regenerar; el sistema nunca pinta ni modifica sus datos.
@export_node_path("Node3D") var terrain_path: NodePath = NodePath(""):
	set(value):
		terrain_path = value
		_queue_rebuild()

@export_group("Forma")
## Anchura sólida del sendero en metros. Aumentarla deja más espacio transitable visualmente.
@export_range(0.5, 20.0, 0.05, "suffix:m") var path_width := 3.4:
	set(value):
		path_width = value
		_queue_rebuild()
## Franja tintada en metros que disimula el borde contra el pasto. No cambia la ruta ni la colisión.
@export_range(0.0, 5.0, 0.05, "suffix:m") var edge_feather := 0.85:
	set(value):
		edge_feather = value
		_queue_rebuild()
## Distancia entre secciones generadas en metros. Menor valor sigue curvas y relieves mejor, a cambio de más triángulos.
@export_range(0.1, 4.0, 0.05, "suffix:m") var sample_spacing := 0.5:
	set(value):
		sample_spacing = value
		_queue_rebuild()
## Variación lateral máxima por borde en metros. Cero deja un borde geométricamente perfecto; reconstruye.
@export_range(0.0, 1.5, 0.01, "suffix:m") var edge_irregularity := 0.22:
	set(value):
		edge_irregularity = value
		_queue_rebuild()
## Tamaño en metros de las ondulaciones del borde. Mayor valor genera curvas más amplias y menos frecuentes.
@export_range(0.5, 20.0, 0.1, "suffix:m") var irregularity_scale := 3.0:
	set(value):
		irregularity_scale = value
		_queue_rebuild()
## Semilla reproducible para la irregularidad de ambos bordes.
@export var irregularity_seed := 17:
	set(value):
		irregularity_seed = value
		_queue_rebuild()
## Separación vertical en metros sobre el terreno. Evita z-fighting; mantener muy baja para que la ardilla parezca pisar el suelo.
@export_range(0.0, 0.2, 0.001, "suffix:m") var terrain_offset := 0.025:
	set(value):
		terrain_offset = value
		_queue_rebuild()

@export_group("Apariencia")
## Textura repetible del camino. Dejar vacía usa sólo el color; se actualiza al regenerar.
@export var albedo_texture: Texture2D:
	set(value):
		albedo_texture = value
		_queue_rebuild()
## Metros de recorrido por repetición vertical de la textura. Mayor valor hace el patrón visual más grande.
@export_range(0.25, 50.0, 0.05, "suffix:m") var texture_repeat_length := 3.0:
	set(value):
		texture_repeat_length = value
		_queue_rebuild()
## Tinte del interior del camino. Se multiplica con Albedo Texture cuando hay una asignada.
@export var path_color := Color(0.72, 0.52, 0.30, 1.0):
	set(value):
		path_color = value
		_queue_rebuild()
## Tinte de la franja exterior. Elegir un verde cercano al pasto integra visualmente el borde.
@export var edge_color := Color(0.39, 0.63, 0.27, 1.0):
	set(value):
		edge_color = value
		_queue_rebuild()
## Rugosidad del camino: uno es mate y cero brillante. No reconstruye la geometría.
@export_range(0.0, 1.0, 0.01) var roughness := 0.92:
	set(value):
		roughness = value
		_queue_rebuild()
## Permite que el camino proyecte sombras. Útil si tiene relieve real; apagado es más barato para esta cinta plana.
@export var cast_path_shadows := false:
	set(value):
		cast_path_shadows = value
		_queue_rebuild()

@export_group("Actualización")
## Reconstruye la malla ahora. Live Preview también se actualiza al editar la curva o los controles anteriores.
@export_tool_button("Regenerar sendero", "Reload") var regenerate_path = rebuild_path

var _queued_rebuild := false
var _observed_curve: Curve3D


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_connect_curve()
	_queue_rebuild()


func _exit_tree() -> void:
	if _observed_curve != null and _observed_curve.changed.is_connected(_queue_rebuild):
		_observed_curve.changed.disconnect(_queue_rebuild)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PARENTED:
		call_deferred("_connect_curve")


func _connect_curve() -> void:
	var route := get_parent() as Path3D
	_ensure_demo_curve(route)
	var next_curve := route.curve if route != null else null
	if _observed_curve == next_curve:
		return
	if _observed_curve != null and _observed_curve.changed.is_connected(_queue_rebuild):
		_observed_curve.changed.disconnect(_queue_rebuild)
	_observed_curve = next_curve
	if _observed_curve != null:
		_observed_curve.changed.connect(_queue_rebuild)
	_queue_rebuild()


func _ensure_demo_curve(route: Path3D) -> void:
	if route == null or route.curve != null:
		return
	var default_curve := Curve3D.new()
	default_curve.add_point(Vector3(-18.0, 0.0, -22.0))
	default_curve.add_point(Vector3(-8.0, 0.0, -8.0))
	default_curve.add_point(Vector3(5.0, 0.0, 3.0))
	default_curve.add_point(Vector3(14.0, 0.0, 20.0))
	route.curve = default_curve


func _queue_rebuild() -> void:
	if _queued_rebuild or not is_inside_tree():
		return
	_queued_rebuild = true
	call_deferred("rebuild_path")


func rebuild_path() -> void:
	_queued_rebuild = false
	_connect_curve()
	var route := get_parent() as Path3D
	if route == null or route.curve == null or route.curve.point_count < 2:
		mesh = null
		return
	var terrain := get_node_or_null(terrain_path)
	if terrain == null or terrain.get("data") == null:
		mesh = null
		push_warning("Terrain Path Overlay necesita un Terrain3D válido en Terrain Path.")
		return
	var terrain_data = terrain.get("data")
	var length := route.curve.get_baked_length()
	if length <= 0.01:
		mesh = null
		return

	var section_count := maxi(2, ceili(length / maxf(sample_spacing, 0.1)) + 1)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for section in range(section_count):
		var distance := length * float(section) / float(section_count - 1)
		_add_section(surface, route, terrain_data, distance, length)
	for section in range(section_count - 1):
		var current := section * 4
		var following := (section + 1) * 4
		for strip in range(3):
			surface.add_index(current + strip)
			surface.add_index(following + strip)
			surface.add_index(following + strip + 1)
			surface.add_index(current + strip)
			surface.add_index(following + strip + 1)
			surface.add_index(current + strip + 1)
	surface.generate_normals()
	mesh = surface.commit()
	material_override = _make_material()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_path_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _add_section(surface: SurfaceTool, route: Path3D, terrain_data: Variant, distance: float, length: float) -> void:
	var center_local := route.curve.sample_baked(distance, true)
	var previous_local := route.curve.sample_baked(maxf(0.0, distance - 0.05), true)
	var next_local := route.curve.sample_baked(minf(length, distance + 0.05), true)
	var tangent := (route.to_global(next_local) - route.to_global(previous_local))
	tangent.y = 0.0
	if tangent.length_squared() < 0.0001:
		tangent = Vector3.FORWARD
	else:
		tangent = tangent.normalized()
	var side := Vector3(-tangent.z, 0.0, tangent.x)
	var irregularity := _edge_noise(distance)
	var half_width := maxf(0.25, path_width * 0.5)
	var widths := PackedFloat32Array([
		maxf(0.05, half_width + edge_feather + irregularity.x),
		maxf(0.05, half_width + irregularity.x),
		maxf(0.05, half_width + irregularity.y),
		maxf(0.05, half_width + edge_feather + irregularity.y),
	])
	var colors := PackedColorArray([edge_color, path_color, path_color, edge_color])
	for index in range(4):
		var direction := -1.0 if index < 2 else 1.0
		var world_position := route.to_global(center_local) + side * widths[index] * direction
		var sampled_height: float = terrain_data.get_height(world_position)
		if not is_nan(sampled_height):
			world_position.y = sampled_height + terrain_offset
		surface.set_color(colors[index])
		surface.set_uv(Vector2(float(index) / 3.0, distance / maxf(0.25, texture_repeat_length)))
		surface.add_vertex(to_local(world_position))


func _edge_noise(distance: float) -> Vector2:
	var phase := float(irregularity_seed) * 0.6180339
	var wave := distance / maxf(0.5, irregularity_scale)
	return Vector2(
		sin(wave * 1.71 + phase) * edge_irregularity,
		sin(wave * 1.39 + phase * 1.71) * edge_irregularity
	)


func _make_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.albedo_texture = albedo_texture
	material.vertex_color_use_as_albedo = true
	material.roughness = roughness
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
