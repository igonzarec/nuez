extends Node
## Agarre por contacto frontal. La marca física climbable identifica la roca,
## independientemente de su material visual.
var actor: ExplorerPlayer
var wall_normal := Vector3.BACK
var cooldown := 0.0
var mantle_stage := 0
var mantle_up := Vector3.ZERO
var mantle_end := Vector3.ZERO
var mantle_points: Array[Vector3] = []
var mantle_segment_start := Vector3.ZERO
var mantle_elapsed := 0.0
var mantle_duration := 0.55
var contact_lost_time := 0.0
var mantle_retry_left := 0.0
var forbidden_contact := false
var mantle_wall_normal := Vector3.BACK
var mantle_ground_normal := Vector3.UP
var mantle_surface_blend_start := 0.1
var mantle_surface_blend_end := 0.7
var firm_support_time := 0.0
var stand_elapsed := 0.0
var assist_direction := Vector3.FORWARD
var assist_distance := 0.0
var assist_cycles := 0.0

func reset() -> void:
	actor.is_climbing = false
	actor.climb_motion = 0.0
	mantle_stage = 0
	mantle_points.clear()
	contact_lost_time = 0.0
	mantle_retry_left = 0.0
	actor.climb_mantle_progress = -1.0
	actor.climb_stand_progress = -1.0
	actor.climb_surface_assist_active = false
	firm_support_time = 0.0
	stand_elapsed = 0.0
	cooldown = 0.25

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, actor.collision_mask, [actor.get_rid()]))
	if not hit.is_empty():
		var npc := hit.collider as ExplorerPlayer
		if npc and npc.is_in_group("npc_actors") and not npc.allows_climb(hit.position):
			# Bloqueo explícito también para apoyo de pies y asistencia de cima.
			# No continuar el rayo detrás del NPC ni recurrir al modo sin etiqueta.
			forbidden_contact = true
			return {}
	return hit

func _wall_hit(direction: Vector3, sustained := false) -> Dictionary:
	forbidden_contact = false
	var chest := actor.global_position + Vector3.UP * 0.85
	var hit := _ray(chest, chest + direction * actor.climb_grab_distance)
	if hit.is_empty():
		return {}
	var normal: Vector3 = hit.normal
	var collider := hit.collider as Node
	if collider and (collider.is_in_group("climbable") or collider.is_in_group("npc_actors")):
		# Las rocas procedurales mantienen sus zonas y sus límites propios. El
		# prototipo por pendiente no debe convertir una zona Disabled en escalable.
		if collider.has_method("allows_climb") and not collider.allows_climb(hit.position):
			forbidden_contact = true
			return {}
		var normal_limit: float = collider.climb_normal_limit() if collider.has_method("climb_normal_limit") else 0.25
		if sustained and actor.climb_sustain_enabled:
			normal_limit = maxf(normal_limit, cos(deg_to_rad(actor.climb_sustain_min_slope_degrees)))
		if absf(normal.y) > normal_limit:
			return {}
	elif not _is_untagged_steep_surface(normal, sustained):
		return {}
	if direction.dot(-normal) < cos(deg_to_rad(actor.climb_facing_angle_degrees)):
		return {}
	return hit

func _is_untagged_steep_surface(normal: Vector3, sustained := false) -> bool:
	# Terrain3D es una altura: sus normales útiles miran hacia arriba y nunca
	# superan 90°. No usamos su control map ni el material visual como gameplay.
	if not actor.climb_untagged_steep_surfaces_enabled or normal.y < 0.0:
		return false
	var slope_degrees := rad_to_deg(acos(clampf(normal.y, -1.0, 1.0)))
	var minimum := minf(actor.climb_untagged_min_slope_degrees, actor.climb_untagged_max_slope_degrees)
	var maximum := maxf(actor.climb_untagged_min_slope_degrees, actor.climb_untagged_max_slope_degrees)
	if sustained and actor.climb_sustain_enabled:
		minimum = minf(minimum, actor.climb_sustain_min_slope_degrees)
	return slope_degrees >= minimum and slope_degrees <= maximum

func _release() -> void:
	reset()
	actor.velocity = wall_normal * actor.climb_detach_speed
	actor.glide_button_pressed_in_air = false
	actor.buffer_left = 0.0
	actor.coyote_left = 0.0
	actor.model.end_climb()

