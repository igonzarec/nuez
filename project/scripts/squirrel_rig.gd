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
var climb_surface_lean := 0.0
var climb_ground_offset_active := false
var climb_ground_uses_assist_offset := false
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
		elif animation_text.ends_with("GlideStart"):
			playertest2_glide_start = animation_name
		elif animation_text.ends_with("Glide"):
			playertest2_glide_loop = animation_name
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

func update_climb(speed: float) -> void:
	var actor := get_parent() as ExplorerPlayer
	if not actor:
		return
	if not climb_active:
		climb_phase = 0.0
		climb_surface_lean = 0.0
		_capture_air_pose()
		if actor.climb_sound_enabled:
			actor.feedback.emit("climb")
		if playertest2_animation:
			playertest2_animation.stop()
	climb_active = true
	climb_ground_offset_active = false
	air_active = false
	air_pose_releasing = false
	landing_pose_active = false
	glide_active = false
	glide_started = false
	idle_active = false
	glide_amount = 0.0
	climb_visual_speed = maxf(0.0, speed)
	_set_membrane_amount(0.0)
	scale = Vector3.ONE
	var mantle_effort := sin(clampf(actor.climb_mantle_progress, 0.0, 1.0) * PI) if actor.climb_mantle_progress >= 0.0 else 0.0
	var stand_up := 1.0 - smoothstep(0.85, 1.0, actor.climb_mantle_progress) if actor.climb_mantle_progress >= 0.0 else 1.0
	if actor.climb_stand_progress >= 0.0:
		stand_up = 1.0 - smoothstep(0.0, 1.0, actor.climb_stand_progress)
	var target_lean := 0.0
	if actor.climb_surface_follow_enabled:
		target_lean = minf(rad_to_deg(asin(clampf(actor.climb_surface_normal.y, -1.0, 1.0))), actor.climb_surface_max_lean_degrees) * actor.climb_surface_follow_strength
	climb_surface_lean = lerpf(climb_surface_lean, target_lean, 1.0 - exp(-actor.climb_surface_follow_response * get_physics_process_delta_time()))
	# El offset visual sigue la normal de la roca, no una distancia horizontal
	# fija que se convierte en hueco cuando la pendiente se suaviza.
	var offset_axis := actor.climb_surface_normal if actor.climb_surface_follow_enabled else Vector3.BACK.rotated(Vector3.UP, rotation.y)
	position = offset_axis * actor.climb_visual_wall_offset * stand_up
	if actor.climb_stand_progress >= 0.0:
		position = (offset_axis * actor.climb_visual_wall_offset).lerp(Vector3.UP * actor.climb_finish_visual_height, 1.0 - stand_up)
	if actor.climb_surface_assist_active:
		position = offset_axis * lerpf(actor.climb_mantle_surface_offset_start, actor.climb_mantle_surface_offset_end, 1.0 - stand_up)
	var mantle_lean_weight := 1.0 - clampf(actor.climb_surface_normal.y, 0.0, 1.0) * actor.climb_surface_follow_strength if actor.climb_surface_follow_enabled else 1.0
	set_body_tilt(-deg_to_rad(climb_surface_lean + actor.climb_body_lean_degrees + actor.climb_mantle_body_lean_degrees * mantle_effort * mantle_lean_weight) * stand_up, 0.0)


func end_climb(natural_finish := false, surface_finish := false) -> void:
	if not climb_active:
		return
	climb_active = false
	climb_visual_speed = 0.0
	# Conserva la última pose para mezclar hacia la nueva animación.
	air_pose_releasing = true
	climb_ground_offset_active = natural_finish
	climb_ground_uses_assist_offset = surface_finish
	if not natural_finish:
		position = Vector3.ZERO
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
			if not playertest2_animation.is_playing():
				playertest2_animation.play()
		elif playertest2_animation.current_animation == playertest2_glide_start and not playertest2_animation.is_playing():
			playertest2_animation.play()
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
	if not climb_active and climb_ground_offset_active:
		var actor := get_parent() as ExplorerPlayer
		if actor:
			var height := actor.climb_mantle_surface_offset_end if climb_ground_uses_assist_offset else actor.climb_finish_visual_height
			var target_offset := Vector3.UP * height if actor.is_on_floor() else Vector3.ZERO
			position = position.lerp(target_offset, 1.0 - exp(-actor.climb_finish_visual_response * delta))
			if not actor.is_on_floor() and position.length_squared() < 0.000001:
				position = Vector3.ZERO
				climb_ground_offset_active = false
	_update_landing_clearance(delta)
	if not playertest2_skeleton:
		return
	if climb_active:
		_apply_procedural_climb(delta)
		return
	if glide_active and playertest2_animation:
		# Primero la pose del clip, luego la mezcla de salida aérea y al final
		# el temblor. Una mezcla que persigue Glide nunca debe silenciarlo.
		playertest2_animation.advance(0.0)
	if air_active or landing_pose_active or air_pose_releasing:
		_apply_air_pose(delta)
		if air_active or landing_pose_active or not glide_active:
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


