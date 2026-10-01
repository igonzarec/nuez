class_name SquirrelRig
extends Node3D
## Contenedor visual del personaje artesanal. Solo carga playertest2.

const PLAYERTES2_VISUAL := preload("res://assets/playertest2/playertest2.glb")

var glide_amount := 0.0
var tail_rotation := Vector3.ZERO
var body_pivot: Node3D
var playertest2_animation: AnimationPlayer
var playertest2_run := &""
var playertest2_run_fast := &""
var playertest2_glide_start := &""
var playertest2_glide_loop := &""
var glide_active := false
var glide_started := false
var glide_membranes: Array[MeshInstance3D] = []
var playertest2_skeleton: Skeleton3D
var glide_tremor_degrees := 0.0
var glide_tremor_speed := 12.0
var glide_tremor_clock := 0.0
var idle_active := false
var climb_active := false
var climb_phase := 0.0
var climb_visual_speed := 0.0
var climb_amplitude := 0.0
var climb_cadence := 0.7
const GLIDE_TREMOR_BONES := [&"arm_left", &"arm_right", &"leg_left", &"leg_right"]

func _ready() -> void:
	body_pivot = Node3D.new()
	body_pivot.name = "BodyPivot"
	add_child(body_pivot)
	var handmade_visual := PLAYERTES2_VISUAL.instantiate()
	handmade_visual.name = "NuezPlayerTest2"
	# Blender exporta el frente en sentido opuesto al movimiento del controlador.
	handmade_visual.rotation.y = PI
	body_pivot.add_child(handmade_visual)
	_find_glide_membranes(handmade_visual)
	_set_membrane_amount(0.0)
	playertest2_skeleton = _find_skeleton(handmade_visual)
	# Se ejecuta después del AnimationPlayer para aplicar el temblor encima del clip Glide.
	process_priority = 100
	playertest2_animation = handmade_visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not playertest2_animation:
		return
	for animation_name in playertest2_animation.get_animation_list():
		var animation_text := String(animation_name)
		if animation_text.ends_with("RunFast"):
			playertest2_run_fast = animation_name
		elif animation_text.ends_with("Run"):
			playertest2_run = animation_name
		elif animation_text.ends_with("GlideStart"):
			playertest2_glide_start = animation_name
		elif animation_text.ends_with("Glide"):
			playertest2_glide_loop = animation_name
	if not playertest2_run.is_empty():
		playertest2_animation.play(playertest2_run)
		playertest2_animation.pause()

func update_handmade_run(speed: float, walk_member_speed: float, run_member_speed: float, sprint_requested: bool) -> void:
	if glide_active:
		return
	if not playertest2_animation or playertest2_run.is_empty():
		return
	if speed > 0.12:
		idle_active = false
		# RunFast es opcional para que las versiones antiguas del GLB sigan funcionando.
		var use_run_fast := sprint_requested and not playertest2_run_fast.is_empty()
		var locomotion_animation := playertest2_run_fast if use_run_fast else playertest2_run
		if playertest2_animation.current_animation != locomotion_animation:
			playertest2_animation.play(locomotion_animation)
		elif not playertest2_animation.is_playing():
			playertest2_animation.play()
		playertest2_animation.speed_scale = run_member_speed if use_run_fast else walk_member_speed
	else:
		idle_active = true
		# Nunca congelamos la última zancada: Idle siempre parte de la pose base.
		if playertest2_animation.current_animation != playertest2_run:
			playertest2_animation.play(playertest2_run)
		playertest2_animation.seek(0.0, true)
		playertest2_animation.pause()

func update_climb(speed: float, amplitude: float, cadence: float) -> void:
	if not climb_active and playertest2_animation:
		playertest2_animation.stop()
	climb_active = true
	glide_active = false
	glide_started = false
	idle_active = false
	glide_amount = 0.0
	climb_visual_speed = speed
	climb_amplitude = deg_to_rad(amplitude)
	climb_cadence = cadence
	_set_membrane_amount(0.0)
	position = Vector3.ZERO
	scale = Vector3.ONE
	set_body_tilt(-0.08, 0.0)

func end_climb() -> void:
	if not climb_active:
		return
	climb_active = false
	climb_visual_speed = 0.0
	if playertest2_skeleton:
		_reset_idle_pose()
	reset_body_tilt()

func update_handmade_glide(amount: float, flutter_speed: float, start_speed := 1.0, tremor_degrees := 0.0, tremor_speed := 12.0) -> void:
	var should_glide := amount > 0.08
	glide_active = should_glide
	idle_active = false
	glide_tremor_degrees = tremor_degrees * amount
	glide_tremor_speed = tremor_speed
	_set_membrane_amount(amount)
	if not playertest2_animation:
		return

	if should_glide:
		if not glide_started:
			glide_started = true
			if not playertest2_glide_start.is_empty():
				playertest2_animation.play(playertest2_glide_start, -1.0, start_speed)
				if not playertest2_glide_loop.is_empty():
					playertest2_animation.queue(playertest2_glide_loop)
			elif not playertest2_glide_loop.is_empty():
				playertest2_animation.play(playertest2_glide_loop, -1.0, flutter_speed)
		elif playertest2_animation.current_animation == playertest2_glide_loop:
			playertest2_animation.speed_scale = flutter_speed
	elif glide_started:
		glide_started = false
		_clear_glide_tremor()
		if playertest2_animation.current_animation == playertest2_glide_start or playertest2_animation.current_animation == playertest2_glide_loop:
			playertest2_animation.stop()


