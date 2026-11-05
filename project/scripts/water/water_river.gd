@tool
class_name WaterRiver
extends WaterBody
## Rio que sigue la curva: la altura de cada punto es la superficie del agua y el agua fluye del primer punto al ultimo.
## Donde la curva baja empinada aparecen rapidos y, casi en vertical, una cascada (cortina con espuma arriba y abajo); esos
## tramos empinados no tallan el terreno. Edita los puntos con las herramientas de Path3D; la malla se rehace en vivo.

@export_group("Forma")
## Ancho del agua en metros. Width Curve lo multiplica a lo largo del rio. En vivo.
@export_range(0.5, 80.0, 0.05, "suffix:m") var width := 6.0:
	set(value):
		width = value
		_queue_rebuild()
## Multiplicador del ancho a lo largo del rio (x: 0 = primer punto, 1 = ultimo). Vacio = ancho constante. En vivo.
@export var width_curve: Curve:
	set(value):
		if width_curve != null and width_curve.changed.is_connected(_queue_rebuild):
			width_curve.changed.disconnect(_queue_rebuild)
		width_curve = value
		if width_curve != null:
			width_curve.changed.connect(_queue_rebuild)
		_queue_rebuild()
## Metros que la malla se extiende bajo cada orilla para que su borde quede oculto en el terreno. En vivo.
@export_range(0.0, 4.0, 0.05, "suffix:m") var bank_overlap := 0.75:
	set(value):
		bank_overlap = value
		_queue_rebuild()
## Separacion en metros entre filas de la malla a lo largo del rio. Menor sigue mejor las curvas cerradas y las cascadas;
## coste: mas vertices (muy pocos en cualquier caso). En vivo.
@export_range(0.1, 4.0, 0.05, "suffix:m") var step := 0.5:
	set(value):
		step = value
		_queue_rebuild()
## Divisiones a lo ancho de la malla. Mas sigue mejor un fondo curvo en cascadas anchas. En vivo.
@export_range(1, 16, 1) var cross_segments := 4:
	set(value):
		cross_segments = value
		_queue_rebuild()
## Metros antes y despues de un cambio de pendiente (borde de cascada, base, inicio de rapidos) con espuma. En vivo.
@export_range(0.25, 10.0, 0.05, "suffix:m") var break_foam_length := 2.5:
	set(value):
		break_foam_length = value
		_queue_rebuild()

@export_group("Desembocadura")
## Funde el rio con el lago donde entra o sale de uno (WaterLake a la misma altura): la malla del rio sigue dentro del lago y
## se desvanece poco a poco, en vez de cortarse en la orilla. Apagado = corte en la orilla. En vivo.
@export var mouth_blend_enabled := true:
	set(value):
		mouth_blend_enabled = value
		_queue_rebuild()
## Metros dentro del lago, medidos desde la orilla, en que el rio pasa de opaco a invisible. Mayor = transicion mas suave y
## larga (la corriente del rio se ve entrar mas en el lago); menor = cambio mas rapido. Si la curva acaba antes, el rio se
## prolonga en linea recta. Coste: unas filas mas de malla. En vivo.
@export_range(0.5, 40.0, 0.25, "suffix:m") var mouth_blend_length := 8.0:
	set(value):
		mouth_blend_length = value
		_queue_rebuild()

@export_group("Cauce (Terrain3D)")
## 0-1: parte del ancho con fondo plano a Carve Depth; el resto sube en curva hasta la orilla. Al tallar.
@export_range(0.0, 1.0, 0.01) var bed_flat := 0.45
## Inclinacion en grados de la orilla interior de las curvas, donde un rio deposita arena: playas suaves frente a la margen
## exterior cortada (Bank Angle). Igual a Bank Angle = sin diferencia entre margenes. Al tallar.
@export_range(5.0, 80.0, 0.5, "suffix:degrees") var bank_angle_inner := 20.0
## Radio en metros de una curva cuya orilla interior ya es playa completa. Curvas mas abiertas mezclan hacia Bank Angle;
## mayor = playas tambien en curvas suaves. Al tallar.
@export_range(2.0, 200.0, 0.5, "suffix:m") var beach_bend_radius := 25.0