func tick(delta: float) -> bool:
	cooldown = maxf(0.0, cooldown - delta)
	mantle_retry_left = maxf(0.0, mantle_retry_left - delta)
	var grab_held := actor.action_pressed("climb")
	if actor.is_splat or actor.is_glide_recoiling or not actor.climb_enabled or not grab_held:
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
		actor.climb_surface_normal = wall_normal
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
		contact_lost_time = 0.0
		mantle_retry_left = 0.0
		actor.climb_mantle_status = "Agarrado; esperando transición hacia la cima"
	if mantle_stage != 0:
		_mantle_tick(delta)
		return true
	var input := actor.movement_input()
	var contact := _wall_hit(-wall_normal, true)
	# Al rebasar la pared el pecho puede dejar de verla. Sólo se continúa
	# sobre suelo cercano bajo los pies; nunca se busca un destino lejano.
	if not forbidden_contact and not actor.climb_mantle_enabled:
		var support := _ray(actor.global_position + Vector3.UP * 0.1, actor.global_position - Vector3.UP * actor.snap_distance)
		if not support.is_empty() and _is_firm_ground(support.normal):
			var support_collider := support.collider as Node
			var allowed := not (support_collider and support_collider.has_method("allows_climb")) or bool(support_collider.call("allows_climb", support.position))
			if allowed:
				contact = support
	if contact.is_empty():
		if not forbidden_contact and input.y < -0.1 and _start_mantle():
			return true
		contact_lost_time += delta
		if not forbidden_contact and actor.climb_mantle_enabled and contact_lost_time < actor.climb_mantle_contact_grace:
			# Puente corto sobre una discontinuidad, nunca un teletransporte.
			var before := actor.global_position
			actor.velocity = Vector3.UP.slide(wall_normal).normalized() * actor.climb_speed if input.y < -0.1 else Vector3.ZERO
			actor.move_and_slide()
			actor.climb_motion = actor.global_position.distance_to(before) / maxf(delta, 0.001)
			actor.animation_state = "climb_search"
			actor.model.update_climb(actor.climb_motion)
			return true
		if forbidden_contact:
			actor.climb_mantle_status = "Agarre cancelado: zona no permitida"
		_release()
		return false
	contact_lost_time = 0.0
	wall_normal = contact.normal
	actor.climb_surface_normal = wall_normal
	if input.y < -0.1 and wall_normal.y >= cos(actor.floor_max_angle) and _start_mantle():
		return true
	var right := Vector3.UP.cross(wall_normal).normalized()
	# Arriba/abajo del stick son verticales en la pared; izquierda/derecha,
	# laterales respecto a la ardilla, aunque se haya orbitado la cámara.
	var surface_up := Vector3.UP.slide(wall_normal).normalized()
	if wall_normal.y >= cos(actor.floor_max_angle):
		# Cerca de horizontal la proyección de UP degenera. Conserva el
		# rumbo del jugador, sin hacerle girar al cambiar la normal.
		surface_up = Vector3.FORWARD.rotated(Vector3.UP, actor.model.rotation.y).slide(wall_normal).normalized()
		right = surface_up.cross(wall_normal).normalized()
	var tangent := (right * input.x + surface_up * -input.y) * actor.climb_speed
	var distance := (actor.global_position - Vector3(contact.position)).dot(wall_normal)
	var desired_distance := actor.climb_wall_distance
	if actor.climb_surface_follow_enabled:
		var slope_distance := lerpf(actor.climb_wall_distance, actor.climb_surface_floor_distance, clampf(wall_normal.y, 0.0, 1.0))
		desired_distance = lerpf(desired_distance, slope_distance, actor.climb_surface_follow_strength)
	var correction := clampf((desired_distance - distance) * 12.0, -3.0, 3.0)
	actor.velocity = tangent + wall_normal * correction
	if not actor.climb_mantle_enabled and wall_normal.y >= cos(actor.floor_max_angle):
		# Presión hacia el suelo, no elevación: move_and_slide resuelve el
		# apoyo de la cápsula y permite confirmar contacto físico real.
		actor.velocity = tangent - wall_normal * actor.climb_speed
	var before := actor.global_position
	actor.move_and_slide()
	actor.climb_motion = (actor.global_position - before).slide(wall_normal).length() / maxf(delta, 0.001)
	actor.horizontal_speed = 0.0
	actor.previous_motion = Vector3.ZERO
	actor.motion_acceleration = Vector3.ZERO
	actor.angular_velocity = 0.0
	if wall_normal.y < cos(actor.floor_max_angle):
		actor.model.rotation.y = lerp_angle(actor.model.rotation.y, atan2(wall_normal.x, wall_normal.z), 1.0 - exp(-12.0 * delta))
	actor.animation_state = "climb"
	if not actor.climb_mantle_enabled:
		var grounded := actor.is_on_floor() and _is_firm_ground(actor.get_floor_normal())
		if grounded:
			actor.climb_surface_normal = actor.get_floor_normal()
			firm_support_time += delta
			if firm_support_time >= actor.climb_finish_support_time:
				stand_elapsed += delta
				actor.climb_stand_progress = clampf(stand_elapsed / actor.climb_finish_stand_duration, 0.0, 1.0)
				actor.animation_state = "climb_stand"
				actor.climb_mantle_status = "Apoyo confirmado: incorporándose %.0f%%" % (actor.climb_stand_progress * 100.0)
		else:
			firm_support_time = 0.0
			stand_elapsed = 0.0
			actor.climb_stand_progress = -1.0
			actor.climb_mantle_status = "Salida natural: siguiendo la superficie; esperando apoyo firme"
	actor.model.update_climb(actor.climb_motion)
	if actor.climb_stand_progress >= 1.0:
		_finish_mantle()
	elif actor.climb_mantle_enabled and input.y < -0.1 and actor.is_on_floor() and _is_firm_ground(actor.get_floor_normal()):
		_start_mantle()
	return true

