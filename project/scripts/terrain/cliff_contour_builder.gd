extends RefCounted
## Reconstructs independent strips from contours. No heightmap triangles survive in the wall.
var vertices := PackedVector3Array()
var indices := PackedInt32Array()
var normals := PackedVector3Array()
var relief := PackedFloat32Array()
var error := ""
var wall_count := 0
var _h := PackedFloat32Array()
var _w: int
var _d: int
var _spacing: float
var _origin: Vector2i
var _step: float
var _fade: float
var _overlap: float
var _smooth: int
var _limit: float
var _reach: float

func build(heights: PackedFloat32Array, mask: PackedFloat32Array, width: int, depth: int,
		spacing: float, origin: Vector2i, step: float, fade: float, overlap: float,
		smoothing: int, limit: float, reach: float) -> bool:
	_h = heights
	_w = width
	_d = depth
	_spacing = spacing
	_origin = origin
	_step = step
	_fade = fade
	_overlap = overlap
	_smooth = smoothing
	_limit = limit
	_reach = reach
	var visited := PackedByteArray()
	visited.resize(mask.size())
	visited.fill(0)
	for seed in mask.size():
		if visited[seed] or mask[seed] <= 0.001:
			continue
		var component: Array[int] = [seed]
		visited[seed] = 1
		var head := 0
		while head < component.size():
			var i := component[head]
			head += 1
			var x := i % _w
			var z := i / _w
			for delta in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
				var q: Vector2i = Vector2i(x, z) + delta
				if q.x < 0 or q.y < 0 or q.x >= _w or q.y >= _d:
					continue
				var j := q.y * _w + q.x
				if not visited[j] and mask[j] > 0.001:
					visited[j] = 1
					component.append(j)
		if not _component(component):
			return false
	compute_normals()
	return true

func _component(component: Array[int]) -> bool:
	var low := INF
	var high := -INF
	var cells := {}
	for i in component:
		low = minf(low, _h[i])
		high = maxf(high, _h[i])
		var p := Vector2i(i % _w, i / _w)
		for offset in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.UP, Vector2i(-1, -1)]:
			var c: Vector2i = p + offset
			if c.x >= 0 and c.y >= 0 and c.x < _w - 1 and c.y < _d - 1:
				cells[c] = true
	if high - low < _step:
		error = "Pared demasiado baja para Mesh Step. Reduce Mesh Step o aumenta Minimum Slope."
		return false
	var level := (low + high) * 0.5
	var points := PackedVector3Array()
	var ids := {}
	var links := {}
	for cell: Vector2i in cells:
		var corners := [cell, cell + Vector2i.RIGHT, cell + Vector2i.ONE, cell + Vector2i.DOWN]
		var crossings: Array[int] = []
		for side in 4:
			var a: Vector2i = corners[side]
			var b: Vector2i = corners[(side + 1) % 4]
			var ha := _h[a.y * _w + a.x]
			var hb := _h[b.y * _w + b.x]
			if is_nan(ha) or is_nan(hb):
				error = "Pared junto a datos ausentes; completa las regiones antes de generar."
				return false
			if (ha > level) == (hb > level):
				continue
			var ia := a.y * _w + a.x
			var ib := b.y * _w + b.x
			var key := Vector2i(mini(ia, ib), maxi(ia, ib))
			if not ids.has(key):
				ids[key] = points.size()
				var xz := Vector2(a + _origin).lerp(Vector2(b + _origin), (level - ha) / (hb - ha)) * _spacing
				points.append(Vector3(xz.x, level, xz.y))
			crossings.append(ids[key])
		if crossings.size() == 4:
			error = "Contorno ambiguo (silla o bifurcacion). Separa esa pared o suaviza el esculpido."
			return false
		if crossings.size() == 2:
			for k in 2:
				var id := crossings[k]
				if not links.has(id):
					links[id] = []
				links[id].append(crossings[1 - k])
	if links.is_empty():
		error = "No se encontro un contorno continuo para una de las paredes."
		return false
	var ends: Array[int] = []
	for id: int in links:
		if links[id].size() == 1:
			ends.append(id)
		elif links[id].size() != 2:
			error = "Contorno ramificado: esta pared necesita dividirse."
			return false
	if ends.size() != 0 and ends.size() != 2:
		error = "Varios contornos en una pared. Divide las terrazas antes de generar."
		return false
	var closed := ends.is_empty()
	var current: int = links.keys()[0] if closed else ends[0]
	var previous := -1
	var path := PackedVector3Array()
	var seen := {}
	while not seen.has(current):
		seen[current] = true
		path.append(points[current])
		var next := -1
		for neighbor: int in links[current]:
			if neighbor != previous:
				next = neighbor
				break
		if next < 0:
			break
		previous = current
		current = next
	if seen.size() != links.size():
		error = "La misma zona contiene contornos separados; no se conectan automaticamente."
		return false
	path = _resample(path, closed)
	var original := path.duplicate()
	for iteration in _smooth:
		var next := path.duplicate()
		for i in path.size():
			if not closed and (i == 0 or i == path.size() - 1):
				continue
			var target := path[i].lerp((path[posmod(i - 1, path.size())] + path[(i + 1) % path.size()]) * 0.5, 0.5)
			next[i] = original[i] + (target - original[i]).limit_length(_limit)
		path = next
	return _strip(path, closed, low, high)

