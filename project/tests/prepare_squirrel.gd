extends SceneTree
## Rebuild the game-ready, weighted GLB from the untouched user-supplied source.
## Run with Godot --headless --path . --script tests/prepare_squirrel.gd -- SOURCE.glb

const BONE_NAMES := ["root", "head", "arm_left", "arm_right", "hip_left", "knee_left", "foot_left", "hip_right", "knee_right", "foot_right", "tail", "tail_tip", "forearm_left", "forearm_right", "spine"]
const PARENTS := [-1, 14, 14, 14, 0, 4, 5, 0, 7, 8, 0, 10, 2, 3, 0]
const PIVOTS := [Vector3.ZERO, Vector3(0, 1.12, -0.02), Vector3(-0.29, 0.98, 0), Vector3(0.29, 0.98, 0), Vector3(-0.16, 0.40, 0), Vector3(-0.16, 0.23, 0), Vector3(-0.16, 0.06, 0), Vector3(0.16, 0.40, 0), Vector3(0.16, 0.23, 0), Vector3(0.16, 0.06, 0), Vector3(0, 0.47, 0.25), Vector3(0, 0.74, 0.83), Vector3(-0.37, 0.69, 0), Vector3(0.37, 0.69, 0), Vector3(0, 0.60, 0)]

func _initialize() -> void:
	run.call_deferred()

func weights_for(p: Vector3) -> Array:
	var w := PackedFloat32Array()
	w.resize(BONE_NAMES.size())
	# Anatomical masks in normalized game space, with soft attachment transitions.
	var arm_side := smoothstep(0.30, 0.38, absf(p.x))
	var arm_depth := smoothstep(-0.26, -0.15, p.z) * (1.0 - smoothstep(0.48, 0.62, p.z))
	var arm_region := arm_side * arm_depth * smoothstep(0.37, 0.49, p.y) * (1.0 - smoothstep(0.93, 1.08, p.y))
	var tail := smoothstep(0.28, 0.48, p.z) * (1.0 - smoothstep(1.2, 1.4, p.y)) * (1.0 - arm_region)
	var tip := smoothstep(0.66, 1.04, p.z)
	w[10] = tail * (1.0 - tip)
	w[11] = tail * tip
	var head := smoothstep(1.05, 1.25, p.y) * (1.0 - tail)
	w[1] = head
	# Keep the abdomen/front of the torso out of the arm weights. The old broad
	# X-only mask pulled belly vertices upward when shoulders lifted above 90°.
	var arm := arm_region * (1.0 - head)
	var elbow := 1.0 - smoothstep(0.62, 0.76, p.y)
	w[2 if p.x < 0 else 3] = arm * (1.0 - elbow)
	w[12 if p.x < 0 else 13] = arm * elbow
	var leg := (1.0 - smoothstep(0.31, 0.48, p.y)) * (1.0 - tail) * (1.0 - arm)
	var hip := 4 if p.x < 0 else 7
	var knee := 1.0 - smoothstep(0.18, 0.29, p.y)
	var foot := 1.0 - smoothstep(0.065, 0.12, p.y)
	w[hip] = leg * (1.0 - knee)
	w[hip + 1] = leg * knee * (1.0 - foot)
	w[hip + 2] = leg * knee * foot
	var used := 0.0
	for value in w: used += value
	var torso := smoothstep(0.40, 0.78, p.y)
	w[0] = maxf(0, 1.0 - used) * (1.0 - torso)
	w[14] = maxf(0, 1.0 - used) * torso
	var order: Array[int] = []
	for i in w.size(): order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return w[a] > w[b])
	var ids := PackedInt32Array()
	var values := PackedFloat32Array()
	var total := 0.0
	for i in 4:
		ids.append(order[i])
		values.append(w[order[i]])
		total += w[order[i]]
	for i in 4: values[i] /= total
	return [ids, values]