# Samples in world space for water queries (swimming, camera), refreshed with the mesh.
var _world_points := PackedVector3Array()
var _world_halves := PackedFloat32Array()
var _world_bounds := Rect2()

func _ready() -> void:
	set_notify_transform(true)
	super()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_queue_rebuild()

func _default_curve() -> Curve3D:
	var shape := Curve3D.new()
	shape.add_point(Vector3(0, 0, 0))
	shape.add_point(Vector3(0, 0, 20))
	return shape

func _cache_world_samples(points: PackedVector3Array, halves: PackedFloat32Array) -> void:
	_world_points = PackedVector3Array()
	_world_halves = halves
	for point in points:
		_world_points.append(to_global(point))
	if _world_points.is_empty():
		return
	_world_bounds = Rect2(Vector2(_world_points[0].x, _world_points[0].z), Vector2.ZERO)
	var widest := 0.0
	for i in _world_points.size():
		_world_bounds = _world_bounds.expand(Vector2(_world_points[i].x, _world_points[i].z))
		widest = maxf(widest, halves[i])
	_world_bounds = _world_bounds.grow(widest + 1.0)

func _surface_at(point: Vector3) -> Dictionary:
	var q := Vector2(point.x, point.z)
	if _world_points.size() < 2 or not _world_bounds.has_point(q):
		return {}
	var steep := tan(deg_to_rad(35.0))
	var rapids_start := deg_to_rad(style.rapids_start_angle if style != null else 4.0)
	var rapids_full := maxf(deg_to_rad(style.rapids_full_angle if style != null else 15.0), rapids_start + 0.01)
	var best := INF
	var result := {}
	for i in _world_points.size() - 1:
		var a := _world_points[i]
		var b := _world_points[i + 1]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var run := ab.length()
		# Falls hang in the air: nothing to swim in, the swimmer drops down the sheet.
		if absf(b.y - a.y) > maxf(run, 0.001) * steep:
			continue
		var u := clampf((q - Vector2(a.x, a.z)).dot(ab) / maxf(run * run, 0.000001), 0.0, 1.0)
		var d := q.distance_to(Vector2(a.x, a.z) + ab * u)
		var half := lerpf(_world_halves[i], _world_halves[i + 1], u)
		if d > half + 0.25 or d >= best:
			continue
		best = d
		var flat := ab / maxf(run, 0.001)
		# Same speed-up as the shader in rapids, weaker towards the banks.
		var rapids := smoothstep(rapids_start, rapids_full, atan2(maxf(a.y - b.y, 0.0), maxf(run, 0.001)))
		var edge := clampf((half - d) / maxf(half * 0.4, 0.01), 0.0, 1.0)
		var speed := _style_flow_speed() * (1.0 + rapids * 1.5) * lerpf(0.25, 1.0, edge)
		result = {"surface": lerpf(a.y, b.y, u), "flow": Vector3(flat.x, 0.0, flat.y) * speed, "edge": edge}
	return result

## Points (local), half widths, distances, tangents and slopes along the curve.
func _samples() -> Dictionary:
	var length := curve.get_baked_length()
	var count := maxi(2, ceili(length / step) + 1)
	var points := PackedVector3Array()
	var halves := PackedFloat32Array()
	var distances := PackedFloat32Array()
	for i in count:
		var d := length * i / (count - 1)
		points.append(curve.sample_baked(d, true))
		distances.append(d)
		var factor := width_curve.sample_baked(d / maxf(length, 0.001)) if width_curve != null else 1.0
		halves.append(maxf(width * factor, 0.1) * 0.5)
	var tangents := PackedVector3Array()
	var slopes := PackedFloat32Array()
	for i in count:
		var t := (points[mini(i + 1, count - 1)] - points[maxi(i - 1, 0)]).normalized()
		tangents.append(t)
		slopes.append(asin(clampf(absf(t.y), 0.0, 1.0)) / (PI * 0.5))
	return {"points": points, "halves": halves, "distances": distances, "tangents": tangents, "slopes": slopes}

