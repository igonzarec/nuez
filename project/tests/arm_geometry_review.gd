extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func bone_transform(rig: SquirrelRig, bone: int) -> Transform3D:
	var local := Transform3D(Basis(rig.current_rotations[bone]).scaled(rig.current_scales[bone]), rig.current_positions[bone])
	var parent := rig.skeleton.get_bone_parent(bone)
	return bone_transform(rig, parent) * local if parent >= 0 else local

func run() -> void:
	var rig := SquirrelRig.new()
	root.add_child(rig)
	var mesh := (rig.find_child("SquirrelMesh", true, false) as MeshInstance3D).mesh
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var used := {}
	for index in arrays[Mesh.ARRAY_INDEX]: used[index] = true
	rig.pose("arm_left", Vector3(0, 0, deg_to_rad(-150)))
	rig.pose("arm_right", Vector3(0, 0, deg_to_rad(150)))
	rig.pose("forearm_left", Vector3(deg_to_rad(5), 0, 0))
	rig.pose("forearm_right", Vector3(deg_to_rad(5), 0, 0))
	rig.deform_arms(-1, 0.08, 0.15)
	var transforms: Array[Transform3D] = []
	for bone in rig.skeleton.get_bone_count():
		transforms.append(bone_transform(rig, bone) * rig.skeleton.get_bone_global_rest(bone).affine_inverse())
	var left := {}
	var right := {}
	var max_body_change := 0.0
	for index: int in used:
		var arm := 0.0
		var total := 0.0
		var deformed := Vector3.ZERO
		for slot in 4:
			var bone := bones[index*4+slot]
			var weight := weights[index*4+slot]
			total += weight
			if bone in [2, 3, 12, 13]: arm += weight
			deformed += (transforms[bone] * vertices[index]) * weight
		assert(absf(total - 1) < 0.0001)
		assert(arm < 0.0001 or arm > 0.9999, "No membrane weights shared between arm and torso")
		if arm > 0.99:
			if vertices[index].x < 0:
				left[Vector3(-deformed.x, deformed.y, deformed.z).snapped(Vector3.ONE*0.0001)] = true
			else: right[deformed.snapped(Vector3.ONE*0.0001)] = true
		# Packed mesh weights can be quantized; compare against the same weighted
		# rest point rather than treating normalization roundoff as pose movement.
		else: max_body_change = maxf(max_body_change, deformed.distance_to(vertices[index] * total))
	assert(left.size() >= 80 and left.size() == right.size())
	for point in left: assert(right.has(point), "Arms remain mirrored at maximum lift/stretch")
	assert(max_body_change < 0.00001, "Torso, belly and tail stay unchanged when arms move")
	print("ARM GEOMETRY PASS: independent normalized weights; ", left.size(), " mirrored points per arm at 150 degrees; non-arm displacement=", max_body_change)
	rig.queue_free()
	await process_frame
	quit()