func run() -> void:
	var source := "C:/Users/USER/Downloads/model.glb"
	var keep_authored_arms := "--use-authored-arms" in OS.get_cmdline_user_args()
	for argument in OS.get_cmdline_user_args():
		if argument.to_lower().ends_with(".glb"):
			source = argument
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	assert(doc.append_from_file(source, state) == OK)
	var original := doc.generate_scene(state)
	var instance := original.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var imported := ImporterMesh.from_mesh(instance.mesh)
	imported.generate_lods(25, 60, [])
	var arrays := imported.get_surface_arrays(0)
	var selected: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for lod in imported.get_surface_lod_count(0):
		var indices := imported.get_surface_lod_indices(0, lod)
		print("LOD ", lod, ": ", indices.size() / 3, " triangles")
		# Keep fine facial contours and the original UV seams. Never choose a tiny LOD.
		if indices.size() >= 24000 * 3 and indices.size() < selected.size(): selected = indices
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var remap := {}
	var out_vertices := PackedVector3Array()
	var out_normals := PackedVector3Array()
	var out_uv := PackedVector2Array()
	var out_indices := PackedInt32Array()
	var out_bones := PackedInt32Array()
	var out_weights := PackedFloat32Array()
	var basis := Basis(Vector3.UP, PI / 2)
	var scale_factor := 2.15 / instance.get_aabb().size.y
	for index in selected:
		if not remap.has(index):
			remap[index] = out_vertices.size()
			var p := basis * vertices[index] * scale_factor + Vector3(0, -instance.get_aabb().position.y * scale_factor, 0.40)
			out_vertices.append(p)
			out_normals.append(basis * normals[index])
			out_uv.append(uv[index])
			var weights := weights_for(p)
			out_bones.append_array(weights[0])
			out_weights.append_array(weights[1])
		out_indices.append(remap[index])
	var output: Array = []
	output.resize(Mesh.ARRAY_MAX)
	output[Mesh.ARRAY_VERTEX] = out_vertices
	output[Mesh.ARRAY_NORMAL] = out_normals
	output[Mesh.ARRAY_TEX_UV] = out_uv
	output[Mesh.ARRAY_INDEX] = out_indices
	output[Mesh.ARRAY_BONES] = out_bones
	output[Mesh.ARRAY_WEIGHTS] = out_weights
	_repair_nape_uv(output, instance.mesh.surface_get_material(0) as StandardMaterial3D)
	if not keep_authored_arms:
		preload("res://tests/arm_mesh_builder.gd").rebuild(output, instance.mesh.surface_get_material(0) as StandardMaterial3D)
	else:
		print("ARMS: retained authored geometry from the rigged reference")
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, output)
	var material := instance.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
	material.roughness = 0.95
	material.metallic_specular = 0.12
	mesh.surface_set_material(0, material)
	var visual := Node3D.new()
	visual.name = "SquirrelVisual"
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	visual.add_child(skeleton)
	skeleton.owner = visual
	for i in BONE_NAMES.size():
		skeleton.add_bone(BONE_NAMES[i])
	for i in BONE_NAMES.size():
		if PARENTS[i] >= 0: skeleton.set_bone_parent(i, PARENTS[i])
		var rest_position: Vector3 = PIVOTS[i] - (PIVOTS[PARENTS[i]] if PARENTS[i] >= 0 else Vector3.ZERO)
		skeleton.set_bone_rest(i, Transform3D(Basis.IDENTITY, rest_position))
	skeleton.reset_bone_poses()
	var skinned := MeshInstance3D.new()
	skinned.name = "SquirrelMesh"
	skinned.mesh = mesh
	skeleton.add_child(skinned)
	skinned.owner = visual
	skinned.skeleton = NodePath("..")
	skinned.skin = skeleton.create_skin_from_rest_transforms()
	DirAccess.make_dir_recursive_absolute("res://assets/squirrel")
	var packed := PackedScene.new()
	assert(packed.pack(visual) == OK)
	assert(ResourceSaver.save(packed, "res://assets/squirrel/squirrel_visual.scn", ResourceSaver.FLAG_COMPRESS) == OK)
	var export_state := GLTFState.new()
	assert(doc.append_from_scene(visual, export_state) == OK)
	assert(doc.write_to_filesystem(export_state, "res://assets/squirrel/squirrel_optimized.glb") == OK)
	print("OPTIMIZED: ", output[Mesh.ARRAY_VERTEX].size(), " vertices; ", output[Mesh.ARRAY_INDEX].size() / 3, " triangles; ", BONE_NAMES.size(), " weighted bones; height 2.15 m")
	visual.free()
	original.free()
	quit()

func _repair_nape_uv(arrays: Array, material: StandardMaterial3D) -> void:
	# Repair the two baked white marks with neighboring fur UVs, not a texture edit.
	# Duplicate only affected faces so unrelated UV islands and facial details stay intact.
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var picture := material.albedo_texture.get_image()
	var samples: Array[int] = []
	for i in vertices.size():
		var p := vertices[i]
		if p.y < 1.32 or p.y > 1.40 or p.z < 0.03: continue
		var color := picture.get_pixel(clampi(int(uv[i].x * picture.get_width()), 0, picture.get_width() - 1), clampi(int(uv[i].y * picture.get_height()), 0, picture.get_height() - 1))
		if color.r > 0.2 and color.g < color.r * 0.8 and color.b < color.r * 0.6:
			samples.append(i)
	assert(not samples.is_empty(), "No neighboring fur sample found")
	var repaired := 0
	for face in range(0, indices.size(), 3):
		var center := (vertices[indices[face]] + vertices[indices[face + 1]] + vertices[indices[face + 2]]) / 3.0
		if center.y < 1.20 or center.y > 1.32 or center.z < -0.02 or absf(center.x) < 0.22: continue
		var nearest := samples[0]
		for sample in samples:
			if center.distance_squared_to(vertices[sample]) < center.distance_squared_to(vertices[nearest]): nearest = sample
		for corner in 3:
			var old := indices[face + corner]
			indices[face + corner] = vertices.size()
			vertices.append(vertices[old])
			normals.append(normals[old])
			uv.append(uv[nearest])
			for slot in 4:
				bones.append(bones[old * 4 + slot])
				weights.append(weights[old * 4 + slot])
		repaired += 1
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	print("NAPE: repaired ", repaired, " faces using adjacent fur, texture/source unchanged")