func _start_mantle() -> bool:
	if actor.climb_mantle_surface_assist_enabled:
		return _start_surface_assist()
	return _start_legacy_mantle()

func _start_surface_assist() -> bool:
	if not actor.climb_mantle_enabled or mantle_retry_left > 0.0:
		return false
	mantle_retry_left = actor.climb_mantle_retry_interval
	var forward := Vector3(-wall_normal.x, 0.0, -wall_normal.z).normalized()
	if forward.is_zero_approx():
		forward = Vector3.FORWARD.rotated(Vector3.UP, actor.model.rotation.y)
	# La búsqueda autoriza iniciar, no define una trayectoria por el aire.
	var minimum := minf(actor.climb_mantle_search_min_reach, actor.climb_mantle_forward_reach)
	var maximum := maxf(minimum, actor.climb_mantle_forward_reach + actor.climb_mantle_search_extension)
	for sample in actor.climb_mantle_search_samples:
		var reach := lerpf(minimum, maximum, float(sample) / maxf(1.0, actor.climb_mantle_search_samples - 1))
		var point := actor.global_position + forward * reach
		var support := _ray(point + Vector3.UP * actor.climb_mantle_max_height, point - Vector3.UP * actor.climb_mantle_max_drop)
		if support.is_empty() or not _is_firm_ground(support.normal) or not _allows_support(support):
			continue
		assist_direction = forward
		assist_distance = 0.0
		assist_cycles = 0.0
		mantle_elapsed = 0.0
		firm_support_time = 0.0
		stand_elapsed = 0.0
		contact_lost_time = 0.0
		mantle_stage = 4
		actor.climb_surface_assist_active = true
		actor.climb_mantle_cycle_count = actor.climb_mantle_extra_cycles
		actor.climb_mantle_status = "Asistencia iniciada: siguiendo superficie real"
		return true
	actor.climb_mantle_status = "Asistencia: sin suelo caminable delante dentro del alcance"
	return false

func _allows_support(hit: Dictionary) -> bool:
	var collider := hit.collider as Node
	return not (collider and collider.has_method("allows_climb")) or bool(collider.call("allows_climb", hit.position))

