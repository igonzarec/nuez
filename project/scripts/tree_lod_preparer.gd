@tool
extends RefCounted
## Preparación de LOD estáticos en disco. No simplifica ni crea lotes durante el juego.


static func triangle_count(mesh: ArrayMesh) -> int:
	var total := 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		total += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null else arrays[Mesh.ARRAY_VERTEX].size()) / 3
	return total


static func copy_level(source: ArrayMesh, ratio: float, minimum_triangles: int,
		protect_leaves: bool = false, leaf_keywords: PackedStringArray = [],
		leaf_surfaces: PackedInt32Array = [], uv_tolerance: float = 0.002) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if source.get_blend_shape_count() > 0:
		push_error("Preparar LOD requiere una malla estática sin blend shapes.")
		return null
	for surface in source.get_surface_count():
		if source.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			push_error("Preparar LOD sólo admite superficies de triángulos.")
			return null
		var arrays := source.surface_get_arrays(surface)
		if arrays[Mesh.ARRAY_BONES] != null and not arrays[Mesh.ARRAY_BONES].is_empty():
			push_error("Hornear el rig antes de preparar LOD estáticos.")
			return null
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			for index in vertices.size():
				indices.append(index)
		var base_count := indices.size()
		var target := base_count * clampf(ratio, 0.01, 1.0)
		var best_error := absf(base_count - target)
		var leaf_surface := surface in leaf_surfaces
		var material := source.surface_get_material(surface)
		var label := source.surface_get_name(surface).to_lower() + " " + (material.resource_name.to_lower() if material != null else "")
		for keyword in leaf_keywords:
			if not keyword.is_empty() and label.contains(keyword.to_lower()):
				leaf_surface = true
		if ratio < 1.0 and protect_leaves and leaf_surface and base_count > minimum_triangles * 3:
			indices = _leaf_indices(arrays, indices, ratio, uv_tolerance)
		elif ratio < 1.0:
			var data := RenderingServer.mesh_get_surface(source.get_rid(), surface)
			for lod: Dictionary in data.get("lods", []):
				var bytes: PackedByteArray = lod.index_data
				var stride := 2 if vertices.size() < 65536 else 4
				var count := bytes.size() / stride
				if count < mini(minimum_triangles * 3, base_count) or absf(count - target) >= best_error:
					continue
				best_error = absf(count - target)
				indices.resize(count)
				for index in count:
					indices[index] = bytes.decode_u16(index * stride) if stride == 2 else bytes.decode_u32(index * stride)
		# Retain ALL vertex attributes. In particular, textured alpha foliage needs
		# UVs/tangents/colors; the old flat-color-only simplifier discarded them.
		# No internal LOD table is copied: Terrain3D switches these explicit levels.
		arrays[Mesh.ARRAY_INDEX] = indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_name(surface, source.surface_get_name(surface))
		mesh.surface_set_material(surface, source.surface_get_material(surface))
	return mesh


static func _root(parents: Array[int], vertex: int) -> int:
	while parents[vertex] != vertex:
		parents[vertex] = parents[parents[vertex]]
		vertex = parents[vertex]
	return vertex


static func _leaf_indices(arrays: Array, indices: PackedInt32Array, ratio: float, uv_tolerance: float) -> PackedInt32Array:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var parents: Array[int] = []
	var positions: Dictionary = {}
	for vertex in vertices.size():
		parents.append(vertex)
		var key := vertices[vertex].snapped(Vector3.ONE * 0.00001)
		if positions.has(key):
			parents[vertex] = positions[key]
		else:
			positions[key] = vertex
	for face in range(0, indices.size(), 3):
		var a := _root(parents, indices[face])
		parents[_root(parents, indices[face + 1])] = a
		parents[_root(parents, indices[face + 2])] = a
	var parts: Dictionary = {}
	for face in range(0, indices.size(), 3):
		var part := _root(parents, indices[face])
		if not parts.has(part):
			parts[part] = PackedInt32Array()
		var list: PackedInt32Array = parts[part]
		list.append_array(PackedInt32Array([indices[face], indices[face + 1], indices[face + 2]]))
		parts[part] = list
	var result := PackedInt32Array()
	for part: PackedInt32Array in parts.values():
		var best := part
		var target := maxf(6.0, part.size() * ratio)
		var error := absf(part.size() - target)
		# Simplify each connected leaf chart, never the entire crown. This keeps
		# upper branches that a global index LOD would simply delete.
		var piece := ImporterMesh.new()
		var piece_arrays := arrays.duplicate()
		piece_arrays[Mesh.ARRAY_INDEX] = part
		piece.add_surface(Mesh.PRIMITIVE_TRIANGLES, piece_arrays)
		piece.generate_lods(60.0, 180.0, [])
		for level in piece.get_surface_lod_count(0):
			var candidate := piece.get_surface_lod_indices(0, level)
			if candidate.size() >= 6 and absf(candidate.size() - target) < error:
				best = candidate
				error = absf(candidate.size() - target)
		# A complete convex UV chart can also be flattened to its boundary. UV
		# area checks reject overlapping/double-sided/concave charts and holes.
		var hull := _chart_boundary(arrays, part, uv_tolerance)
		if not hull.is_empty() and absf(hull.size() - target) < error:
			best = hull
		result.append_array(best)
	return result


