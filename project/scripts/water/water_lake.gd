@tool
class_name WaterLake
extends WaterBody
## Lago o estanque: agua quieta con el contorno de la curva (cerrada sola) y la superficie a la altura de este nodo. Mueve
## el nodo en Y para subir o bajar el nivel; la altura de los puntos de la curva se ignora. La malla se rehace en vivo.

@export_group("Forma")
## Metros que la malla se extiende bajo la orilla para que su borde quede oculto en el terreno. En vivo.
@export_range(0.0, 4.0, 0.05, "suffix:m") var bank_overlap := 0.75:
	set(value):
		bank_overlap = value
		_queue_rebuild()

@export_group("Cauce (Terrain3D)")
## Metros desde la orilla hacia dentro en que el fondo baja hasta Carve Depth. Menor = pozo de bordes bruscos; mayor = playa
## que entra suave en el agua. Al tallar.
@export_range(0.25, 40.0, 0.25, "suffix:m") var shore_width := 4.0

# Outline in world XZ for water queries (swimming, camera), refreshed with the mesh.
var _world_polygon := PackedVector2Array()
var _world_bounds := Rect2()

func _ready() -> void:
	set_notify_transform(true)
	super()

func _notification(what: int) -> void:
	# Flow space is world XZ: moving the lake keeps the pattern fixed in the world.
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_queue_rebuild()

func _default_curve() -> Curve3D:
	var shape := Curve3D.new()
	for i in 8:
		var angle := TAU * i / 8.0
		shape.add_point(Vector3(cos(angle), 0.0, sin(angle)) * 6.0)
	return shape

## Outline in local XZ (curve baked points, closed).
func _outline() -> PackedVector2Array:
	var outline := PackedVector2Array()
	for point in curve.get_baked_points():
		var flat := Vector2(point.x, point.z)
		if outline.is_empty() or outline[outline.size() - 1].distance_to(flat) > 0.05:
			outline.append(flat)
	if outline.size() > 2 and outline[0].distance_to(outline[outline.size() - 1]) < 0.05:
		outline.remove_at(outline.size() - 1)
	return outline

## True if a world point lies over this lake (inside its outline, within Margin metres of its surface height).
## Rivers use it to stop where they enter a lake instead of drawing a second surface on top.
func covers(point: Vector3, margin := 0.5) -> bool:
	if curve == null or curve.point_count < 3 or absf(point.y - global_position.y) > margin:
		return false
	var local := to_local(point)
	return Geometry2D.is_point_in_polygon(Vector2(local.x, local.z), _outline())

## Horizontal metres from a world point to the shore: positive inside the lake, negative outside. -INF if the point is
## not within Margin metres of the lake surface height. Rivers use it to fade into the lake at their mouth.
func shore_depth(point: Vector3, outline: PackedVector2Array, margin := 0.5) -> float:
	if outline.size() < 3 or absf(point.y - global_position.y) > margin:
		return -INF
	var local := to_local(point)
	var flat := Vector2(local.x, local.z)
	var nearest := INF
	for i in outline.size():
		var closest := Geometry2D.get_closest_point_to_segment(flat, outline[i], outline[(i + 1) % outline.size()])
		nearest = minf(nearest, flat.distance_to(closest))
	return nearest if Geometry2D.is_point_in_polygon(flat, outline) else -nearest

## Outline in local XZ, for repeated shore_depth calls.
func shore_outline() -> PackedVector2Array:
	return _outline() if curve != null and curve.point_count >= 3 else PackedVector2Array()

func _surface_at(point: Vector3) -> Dictionary:
	if _world_polygon.size() < 3 or not _world_bounds.has_point(Vector2(point.x, point.z)):
		return {}
	if not Geometry2D.is_point_in_polygon(Vector2(point.x, point.z), _world_polygon):
		return {}
	return {"surface": global_position.y, "flow": Vector3.ZERO, "edge": 1.0}

func _build_mesh() -> ArrayMesh:
	_world_polygon = PackedVector2Array()
	if curve.point_count < 3:
		return null
	var outline := _outline()
	if outline.size() < 3:
		return null
	for point in outline:
		var world := to_global(Vector3(point.x, 0.0, point.y))
		_world_polygon.append(Vector2(world.x, world.z))
	_world_bounds = Rect2(_world_polygon[0], Vector2.ZERO)
	for point in _world_polygon:
		_world_bounds = _world_bounds.expand(point)
	if bank_overlap > 0.0:
		var grown := Geometry2D.offset_polygon(outline, bank_overlap, Geometry2D.JOIN_ROUND)
		if not grown.is_empty():
			outline = grown[0]
	var triangles := Geometry2D.triangulate_polygon(outline)
	if triangles.is_empty():
		push_warning("%s: el contorno del lago se cruza consigo mismo." % name)
		return null
	var origin := global_position
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangent_data := PackedFloat32Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	for point in outline:
		vertices.append(Vector3(point.x, 0.0, point.y))
		normals.append(Vector3.UP)
		tangent_data.append_array(PackedFloat32Array([1.0, 0.0, 0.0, 1.0]))
		colors.append(Color(0.0, 0.0, 1.0, 0.0))
		uvs.append(Vector2(origin.x + point.x, origin.z + point.y))
		# UV2.x = mouth fade of rivers (0 = opaque).
		uv2s.append(Vector2.ZERO)
	# Triangulation winds clockwise seen from above; flip so the faces look up.
	var indices := PackedInt32Array()
	for i in range(0, triangles.size(), 3):
		indices.append_array(PackedInt32Array([triangles[i], triangles[i + 2], triangles[i + 1]]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangent_data
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _collect_targets(targets: Dictionary) -> void:
	if curve == null or curve.point_count < 3:
		return
	var polygon := PackedVector2Array()
	for point in _outline():
		var world := to_global(Vector3(point.x, 0.0, point.y))
		polygon.append(Vector2(world.x, world.z))
	if polygon.size() < 3:
		return
	var surface := global_position.y
	var waterline := surface - 0.05
	var spacing := terrain.vertex_spacing
	var low := polygon[0]
	var high := polygon[0]
	for point in polygon:
		low = low.min(point)
		high = high.max(point)
	low -= Vector2.ONE * bank_reach
	high += Vector2.ONE * bank_reach
	for z in range(floori(low.y / spacing), ceili(high.y / spacing) + 1):
		for x in range(floori(low.x / spacing), ceili(high.x / spacing) + 1):
			var q := Vector2(x * spacing, z * spacing)
			var edge := INF
			for i in polygon.size():
				var closest := Geometry2D.get_closest_point_to_segment(q, polygon[i], polygon[(i + 1) % polygon.size()])
				edge = minf(edge, q.distance_to(closest))
			var target: float
			if Geometry2D.is_point_in_polygon(q, polygon):
				target = lerpf(waterline, surface - carve_depth, _smooth(0.0, shore_width, edge))
			elif edge <= bank_reach:
				target = _bank_height(waterline, edge, bank_angle)
			else:
				continue
			targets[Vector2i(x, z)] = Vector3(target, surface, bank_angle)
