extends RefCounted
## Builds cliff strips along downhill flow lines that follow the sculpted profile, shoulder included.
## Each column has five segments: fade, collar, cliff, collar, fade. Relief is a function of position (zero
## off the wall), so collars and fades rest on the sculpture and overlapping strips fold identically.
## Walls are seeded from height contours in several passes: terraces and variable tops get their own strips.

const CLIFF := 2
const MIN_GROUP := 32

var vertices := PackedVector3Array()
var indices := PackedInt32Array()
var normals := PackedVector3Array()
## Heightmap normal computed like Terrain3D. Drives texturing and the lighting where the mesh meets the terrain.
var terrain_normals := PackedVector3Array()
## 0-1 fold weight from the position (see _world_relief), reduced at free strip ends.
var relief := PackedFloat32Array()
## 0-1 opacity: below 1 only in the seam fade band.
var alpha := PackedFloat32Array()
## Smoothed sculpted normal (Normal Radius) at each vertex: fold direction. Depends only on the position,
## so overlapping strips fold identically and their joints do not show.
var fold_normals := PackedVector3Array()
var error := ""
var wall_count := 0
var reach_hits := 0
## Detected wall vertices that no strip covers: they keep the sculpted Terrain3D without folds.
var bare_cells := 0
var wall_cells := 0

# Settings assigned by the generator before build().
var step := 0.5
var fade := 2.0
var overlap := 2.0
var seam_fade := 1.0
var smoothing := 16
var limit := 0.5
var reach := 16.0
var break_distance := 2.0
var passes := 6
var minimum_slope := 60.0
var reentry_slope := 70.0

var _h := PackedFloat32Array()
# Per mask vertex: 0-1 position between the foot (lo) and the top (hi) of its own wall, found along the slope.
var _wall_t := PackedFloat32Array()
var _wall_lo := PackedFloat32Array()
var _wall_hi := PackedFloat32Array()
# Vertices with a known wall (mask, plus a band around it that inherits the nearest wall).
var _wall_known := PackedByteArray()
var _n := PackedVector3Array()
var _w := 0
var _d := 0
var _spacing := 1.0
var _origin := Vector2i.ZERO
var _steep_cos := 0.5
var _reentry_cos := 0.34
# Grid vertices under generated quads: owning strip of the cliff band, maximum relief, deepest opaque inset and any quad.
var _cliff_owner := PackedInt32Array()
var _strips := []
var _relief_cover := PackedFloat32Array()
var _inset_cover := PackedFloat32Array()
# Grid vertices near a free strip end, in plan: on near-vertical walls the inset alone cannot tell rows apart.
var _no_hole := PackedByteArray()
# Per vertex: distance along the mesh surface to its nearest translucent or open edge.
var _inset := PackedFloat32Array()
var _footprint := PackedByteArray()
var _relief_cells := PackedInt32Array()
var _footprint_cells := PackedInt32Array()

func build(heights: PackedFloat32Array, slope_normals: PackedVector3Array, mask: PackedFloat32Array,
		width: int, depth: int, spacing: float, origin: Vector2i) -> bool:
	_h = heights
	_n = slope_normals
	_w = width
	_d = depth
	_spacing = spacing
	_origin = origin
	_steep_cos = cos(deg_to_rad(minimum_slope))
	_reentry_cos = cos(deg_to_rad(maxf(minimum_slope, reentry_slope)))
	_cliff_owner.resize(_w * _d)
	_cliff_owner.fill(-1)
	_inset_cover.resize(_w * _d)
	_inset_cover.fill(-1.0)
	_no_hole.resize(_w * _d)
	_no_hole.fill(0)
	_footprint.resize(_w * _d)
	_footprint.fill(0)
	_relief_cover.resize(_w * _d)
	_relief_cover.fill(0.0)
	var cells := PackedInt32Array()
	for i in mask.size():
		if mask[i] > 0.001:
			cells.append(i)
	if cells.is_empty():
		return true
	var target := PackedByteArray()
	target.resize(_w * _d)
	for i in cells:
		target[i] = 1
	_wall_field(cells)
	# First pass: the middle of each wall, whatever its height, so every wall gets one continuous strip.
	# Later passes seed what is still uncovered at its median height (terrace junctions, leftovers).
	for iteration in passes:
		var added := 0
		for group in _groups(cells, target):
			var pieces := _contours(group, true, 0.5) if iteration == 0 else _contours(group, false, _median(group))
			for piece in pieces:
				added += _piece(piece[0], piece[1])
		if added == 0 and iteration > 0:
			break
		for i in cells:
			if target[i] and _covered_index(i):
				target[i] = 0
	wall_cells = cells.size()
	for i in cells:
		if not _covered_index(i):
			bare_cells += 1
	if wall_count == 0:
		error = "No se pudo construir ninguna franja. Revisa Minimum Slope, Profile Search Distance o Mesh Step."
		return false
	_finalize()
	compute_normals()
	return true