func _resample(path: PackedVector3Array, closed: bool) -> PackedVector3Array:
	var chain := path.duplicate()
	if closed:
		chain.append(chain[0])
	var cumulative := PackedFloat32Array([0.0])
	for i in range(1, chain.size()):
		cumulative.append(cumulative[-1] + chain[i].distance_to(chain[i - 1]))
	var segments := maxi(3 if closed else 1, ceili(cumulative[-1] / _step))
	var result := PackedVector3Array()
	var edge := 1
	for i in segments if closed else segments + 1:
		var d := cumulative[-1] * float(i) / segments
		while edge < chain.size() - 1 and cumulative[edge] < d:
			edge += 1
		var fraction := (d - cumulative[edge - 1]) / maxf(0.00001, cumulative[edge] - cumulative[edge - 1])
		result.append(chain[edge - 1].lerp(chain[edge], fraction))
	return result

func _height(p: Vector3) -> float:
	var u := p.x / _spacing - _origin.x
	var v := p.z / _spacing - _origin.y
	var x := floori(u)
	var z := floori(v)
	if x < 0 or z < 0 or x >= _w - 1 or z >= _d - 1:
		return NAN
	var i := z * _w + x
	return lerpf(lerpf(_h[i], _h[i + 1], u - x), lerpf(_h[i + _w], _h[i + _w + 1], u - x), v - z)

func _endpoint(p: Vector3, direction: Vector3, target: float, rising: bool) -> Vector3:
	var increment := _spacing * 0.5
	var previous := p
	for s in range(1, ceili(_reach / increment) + 1):
		var q := p + direction * (s * increment)
		q.y = _height(q)
		if is_nan(q.y):
			break
		if (rising and q.y >= target) or (not rising and q.y <= target):
			# Continue half a sample onto the plateau, retaining its actual height.
			return q
		previous = q
	return Vector3(NAN, NAN, NAN)

