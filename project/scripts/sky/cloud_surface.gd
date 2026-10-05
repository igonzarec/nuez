@tool
extends RefCounted
## Extrae una superficie única de la unión suave de elipsoides.
const CORNERS = [Vector3i(0,0,0), Vector3i(1,0,0), Vector3i(1,1,0), Vector3i(0,1,0), Vector3i(0,0,1), Vector3i(1,0,1), Vector3i(1,1,1), Vector3i(0,1,1)]
const TETS = [[0,5,1,6], [0,1,2,6], [0,2,3,6], [0,3,7,6], [0,7,4,6], [0,4,5,6]]
const EDGES = [[0,1], [1,2], [2,0], [0,3], [1,3], [2,3]]
const TRIANGLES = [[], [0,3,2], [0,1,4], [1,4,2,2,4,3], [1,2,5], [0,3,5,0,5,1], [0,2,5,0,5,4], [5,4,3], [3,4,5], [4,5,0,5,2,0], [1,5,0,5,3,0], [5,2,1], [3,4,2,2,4,1], [4,1,0], [2,3,0], []]

static func build(shapes: Array[Transform3D], resolution: int, blend: float) -> ArrayMesh:
	var centers: Array[Vector3] = []
	var radii: Array[Vector3] = []
	var low := Vector3(INF, INF, INF)
	var high := -low
	for shape in shapes:
		var radius := shape.basis.get_scale() * 0.5
		centers.append(shape.origin)
		radii.append(radius)
		low = low.min(shape.origin - radius)
		high = high.max(shape.origin + radius)
	# Smooth min can expand the surface; leave a conservative empty border.
	var padding := blend + 0.08
	low -= Vector3.ONE * padding
	high += Vector3.ONE * padding
	var cells := maxi(12, resolution)
	var side := cells + 1
	var step := (high - low) / float(cells)
	var values := PackedFloat32Array()
	values.resize(side * side * side)
	for z in side:
		for y in side:
			for x in side:
				var p := low + Vector3(x,y,z) * step
				var distance := 1000.0
				for j in centers.size():
					var r := radii[j]
					var d := ((p - centers[j]) / r).length() - 1.0
					d *= minf(r.x, minf(r.y, r.z))
					var h := maxf(blend - absf(distance - d), 0.0) / blend
					distance = minf(distance, d) - h * h * blend * 0.25
				values[x + side * (y + side * z)] = distance
	var normals := PackedVector3Array()
	normals.resize(values.size())
	for z in side:
		for y in side:
			for x in side:
				var dx := values[mini(x+1,cells) + side*(y+side*z)] - values[maxi(x-1,0) + side*(y+side*z)]
				var dy := values[x + side*(mini(y+1,cells)+side*z)] - values[x + side*(maxi(y-1,0)+side*z)]
				var dz := values[x + side*(y+side*mini(z+1,cells))] - values[x + side*(y+side*maxi(z-1,0))]
				normals[x + side*(y+side*z)] = (Vector3(dx,dy,dz) / step).normalized()
	var vertices := PackedVector3Array()
	var output_normals := PackedVector3Array()
	for z in cells:
		for y in cells:
			for x in cells:
				var ids: Array[int] = []
				var points: Array[Vector3] = []
				var inside := 0
				for corner in CORNERS:
					var c: Vector3i = Vector3i(x,y,z) + corner
					var id := c.x + side*(c.y+side*c.z)
					ids.append(id)
					points.append(low + Vector3(c) * step)
					if values[id] < 0:
						inside += 1
				if inside == 0 or inside == 8:
					continue
				for tet in TETS:
					var mask := 0
					for i in 4:
						if values[ids[tet[i]]] < 0:
							mask |= 1 << i
					var table: Array = TRIANGLES[mask]
					for ti in range(0, table.size(), 3):
						var vs: Array[Vector3] = []
						var ns: Array[Vector3] = []
						for k in 3:
							var edge: Array = EDGES[table[ti+k]]
							var a: int = tet[edge[0]]
							var b: int = tet[edge[1]]
							var weight := values[ids[a]] / (values[ids[a]] - values[ids[b]])
							vs.append(points[a].lerp(points[b], weight))
							ns.append(normals[ids[a]].lerp(normals[ids[b]], weight).normalized())
						var cross := (vs[1]-vs[0]).cross(vs[2]-vs[0])
						if cross.length_squared() < 1e-16:
							continue
						# Godot usa caras frontales con orden horario.
						var order := [0,2,1] if cross.dot(ns[0]+ns[1]+ns[2]) > 0 else [0,1,2]
						for k in order:
							vertices.append(vs[k])
							output_normals.append(ns[k])
	var mesh := ArrayMesh.new()
	if not vertices.is_empty():
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = output_normals
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