## Terrain vertices (global pixels, x/z pairs) that must be holes: under relief plus one ring, so no terrain
## triangle crosses a fold, and at least Seam Overlap (measured on the mesh surface) inside the opaque mesh:
## Terrain3D LODs remove whole coarse triangles around each hole and the collar must hide them.
func hole_cells() -> PackedInt32Array:
	var result := PackedInt32Array()
	var inset := maxf(overlap, _spacing * 2.0) - 0.001
	var checked := PackedByteArray()
	checked.resize(_w * _d)
	for i in _relief_cells:
		var x := i % _w
		var z := i / _w
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var j := (z + dz) * _w + x + dx
				if x + dx < 1 or z + dz < 1 or x + dx >= _w - 1 or z + dz >= _d - 1 or checked[j]:
					continue
				checked[j] = 1
				if _inset_cover[j] >= inset and not _no_hole[j]:
					result.append(j % _w + _origin.x)
					result.append(j / _w + _origin.y)
	return result

## Every terrain vertex under the generated mesh, global pixels as x/z pairs.
func footprint_cells() -> PackedInt32Array:
	var result := PackedInt32Array()
	for i in _footprint_cells:
		result.append(i % _w + _origin.x)
		result.append(i / _w + _origin.y)
	return result

func _covered_index(i: int) -> bool:
	var x := i % _w
	var z := i / _w
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if x + dx >= 0 and z + dz >= 0 and x + dx < _w and z + dz < _d and _cliff_owner[i + dz * _w + dx] >= 0:
				return true
	return false

func _groups(cells: PackedInt32Array, target: PackedByteArray) -> Array:
	var groups := []
	var visited := PackedByteArray()
	visited.resize(_w * _d)
	for seed in cells:
		if visited[seed] or not target[seed]:
			continue
		var group := PackedInt32Array([seed])
		visited[seed] = 1
		var head := 0
		while head < group.size():
			var i := group[head]
			head += 1
			var x := i % _w
			var z := i / _w
			for delta in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
				var q: Vector2i = Vector2i(x, z) + delta
				if q.x < 0 or q.y < 0 or q.x >= _w or q.y >= _d:
					continue
				var j := q.y * _w + q.x
				if not visited[j] and target[j]:
					visited[j] = 1
					group.append(j)
		if group.size() >= MIN_GROUP:
			groups.append(group)
	return groups

func _median(group: PackedInt32Array) -> float:
	var values := PackedFloat32Array()
	for i in group:
		values.append(_h[i])
	values.sort()
	return values[values.size() / 2]

## Foot and top of the wall under each mask vertex: follow the steepest neighbour up (or down) until it leaves
## the mask. Processed in height order so each vertex reuses its neighbour's answer.
func _wall_field(cells: PackedInt32Array) -> void:
	_wall_t.resize(_w * _d)
	_wall_t.fill(NAN)
	_wall_lo.resize(_w * _d)
	_wall_hi.resize(_w * _d)
	var inside := PackedByteArray()
	inside.resize(_w * _d)
	var order := []
	for i in cells:
		inside[i] = 1
		order.append(Vector2(_h[i], i))
	order.sort()
	for k in order.size():
		_wall_lo[int(order[k].y)] = _wall_end(int(order[k].y), inside, _wall_lo, -1.0)
	for k in range(order.size() - 1, -1, -1):
		_wall_hi[int(order[k].y)] = _wall_end(int(order[k].y), inside, _wall_hi, 1.0)
	for i in cells:
		if _wall_hi[i] - _wall_lo[i] > step:
			_wall_t[i] = (_h[i] - _wall_lo[i]) / (_wall_hi[i] - _wall_lo[i])
	# Collars and fades reach past the mask: give that band the foot and top of the nearest wall.
	_wall_known = inside
	var front := cells.duplicate()
	for ring in ceili((overlap + seam_fade) / _spacing) + 2:
		var next := PackedInt32Array()
		for i in front:
			var x := i % _w
			var z := i / _w
			for delta in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
				var q: Vector2i = Vector2i(x, z) + delta
				if q.x < 0 or q.y < 0 or q.x >= _w or q.y >= _d:
					continue
				var j := q.y * _w + q.x
				if not _wall_known[j]:
					_wall_known[j] = 1
					_wall_lo[j] = _wall_lo[i]
					_wall_hi[j] = _wall_hi[i]
					next.append(j)
		front = next

