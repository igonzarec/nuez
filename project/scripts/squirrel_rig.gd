class_name SquirrelRig
extends Node3D
## Render-interpolated procedural poses for the optimized weighted user model.

const VISUAL := preload("res://assets/squirrel/squirrel_visual.scn")
var skeleton: Skeleton3D
var current_rotations: Array[Quaternion] = []
var previous_rotations: Array[Quaternion] = []
var current_positions: Array[Vector3] = []
var previous_positions: Array[Vector3] = []
var current_scales: Array[Vector3] = []
var previous_scales: Array[Vector3] = []
var tail_rotation := Vector3.ZERO
var bone_indices: Dictionary = {}
var glide_amount := 0.0
var glide_membrane: MeshInstance3D
var membrane_mesh := ArrayMesh.new()
var membrane_material := StandardMaterial3D.new()

func _ready() -> void:
	var visual := VISUAL.instantiate()
	add_child(visual)
	skeleton = visual.find_child("Skeleton3D", true, false) as Skeleton3D
	for i in skeleton.get_bone_count():
		bone_indices[skeleton.get_bone_name(i)] = i
		current_rotations.append(Quaternion.IDENTITY)
		current_positions.append(skeleton.get_bone_rest(i).origin)
		current_scales.append(Vector3.ONE)
	reset_interpolation()
	glide_membrane = MeshInstance3D.new()
	glide_membrane.name = "GlidingMembranes"
	glide_membrane.mesh = membrane_mesh
	membrane_material.vertex_color_use_as_albedo = true
	membrane_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	membrane_material.roughness = 1.0
	membrane_material.metallic_specular = 0.1
	glide_membrane.material_override = membrane_material
	glide_membrane.visible = false
	add_child(glide_membrane)

func begin_pose() -> void:
	previous_rotations.assign(current_rotations)
	previous_positions.assign(current_positions)
	previous_scales.assign(current_scales)

func pose(bone: String, euler: Vector3) -> void:
	current_rotations[bone_indices[bone]] = Quaternion.from_euler(euler)

func smooth_pose(bone: String, euler: Vector3, weight: float) -> void:
	var index: int = bone_indices[bone]
	current_rotations[index] = current_rotations[index].slerp(Quaternion.from_euler(euler), weight)

func deform_tail(flex: float, drop: float, stretch: float, sideways := 0.0) -> void:
	var index: int = bone_indices["tail_tip"]
	# Weighted translation bends the narrow attachment like a soft shear, while
	# nonuniform scaling squashes/stretches the large curl and preserves volume.
	current_positions[index] = skeleton.get_bone_rest(index).origin + Vector3(sideways, -flex * drop, flex * drop * 0.22)
	var vertical := 1.0 - flex * stretch * 0.65
	var lengthwise := 1.0 + flex * stretch
	current_scales[index] = Vector3(1.0 / sqrt(vertical * lengthwise), vertical, lengthwise)

func deform_arms(flex: float, drop: float, stretch: float) -> void:
	# Keep shoulders attached; weighted elbow displacement bends the lower arms.
	for bone in ["forearm_left", "forearm_right"]:
		var index: int = bone_indices[bone]
		current_positions[index] = skeleton.get_bone_rest(index).origin + Vector3(0, -flex * drop, 0)
		var lengthwise := 1.0 + absf(flex) * stretch
		var width := 1.0 / sqrt(lengthwise)
		current_scales[index] = Vector3(width, lengthwise, width)

func leg_pose(side: int, target: Vector3, foot_pitch: float) -> void:
	# Two-bone sagittal IK keeps the ankle level as the hip and knee bend.
	var hip := 4 if side == 0 else 7
	var hip_position := skeleton.get_bone_global_rest(hip).origin
	var offset := target - hip_position
	var length := clampf(Vector2(offset.y, offset.z).length(), 0.06, 0.339)
	var bend := acos(clampf(length / 0.34, 0.0, 1.0))
	var direction := atan2(-offset.z, -offset.y)
	current_rotations[hip] = Quaternion(Vector3.RIGHT, direction + bend)
	current_rotations[hip + 1] = Quaternion(Vector3.RIGHT, -2 * bend)
	current_rotations[hip + 2] = Quaternion(Vector3.RIGHT, -direction + bend + foot_pitch)

func reset_interpolation() -> void:
	previous_rotations.assign(current_rotations)
	previous_positions.assign(current_positions)
	previous_scales.assign(current_scales)

func _process(_delta: float) -> void:
	var fraction := Engine.get_physics_interpolation_fraction()
	for i in current_rotations.size():
		skeleton.set_bone_pose_rotation(i, previous_rotations[i].slerp(current_rotations[i], fraction))
		skeleton.set_bone_pose_position(i, previous_positions[i].lerp(current_positions[i], fraction))
		skeleton.set_bone_pose_scale(i, previous_scales[i].lerp(current_scales[i], fraction))
	_update_membranes()

func _skin_point(bone: String, rest_point: Vector3) -> Vector3:
	var index: int = bone_indices[bone]
	return skeleton.get_bone_global_pose(index) * skeleton.get_bone_global_rest(index).affine_inverse() * rest_point

func _update_membranes() -> void:
	glide_membrane.visible = glide_amount > 0.015
	if not glide_membrane.visible: return
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for side in [-1, 1]:
		var suffix := "left" if side < 0 else "right"
		var shoulder := _skin_point("spine", Vector3(side * 0.25, 0.94, 0.055))
		var waist := _skin_point("spine", Vector3(side * 0.22, 0.46, 0.055))
		var hand := _skin_point("forearm_" + suffix, Vector3(side * 0.395, 0.49, 0.035))
		var foot := _skin_point("foot_" + suffix, Vector3(side * 0.17, 0.09, 0.055))
		hand = shoulder.lerp(hand, glide_amount)
		foot = waist.lerp(foot, glide_amount)
		var edge := hand.lerp(foot, 0.5)
		edge.x -= side * 0.055 * glide_amount
		edge.z += 0.045 * glide_amount
		var center := (shoulder + waist + hand + foot) * 0.25 + Vector3(0, 0, 0.05 * glide_amount)
		var outline := [shoulder, hand, edge, foot, waist]
		for triangle in outline.size():
			var a: Vector3 = outline[triangle]
			var b: Vector3 = outline[(triangle+1)%outline.size()]
			var normal := (a-center).cross(b-center).normalized()
			var color := Color("a76a35").lerp(Color("c98c49"), float(triangle % 3) * 0.22)
			for point: Vector3 in [center, a, b]:
				vertices.append(point)
				normals.append(normal)
				colors.append(color)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	membrane_mesh.clear_surfaces()
	membrane_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
