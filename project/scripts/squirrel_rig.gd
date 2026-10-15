class_name SquirrelRig
extends Node3D
## Contenedor visual del personaje artesanal. Solo carga playertest2.

const PLAYERTES2_VISUAL := preload("res://assets/playertest2/playertest2.glb")
const MOVEMENT_DUST := preload("res://scripts/movement_dust.gd")

var glide_amount := 0.0
var tail_rotation := Vector3.ZERO
var body_pivot: Node3D
var playertest2_animation: AnimationPlayer
var playertest2_run := &""
var playertest2_run_fast := &""
var playertest2_climb := &""
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
var climb_sound_position := 0.0
var movement_dust: MovementDust
var air_active := false
var landing_pose_active := false
var landing_clearance_meshes: Array[MeshInstance3D] = []
var landing_clearance_height := 0.0
var air_pose_targets: Dictionary = {}
var air_position_targets: Dictionary = {}
var air_pose_rotations: Dictionary = {}
var air_pose_positions: Dictionary = {}
var air_pose_response := 18.0
var air_pose_clock := 0.0
var air_pose_releasing := false
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
	movement_dust = MOVEMENT_DUST.new()
	movement_dust.name = "MovementDust"
	add_child(movement_dust)
	movement_dust.setup(self, get_parent() as ExplorerPlayer)
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
		elif animation_text.ends_with("Climb"):
			playertest2_climb = animation_name
		elif animation_text.ends_with("GlideStart"):
			playertest2_glide_start = animation_name
		elif animation_text.ends_with("Glide"):
			playertest2_glide_loop = animation_name
	if not playertest2_climb.is_empty():
		# El clip de Blender contiene la misma pose al inicio y al final.
		# Forzamos el bucle aquí para que el importador no dependa de metadatos
		# específicos de glTF y el control siga siendo portable en Godot 4.6.
		var climb_animation := playertest2_animation.get_animation(playertest2_climb)
		if climb_animation:
			climb_animation.loop_mode = Animation.LOOP_LINEAR
	if not playertest2_run.is_empty():
		playertest2_animation.play(playertest2_run)
		playertest2_animation.pause()

func update_handmade_run(speed: float, walk_member_speed: float, run_member_speed: float, sprint_requested: bool) -> void:
	if glide_active or climb_active or air_active:
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
	_clear_air_pose()
	if not climb_active:
		climb_sound_position = 0.0
		var actor := get_parent() as ExplorerPlayer
		if actor and actor.climb_sound_enabled:
			actor.feedback.emit("climb")
	if not climb_active and playertest2_animation:
		playertest2_animation.stop()
		if not playertest2_climb.is_empty():
			playertest2_animation.play(playertest2_climb)
	climb_active = true
	glide_active = false
	glide_started = false
	idle_active = false
	glide_amount = 0.0
	climb_visual_speed = speed
	climb_amplitude = deg_to_rad(amplitude)
	climb_cadence = cadence
	if playertest2_animation and not playertest2_climb.is_empty():
		if playertest2_animation.current_animation != playertest2_climb:
			playertest2_animation.play(playertest2_climb)
		playertest2_animation.speed_scale = maxf(0.0, speed * cadence)
		if speed > 0.01 and not playertest2_animation.is_playing():
			playertest2_animation.play()
	_set_membrane_amount(0.0)
	position = Vector3.ZERO
	scale = Vector3.ONE
	set_body_tilt(-0.08, 0.0)

func end_climb() -> void:
	if not climb_active:
		return
	climb_active = false
	climb_visual_speed = 0.0
	if playertest2_animation and playertest2_animation.current_animation == playertest2_climb:
		playertest2_animation.stop()
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


func hold_glide_landing_pose() -> void:
	_clear_air_pose()
	glide_active = true
	idle_active = false
	landing_pose_active = false
	glide_tremor_degrees = 0.0
	if playertest2_animation:
		playertest2_animation.pause()