func _build_mesh() -> ArrayMesh:
	if curve.point_count < 2 or curve.get_baked_length() < 0.01:
		_world_points = PackedVector3Array()
		return null
	var s := _samples()
	var points: PackedVector3Array = s.points
	var halves: PackedFloat32Array = s.halves
	var distances: PackedFloat32Array = s.distances
	var tangents: PackedVector3Array = s.tangents
	var slopes: PackedFloat32Array = s.slopes
	_cache_world_samples(points, halves)
	var lakes := []
	var outlines := []
	if is_inside_tree():
		for body in get_tree().get_nodes_in_group("water_bodies"):
			if body is WaterLake and body != self:
				lakes.append(body)
				outlines.append(body.shore_outline())
	if mouth_blend_enabled:
		_extend_into_lakes(s, lakes, outlines)
		points = s.points
		halves = s.halves
		distances = s.distances
		tangents = s.tangents
		slopes = s.slopes
	var count := points.size()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangent_data := PackedFloat32Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var indices := PackedInt32Array()
	var across := Vector3.RIGHT
	var columns := cross_segments + 1
	var window := ceili(break_foam_length / maxf(distances[1] - distances[0], 0.001))
	# Rows inside a lake at the same height: with the mouth blend they fade out along the river over Mouth Blend Length
	# from the shore and sit just above the lake (drawn after it, see _render_priority); without it they are skipped (one
	# row is kept past the shore).
	var in_lake := PackedByteArray()
	in_lake.resize(count)
	var mouth := PackedFloat32Array()
	mouth.resize(count)
	var sides := PackedFloat32Array()
	sides.resize(count)
	for i in count:
		var world := to_global(points[i])
		for l in lakes.size():
			var lake: WaterLake = lakes[l]
			var depth: float = lake.shore_depth(world, outlines[l])
			# The lake mesh reaches Bank Overlap past its outline: the river must stay above it there too, or the lake
			# edge shows on top of the river as a strip across it.
			if depth <= -(lake.bank_overlap + 0.5):
				continue
			if mouth_blend_enabled:
				var lifted := to_local(Vector3(world.x, lake.global_position.y + 0.01, world.z))
				var point := points[i]
				point.y = maxf(point.y, lifted.y)
				points[i] = point
			if depth <= 0.0:
				continue
			in_lake[i] = 1
			break
	if mouth_blend_enabled:
		_mouth_fades(in_lake, distances, mouth, sides)
	for i in count:
		var t := tangents[i]
		var flat := Vector3(t.x, 0.0, t.z)
		# Across stays horizontal; in a vertical drop it keeps the direction from above the fall.
		if flat.length() > 0.001:
			across = Vector3(-flat.z, 0.0, flat.x).normalized()
		var normal := across.cross(t).normalized()
		# Foam where the slope changes nearby: the lip and the base of a fall, the start of rapids.
		var nearby := slopes[i]
		for j in range(maxi(i - window, 0), mini(i + window + 1, count)):
			nearby = maxf(nearby, slopes[j])
		var break_foam := clampf((nearby - slopes[i]) * 2.0, 0.0, 1.0)
		var extent := halves[i] + bank_overlap
		for k in columns:
			var side := -1.0 + 2.0 * k / cross_segments
			vertices.append(points[i] + across * side * extent)
			normals.append(normal)
			tangent_data.append_array(PackedFloat32Array([t.x, t.y, t.z, 1.0]))
			uvs.append(Vector2(side * extent, distances[i]))
			var edge := clampf((halves[i] - absf(side) * extent) / maxf(halves[i], 0.01), 0.0, 1.0)
			colors.append(Color(slopes[i], break_foam, edge, 1.0))
			uv2s.append(Vector2(mouth[i], sides[i]))
		var buried := false
		if i > 0 and mouth_blend_enabled:
			buried = mouth[i] >= 1.0 and mouth[i - 1] >= 1.0
		elif i > 0:
			buried = in_lake[i] and in_lake[i - 1]
		if i > 0 and not buried:
			var row := i * columns
			var previous := row - columns
			for k in cross_segments:
				indices.append_array(PackedInt32Array([previous + k, row + k, previous + k + 1,
					previous + k + 1, row + k, row + k + 1]))
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

