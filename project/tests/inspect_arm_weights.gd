extends SceneTree

func _initialize() -> void:
	var scene: Node3D = load("res://assets/squirrel/squirrel_visual.scn").instantiate()
	var mesh := (scene.find_child("SquirrelMesh", true, false) as MeshInstance3D).mesh
	var a := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var picture := (mesh.surface_get_material(0) as StandardMaterial3D).albedo_texture.get_image()
	var belly_vertices := 0
	var max_arm_weight := 0.0
	var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	for i in vertices.size():
		var p := vertices[i]
		if p.y < 0.45 or p.y > 0.92: continue
		var c := picture.get_pixel(clampi(int(uv[i].x * picture.get_width()), 0, picture.get_width()-1), clampi(int(uv[i].y * picture.get_height()), 0, picture.get_height()-1))
		var key := "belly" if c.g > c.r * 0.6 and c.b > c.r * 0.3 else "fur"
		if key == "belly" and p.z < 0:
			belly_vertices += 1
			for slot in 4:
				if bones[i * 4 + slot] in [2, 3, 12, 13]:
					max_arm_weight = maxf(max_arm_weight, weights[i * 4 + slot])
	print("BELLY SKIN: vertices=", belly_vertices, " maximum arm influence=", max_arm_weight)
	scene.free()
	quit(0 if belly_vertices > 50 and max_arm_weight < 0.00001 else 1)