## Fold weight as a function of position only: fades within Edge Fade Meters of the foot and top of the
## wall at that point. Strips that overlap therefore fold the same surface identically. The wall is taken
## from the nearby vertex closest in height whose wall spans this height, so stacked terraces stay apart.
func _world_relief(p: Vector3) -> float:
	var g := Vector2(p.x, p.z) / _spacing - Vector2(_origin)
	var cx := roundi(g.x)
	var cz := roundi(g.y)
	var best := -1
	var gap := INF
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var x := cx + dx
			var z := cz + dz
			if x < 0 or z < 0 or x >= _w or z >= _d:
				continue
			var i := z * _w + x
			if not _wall_known[i] or p.y < _wall_lo[i] or p.y > _wall_hi[i]:
				continue
			if absf(_h[i] - p.y) < gap:
				gap = absf(_h[i] - p.y)
				best = i
	if best < 0:
		return 0.0
	return smoothstep(0.0, fade, p.y - _wall_lo[best]) * smoothstep(0.0, fade, _wall_hi[best] - p.y)

func _wall_end(i: int, inside: PackedByteArray, known: PackedFloat32Array, direction: float) -> float:
	var x := i % _w
	var z := i / _w
	var best := -1
	var best_rise := 0.0
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if (dx == 0 and dz == 0) or x + dx < 0 or z + dz < 0 or x + dx >= _w or z + dz >= _d:
				continue
			var j := i + dz * _w + dx
			var rise := (_h[j] - _h[i]) * direction / Vector2(dx, dz).length()
			if rise > best_rise:
				best_rise = rise
				best = j
	if best < 0:
		return _h[i]
	return known[best] if inside[best] else _h[best]

## Iso-lines at level inside the group, of the wall field (wall) or of the height. Saddles are resolved by the cell average; pieces may be open.
## On the wall field, cells whose walls end at clearly different heights are skipped: a terrace junction
## splits the contour instead of joining two walls.
func _contours(group: PackedInt32Array, wall: bool, level: float) -> Array:
	var field := _wall_t if wall else _h
	var quads := {}
	for i in group:
		var p := Vector2i(i % _w, i / _w)
		for offset in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.UP, Vector2i(-1, -1)]:
			var c: Vector2i = p + offset
			if c.x >= 0 and c.y >= 0 and c.x < _w - 1 and c.y < _d - 1:
				quads[c] = true
	var points := PackedVector3Array()
	var ids := {}
	var links := {}
	for cell: Vector2i in quads:
		var base := cell.y * _w + cell.x
		var corner := PackedInt32Array([base, base + 1, base + _w + 1, base + _w])
		var heights := PackedFloat32Array()
		var nan := false
		for k in 4:
			heights.append(field[corner[k]])
			nan = nan or is_nan(heights[k])
		if nan:
			continue
		if wall:
			var lo := PackedFloat32Array([_wall_lo[corner[0]], _wall_lo[corner[1]], _wall_lo[corner[2]], _wall_lo[corner[3]]])
			var hi := PackedFloat32Array([_wall_hi[corner[0]], _wall_hi[corner[1]], _wall_hi[corner[2]], _wall_hi[corner[3]]])
			lo.sort()
			hi.sort()
			if lo[3] - lo[0] > break_distance or hi[3] - hi[0] > break_distance:
				continue
		var crossing := PackedInt32Array([-1, -1, -1, -1])
		var count := 0
		for e in 4:
			var ha := heights[e]
			var hb := heights[(e + 1) % 4]
			if (ha > level) == (hb > level):
				continue
			var ia := corner[e]
			var ib := corner[(e + 1) % 4]
			var key := Vector2i(mini(ia, ib), maxi(ia, ib))
			if not ids.has(key):
				ids[key] = points.size()
				var a := Vector2(ia % _w, ia / _w) + Vector2(_origin)
				var b := Vector2(ib % _w, ib / _w) + Vector2(_origin)
				var fraction := (level - ha) / (hb - ha)
				var xz := a.lerp(b, fraction) * _spacing
				points.append(Vector3(xz.x, lerpf(_h[ia], _h[ib], fraction), xz.y))
			crossing[e] = ids[key]
			count += 1
		if count == 2:
			var pair := PackedInt32Array()
			for e in 4:
				if crossing[e] >= 0:
					pair.append(crossing[e])
			_link(links, pair[0], pair[1])
		elif count == 4:
			# Cut off each corner whose side differs from the cell centre.
			var centre := (heights[0] + heights[1] + heights[2] + heights[3]) * 0.25 > level
			for k in 4:
				if (heights[k] > level) != centre:
					_link(links, crossing[(k + 3) % 4], crossing[k])
	var starts: Array[int] = []
	for id: int in links:
		if links[id].size() == 1:
			starts.append(id)
	for id: int in links:
		if links[id].size() != 1:
			starts.append(id)
	var pieces := []
	var seen := {}
	for start in starts:
		if seen.has(start):
			continue
		var closed: bool = links[start].size() == 2
		var path := PackedVector3Array()
		var previous := -1
		var current := start
		while current >= 0 and not seen.has(current):
			seen[current] = true
			path.append(points[current])
			var next := -1
			for neighbor: int in links[current]:
				if neighbor != previous and not seen.has(neighbor):
					next = neighbor
					break
			previous = current
			current = next
		if path.size() < 3:
			continue
		path = _resample(path, closed)
		var original := path.duplicate()
		for iteration in smoothing:
			var smoothed := path.duplicate()
			for i in path.size():
				if not closed and (i == 0 or i == path.size() - 1):
					continue
				var target := path[i].lerp((path[posmod(i - 1, path.size())] + path[(i + 1) % path.size()]) * 0.5, 0.5)
				smoothed[i] = original[i] + (target - original[i]).limit_length(limit)
			path = smoothed
		pieces.append([path, closed])
	return pieces