func _strip(path: PackedVector3Array, closed: bool, low: float, high: float) -> bool:
	var top := PackedVector3Array()
	var bottom := PackedVector3Array()
	var outside := PackedVector3Array()
	var max_length := 0.0
	for i in path.size():
		var before := path[posmod(i - 1, path.size())] if closed or i > 0 else path[i]
		var after := path[(i + 1) % path.size()] if closed or i < path.size() - 1 else path[i]
		var tangent := (after - before).normalized()
		var normal := Vector3(tangent.z, 0, -tangent.x)
		var left := _height(path[i] + normal * _spacing)
		var right := _height(path[i] - normal * _spacing)
		if is_nan(left) or is_nan(right):
			error = "Faltan muestras a los lados del contorno."
			return false
		if left > right:
			normal = -normal
		var a := _endpoint(path[i], -normal, high - 0.01, true)
		var b := _endpoint(path[i], normal, low + 0.01, false)
		if is_nan(a.x) or is_nan(b.x):
			error = "No se encontro cima/pie continuo dentro de Profile Search Distance. La pared puede tener terrazas o alturas variables."
			return false
		top.append(a)
		bottom.append(b)
		outside.append(normal)
		max_length = maxf(max_length, a.distance_to(b))
	# Smooth endpoint runs along the regular contour, avoiding sampling stair steps.
	var original_top := top.duplicate()
	var original_bottom := bottom.duplicate()
	for iteration in _smooth:
		var next_top := top.duplicate()
		var next_bottom := bottom.duplicate()
		for i in path.size():
			if not closed and (i == 0 or i == path.size() - 1):
				continue
			var a := posmod(i - 1, path.size())
			var b := (i + 1) % path.size()
			var t := top[i].lerp((top[a] + top[b]) * 0.5, 0.5)
			var foot := bottom[i].lerp((bottom[a] + bottom[b]) * 0.5, 0.5)
			t.y = top[i].y
			foot.y = bottom[i].y
			next_top[i] = original_top[i] + (t - original_top[i]).limit_length(_limit)
			next_bottom[i] = original_bottom[i] + (foot - original_bottom[i]).limit_length(_limit)
		top = next_top
		bottom = next_bottom
	var inner := PackedVector3Array()
	var outer := PackedVector3Array()
	for i in path.size():
		inner.append(top[i] - outside[i] * _overlap)
		outer.append(bottom[i] + outside[i] * _overlap)
	for contour in [top, bottom, inner, outer]:
		if not _simple_contour(contour, closed):
			error = "El contorno o la banda de union se cruza consigo misma. Reduce Seam Overlap/Smoothing Limit o separa la pared."
			return false
	var rows := maxi(2, ceili(max_length / _step))
	var collar_rows := maxi(1, ceili(_overlap / _step))
	var start := vertices.size()
	var columns := path.size()
	for row in range(-collar_rows, rows + collar_rows + 1):
		for col in columns:
			var p: Vector3
			var weight := 0.0
			if row < 0:
				p = top[col] - outside[col] * (_overlap * float(-row) / collar_rows)
				p.y = _height(p)
			elif row > rows:
				p = bottom[col] + outside[col] * (_overlap * float(row - rows) / collar_rows)
				p.y = _height(p)
			else:
				p = top[col].lerp(bottom[col], float(row) / rows)
				weight = smoothstep(0.0, _fade, p.y - bottom[col].y) * smoothstep(0.0, _fade, top[col].y - p.y)
				if not closed:
					weight *= smoothstep(0.0, _fade, col * _step) * smoothstep(0.0, _fade, (columns - 1 - col) * _step)
			if is_nan(p.y):
				error = "La banda de union sale del terreno. Reduce Seam Overlap o amplia las regiones."
				return false
			vertices.append(p)
			relief.append(weight)
	for row in rows + collar_rows * 2:
		for col in columns if closed else columns - 1:
			var a := start + row * columns + col
			var b := start + row * columns + (col + 1) % columns
			var c := a + columns
			var d := b + columns
			var n := (bottom[col] - top[col]).cross(path[(col + 1) % columns] - path[col])
			if n.dot(outside[col]) < 0.0:
				indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
			else:
				indices.append_array(PackedInt32Array([a, b, c, b, d, c]))
	wall_count += 1
	return true

func _simple_contour(path: PackedVector3Array, closed: bool) -> bool:
	var segments := path.size() if closed else path.size() - 1
	for i in segments:
		var a := Vector2(path[i].x, path[i].z)
		var b := Vector2(path[(i + 1) % path.size()].x, path[(i + 1) % path.size()].z)
		for j in range(i + 2, segments):
			if closed and i == 0 and j == segments - 1:
				continue
			var c := Vector2(path[j].x, path[j].z)
			var d := Vector2(path[(j + 1) % path.size()].x, path[(j + 1) % path.size()].z)
			if Geometry2D.segment_intersects_segment(a, b, c, d) != null:
				return false
	return true

func compute_normals() -> void:
	normals.resize(vertices.size())
	normals.fill(Vector3.ZERO)
	for t in range(0, indices.size(), 3):
		var a := indices[t]
		var b := indices[t + 1]
		var c := indices[t + 2]
		var n := (vertices[c] - vertices[a]).cross(vertices[b] - vertices[a])
		normals[a] += n
		normals[b] += n
		normals[c] += n
	for i in normals.size():
		normals[i] = normals[i].normalized()