func _surface_assist_tick(delta: float) -> void:
	mantle_elapsed += delta
	var feet := _ray(actor.global_position + Vector3.UP * 0.1, actor.global_position - Vector3.UP * actor.snap_distance)
	var contact := _wall_hit(-wall_normal, true)
	if forbidden_contact:
		_release()
		return
	if not feet.is_empty() and _allows_support(feet):
		contact = feet
	if contact.is_empty() or not _allows_support(contact):
		# No inventa apoyo ni prolonga avance sobre un hueco.
		_cancel_surface_assist("Asistencia pausada: sin contacto real")
		return
	wall_normal = Vector3(contact.normal).normalized()
	actor.climb_surface_normal = wall_normal
	var uphill := assist_direction.slide(wall_normal).normalized()
	if uphill.is_zero_approx():
		uphill = Vector3.UP.slide(wall_normal).normalized()
	actor.velocity = uphill * actor.climb_mantle_surface_speed - wall_normal * actor.climb_mantle_surface_contact_speed
	var before := actor.global_position
	actor.move_and_slide()
	var traveled := actor.global_position.distance_to(before)
	assist_distance += traveled
	actor.climb_motion = traveled / maxf(delta, 0.001)
	if traveled > 0.0001:
		assist_cycles += delta * actor.climb_mantle_cycle_speed
	var grounded := actor.is_on_floor() and _is_firm_ground(actor.get_floor_normal())
	if grounded:
		actor.climb_surface_normal = actor.get_floor_normal()
		firm_support_time += delta
		if firm_support_time >= actor.climb_finish_support_time and assist_cycles >= actor.climb_mantle_cycle_count:
			stand_elapsed += delta
			actor.climb_stand_progress = clampf(stand_elapsed / actor.climb_finish_stand_duration, 0.0, 1.0)
	else:
		firm_support_time = 0.0
		stand_elapsed = 0.0
		actor.climb_stand_progress = -1.0
	actor.animation_state = "climb_surface_exit"
	actor.climb_mantle_status = "Superficie real: %.2f m; %.1f/%d vueltas; apoyo %s" % [assist_distance, assist_cycles, actor.climb_mantle_cycle_count, "sí" if grounded else "no"]
	actor.model.update_climb(actor.climb_motion)
	if actor.climb_stand_progress >= 1.0:
		_finish_mantle()
	elif assist_distance >= actor.climb_mantle_surface_max_distance or mantle_elapsed >= actor.climb_mantle_surface_timeout:
		_cancel_surface_assist("Asistencia detenida: límite de recorrido/tiempo; control de trepa recuperado")

func _cancel_surface_assist(message: String) -> void:
	mantle_stage = 0
	actor.climb_surface_assist_active = false
	actor.climb_stand_progress = -1.0
	actor.velocity = Vector3.ZERO
	mantle_retry_left = actor.climb_mantle_contact_grace
	actor.climb_mantle_status = message

func _start_legacy_mantle() -> bool:
	if not actor.climb_mantle_enabled:
		return false
	if mantle_retry_left > 0.0:
		return false
	mantle_retry_left = actor.climb_mantle_retry_interval
	var inward := Vector3(-wall_normal.x, 0.0, -wall_normal.z).normalized()
	if inward.is_zero_approx():
		inward = Vector3.FORWARD.rotated(Vector3.UP, actor.model.rotation.y)
	var minimum := minf(actor.climb_mantle_search_min_reach, actor.climb_mantle_forward_reach)
	var maximum := maxf(minimum, actor.climb_mantle_forward_reach + actor.climb_mantle_search_extension)
	var no_ground := 0
	var steep := 0
	var blocked := 0
	var last_blocked_stage := 0
	for sample in actor.climb_mantle_search_samples:
		var fraction := float(sample) / maxf(1.0, actor.climb_mantle_search_samples - 1)
		var reach := lerpf(minimum, maximum, fraction)
		var inside := actor.global_position + inward * reach
		var hit := _ray(inside + Vector3.UP * actor.climb_mantle_max_height, inside - Vector3.UP * actor.climb_mantle_max_drop)
		if hit.is_empty():
			no_ground += 1
			continue
		if not _is_firm_ground(hit.normal):
			steep += 1
			continue
		var end := Vector3(inside.x, Vector3(hit.position).y + actor.climb_mantle_floor_margin, inside.z)
		var clearance_y := maxf(actor.global_position.y, end.y) + actor.climb_mantle_clearance
		var up := Vector3(actor.global_position.x, clearance_y, actor.global_position.z)
		var over := Vector3(end.x, clearance_y, end.z)
		var points: Array[Vector3] = [up, over, end]
		var probe := actor.global_transform
		var clear := true
		for stage in points.size():
			if actor.test_move(probe, points[stage] - probe.origin):
				blocked += 1
				last_blocked_stage = stage + 1
				clear = false
				break
			probe.origin = points[stage]
		if not clear:
			continue
		mantle_end = end
		mantle_wall_normal = wall_normal
		mantle_ground_normal = Vector3(hit.normal).normalized()
		mantle_surface_blend_start = actor.climb_mantle_surface_blend_start
		mantle_surface_blend_end = maxf(mantle_surface_blend_start + 0.01, actor.climb_mantle_surface_blend_end)
		mantle_up = up
		mantle_points = points
		mantle_stage = 1
		mantle_segment_start = actor.global_position
		mantle_elapsed = 0.0
		contact_lost_time = 0.0
		actor.climb_mantle_cycle_start = actor.model.climb_phase
		actor.climb_mantle_cycle_count = actor.climb_mantle_extra_cycles
		var rate := maxf(0.1, actor.climb_mantle_cycle_speed)
		mantle_duration = maxf(actor.climb_mantle_duration, float(actor.climb_mantle_cycle_count) / rate / 0.85)
		actor.climb_mantle_progress = 0.0
		actor.velocity = Vector3.ZERO
		actor.climb_mantle_status = "Salida iniciada: apoyo a %.2f m; %d vueltas" % [reach, actor.climb_mantle_cycle_count]
		return true
	actor.climb_mantle_status = "Sin salida: %d sin suelo; %d con pendiente excesiva; %d bloqueados (último tramo %d). Límite efectivo %.1f°" % [no_ground, steep, blocked, last_blocked_stage, rad_to_deg(minf(actor.floor_max_angle, deg_to_rad(actor.climb_finish_max_slope_degrees)))]
	return false