func _apply_procedural_climb(delta: float) -> void:
	var actor := get_parent() as ExplorerPlayer
	if not actor:
		return
	var previous_cycle := climb_phase
	if actor.climb_procedural_enabled:
		if actor.climb_surface_assist_active:
			if climb_visual_speed > 0.006:
				climb_phase += actor.climb_mantle_cycle_speed * delta
		elif actor.climb_mantle_progress >= 0.0:
			climb_phase = actor.climb_mantle_cycle_start + minf(1.0, actor.climb_mantle_progress / 0.85) * actor.climb_mantle_cycle_count
		else:
			climb_phase += climb_visual_speed * actor.climb_member_speed * delta
	_tick_procedural_climb_sounds(previous_cycle, climb_phase, actor)
	# Sólo reposo del rig + matemáticas de Godot. Ninguna curva de Climb.
	_reset_idle_pose()
	var blend := 1.0 - exp(-actor.climb_pose_response * delta)
	var targets: Dictionary = {}
	var mantle_effort := sin(clampf(actor.climb_mantle_progress, 0.0, 1.0) * PI) if actor.climb_mantle_progress >= 0.0 else 0.0
	var stand_weight := 1.0 - smoothstep(0.85, 1.0, actor.climb_mantle_progress) if actor.climb_mantle_progress >= 0.0 else 1.0
	if actor.climb_stand_progress >= 0.0:
		stand_weight = 1.0 - smoothstep(0.0, 1.0, actor.climb_stand_progress)
	var walking_rotations: Dictionary = {}
	if actor.climb_surface_assist_active and stand_weight < 1.0 and playertest2_animation and not playertest2_run.is_empty():
		# Muestrea caminar para mezclar los miembros, sin reproducir Climb de Blender.
		if playertest2_animation.current_animation != playertest2_run:
			playertest2_animation.play(playertest2_run)
		var clip := playertest2_animation.get_animation(playertest2_run)
		playertest2_animation.seek(fposmod(climb_phase, 1.0) * clip.length, true)
		playertest2_animation.pause()
		for bone in playertest2_skeleton.get_bone_count():
			walking_rotations[bone] = playertest2_skeleton.get_bone_pose_rotation(bone)
		_reset_idle_pose()
	if actor.climb_procedural_enabled:
		for bone_name in GLIDE_TREMOR_BONES:
			var index := playertest2_skeleton.find_bone(bone_name)
			if index < 0:
				continue
			var arm := String(bone_name).begins_with("arm")
			var left := String(bone_name).ends_with("left")
			var offset := actor.climb_arm_phase if arm else actor.climb_leg_phase
			var side_offset := 0.0 if left else actor.climb_opposite_side_phase
			var phase := (climb_phase - offset - side_offset) * TAU
			if actor.climb_reverse_cycle:
				phase = -phase
			var vertical := actor.climb_arm_vertical_degrees if arm else actor.climb_leg_vertical_degrees
			var depth := actor.climb_arm_depth_degrees if arm else actor.climb_leg_depth_degrees
			var tilt := actor.climb_arm_path_tilt_degrees if arm else actor.climb_leg_path_tilt_degrees
			# Dos componentes a 90° recorren una elipse, sin trasladar la raíz.
			var orbit := Vector2(sin(phase) * vertical, cos(phase) * depth).rotated(deg_to_rad(tilt))
			var elevation := (actor.climb_arm_base_elevation_degrees if arm else actor.climb_leg_base_elevation_degrees) + orbit.x
			elevation += mantle_effort * (actor.climb_mantle_arm_reach_degrees if arm else actor.climb_mantle_leg_tuck_degrees)
			var spread := (actor.climb_arm_base_spread_degrees if arm else actor.climb_leg_base_spread_degrees) - orbit.y
			var side := -1.0 if left else 1.0
			var lift := deg_to_rad(clampf(elevation, 0.0, 175.0))
			var opening := deg_to_rad(spread)
			var direction := Vector3(side * sin(lift) * sin(opening), -cos(lift), sin(lift) * cos(opening)).normalized()
			var rest_basis := playertest2_skeleton.get_bone_global_rest(index).basis.orthonormalized()
			var rest_direction := (rest_basis * Vector3.UP).normalized()
			var swing := Quaternion(rest_direction, direction)
			var parent_index := playertest2_skeleton.get_bone_parent(index)
			var parent_basis := playertest2_skeleton.get_bone_global_rest(parent_index).basis.orthonormalized() if parent_index >= 0 else Basis.IDENTITY
			targets[index] = parent_basis.get_rotation_quaternion().inverse() * swing * rest_basis.get_rotation_quaternion()
	if actor.climb_procedural_enabled and actor.climb_head_sway_enabled:
		var head := playertest2_skeleton.find_bone("head")
		if head >= 0:
			var phase := (climb_phase - actor.climb_arm_phase - actor.climb_head_sway_phase) * TAU
			if actor.climb_reverse_cycle:
				phase = -phase
			var roll := deg_to_rad(actor.climb_head_sway_degrees) * sin(phase)
			var head_axis := playertest2_skeleton.get_bone_global_rest(head).basis.orthonormalized().inverse() * Vector3.BACK
			var rest_rotation := playertest2_skeleton.get_bone_rest(head).basis.get_rotation_quaternion()
			targets[head] = rest_rotation * Quaternion(head_axis.normalized(), roll)
	if actor.climb_procedural_enabled and actor.climb_tail_sway_enabled:
		var tail := playertest2_skeleton.find_bone("tail_base")
		if tail >= 0:
			var sway := deg_to_rad(actor.climb_tail_sway_degrees) * _climb_cycle_wave(actor.climb_tail_sway_phase, actor)
			var rest_rotation := playertest2_skeleton.get_bone_rest(tail).basis.get_rotation_quaternion()
			targets[tail] = rest_rotation * _climb_axis_rotation(tail, Vector3.UP, sway)
	if actor.climb_procedural_enabled and actor.climb_torso_motion_enabled:
		var spine := playertest2_skeleton.find_bone("spine")
		if spine >= 0:
			var twist := deg_to_rad(actor.climb_torso_twist_degrees) * _climb_cycle_wave(actor.climb_torso_twist_phase, actor)
			var side_lean := deg_to_rad(actor.climb_torso_side_lean_degrees) * _climb_cycle_wave(actor.climb_torso_side_lean_phase, actor)
			var forward_lean := deg_to_rad(actor.climb_torso_forward_lean_degrees) * _climb_cycle_wave(actor.climb_torso_forward_lean_phase, actor)
			var rest_rotation := playertest2_skeleton.get_bone_rest(spine).basis.get_rotation_quaternion()
			targets[spine] = rest_rotation * _climb_axis_rotation(spine, Vector3.UP, twist) * _climb_axis_rotation(spine, Vector3.BACK, side_lean) * _climb_axis_rotation(spine, Vector3.RIGHT, forward_lean)
	for index in playertest2_skeleton.get_bone_count():
		var rest := playertest2_skeleton.get_bone_rest(index)
		var target: Quaternion = targets.get(index, rest.basis.get_rotation_quaternion())
		var grounded_rotation: Quaternion = walking_rotations.get(index, rest.basis.get_rotation_quaternion())
		target = grounded_rotation.slerp(target, stand_weight)
		var previous: Quaternion = air_pose_rotations.get(index, playertest2_skeleton.get_bone_pose_rotation(index))
		var rotation := previous.slerp(target, blend)
		var before_position: Vector3 = air_pose_positions.get(index, rest.origin)
		var bone_position := before_position.lerp(rest.origin, blend)
		playertest2_skeleton.set_bone_pose_rotation(index, rotation)
		playertest2_skeleton.set_bone_pose_position(index, bone_position)
		air_pose_rotations[index] = rotation
		air_pose_positions[index] = bone_position