func _link(links: Dictionary, a: int, b: int) -> void:
	if not links.has(a):
		links[a] = []
	if not links.has(b):
		links[b] = []
	links[a].append(b)
	links[b].append(a)

func _resample(path: PackedVector3Array, closed: bool) -> PackedVector3Array:
	var chain := path.duplicate()
	if closed:
		chain.append(chain[0])
	var cumulative := PackedFloat32Array([0.0])
	for i in range(1, chain.size()):
		cumulative.append(cumulative[-1] + chain[i].distance_to(chain[i - 1]))
	var segments := maxi(3 if closed else 1, ceili(cumulative[-1] / step))
	var result := PackedVector3Array()
	var edge := 1
	for i in segments if closed else segments + 1:
		var d := cumulative[-1] * float(i) / segments
		while edge < chain.size() - 1 and cumulative[edge] < d:
			edge += 1
		var fraction := (d - cumulative[edge - 1]) / maxf(0.00001, cumulative[edge] - cumulative[edge - 1])
		result.append(chain[edge - 1].lerp(chain[edge], fraction))
	return result

## Builds the strips of one contour piece. Columns already covered, not steep, or too different from their
## neighbour split the piece into runs; the gaps keep the sculpted Terrain3D.
func _piece(path: PackedVector3Array, closed: bool) -> int:
	var count := path.size()
	var columns := []
	for p in path:
		var xz := _steep_seed(Vector2(p.x, p.z))
		var column = null
		if not is_nan(xz.x) and not _covered_at(xz):
			column = _column(xz)
			if column.is_empty():
				column = null
		columns.append(column)
	var cut := PackedByteArray()
	cut.resize(count)
	for i in count:
		var j := (i + 1) % count
		if (not closed and i == count - 1) or columns[i] == null or columns[j] == null \
				or columns[i].bottom.distance_to(columns[j].bottom) > break_distance \
				or columns[i].top.distance_to(columns[j].top) > break_distance:
			cut[i] = 1
	var first_cut := cut.find(1)
	if first_cut < 0:
		return 1 if _strip(columns, true) else 0
	var added := 0
	var run := []
	for k in count:
		var i := (first_cut + 1 + k) % count
		if columns[i] != null:
			run.append(columns[i])
		if cut[i]:
			if run.size() >= 2:
				# Carry the strip past its end along the same wall (a terrace junction or another strip):
				# the overlap folds identically, so the joint does not show.
				_extend(run, true)
				_extend(run, false)
				if _strip(run, false):
					added += 1
			run = []
	return added

## Adds columns beyond one end of the run, walking along the wall at the seed height. Each new column is
## cut to the height range of the run's end, so a strip of a 20-60 m wall can continue over a 0-60 m
## junction wall. Stops where the wall no longer spans that range.
func _extend(run: Array, at_start: bool) -> void:
	var last: Dictionary = run[0] if at_start else run[-1]
	var previous: Dictionary = run[1] if at_start else run[-2]
	var direction := (Vector2(last.xz) - Vector2(previous.xz)).normalized()
	var level := _point(last, last.seed).y
	var bottom: float = last.bottom.y
	var top: float = last.top.y
	for k in ceili((overlap + seam_fade + fade) / step) + 1:
		var guess := _steep_seed(Vector2(last.xz) + direction * step)
		if is_nan(guess.x):
			return
		var column := _clip(_column(guess), level, bottom, top)
		if column.is_empty() or column.bottom.distance_to(last.bottom) > break_distance \
				or column.top.distance_to(last.top) > break_distance:
			return
		var advance := Vector2(column.xz) - Vector2(last.xz)
		if advance.length() < step * 0.25:
			return
		direction = advance.normalized()
		if at_start:
			run.push_front(column)
		else:
			run.append(column)
		last = column