func _find_glide_membranes(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		# El exportador conserva los nombres de malla Plane/Plane.001, pero ambas
		# membranas comparten esta Shape Key exclusiva.
		if mesh_instance.mesh and mesh_instance.mesh.get_blend_shape_count() > 0:
			for shape_index: int in mesh_instance.mesh.get_blend_shape_count():
				if mesh_instance.mesh.get_blend_shape_name(shape_index) == &"membrana_abierta":
					glide_membranes.append(mesh_instance)
					break
	for child in node.get_children():
		_find_glide_membranes(child)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var child_skeleton := _find_skeleton(child)
		if child_skeleton:
			return child_skeleton
	return null


func _set_membrane_amount(amount: float) -> void:
	for membrane in glide_membranes:
		if is_instance_valid(membrane):
			# Una Shape Key con valor 0 solo pliega el plano; no lo vuelve invisible.
			# Por eso la visibilidad se controla aparte y las membranas no aparecen
			# durante Idle, Run ni RunFast.
			membrane.visible = amount > 0.01
			var shape_index: int = -1
			for candidate_index: int in membrane.mesh.get_blend_shape_count():
				if membrane.mesh.get_blend_shape_name(candidate_index) == &"membrana_abierta":
					shape_index = candidate_index
					break
			if shape_index >= 0:
				membrane.set_blend_shape_value(shape_index, clampf(amount, 0.0, 1.0))


func _process(delta: float) -> void:
	if not playertest2_skeleton:
		return
	if climb_active:
		climb_phase += climb_visual_speed * climb_cadence * TAU * delta
		_reset_idle_pose()
		for bone_name in GLIDE_TREMOR_BONES:
			var bone_index := playertest2_skeleton.find_bone(bone_name)
			if bone_index < 0:
				continue
			var side := 1.0 if String(bone_name).ends_with("left") else -1.0
			var arm := String(bone_name).begins_with("arm")
			var stroke := sin(climb_phase + (0.0 if arm else PI)) * side * climb_amplitude
			var pose := Vector3(-0.7 + stroke if arm else 0.25 + stroke, 0.0, side * (0.2 if arm else 0.1))
			playertest2_skeleton.set_bone_pose_rotation(bone_index, Quaternion.from_euler(pose))
		return
	if idle_active:
		# Idle no utiliza el primer frame de Run: ese frame puede contener una
		# zancada. Restablecemos la pose real del rig para tener piernas y brazos
		# rectos; es una postura fija sin movimiento adicional.
		_reset_idle_pose()
		return
	if not glide_active or glide_tremor_degrees <= 0.0:
		return
	glide_tremor_clock += delta * glide_tremor_speed
	# Vuelve a evaluar la pose del clip antes de sumar el temblor. Así el giro
	# adicional no se acumula de un frame al siguiente.
	if playertest2_animation:
		playertest2_animation.advance(0.0)
	var amplitude := deg_to_rad(glide_tremor_degrees)
	for bone_offset in GLIDE_TREMOR_BONES.size():
		var bone_index: int = playertest2_skeleton.find_bone(GLIDE_TREMOR_BONES[bone_offset])
		if bone_index < 0:
			continue
		var phase: float = glide_tremor_clock + float(bone_offset) * 1.83
		var roll: float = sin(phase * 1.7) * amplitude
		var pitch: float = cos(phase * 2.3) * amplitude * 0.45
		var current_rotation: Quaternion = playertest2_skeleton.get_bone_pose_rotation(bone_index)
		playertest2_skeleton.set_bone_pose_rotation(bone_index, current_rotation * Quaternion.from_euler(Vector3(pitch, 0.0, roll)))


func _reset_idle_pose() -> void:
	for bone_index in playertest2_skeleton.get_bone_count():
		playertest2_skeleton.reset_bone_pose(bone_index)


func _clear_glide_tremor() -> void:
	if not playertest2_skeleton:
		return
	for bone_name in GLIDE_TREMOR_BONES:
		var bone_index: int = playertest2_skeleton.find_bone(bone_name)
		if bone_index >= 0:
			playertest2_skeleton.reset_bone_pose(bone_index)

func set_body_tilt(pitch: float, roll: float, bank: float = 0.0) -> void:
	if not body_pivot:
		return
	# El modelo está erguido en reposo: su eje cadera-cabeza es +Y, no -Z.
	# Los productos actúan de derecha a izquierda: primero bank sobre el torso,
	# después pitch lleva también ese eje hacia la postura horizontal de Glide.
	# El balanceo terrestre conserva su eje -Z; el yaw sigue en SquirrelRig.
	body_pivot.quaternion = Quaternion(Vector3.RIGHT, pitch) * Quaternion(Vector3.FORWARD, roll) * Quaternion(Vector3.UP, bank)

func reset_body_tilt() -> void:
	if body_pivot:
		body_pivot.quaternion = Quaternion.IDENTITY

# Compatibilidad temporal con el controlador de movimiento. El modelo nuevo
# usa sus propias animaciones y no necesita el antiguo esqueleto procedural.
func begin_pose() -> void: pass
func pose(_bone: String, _euler: Vector3) -> void: pass
func smooth_pose(_bone: String, _euler: Vector3, _weight: float) -> void: pass
func deform_tail(_flex: float, _drop: float, _stretch: float, _sideways := 0.0) -> void: pass
func deform_arms(_flex: float, _drop: float, _stretch: float) -> void: pass
func leg_pose(_side: int, _target: Vector3, _foot_pitch: float) -> void: pass
func reset_interpolation() -> void:
	glide_active = false
	glide_started = false
	idle_active = false
	reset_body_tilt()
	_set_membrane_amount(0.0)
	_clear_glide_tremor()