## Drawn after lakes (priority 0) so a mouth fading out blends over the lake surface.
func _render_priority() -> int:
	return 1

## Fade (0 opaque - 1 gone) of each row inside a lake, measured along the river from the shore it crossed. A run touching
## an end of the river fades toward that end; a run through the middle (the river crosses a lake) fades from both shores.
## Short runs fade over their own length so they always end invisible.
## Sides: 0-1 over the first metres past the shore, so the edges of the river soften right where it meets the lake
## instead of showing as straight lines over the lake surface.
func _mouth_fades(in_lake: PackedByteArray, distances: PackedFloat32Array, mouth: PackedFloat32Array,
		sides: PackedFloat32Array) -> void:
	var count := in_lake.size()
	var a := 0
	while a < count:
		if not in_lake[a]:
			a += 1
			continue
		var b := a
		while b + 1 < count and in_lake[b + 1]:
			b += 1
		var touches_start := a == 0
		var touches_end := b == count - 1
		var run := distances[b] - distances[a]
		if not (touches_start and touches_end):
			var both := not touches_start and not touches_end
			var length := maxf(minf(mouth_blend_length, run * (0.5 if both else 1.0)), 0.01)
			for i in range(a, b + 1):
				var from_entry := distances[i] - distances[a]
				var to_exit := distances[b] - distances[i]
				var inside := minf(from_entry, to_exit) if both else (from_entry if touches_end else to_exit)
				mouth[i] = clampf(inside / length, 0.0, 1.0)
				sides[i] = clampf(inside / minf(1.5, length), 0.0, 1.0)
		a = b + 1

## If an end of the curve stops at or inside a lake, prolongs it straight (flat, at the lake height) so the fade has Mouth
## Blend Length of river inside the lake. It never leaves the lake: in a small pond the fade is shorter. Mesh only: carving
## and water queries use the curve as drawn.
func _extend_into_lakes(s: Dictionary, lakes: Array, outlines: Array) -> void:
	# Packed arrays are values: edit local copies and store them back.
	var points: PackedVector3Array = s.points
	var halves: PackedFloat32Array = s.halves
	var distances: PackedFloat32Array = s.distances
	var tangents: PackedVector3Array = s.tangents
	var slopes: PackedFloat32Array = s.slopes
	var spacing := maxf(step, 0.1)
	for at_start in [false, true]:
		var count := points.size()
		var index := 0 if at_start else count - 1
		var end := points[index]
		var half := halves[index]
		var tangent := tangents[index]
		var outward := Vector3(tangent.x, 0.0, tangent.z) * (-1.0 if at_start else 1.0)
		if outward.length() < 0.001:
			continue
		outward = outward.normalized()
		var world := to_global(end)
		for l in lakes.size():
			var lake: WaterLake = lakes[l]
			var depth := lake.shore_depth(world, outlines[l])
			if depth < -(half + bank_overlap + 1.0):
				continue
			# River already inside the lake at this end.
			var inside := 0.0
			var j := index
			while j >= 0 and j < count and lake.shore_depth(to_global(points[j]), outlines[l]) > 0.0:
				inside = absf(distances[index] - distances[j])
				j += 1 if at_start else -1
			var level := to_local(Vector3(world.x, lake.global_position.y, world.z)).y
			var travelled := 0.0
			var entered := depth > 0.0
			var limit := mouth_blend_length + half * 2.0 + bank_overlap + 1.0
			while inside < mouth_blend_length and travelled < limit:
				var point := Vector3(end.x, level, end.z) + outward * (travelled + spacing)
				var point_depth := lake.shore_depth(to_global(point), outlines[l])
				if entered and point_depth <= 0.25:
					break
				travelled += spacing
				if point_depth > 0.0:
					entered = true
					inside += spacing
				if at_start:
					points.insert(0, point)
					halves.insert(0, half)
					distances.insert(0, distances[0] - spacing)
					tangents.insert(0, -outward)
					slopes.insert(0, 0.0)
				else:
					points.append(point)
					halves.append(half)
					distances.append(distances[distances.size() - 1] + spacing)
					tangents.append(outward)
					slopes.append(0.0)
			break
	s.points = points
	s.halves = halves
	s.distances = distances
	s.tangents = tangents
	s.slopes = slopes