## Re-seeds a column at level and limits its cliff to [bottom, top] heights; empty if the column's own
## cliff does not span that range (within Strip Break Distance).
func _clip(column: Dictionary, level: float, bottom: float, top: float) -> Dictionary:
	if column.is_empty() or column.bottom.y > bottom + break_distance or column.top.y < top - break_distance:
		return {}
	var points: PackedVector3Array = column.points
	var cumulative: PackedFloat32Array = column.cumulative
	var seed := -1.0
	for k in points.size() - 1:
		if (points[k].y - level) * (points[k + 1].y - level) <= 0.0 and points[k].y != points[k + 1].y:
			var s := lerpf(cumulative[k], cumulative[k + 1], (level - points[k].y) / (points[k + 1].y - points[k].y))
			if seed < 0.0 or absf(s - column.seed) < absf(seed - column.seed):
				seed = s
	if seed < 0.0:
		return {}
	var low := _arc_at(column, seed, maxf(bottom, column.bottom.y), -1)
	var high := _arc_at(column, seed, minf(top, column.top.y), 1)
	var clipped := column.duplicate()
	var anchor := _point(column, seed)
	clipped.seed = seed
	clipped.xz = Vector2(anchor.x, anchor.z)
	clipped.low = seed - low
	clipped.high = high - seed
	clipped.bottom = _point(column, low)
	clipped.top = _point(column, high)
	return clipped

## Arc length where the column first reaches height, walking from s down (-1) or up (+1).
func _arc_at(column: Dictionary, s: float, height: float, direction: int) -> float:
	var points: PackedVector3Array = column.points
	var cumulative: PackedFloat32Array = column.cumulative
	var k := clampi(cumulative.bsearch(s), 1, points.size() - 1)
	if direction < 0:
		for j in range(k, 0, -1):
			if points[j - 1].y <= height:
				return lerpf(cumulative[j - 1], cumulative[j], clampf((height - points[j - 1].y) / maxf(0.0001, points[j].y - points[j - 1].y), 0.0, 1.0))
		return 0.0
	for j in range(k - 1, points.size() - 1):
		if points[j + 1].y >= height:
			return lerpf(cumulative[j], cumulative[j + 1], clampf((height - points[j].y) / maxf(0.0001, points[j + 1].y - points[j].y), 0.0, 1.0))
	return cumulative[-1]

## A contour point may cross a softer spot of the wall: slide along the flow line, up to Strip Break
## Distance, to the nearest steep point. Returns NAN when there is none.
func _steep_seed(xz: Vector2) -> Vector2:
	if _sample_normal(xz).y <= _steep_cos:
		return xz
	var n := _sample_normal(xz)
	var downhill := Vector2(n.x, n.z)
	if downhill.length_squared() < 1e-6:
		return Vector2(NAN, NAN)
	downhill = downhill.normalized()
	var increment := _spacing * 0.5
	for k in range(1, ceili(break_distance / increment) + 1):
		for side in [1.0, -1.0]:
			var q: Vector2 = xz + downhill * (side * k * increment)
			if _sample_normal(q).y <= _steep_cos:
				return q
	return Vector2(NAN, NAN)

## Follows the downhill flow line through the seed until the slope leaves the cliff zone, then continues
## on the terrain for the collar and the fade. Stops early where another cliff starts.
func _trace(seed: Vector2, upward: bool) -> Dictionary:
	var increment := _spacing * 0.5
	var p := seed
	var points := PackedVector3Array([Vector3(seed.x, _height_at(seed), seed.y)])
	var cliff := -1
	var travelled := 0.0
	var tail := 0.0
	var direction := Vector2.ZERO
	var tail_length := overlap + seam_fade
	for attempt in ceili((reach + tail_length) / increment) * 2 + 8:
		var n := _sample_normal(p)
		var downhill := Vector2(n.x, n.z)
		if downhill.length_squared() > 0.0025:
			direction = (-downhill if upward else downhill).normalized()
		elif direction == Vector2.ZERO:
			break
		var q := p + direction * increment
		var y := _height_at(q)
		if is_nan(y):
			break
		var point := Vector3(q.x, y, q.y)
		var slope := _sample_normal(q).y
		if cliff < 0:
			travelled += increment
			if slope > _steep_cos:
				cliff = points.size() - 1
			elif travelled > reach:
				cliff = points.size() - 1
				reach_hits += 1
		elif slope < _reentry_cos:
			break
		if cliff >= 0:
			tail += point.distance_to(points[-1])
		points.append(point)
		p = q
		if cliff >= 0 and tail >= tail_length:
			break
	return {"points": points, "cliff": cliff if cliff >= 0 else points.size() - 1}

