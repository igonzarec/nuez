extends RefCounted
## Replace fused arm/body triangles with independent closed tubular limbs.

static func rebuild(a: Array, material: StandardMaterial3D) -> void:
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var indices: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var kept := PackedInt32Array()
	var arm_influence := PackedFloat32Array()
	var tail_influence := PackedFloat32Array()
	arm_influence.resize(v.size())
	tail_influence.resize(v.size())
	var edges := {}
	var removed := 0
	var picture := material.albedo_texture.get_image()
	var fur_uv := Vector2.ZERO
	var paw_uv := Vector2.ZERO
	var fur_distance := INF
	var paw_distance := INF
	for i in v.size():
		var color := picture.get_pixel(clampi(int(uv[i].x * picture.get_width()), 0, picture.get_width()-1), clampi(int(uv[i].y * picture.get_height()), 0, picture.get_height()-1))
		if color.r > 0.3 and color.g < color.r * 0.65 and color.b < color.r * 0.3:
			var distance := v[i].distance_squared_to(Vector3(-0.47, 0.8, -0.04))
			if distance < fur_distance:
				fur_distance = distance
				fur_uv = uv[i]
		if color.r < 0.35 and color.g < 0.2:
			var distance := v[i].distance_squared_to(Vector3(-0.56, 0.52, -0.03))
			if distance < paw_distance:
				paw_distance = distance
				paw_uv = uv[i]
	# Capture the original skin regions before moving stray arm weights to spine.
	# This lets the face cut follow both mirrored arm surfaces instead of a box.
	for i in v.size():
		var transferred := 0.0
		for j in 4:
			if bones[i * 4 + j] in [2, 3, 12, 13]:
				transferred += weights[i * 4 + j]
			elif bones[i * 4 + j] in [10, 11]:
				tail_influence[i] += weights[i * 4 + j]
		arm_influence[i] = transferred
		# Geometry remaining on the torso must never be skinned to either arm.
		for j in 4:
			if bones[i * 4 + j] in [2, 3, 12, 13]:
				weights[i * 4 + j] = 0
		if transferred > 0:
			for j in 4:
				if weights[i * 4 + j] == 0:
					bones[i * 4 + j] = 14
					weights[i * 4 + j] = transferred
					break
	for face in range(0, indices.size(), 3):
		var i0 := indices[face]
		var i1 := indices[face+1]
		var i2 := indices[face+2]
		var center := (v[i0] + v[i1] + v[i2]) / 3.0
		var arm_score := (arm_influence[i0] + arm_influence[i1] + arm_influence[i2]) / 3.0
		var tail_score := (tail_influence[i0] + tail_influence[i1] + tail_influence[i2]) / 3.0
		var near_shoulder := absf(center.x) > 0.27 and center.y > 0.38 and center.y < 1.08
		var cut := near_shoulder and arm_score > 0.24 and arm_score > tail_score * 0.85
		if cut: removed += 1
		else: kept.append_array(indices.slice(face, face + 3))
		for j in 3:
			var first := indices[face+j]
			var second := indices[face+(j+1)%3]
			# Weld position keys for adjacency across the source's UV/normal seams.
			var ka := str(v[first].snapped(Vector3.ONE * 0.00001))
			var kb := str(v[second].snapped(Vector3.ONE * 0.00001))
			var key := ka + "|" + kb if ka < kb else kb + "|" + ka
			if not edges.has(key): edges[key] = {"cut": false, "keep": false, "a": first, "b": second}
			if cut: edges[key].cut = true
			else:
				edges[key].keep = true
				edges[key].a = first
				edges[key].b = second
	# Source UV seams split the shoulder perimeter into small edge chains. Seal
	# those chains toward a point buried in the torso. The closure is therefore
	# invisible from outside, unlike the old center at the surface that formed a
	# visible point before each arm.
	for edge: Dictionary in edges.values():
		if not edge.cut or not edge.keep: continue
		var p: Vector3 = v[edge.a]
		var q: Vector3 = v[edge.b]
		var side := signf(p.x + q.x)
		var center := Vector3(side * 0.12, 0.77, -0.01)
		var first := v.size()
		for point: Vector3 in [q, p, center]:
			v.append(point)
			n.append(Vector3(side, 0, 0))
			uv.append(fur_uv)
			bones.append_array(PackedInt32Array([14, 0, 0, 0]))
			weights.append_array(PackedFloat32Array([1, 0, 0, 0]))
		kept.append_array(PackedInt32Array([first, first + 1, first + 2]))
	# The rigged open-arms reference provides the desired limb profile: a rounded
	# upper arm, clear elbow, slimmer forearm and compact paw. Keep that profile
	# on the game's existing mirrored skeleton, rather than importing its
	# incompatible 29-bone armature.
	var heights := [1.02, 0.98, 0.92, 0.84, 0.74, 0.69, 0.63, 0.54, 0.47, 0.43]
	var outward := [0.22, 0.26, 0.30, 0.35, 0.38, 0.40, 0.415, 0.43, 0.435, 0.42]
	var forward := [0.0, -0.01, -0.025, -0.045, -0.065, -0.07, -0.06, -0.04, -0.025, -0.015]
	var radii := [0.13, 0.125, 0.115, 0.115, 0.108, 0.095, 0.09, 0.082, 0.075, 0.048]
	var tube_start := kept.size()
	for side in [-1, 1]:
		var first := v.size()
		for ring in heights.size():
			var y: float = heights[ring]
			var x: float = outward[ring] * side
			var lower := 1.0 - smoothstep(0.65, 0.73, y)
			for spoke in 10:
				var angle := TAU * spoke / 10
				var radial := Vector3(cos(angle), 0, sin(angle))
				v.append(Vector3(x, y, forward[ring]) + radial * radii[ring])
				n.append(radial)
				uv.append(paw_uv if y <= 0.54 else fur_uv)
				bones.append_array(PackedInt32Array([2 if side < 0 else 3, 12 if side < 0 else 13, 0, 0]))
				weights.append_array(PackedFloat32Array([1-lower, lower, 0, 0]))
		for ring in heights.size()-1:
			for spoke in 10:
				var p := first + ring * 10 + spoke
				var q := first + ring * 10 + (spoke+1)%10
				kept.append_array(PackedInt32Array([p, p+10, q, q, p+10, q+10]))
		for spoke in range(1, 9):
			kept.append_array(PackedInt32Array([first, first+spoke, first+spoke+1]))
			var end := first + (heights.size()-1)*10
			kept.append_array(PackedInt32Array([end, end+spoke+1, end+spoke]))
	# Never interpolate between unrelated texture-atlas regions at the wrist.
	for face in range(tube_start, kept.size(), 3):
		var y := (v[kept[face]].y + v[kept[face+1]].y + v[kept[face+2]].y) / 3.0
		for corner in 3:
			var old := kept[face+corner]
			kept[face+corner] = v.size()
			v.append(v[old])
			n.append(n[old])
			uv.append(paw_uv if y < 0.555 else fur_uv)
			for slot in 4:
				bones.append(bones[old*4+slot])
				weights.append(weights[old*4+slot])
	a[Mesh.ARRAY_VERTEX] = v
	a[Mesh.ARRAY_NORMAL] = n
	a[Mesh.ARRAY_TEX_UV] = uv
	a[Mesh.ARRAY_INDEX] = kept
	a[Mesh.ARRAY_BONES] = bones
	a[Mesh.ARRAY_WEIGHTS] = weights
	print("ARMS: removed ", removed, " fused faces; independent mirrored tubes added; final triangles=", kept.size()/3)