func _find_glide_membranes(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if String(node.name).contains("nuez_torso") or String(node.name).contains("nuez_cabeza"):
			landing_clearance_meshes.append(mesh_instance)
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
	_update_landing_clearance(delta)
	if not playertest2_skeleton:
		return
	if climb_active:
		_tick_climb_sounds()
		# Climb se creó en Blender y sustituye por completo el movimiento
		# procedural anterior. Conservamos ese código sólo como respaldo para
		# versiones viejas del GLB que aún no tengan el clip.
		if not playertest2_climb.is_empty():
			return
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
	if air_active or landing_pose_active or air_pose_releasing:
		_apply_air_pose(delta)
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


func _update_landing_clearance(delta: float) -> void:
	var actor := get_parent() as ExplorerPlayer
	if not actor or not body_pivot:
		return
	var required := 0.0
	if actor.is_glide_landing and actor.glide_landing_clearance_enabled:
		var normal := actor.glide_landing_floor_normal.normalized()
		var lift_axis := global_basis * Vector3.UP
		var lift_projection := maxf(0.1, normal.dot(lift_axis))
		for mesh_instance in landing_clearance_meshes:
			if not is_instance_valid(mesh_instance):
				continue
			var bounds := mesh_instance.get_aabb()
			var margin := actor.glide_landing_clearance_margin
			if String(mesh_instance.name).contains("nuez_torso"):
				margin -= actor.glide_landing_belly_sink
			for corner in 8:
				# Retira la corrección anterior antes de calcular la nueva.
				var point := mesh_instance.global_transform * bounds.get_endpoint(corner) - lift_axis * landing_clearance_height
				var distance := normal.dot(point - actor.glide_landing_floor_point)
				required = maxf(required, (margin - distance) / lift_projection)
		required = minf(required, actor.glide_landing_clearance_max_lift)
	if required > landing_clearance_height:
		landing_clearance_height = required
	else:
		landing_clearance_height = lerpf(landing_clearance_height, required, 1.0 - exp(-actor.glide_landing_clearance_recovery * delta))
	body_pivot.position.y = landing_clearance_height


func _tick_climb_sounds() -> void:
	var actor := get_parent() as ExplorerPlayer
	if not actor:
		return
	if not playertest2_animation or playertest2_climb.is_empty():
		return
	var current := playertest2_animation.current_animation_position
	var length := playertest2_animation.get_animation(playertest2_climb).length
	if length <= 0.0:
		return
	# Compara el reloj real del AnimationPlayer: congelar o cambiar el ritmo
	# del clip congela o cambia también los apoyos, sin otro temporizador.
	if actor.climb_sound_enabled and playertest2_animation.get_playing_speed() > 0.0:
		for phase in [actor.climb_sound_phases.x, actor.climb_sound_phases.y]:
			var contact := clampf(phase, 0.0, 0.999) * length
			var crossed := contact > climb_sound_position and contact <= current
			if current < climb_sound_position:
				crossed = contact > climb_sound_position or contact <= current
			if crossed:
				actor.feedback.emit("climb")
	climb_sound_position = current


func update_air_pose(airborne: bool, enabled: bool, lift: float, spread: float, tremor: float, frequency: float, compression: float, body_drop: float, head_retract: float, head_pitch: float, response: float, arm_inset: float = 0.0, stride_swing: Vector2 = Vector2.ZERO, leg_offsets: Vector2 = Vector2.ZERO, torso_lean: float = 0.0, head_forward: float = 0.0, landing_response: float = 30.0, arm_pitches: Vector2 = Vector2.ZERO) -> void:
	if not playertest2_skeleton:
		return
	var active := airborne and not climb_active and not glide_active
	var landing_active := not airborne and enabled and compression > 0.0 and not climb_active and not glide_active
	if (active or landing_active) and not air_active and not landing_pose_active:
		# Captura la pose visible de salida, sin arrastrar la zancada al aire.
		_capture_air_pose()
	if active and not air_active and playertest2_animation:
		playertest2_animation.pause()
	if (not active and air_active) or (not landing_active and landing_pose_active):
		air_pose_releasing = true
	air_active = active
	landing_pose_active = landing_active
	air_pose_response = response if active else landing_response
	if not active and not landing_active:
		return
	if active:
		idle_active = false
		air_pose_releasing = false
	air_pose_targets.clear()
	air_position_targets.clear()
	if not enabled:
		return
	# Ejes del esqueleto, convertidos a los ejes locales reales del rig.
	for side_name in ["left", "right"]:
		var side := -1.0 if side_name == "left" else 1.0
		var phase := air_pose_clock * frequency * TAU + (0.0 if side < 0.0 else 1.7)
		var shake := sin(phase) * tremor
		_set_air_rotation("arm_" + side_name, Vector3.BACK, deg_to_rad((lift + shake) * side), deg_to_rad(arm_pitches.x if side_name == "left" else arm_pitches.y))
		_set_air_position("arm_" + side_name, Vector3.LEFT * side * arm_inset)
		_set_air_rotation("leg_" + side_name, Vector3.BACK, deg_to_rad(spread * side), deg_to_rad(stride_swing.y * side))
		_set_air_position("leg_" + side_name, Vector3.BACK * (leg_offsets.x if side_name == "left" else leg_offsets.y))
	_set_air_rotation("head", Vector3.RIGHT, deg_to_rad(head_pitch * compression))
	_set_air_rotation("spine", Vector3.RIGHT, deg_to_rad(torso_lean))
	_set_air_position("spine", Vector3.DOWN * body_drop * compression)
	_set_air_position("head", Vector3.DOWN * head_retract * compression + Vector3.BACK * head_forward)


func _set_air_rotation(bone_name: String, axis: Vector3, angle: float, pitch: float = 0.0) -> void:
	var index := playertest2_skeleton.find_bone(bone_name)
	if index >= 0:
		var local_axis := playertest2_skeleton.get_bone_global_rest(index).basis.orthonormalized().inverse() * axis
		var rest_rotation := playertest2_skeleton.get_bone_rest(index).basis.get_rotation_quaternion()
		var pitch_axis := playertest2_skeleton.get_bone_global_rest(index).basis.orthonormalized().inverse() * Vector3.RIGHT
		air_pose_targets[index] = rest_rotation * Quaternion(local_axis.normalized(), angle) * Quaternion(pitch_axis.normalized(), pitch)


func _set_air_position(bone_name: String, displacement: Vector3) -> void:
	var index := playertest2_skeleton.find_bone(bone_name)
	if index >= 0:
		var parent_index := playertest2_skeleton.get_bone_parent(index)
		var parent_basis := playertest2_skeleton.get_bone_global_rest(parent_index).basis if parent_index >= 0 else Basis.IDENTITY
		air_position_targets[index] = playertest2_skeleton.get_bone_rest(index).origin + parent_basis.inverse() * displacement


func _capture_air_pose() -> void:
	for index in playertest2_skeleton.get_bone_count():
		air_pose_rotations[index] = playertest2_skeleton.get_bone_pose_rotation(index)
		air_pose_positions[index] = playertest2_skeleton.get_bone_pose_position(index)


func _apply_air_pose(delta: float) -> void:
	air_pose_clock += delta
	if air_active or idle_active:
		_reset_idle_pose()
	var blend := 1.0 - exp(-air_pose_response * delta)
	var settled := true
	for index in playertest2_skeleton.get_bone_count():
		var base_rotation := playertest2_skeleton.get_bone_pose_rotation(index)
		var base_position := playertest2_skeleton.get_bone_pose_position(index)
		var rest_rotation := playertest2_skeleton.get_bone_rest(index).basis.get_rotation_quaternion()
		var target_rotation: Quaternion = air_pose_targets.get(index, rest_rotation) if air_active else base_rotation
		var target_position: Vector3 = air_position_targets.get(index, playertest2_skeleton.get_bone_rest(index).origin) if air_active else base_position
		if landing_pose_active:
			# La contracción se suma al clip terrestre ya en reproducción:
			# no retiene piernas ni brazos hasta terminar el aterrizaje.
			var landing_rotation: Quaternion = air_pose_targets.get(index, rest_rotation)
			var landing_position: Vector3 = air_position_targets.get(index, playertest2_skeleton.get_bone_rest(index).origin)
			target_rotation = base_rotation * rest_rotation.inverse() * landing_rotation
			target_position = base_position + landing_position - playertest2_skeleton.get_bone_rest(index).origin
		var previous_rotation: Quaternion = air_pose_rotations.get(index, base_rotation)
		var previous_position: Vector3 = air_pose_positions.get(index, base_position)
		var rotation := previous_rotation.slerp(target_rotation, blend)
		var bone_position := previous_position.lerp(target_position, blend)
		playertest2_skeleton.set_bone_pose_rotation(index, rotation)
		playertest2_skeleton.set_bone_pose_position(index, bone_position)
		air_pose_rotations[index] = rotation
		air_pose_positions[index] = bone_position
		if rotation.angle_to(target_rotation) > 0.002 or bone_position.distance_to(target_position) > 0.0005:
			settled = false
	if not air_active and not landing_pose_active and settled:
		air_pose_releasing = false


func _clear_air_pose() -> void:
	air_active = false
	landing_pose_active = false
	air_pose_releasing = false
	air_pose_targets.clear()
	air_position_targets.clear()
	air_pose_rotations.clear()
	air_pose_positions.clear()
	air_pose_clock = 0.0


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
	_clear_air_pose()
	landing_clearance_height = 0.0
	if body_pivot:
		body_pivot.position.y = 0.0
	glide_active = false
	glide_started = false
	idle_active = false
	reset_body_tilt()
	_set_membrane_amount(0.0)
	_clear_glide_tremor()