func _column(seed: Vector2) -> Dictionary:
	var down := _trace(seed, false)
	var up := _trace(seed, true)
	var down_points: PackedVector3Array = down.points
	var up_points: PackedVector3Array = up.points
	var points := PackedVector3Array()
	for k in range(down_points.size() - 1, -1, -1):
		points.append(down_points[k])
	var seed_index := down_points.size() - 1
	for k in range(1, up_points.size()):
		points.append(up_points[k])
	if points.size() < 2:
		return {}
	var cumulative := PackedFloat32Array([0.0])
	for k in range(1, points.size()):
		cumulative.append(cumulative[-1] + points[k].distance_to(points[k - 1]))
	var s := cumulative[seed_index]
	var bottom := seed_index - int(down.cliff)
	var top := seed_index + int(up.cliff)
	return {"points": points, "cumulative": cumulative, "seed": s, "xz": seed,
		"low": s - cumulative[bottom], "high": cumulative[top] - s,
		"bottom": points[bottom], "top": points[top]}

func _strip(run: Array, closed: bool) -> bool:
	var count := run.size()
	var along := PackedFloat32Array([0.0])
	var seeds := PackedVector2Array([run[0].xz])
	for i in range(1, count):
		along.append(along[-1] + Vector2(run[i].xz).distance_to(run[i - 1].xz))
		seeds.append(run[i].xz)
	if not closed and along[-1] < fade:
		return false
	# Smooth the cliff limits along the run, measured from the seeds (all at one height): they stay on the sculpture.
	var low := PackedFloat32Array()
	var high := PackedFloat32Array()
	for column in run:
		low.append(column.low)
		high.append(column.high)
	var low_original := low.duplicate()
	var high_original := high.duplicate()
	for iteration in smoothing:
		var next_low := low.duplicate()
		var next_high := high.duplicate()
		for i in count:
			if not closed and (i == 0 or i == count - 1):
				continue
			var a := posmod(i - 1, count)
			var b := (i + 1) % count
			next_low[i] = low_original[i] + clampf(lerpf(low[i], (low[a] + low[b]) * 0.5, 0.5) - low_original[i], -limit, limit)
			next_high[i] = high_original[i] + clampf(lerpf(high[i], (high[a] + high[b]) * 0.5, 0.5) - high_original[i], -limit, limit)
		low = next_low
		high = next_high
	var bounds := []
	var rows := PackedInt32Array([0, 0, 0, 0, 0])
	for i in count:
		var column: Dictionary = run[i]
		var length: float = column.cumulative[-1]
		var b := PackedFloat32Array()
		b.resize(6)
		b[2] = clampf(column.seed - low[i], 0.0, length)
		b[3] = clampf(column.seed + high[i], b[2], length)
		b[1] = maxf(0.0, b[2] - overlap)
		b[0] = maxf(0.0, b[1] - seam_fade)
		b[4] = minf(length, b[3] + overlap)
		b[5] = minf(length, b[4] + seam_fade)
		bounds.append(b)
		for k in 5:
			rows[k] = maxi(rows[k], ceili((b[k + 1] - b[k]) / step - 0.01))
	rows[CLIFF] = maxi(rows[CLIFF], 1)
	var samples := []
	for k in 5:
		for j in rows[k]:
			samples.append(Vector2(k, float(j) / rows[k]))
	samples.append(Vector2(4, 1.0))
	var start := vertices.size()
	for sample: Vector2 in samples:
		var k := int(sample.x)
		for i in count:
			var b: PackedFloat32Array = bounds[i]
			var s := lerpf(b[k], b[k + 1], sample.y)
			var p := _point(run[i], s)
			var weight := _world_relief(p)
			var opacity := 1.0
			if b[1] - b[0] > 0.0001:
				opacity *= smoothstep(b[0], b[1], s)
			if b[5] - b[4] > 0.0001:
				opacity *= 1.0 - smoothstep(b[4], b[5], s)
			vertices.append(p)
			relief.append(weight)
			alpha.append(opacity)
			_inset.append(minf(s - b[1] if b[1] - b[0] > 0.0001 else s, b[4] - s if b[5] - b[4] > 0.0001 else b[5] - s))
			terrain_normals.append(_terrain_normal(Vector2(p.x, p.z)))
			fold_normals.append(_sample_normal(Vector2(p.x, p.z)))
	# Register the cliff band now so later seeds on the same wall are skipped.
	for r in samples.size() - 1:
		if int(samples[r].x) != CLIFF:
			continue
		for i in count if closed else count - 1:
			var a := start + r * count + i
			var b := start + r * count + (i + 1) % count
			_mark_cliff(_quad(a, b, a + count, b + count), wall_count)
	_strips.append({"id": wall_count, "start": start, "count": count, "rows": samples.size(),
		"closed": closed, "along": along, "seeds": seeds})
	wall_count += 1
	return true