func _climb_cycle_wave(offset: float, actor: ExplorerPlayer) -> float:
	var phase := (climb_phase - actor.climb_arm_phase - offset) * TAU
	return sin(-phase if actor.climb_reverse_cycle else phase)


func _climb_axis_rotation(index: int, axis: Vector3, angle: float) -> Quaternion:
	# Ejes del cuerpo convertidos al reposo local del hueso importado.
	var local_axis := playertest2_skeleton.get_bone_global_rest(index).basis.orthonormalized().inverse() * axis
	return Quaternion(local_axis.normalized(), angle)


func _tick_procedural_climb_sounds(previous: float, current: float, actor: ExplorerPlayer) -> void:
	if not actor.climb_sound_enabled or current <= previous:
		return
	var direction := -1.0 if actor.climb_reverse_cycle else 1.0
	for side_offset in [0.0, actor.climb_opposite_side_phase]:
		# Resuelve el punto del recorrido de cada brazo al reloj global.
		var contact := fposmod(actor.climb_arm_phase + side_offset + direction * actor.climb_sound_phase, 1.0)
		var count := int(floor(current - contact)) - int(floor(previous - contact))
		for _event in mini(count, 4):
			actor.feedback.emit("climb")


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
	climb_ground_offset_active = false
	position = Vector3.ZERO
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
