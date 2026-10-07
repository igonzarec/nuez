extends Node
## Agarre por contacto frontal. La marca física climbable identifica la roca,
## independientemente de su material visual.
var actor: ExplorerPlayer
var wall_normal := Vector3.BACK
var cooldown := 0.0
var sound_distance := 0.0
var mantle_stage := 0
var mantle_up := Vector3.ZERO
var mantle_end := Vector3.ZERO

func reset() -> void:
	actor.is_climbing = false
	actor.climb_motion = 0.0
	mantle_stage = 0
	cooldown = 0.25
	sound_distance = 0.0

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	return actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, actor.collision_mask, [actor.get_rid()]))

func _wall_hit(direction: Vector3) -> Dictionary:
	var chest := actor.global_position + Vector3.UP * 0.85
	var hit := _ray(chest, chest + direction * actor.climb_grab_distance)
	if hit.is_empty() or not hit.collider is Node or not hit.collider.is_in_group("climbable"):
		return {}
	if hit.collider.has_method("allows_climb") and not hit.collider.allows_climb(hit.position):
		return {}
	var normal: Vector3 = hit.normal
	var normal_limit: float = hit.collider.climb_normal_limit() if hit.collider.has_method("climb_normal_limit") else 0.25
	if absf(normal.y) > normal_limit:
		return {}
	if direction.dot(-normal) < cos(deg_to_rad(actor.climb_facing_angle_degrees)):
		return {}
	return hit

func _release() -> void:
	reset()
	actor.velocity = wall_normal * actor.climb_detach_speed
	actor.glide_button_pressed_in_air = false
	actor.buffer_left = 0.0
	actor.coyote_left = 0.0
	actor.model.end_climb()

func tick(delta: float) -> bool:
	cooldown = maxf(0.0, cooldown - delta)
	if not actor.climb_enabled or not Input.is_action_pressed("jump"):
		if actor.is_climbing:
			_release()
		return false
	if not actor.is_climbing:
		if cooldown > 0.0 or actor.input_grace > 0.0:
			return false
		var forward := Vector3.FORWARD.rotated(Vector3.UP, actor.model.rotation.y)
		var contact := _wall_hit(forward)
		if contact.is_empty():
			return false
		wall_normal = contact.normal
		actor.is_climbing = true
		actor.is_gliding = false
		actor.is_glide_sprinting = false
		actor.is_sliding = false
		actor.glide_button_pressed_in_air = false
		actor.glide_signed_turn_angle = 0.0
		actor.glide_turn_intent = 0.0
		actor.glide_movement_intent = 0.0
		actor.velocity = Vector3.ZERO
		actor.buffer_left = 0.0
		actor.coyote_left = 0.0
		actor.animator.reset()
		actor.feedback.emit("climb")
	if mantle_stage != 0:
		_mantle_tick(delta)
		return true
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var contact := _wall_hit(-wall_normal)
	if contact.is_empty():
		if input.y < -0.1 and _start_mantle():
			return true
		_release()
		return false
	wall_normal = contact.normal
	var right := Vector3.UP.cross(wall_normal).normalized()
	# Arriba/abajo del stick son verticales en la pared; izquierda/derecha,
	# laterales respecto a la ardilla, aunque se haya orbitado la cámara.
	var tangent := (right * input.x + Vector3.UP * -input.y) * actor.climb_speed
	var distance := (actor.global_position - Vector3(contact.position)).dot(wall_normal)
	var correction := clampf((actor.climb_wall_distance - distance) * 12.0, -3.0, 3.0)
	actor.velocity = tangent + wall_normal * correction
	var before := actor.global_position
	actor.move_and_slide()
	var traveled := actor.global_position.distance_to(before)
	actor.climb_motion = traveled / maxf(delta, 0.001)
	actor.horizontal_speed = 0.0
	actor.previous_motion = Vector3.ZERO
	actor.motion_acceleration = Vector3.ZERO
	actor.angular_velocity = 0.0
	actor.model.rotation.y = lerp_angle(actor.model.rotation.y, atan2(wall_normal.x, wall_normal.z), 1.0 - exp(-12.0 * delta))
	actor.animation_state = "climb"
	actor.model.update_climb(actor.climb_motion, actor.climb_member_degrees, actor.climb_member_speed)
	sound_distance += traveled
	if sound_distance >= actor.climb_sound_spacing:
		sound_distance = fmod(sound_distance, actor.climb_sound_spacing)
		actor.feedback.emit("climb")
	return true

func _start_mantle() -> bool:
	# Busca suelo detrás del borde y comprueba el espacio de la cápsula en los
	# dos tramos. Así no atraviesa techos ni se teletransporta a repisas tapadas.
	var inside := actor.global_position - wall_normal * 1.25
	var hit := _ray(inside + Vector3.UP * 2.0, inside - Vector3.UP * 0.1)
	if hit.is_empty() or Vector3(hit.normal).y < 0.75:
		return false
	mantle_end = Vector3(inside.x, Vector3(hit.position).y + 0.06, inside.z)
	mantle_up = Vector3(actor.global_position.x, mantle_end.y + 0.15, actor.global_position.z)
	if actor.test_move(actor.global_transform, mantle_up - actor.global_position):
		return false
	var raised := actor.global_transform
	raised.origin = mantle_up
	if actor.test_move(raised, mantle_end - mantle_up):
		return false
	mantle_stage = 1
	return true

func _mantle_tick(delta: float) -> void:
	var target := mantle_up if mantle_stage == 1 else mantle_end
	var motion := (target - actor.global_position).limit_length(actor.climb_speed * delta)
	var collision := actor.move_and_collide(motion)
	actor.model.update_climb(actor.climb_speed, actor.climb_member_degrees, actor.climb_member_speed)
	if collision:
		_release()
	elif actor.global_position.distance_to(target) < 0.025:
		if mantle_stage == 1:
			mantle_stage = 2
		else:
			reset()
			actor.velocity = Vector3.ZERO
			actor.model.end_climb()