## Lateral ends and triangles, once every strip exists. An end that overlaps another strip keeps its folds:
## both fold the same surface the same way, so the joint does not show. Free ends get collar and fade.
func _finalize() -> void:
	for strip: Dictionary in _strips:
		var start: int = strip.start
		var count: int = strip.count
		var row_count: int = strip.rows
		var closed: bool = strip.closed
		if not closed:
			var along: PackedFloat32Array = strip.along
			var seeds: PackedVector2Array = strip.seeds
			var free_start := not _abuts(seeds[0], seeds[0] - seeds[1], strip.id)
			var free_end := not _abuts(seeds[-1], seeds[-1] - seeds[-2], strip.id)
			if free_start:
				_protect_end(start, count, row_count, 0)
			if free_end:
				_protect_end(start, count, row_count, count - 1)
			for i in count:
				var relief_factor := 1.0
				var alpha_factor := 1.0
				var lateral_inset := INF
				for end in [[along[i], free_start], [along[-1] - along[i], free_end]]:
					if not end[1]:
						continue
					relief_factor *= smoothstep(overlap + seam_fade, overlap + seam_fade + fade, end[0])
					lateral_inset = minf(lateral_inset, end[0] - seam_fade)
					if seam_fade > 0.0:
						alpha_factor *= smoothstep(0.0, seam_fade, end[0])
				for r in row_count:
					var v := start + r * count + i
					relief[v] *= relief_factor
					alpha[v] *= alpha_factor
					_inset[v] = minf(_inset[v], lateral_inset)
		for r in row_count - 1:
			for i in count if closed else count - 1:
				var a := start + r * count + i
				var b := start + r * count + (i + 1) % count
				var c := a + count
				var d := b + count
				var reference := terrain_normals[a] + terrain_normals[b] + terrain_normals[c] + terrain_normals[d]
				_triangle(a, b, c, reference)
				_triangle(b, d, c, reference)
				var inset := minf(minf(_inset[a], _inset[b]), minf(_inset[c], _inset[d]))
				var top_relief := maxf(maxf(relief[a], relief[b]), maxf(relief[c], relief[d]))
				_rasterize(_quad(a, b, c, d), top_relief, inset)

## Keeps terrain vertices within Seam Overlap (in plan) of a free end column: no hole can open beside it.
func _protect_end(start: int, count: int, row_count: int, column: int) -> void:
	var radius := ceili(maxf(overlap, _spacing * 2.0) / _spacing)
	var previous := Vector2i(-1, -1)
	for r in row_count:
		var p := vertices[start + r * count + column]
		var cell := Vector2i(roundi(p.x / _spacing) - _origin.x, roundi(p.z / _spacing) - _origin.y)
		if cell == previous:
			continue
		previous = cell
		for dz in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var q := cell + Vector2i(dx, dz)
				if dx * dx + dz * dz <= radius * radius and q.x >= 0 and q.y >= 0 and q.x < _w and q.y < _d:
					_no_hole[q.y * _w + q.x] = 1

## True only when the end really overlaps another strip (see _extend); a strip merely nearby leaves a gap.
func _abuts(end: Vector2, direction: Vector2, id: int) -> bool:
	direction = direction.normalized()
	for k in 3:
		var g := (end + direction * (k * step * 0.5)) / _spacing - Vector2(_origin)
		var x := roundi(g.x)
		var z := roundi(g.y)
		if x < 0 or z < 0 or x >= _w or z >= _d:
			return false
		var owner := _cliff_owner[z * _w + x]
		if owner >= 0 and owner != id:
			return true
	return false

func _quad(a: int, b: int, c: int, d: int) -> PackedVector2Array:
	return PackedVector2Array([Vector2(vertices[a].x, vertices[a].z), Vector2(vertices[b].x, vertices[b].z),
		Vector2(vertices[d].x, vertices[d].z), Vector2(vertices[c].x, vertices[c].z)])

## Emits a triangle facing the terrain normal; skips degenerate ones from zero-length segments.
func _triangle(a: int, b: int, c: int, reference: Vector3) -> void:
	var face := (vertices[c] - vertices[a]).cross(vertices[b] - vertices[a])
	if face.length_squared() < 1e-12:
		return
	if face.dot(reference) < 0.0:
		indices.append_array(PackedInt32Array([a, c, b]))
	else:
		indices.append_array(PackedInt32Array([a, b, c]))