func _mantle_tick(delta: float) -> void:
	if mantle_stage == 4:
		_surface_assist_tick(delta)
		return
	mantle_elapsed += delta
	var segment_duration := mantle_duration / 3.0
	var fraction := clampf(mantle_elapsed / segment_duration, 0.0, 1.0)
	var target := mantle_segment_start.lerp(mantle_points[mantle_stage - 1], smoothstep(0.0, 1.0, fraction))
	var motion := target - actor.global_position
	var collision := actor.move_and_collide(motion)
	actor.climb_mantle_progress = (float(mantle_stage - 1) + fraction) / 3.0
	# Transición de plano: no conserva la normal vertical de la pared
	# mientras el cuerpo ya está pasando sobre la superficie superior.
	var support_hit := _ray(actor.global_position + Vector3.UP * actor.climb_mantle_max_height, actor.global_position - Vector3.UP * (actor.climb_mantle_max_drop + actor.climb_mantle_floor_margin))
	if not support_hit.is_empty() and _is_firm_ground(support_hit.normal):
		mantle_ground_normal = Vector3(support_hit.normal).normalized()
	var surface_mix := smoothstep(mantle_surface_blend_start, mantle_surface_blend_end, actor.climb_mantle_progress)
	actor.climb_surface_normal = mantle_wall_normal.slerp(mantle_ground_normal, surface_mix).normalized()
	actor.animation_state = "climb_mantle"
	actor.model.update_climb(0.0)
	if collision:
		actor.climb_mantle_status = "Salida cancelada: colisión durante el tramo %d" % mantle_stage
		_release()
	elif fraction >= 1.0:
		if mantle_stage < 3:
			mantle_stage += 1
			mantle_segment_start = actor.global_position
			mantle_elapsed = 0.0
		else:
			# Confirma el apoyo real bajo el destino antes de ceder el control.
			var support := _ray(actor.global_position + Vector3.UP * 0.2, actor.global_position - Vector3.UP * (actor.climb_mantle_floor_margin + 0.3))
			if not support.is_empty() and _is_firm_ground(support.normal):
				_finish_mantle()
			else:
				actor.climb_mantle_status = "Salida cancelada: el destino ya no tiene apoyo firme"
				_release()


func _finish_mantle() -> void:
	var natural_finish := actor.climb_stand_progress >= 0.0
	var surface_finish := actor.climb_surface_assist_active
	actor.climb_mantle_status = "Salida completada: tierra firme"
	reset()
	actor.velocity = Vector3.ZERO
	actor.previous_motion = Vector3.ZERO
	actor.horizontal_speed = 0.0
	actor.model.end_climb(natural_finish, surface_finish)


func _is_firm_ground(normal: Vector3) -> bool:
	var angle := minf(actor.floor_max_angle, deg_to_rad(actor.climb_finish_max_slope_degrees))
	return normal.y >= cos(angle)