static func _chart_boundary(arrays: Array, part: PackedInt32Array, tolerance: float) -> PackedInt32Array:
	if arrays[Mesh.ARRAY_TEX_UV] == null:
		return PackedInt32Array()
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var unique: Dictionary = {}
	var points := PackedVector2Array()
	for vertex in part:
		var key := uv[vertex].snapped(Vector2.ONE * 0.00001)
		if unique.has(key):
			if vertices[unique[key]].distance_to(vertices[vertex]) > 0.0001:
				return PackedInt32Array()
		else:
			unique[key] = vertex
			points.append(uv[vertex])
	var hull := Geometry2D.convex_hull(points)
	if hull.size() < 4:
		return PackedInt32Array()
	hull.resize(hull.size() - 1) # convex_hull repeats its first point.
	var chart_area := 0.0
	var direction := 0.0
	for face in range(0, part.size(), 3):
		var cross := (uv[part[face + 1]] - uv[part[face]]).cross(uv[part[face + 2]] - uv[part[face]])
		if absf(cross) < 0.000001:
			continue
		if direction != 0.0 and direction * cross < 0.0:
			return PackedInt32Array()
		direction = cross
		chart_area += absf(cross) * 0.5
	var hull_area := 0.0
	for i in hull.size():
		hull_area += hull[i].cross(hull[(i + 1) % hull.size()]) * 0.5
	if absf(hull_area) < 0.000001 or absf(chart_area - absf(hull_area)) > absf(hull_area) * 0.01:
		return PackedInt32Array()
	# Drop almost-collinear UV edge samples, retaining actual chart corners.
	var changed := true
	while changed and hull.size() > 3:
		changed = false
		for i in hull.size():
			var a := hull[(i - 1 + hull.size()) % hull.size()]
			var b := hull[i]
			var c := hull[(i + 1) % hull.size()]
			if absf((b - a).cross(c - a)) <= tolerance * (c - a).length():
				hull.remove_at(i)
				changed = true
				break
	var result := PackedInt32Array()
	for i in range(1, hull.size() - 1):
		var a: int = unique[hull[0].snapped(Vector2.ONE * 0.00001)]
		var b: int = unique[hull[i].snapped(Vector2.ONE * 0.00001)]
		var c: int = unique[hull[i + 1].snapped(Vector2.ONE * 0.00001)]
		if (hull[i] - hull[0]).cross(hull[i + 1] - hull[0]) * direction < 0.0:
			result.append_array(PackedInt32Array([a, c, b]))
		else:
			result.append_array(PackedInt32Array([a, b, c]))
	return result


static func prepare(source_scene: PackedScene, output_directory: String, stem: String,
		mid_ratio: float, far_ratio: float, minimum_triangles: int,
		mid_override: ArrayMesh = null, far_override: ArrayMesh = null,
		protect_leaves: bool = true, leaf_keywords: PackedStringArray = [],
		leaf_surfaces: PackedInt32Array = [], uv_tolerance: float = 0.002) -> Dictionary:
	if source_scene == null or not output_directory.begins_with("res://"):
		return {"error": "Elegir un Source Model y una carpeta dentro de res://."}
	# Use Terrain3D's own extraction, including imported surface overrides. Never
	# take the already colored live asset as the source for regeneration.
	var reader := Terrain3DMeshAsset.new()
	reader.scene_file = source_scene
	var original := reader.get_mesh(0) as ArrayMesh
	if original == null:
		return {"error": "El modelo no contiene una ArrayMesh compatible con Terrain3D."}
	var levels: Array[ArrayMesh] = [copy_level(original, 1.0, minimum_triangles),
		copy_level(mid_override if mid_override != null else original, 1.0 if mid_override != null else mid_ratio, minimum_triangles, protect_leaves, leaf_keywords, leaf_surfaces, uv_tolerance),
		copy_level(far_override if far_override != null else original, 1.0 if far_override != null else far_ratio, minimum_triangles, protect_leaves, leaf_keywords, leaf_surfaces, uv_tolerance)]
	if null in levels:
		return {"error": "No se pudieron preparar los tres niveles. Revisar los errores de malla."}
	var directory := output_directory.trim_suffix("/")
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if error != OK:
		return {"error": "No se puede crear la carpeta de LOD: %s" % error_string(error)}
	var root := Node3D.new()
	root.name = stem
	var counts: Array[int] = []
	var report: PackedStringArray = []
	for level in levels.size():
		var mesh := levels[level]
		mesh.resource_name = "%sLOD%d" % [stem, level]
		var path := directory.path_join("%s_lod%d.res" % [stem, level])
		error = ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
		if error != OK:
			root.free()
			return {"error": "No se puede guardar %s: %s" % [path, error_string(error)]}
		mesh.take_over_path(path)
		var node := MeshInstance3D.new()
		node.name = "%sLOD%d" % [stem, level]
		node.mesh = mesh
		root.add_child(node)
		node.owner = root
		counts.append(triangle_count(mesh))
		report.append("LOD%d: %d triángulos" % [level, counts[-1]])
	var packed := PackedScene.new()
	error = packed.pack(root)
	root.free()
	if error != OK:
		return {"error": "No se puede empaquetar la escena LOD: %s" % error_string(error)}
	var scene_path := directory.path_join(stem + "_lods.tscn")
	error = ResourceSaver.save(packed, scene_path)
	if error != OK:
		return {"error": "No se puede guardar la escena LOD: %s" % error_string(error)}
	packed.take_over_path(scene_path)
	if counts[1] >= counts[0] or counts[2] >= counts[1]:
		report.append("AVISO: algún nivel no reduce más. Revisar LOD importados o asignar una malla manual.")
	report.append("Revisar silueta, UV y recorte alfa antes de aceptar las distancias finales.")
	return {"scene": packed, "counts": counts, "report": "\n".join(report), "path": scene_path}