## Grid vertices inside a quad in XZ, slightly inflated so vertices on shared edges are never lost.
func _grid_vertices(quad: PackedVector2Array) -> PackedInt32Array:
	var grid := PackedVector2Array()
	var centre := Vector2.ZERO
	for p in quad:
		grid.append(p / _spacing - Vector2(_origin))
		centre += grid[-1] * 0.25
	for k in 4:
		grid[k] += (grid[k] - centre).normalized() * 0.01
	var lo := grid[0].min(grid[1]).min(grid[2]).min(grid[3])
	var hi := grid[0].max(grid[1]).max(grid[2]).max(grid[3])
	var result := PackedInt32Array()
	for z in range(maxi(ceili(lo.y), 0), mini(floori(hi.y), _d - 1) + 1):
		for x in range(maxi(ceili(lo.x), 0), mini(floori(hi.x), _w - 1) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x, z), grid):
				result.append(z * _w + x)
	return result

func _mark_cliff(quad: PackedVector2Array, id: int) -> void:
	for i in _grid_vertices(quad):
		_cliff_owner[i] = id

func _rasterize(quad: PackedVector2Array, top_relief: float, inset: float) -> void:
	for i in _grid_vertices(quad):
		if not _footprint[i]:
			_footprint[i] = 1
			_footprint_cells.append(i)
		_inset_cover[i] = maxf(_inset_cover[i], inset)
		if top_relief > _relief_cover[i]:
			if _relief_cover[i] <= 0.0:
				_relief_cells.append(i)
			_relief_cover[i] = top_relief

func _covered_at(xz: Vector2) -> bool:
	var g := xz / _spacing - Vector2(_origin)
	var x := roundi(g.x)
	var z := roundi(g.y)
	if x < 0 or z < 0 or x >= _w or z >= _d:
		return true
	return _covered_index(z * _w + x)

## Column position at arc length s, with the height read again from the sculpture.
func _point(column: Dictionary, s: float) -> Vector3:
	var points: PackedVector3Array = column.points
	var cumulative: PackedFloat32Array = column.cumulative
	var k := clampi(cumulative.bsearch(s) - 1, 0, points.size() - 2)
	var fraction := clampf((s - cumulative[k]) / maxf(0.00001, cumulative[k + 1] - cumulative[k]), 0.0, 1.0)
	var p := points[k].lerp(points[k + 1], fraction)
	var y := _height_at(Vector2(p.x, p.z))
	if not is_nan(y):
		p.y = y
	return p

func _height_at(xz: Vector2) -> float:
	var u := xz.x / _spacing - _origin.x
	var v := xz.y / _spacing - _origin.y
	var x := floori(u)
	var z := floori(v)
	if x < 0 or z < 0 or x >= _w - 1 or z >= _d - 1:
		return NAN
	var i := z * _w + x
	return lerpf(lerpf(_h[i], _h[i + 1], u - x), lerpf(_h[i + _w], _h[i + _w + 1], u - x), v - z)

## Smoothed slope normal (Normal Radius), used for flow direction and cliff limits.
func _sample_normal(xz: Vector2) -> Vector3:
	var u := xz.x / _spacing - _origin.x
	var v := xz.y / _spacing - _origin.y
	var x := floori(u)
	var z := floori(v)
	if x < 0 or z < 0 or x >= _w - 1 or z >= _d - 1:
		return Vector3.UP
	var i := z * _w + x
	return _n[i].lerp(_n[i + 1], u - x).lerp(_n[i + _w].lerp(_n[i + _w + 1], u - x), v - z).normalized()

## Bilinear blend of forward-difference normals, the same normal Terrain3D shades with.
func _terrain_normal(xz: Vector2) -> Vector3:
	var u := xz.x / _spacing - _origin.x
	var v := xz.y / _spacing - _origin.y
	var x := floori(u)
	var z := floori(v)
	if x < 0 or z < 0 or x >= _w - 2 or z >= _d - 2:
		return Vector3.UP
	var i := z * _w + x
	var n := _forward_normal(i).lerp(_forward_normal(i + 1), u - x).lerp(
		_forward_normal(i + _w).lerp(_forward_normal(i + _w + 1), u - x), v - z)
	return Vector3.UP if is_nan(n.x) else n.normalized()

func _forward_normal(i: int) -> Vector3:
	return Vector3(_h[i] - _h[i + 1], _spacing, _h[i] - _h[i + _w]).normalized()

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
		normals[i] = terrain_normals[i] if normals[i].length_squared() < 1e-12 else normals[i].normalized()