func _collect_targets(targets: Dictionary) -> void:
	if curve == null or curve.point_count < 2:
		return
	var s := _samples()
	var points: PackedVector3Array = s.points
	var halves: PackedFloat32Array = s.halves
	var spacing := terrain.vertex_spacing
	var steep := tan(deg_to_rad(35.0))
	# Signed horizontal turn rate (rad/m) at each sample: positive turns toward +cross(tangent, side).
	var turns := PackedFloat32Array()
	turns.resize(points.size())
	for i in points.size():
		var before := points[maxi(i - 1, 0)]
		var after := points[mini(i + 1, points.size() - 1)]
		var t0 := Vector2(points[i].x - before.x, points[i].z - before.z)
		var t1 := Vector2(after.x - points[i].x, after.z - points[i].z)
		if t0.length() > 0.001 and t1.length() > 0.001:
			turns[i] = t0.angle_to(t1) / maxf((t0.length() + t1.length()) * 0.5, 0.001)
	for i in points.size() - 1:
		var a := to_global(points[i])
		var b := to_global(points[i + 1])
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var run := ab.length()
		# Falls and steep drops hang in front of the slope: carving them would cut a slot through the cliff.
		if absf(b.y - a.y) > maxf(run, 0.001) * steep:
			continue
		var reach := maxf(halves[i], halves[i + 1]) + bank_reach
		var low := Vector2i(floori((minf(a.x, b.x) - reach) / spacing), floori((minf(a.z, b.z) - reach) / spacing))
		var high := Vector2i(ceili((maxf(a.x, b.x) + reach) / spacing), ceili((maxf(a.z, b.z) + reach) / spacing))
		for z in range(low.y, high.y + 1):
			for x in range(low.x, high.x + 1):
				var q := Vector2(x * spacing, z * spacing)
				var u := clampf((q - Vector2(a.x, a.z)).dot(ab) / maxf(run * run, 0.000001), 0.0, 1.0)
				var d := q.distance_to(Vector2(a.x, a.z) + ab * u)
				var half := lerpf(halves[i], halves[i + 1], u)
				if d > half + bank_reach:
					continue
				var surface := lerpf(a.y, b.y, u)
				var waterline := surface - 0.05
				# Inner side of a bend (the side the river turns toward): gentler bank, the closer the bend the more.
				var turn := lerpf(turns[i], turns[i + 1], u)
				var side := ab.cross(q - Vector2(a.x, a.z) - ab * u)
				var inner := clampf(absf(turn) * beach_bend_radius, 0.0, 1.0) if side * turn > 0.0 else 0.0
				var angle := lerpf(bank_angle, bank_angle_inner, inner)
				var target: float
				if d <= half:
					target = lerpf(surface - carve_depth, waterline, _smooth(half * bed_flat, half, d))
				else:
					target = _bank_height(waterline, d - half, angle)
				var cell := Vector2i(x, z)
				if not targets.has(cell) or target < targets[cell].x:
					targets[cell] = Vector3(target, surface, angle)
