extends SceneTree

func _initialize() -> void:
	var scene: Node3D = load("res://assets/squirrel/squirrel_visual.scn").instantiate()
	var mesh_node := scene.find_child("SquirrelMesh", true, false) as MeshInstance3D
	var mesh := mesh_node.mesh
	var material := mesh.surface_get_material(0) as StandardMaterial3D
	var picture := material.albedo_texture.get_image()
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var hits := 0
	var affected_bounds := AABB()
	for i in range(0, indices.size(), 3):
		var center := (vertices[indices[i]] + vertices[indices[i + 1]] + vertices[indices[i + 2]]) / 3.0
		if center.y < 1.05 or center.y > 1.5 or center.z < 0.05: continue
		var tex := (uv[indices[i]] + uv[indices[i + 1]] + uv[indices[i + 2]]) / 3.0
		var color := picture.get_pixel(clampi(int(tex.x * picture.get_width()), 0, picture.get_width() - 1), clampi(int(tex.y * picture.get_height()), 0, picture.get_height() - 1))
		if color.r > 0.68 and color.g > 0.65 and color.b > 0.55:
			affected_bounds = AABB(center, Vector3.ZERO) if hits == 0 else affected_bounds.expand(center)
			if hits < 25: print("WHITE head triangle=", i / 3, " center=", center, " uv=", tex, " color=", color)
			hits += 1
	print("WHITE triangle count=", hits, " bounds=", affected_bounds)
	scene.free()
	quit(0 if hits == 0 else 1)
