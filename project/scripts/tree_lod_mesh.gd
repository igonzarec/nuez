extends RefCounted
## Reutiliza los índices LOD importados por Godot; no modifica el GLB ni inventa otra silueta.

static func build(source: ArrayMesh, ratio: float) -> ArrayMesh:
	var result := ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var target := indices.size() * clampf(ratio, 0.05, 1.0)
		var best_error := absf(indices.size() - target)
		var lods: Array = RenderingServer.mesh_get_surface(source.get_rid(), surface).get("lods", [])
		for lod: Dictionary in lods:
			var bytes: PackedByteArray = lod.index_data
			var stride := 2 if vertices.size() < 65536 else 4
			var count := bytes.size() / stride
			if absf(count - target) >= best_error:
				continue
			best_error = absf(count - target)
			indices.resize(count)
			for i in count:
				indices[i] = bytes.decode_u16(i * stride) if stride == 2 else bytes.decode_u32(i * stride)
		# Compact unused vertices so the far mesh saves vertex work as well as triangles.
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var remap: Dictionary = {}
		var compact_vertices := PackedVector3Array()
		var compact_normals := PackedVector3Array()
		for i in indices.size():
			var old := indices[i]
			if not remap.has(old):
				remap[old] = compact_vertices.size()
				compact_vertices.append(vertices[old])
				compact_normals.append(normals[old])
			indices[i] = remap[old]
		var compact: Array = []
		compact.resize(Mesh.ARRAY_MAX)
		compact[Mesh.ARRAY_VERTEX] = compact_vertices
		compact[Mesh.ARRAY_NORMAL] = compact_normals
		compact[Mesh.ARRAY_INDEX] = indices
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, compact)
		result.surface_set_material(surface, source.surface_get_material(surface))
	return result
