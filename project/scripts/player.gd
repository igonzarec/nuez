class_name ExplorerPlayer
extends CharacterBody3D

signal feedback(kind: String)
signal respawned

@export_group("Ground movement")
## Velocidad normal máxima sobre el suelo, en unidades por segundo; no cambia el ritmo visual por sí sola.
## Ejemplo: 4 permite explorar despacio; 6 recorre más terreno. Sprint Speed debe ser mayor para notar la carrera rápida.
@export_range(0.1, 20.0) var walk_speed := 5.6
## Velocidad máxima al mantener Shift, L1 o R1 y moverse, en unidades por segundo.
## Ejemplo: 7 da un sprint moderado; 10 uno más rápido. Las patas adaptan su ritmo a la velocidad real.
@export_range(0.1, 25.0) var sprint_speed := 8.0
@export_group("Animación del modelo artesanal")
## Rapidez del ciclo Run cuando el personaje camina. No modifica el movimiento ni la distancia recorrida.
@export_range(0.1, 3.0, 0.01) var walk_member_animation_speed := 0.72
## Rapidez del ciclo RunFast al mantener sprint. No modifica la velocidad física del personaje.
@export_range(0.1, 3.0, 0.01) var run_member_animation_speed := 1.35
@export_group("Ground movement")
## Rapidez para alcanzar la velocidad deseada en el suelo, en unidades/s². La entrada empieza a actuar de inmediato.
## Ejemplo: 20 tarda aproximadamente 0,28 s en alcanzar 5,6 desde reposo; 40 tarda 0,14 s. Menor valor da más peso.
@export_range(1.0, 100.0) var acceleration := 32.0
## Fuerza de frenado al soltar, invertir dirección o reducir velocidad, en unidades/s². No detiene en un solo frame.
## Ejemplo: desde 5,6, un valor de 28 frena en unos 0,20 s; 56 en 0,10 s. Muy bajo puede sentirse resbaloso.
@export_range(1.0, 100.0) var deceleration := 44.0
## Rapidez del suavizado con que el cuerpo mira hacia su desplazamiento real; no es un ángulo ni controla la cámara.
## Ejemplo: 8 produce giros más lentos; 22 responde con más rapidez. No gira al mover la cámara mientras estás quieto.
@export_range(1.0, 30.0) var turn_speed := 16.0
@export_group("Jump and air")
## Impulso vertical inicial del salto, en unidades/s. Un valor mayor aumenta altura y tiempo en el aire.
## Ejemplo: con Gravity 22, 8,52 alcanza unos 1,65 de altura; 10 alcanza 2,27, sin obstáculos.
@export_range(1.0, 30.0) var jump_velocity := 8.52
## Aceleración hacia abajo, en unidades/s². Más gravedad acorta y hace más firme el salto con el mismo impulso.
## Ejemplo: con Jump Velocity 8,52, Gravity 18 alcanza unos 2,02 de altura; 28 alcanza 1,30.
@export_range(1.0, 60.0) var gravity := 22.0
## Fracción de aceleración y frenado horizontal disponible en el aire; no modifica la gravedad.
## Ejemplo: 0 conserva la inercia horizontal sin dirigirla; 0,5 permite correcciones moderadas; 1 responde como en tierra.
@export_range(0.0, 1.0) var air_control := 0.52
## Segundos de tolerancia para saltar después de abandonar un borde. No permite un segundo salto.
## Ejemplo: 0,10 acepta un salto pulsado 100 ms tarde; 0 exige tener apoyo. No cambia la animación.
@export_range(0.0, 0.3) var coyote_time := 0.10
## Segundos durante los que se recuerda una pulsación anticipada de salto para ejecutarla al obtener apoyo.
## Ejemplo: 0,12 acepta pulsar hasta 120 ms antes de aterrizar. Mantener el botón no repite saltos. Usa un valor positivo: 0 desactiva la solicitud en este controlador.
@export_range(0.0, 0.3) var jump_buffer := 0.12
## Velocidad descendente mínima que activa la reacción de aterrizaje, en unidades/s; no mide altura ni limita el control.
## Ejemplo: 2 reacciona a caídas pequeñas; 5 ignora impactos suaves. Mantén Hard Landing Speed por encima.
@export_range(0.1, 15.0) var landing_threshold := 2.5
## Velocidad de impacto que alcanza la intensidad máxima de compresión al aterrizar, en unidades/s; no causa daño.
## Ejemplo: 12 alcanza la reacción fuerte antes; 24 la reserva para caídas mayores. La amplitud se ajusta con Landing Squash en Animation.
@export_range(5.0, 40.0) var hard_landing_speed := 18.0
@export_group("Ground contact")
## Distancia de búsqueda de suelo para conservar contacto al bajar por pendientes y pequeñas irregularidades.
## Ejemplo: 0,20 sigue desniveles pequeños; 0,45 tolera más cambios. Demasiado alto puede pegar al personaje a bordes. Se aplica al iniciar la escena.
@export_range(0.05, 0.8) var snap_distance := 0.35
## Inclinación máxima caminable, en grados desde el suelo horizontal. Las pendientes superiores con apoyo válido activan deslizamiento.
## Ejemplo: 40 vuelve resbaladizas más laderas; 55 permite subir laderas mayores. No convierte paredes en suelo. Se aplica al iniciar la escena.
@export_range(10.0, 60.0) var walkable_slope_degrees := 48.0
@export_group("Deslizamiento en pendientes")
## Rapidez con que aumenta la velocidad cuesta abajo en pendientes no caminables, en unidades/s².
## Ejemplo: 4 hace gradual el deslizamiento; 10 alcanza más pronto Slide Max Speed. No afecta las pendientes caminables.
@export_range(0.5, 15.0) var slide_acceleration := 7.0
## Límite de velocidad tangencial al resbalar, en unidades/s, incluyendo dirección lateral.
## Ejemplo: 2 baja despacio; 4 es más rápido. No cambia Walk Speed ni Sprint Speed.
@export_range(0.5, 8.0) var slide_max_speed := 3.0
## Intensidad del control lateral mientras resbala, como fracción de Walk Speed. No permite forzar la subida.
## Ejemplo: 0 no permite dirigir de lado; 0,2 da una corrección leve; 0,4 ofrece más control.
@export_range(0.0, 0.5) var slide_steering := 0.2
@export_group("Planeo")
## Permite desplegar membranas al pulsar Brincar una vez que la ardilla ya está en el aire.
## Mantener Brincar desde el salto no activa el planeo; al soltarlo, las membranas se recogen inmediatamente.
@export var glide_enabled := true
## Límite de caída durante planeo, en unidades/s. Nunca añade impulso hacia arriba.
## Ejemplo: 2 prolonga el descenso; 4 baja más rápido. No cambia el salto normal.
@export_range(1.0, 8.0) var glide_fall_speed := 2.6
## Fracción de gravedad durante el descenso planeando; la subida mantiene gravedad normal.
## Ejemplo: 0,25 entra suavemente en el descenso; 0,5 alcanza antes su límite de caída.
@export_range(0.1, 1.0) var glide_gravity_scale := 0.3
## Frenado vertical al desplegar durante una caída rápida, en unidades/s².
## Ejemplo: 18 frena progresivamente; 35 estabiliza antes, sin detenerse en seco.
@export_range(5.0, 60.0) var glide_braking := 30.0
## Control horizontal y de rumbo físico mientras planea.
## Ejemplo: 0,1 casi no permite corregir; 0,7 conserva la curvatura configurada; 1 hace que la trayectoria siga la palanca de inmediato.
@export_range(0.1, 1.0) var glide_air_control := 0.7
@export_group("Curvatura del planeo")
## Reducción adicional del control al intentar girar a mucha velocidad durante Glide.
## Ejemplo: 0 conserva el control actual; 0,35 suaviza las curvas; 1 produce curvas muy amplias a velocidad máxima.
@export_range(0.0, 1.0, 0.01) var glide_high_speed_turn_reduction := 0.35
## Máximo cambio de rumbo durante Glide, en grados por segundo.
## Ejemplo: 60 da vueltas amplias; 105 es equilibrado; 240 permite cambios de rumbo mucho más rápidos.
## Un valor menor obliga a describir curvas más amplias, incluso al mantener la dirección contraria o al comenzar desde reposo.
@export_range(10.0, 360.0, 1.0) var glide_turn_rate_degrees := 105.0
## Multiplicador del giro máximo al alcanzar la velocidad objetivo de Glide.
## Ejemplo: 1 conserva el mismo giro a cualquier velocidad; 0,55 da una trayectoria más amplia al ir rápido; 0,25 es muy pesado.
@export_range(0.1, 1.0, 0.01) var glide_high_speed_turn_rate_multiplier := 0.55
## Relación entre la orientación visual y el rumbo físico durante Glide.
## Ejemplo: 0 hace que el modelo siga solo la trayectoria; 0,35 da respuesta inmediata sin desconectarse; 1 reproduce un giro visual instantáneo.
@export_range(0.0, 1.0, 0.01) var glide_visual_turn_follow := 0.35
## Rapidez con que el modelo gira visualmente durante Glide; no cambia la trayectoria física.
## Ejemplo: 4 hace que el cuerpo acompañe con calma; 10 es fluido; 20 hace que mire al nuevo rumbo casi de inmediato.
@export_range(1.0, 30.0, 0.1) var glide_visual_turn_speed := 10.0
## Fracción de la velocidad horizontal que se conserva al describir una curva durante Glide.
## Ejemplo: 0 permite que el giro reduzca velocidad de forma normal; 0,85 se siente fluido; 1 conserva toda la velocidad al cambiar de rumbo.
@export_range(0.0, 1.0, 0.01) var glide_turn_speed_retention := 0.85
@export_group("Planeo con sprint · R1")
## Multiplica la velocidad horizontal de planeo mientras mantienes R1/Shift.
@export_range(1.0, 2.5, 0.01) var glide_sprint_speed_multiplier := 1.15
## Aumenta el límite de caída durante el planeo rápido, en unidades/s.
@export_range(0.0, 6.0, 0.1) var glide_sprint_fall_speed_bonus := 0.8
## Gravedad adicional durante el planeo rápido. Súbela para que caiga antes.
@export_range(0.0, 1.0, 0.01) var glide_sprint_gravity_scale_bonus := 0.12

var control_enabled := true
var spawn_position := Vector3.ZERO
var camera_rig: TrailCamera
var model: SquirrelRig
var animator: SquirrelAnimator
var animation_state := "idle"
var reaction_kind := ""
var reaction_time := 0.0
var landing_time := 0.0
var landing_strength := 0.0
var last_landing_speed := 0.0
var coyote_left := 0.0
var buffer_left := 0.0
var step_time := 0.0
var input_grace := 0.0
var horizontal_speed := 0.0
var motion_acceleration := Vector3.ZERO
var angular_velocity := 0.0
var jump_consumed := false
var previous_motion := Vector3.ZERO
var is_sliding := false
var slide_velocity := Vector3.ZERO
var is_gliding := false
var is_glide_sprinting := false
var glide_button_pressed_in_air := false
## Intensidad de entrada horizontal actual para que la postura de Glide sepa
## si la ardilla está intentando avanzar o simplemente está cayendo.
var glide_movement_intent := 0.0
## Rumbo visual e intensidad lateral solicitados durante Glide. Se separan de
## la trayectoria física para dar respuesta inmediata sin giros instantáneos.
var glide_facing_direction := Vector3.ZERO
var glide_turn_intent := 0.0
## Ángulo horizontal firmado entre el rumbo actual y el pedido. Solo lo usa
## el modelo para hacer bank/roll; nunca modifica la trayectoria física.
var glide_signed_turn_angle := 0.0
var glide_motion_heading := Vector3.ZERO

func _steep_support() -> Vector3:
	# Sample beneath the feet, never a forward wall. Leave a real jump untouched.
	if jump_consumed and velocity.y > 0.0: return Vector3.ZERO
	# A capsule can span a steep triangle while actually supported by a walkable
	# neighbor. Respect that real contact rather than braking at terrain seams.
	if is_on_floor() and get_floor_normal().y >= cos(floor_max_angle): return Vector3.ZERO
	var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.45, global_position - Vector3.UP * 0.48, collision_mask, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty(): return Vector3.ZERO
	var normal: Vector3 = hit.normal
	if normal.y > 0.15 and normal.y < cos(floor_max_angle + deg_to_rad(0.25)):
		return normal
	return Vector3.ZERO

func _ready() -> void:
	spawn_position = global_position
	process_mode = Node.PROCESS_MODE_PAUSABLE
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = snap_distance
	floor_max_angle = deg_to_rad(walkable_slope_degrees)
	floor_constant_speed = true
	floor_stop_on_slope = true
	safe_margin = 0.02
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.42
	shape.height = 1.42
	collider.shape = shape
	collider.position.y = 0.72
	add_child(collider)
	model = SquirrelRig.new()
	model.name = "AnimatedSquirrel"
	add_child(model)
	animator = get_node("Animation") as SquirrelAnimator
	animator.actor = self

func react(kind: String) -> void:
	reaction_kind = kind
	reaction_time = 0.45

func set_controls(enabled: bool) -> void:
	control_enabled = enabled
	if not enabled:
		glide_movement_intent = 0.0
		glide_facing_direction = Vector3.ZERO
		glide_turn_intent = 0.0
		glide_signed_turn_angle = 0.0
		glide_motion_heading = Vector3.ZERO
	input_grace = 0.16 if enabled else 0.0
	buffer_left = 0
	# The paused tree freezes the body. Preserve momentum and the jump arc:
	# clearing velocity here used to make airborne dialogue/resume drop vertically.
	previous_motion = Vector3(velocity.x, 0, velocity.z)
	motion_acceleration = Vector3.ZERO
	angular_velocity = 0

func respawn() -> void:
	global_position = spawn_position + Vector3.UP * 0.12
	velocity = Vector3.ZERO
	previous_motion = Vector3.ZERO
	horizontal_speed = 0
	motion_acceleration = Vector3.ZERO
	angular_velocity = 0
	buffer_left = 0
	coyote_left = 0
	jump_consumed = false
	is_sliding = false
	is_gliding = false
	is_glide_sprinting = false
	glide_button_pressed_in_air = false
	glide_movement_intent = 0.0
	glide_facing_direction = Vector3.ZERO
	glide_turn_intent = 0.0
	glide_signed_turn_angle = 0.0
	glide_motion_heading = Vector3.ZERO
	slide_velocity = Vector3.ZERO
	reaction_time = 0
	landing_time = 0
	animator.reset()
	reset_physics_interpolation()
	if camera_rig: camera_rig.snap()
	respawned.emit()

func _physics_process(delta: float) -> void:
	if not control_enabled: return
	input_grace = maxf(0, input_grace - delta)
	var grounded := is_on_floor()
	var steep_normal := _steep_support()
	is_sliding = steep_normal != Vector3.ZERO
	if grounded or is_sliding:
		is_gliding = false
		glide_button_pressed_in_air = false
		jump_consumed = false
		coyote_left = coyote_time
	else:
		coyote_left = maxf(0, coyote_left - delta)
	buffer_left = maxf(0, buffer_left - delta)
	var jump_pressed_this_frame := Input.is_action_just_pressed("jump")
	# El planeo necesita una pulsación nueva estando ya en el aire. Esto evita
	# que mantener Brincar desde el despegue lo active al comenzar a caer.
	if jump_pressed_this_frame and not grounded and not is_sliding:
		glide_button_pressed_in_air = true
	if not Input.is_action_pressed("jump"):
		glide_button_pressed_in_air = false
	# Un botón pulsado en el aire ahora sirve para iniciar planeo, no para
	# convertir accidentalmente una caída en un salto de coyote.
	if jump_pressed_this_frame and input_grace <= 0 and not glide_button_pressed_in_air:
		buffer_left = jump_buffer
	is_gliding = glide_enabled and not grounded and not is_sliding and glide_button_pressed_in_air and Input.is_action_pressed("jump")
	is_glide_sprinting = is_gliding and Input.is_action_pressed("sprint")
	if grounded:
		velocity.y = 0
	elif is_gliding and velocity.y <= 0:
		var glide_fall_limit := glide_fall_speed + (glide_sprint_fall_speed_bonus if is_glide_sprinting else 0.0)
		var glide_gravity := glide_gravity_scale + (glide_sprint_gravity_scale_bonus if is_glide_sprinting else 0.0)
		if velocity.y < -glide_fall_limit:
			velocity.y = move_toward(velocity.y, -glide_fall_limit, glide_braking * delta)
		else:
			velocity.y = maxf(-glide_fall_limit, velocity.y - gravity * glide_gravity * delta)
	else:
		velocity.y -= gravity * delta
	if buffer_left > 0 and coyote_left > 0 and not jump_consumed:
		velocity.y = jump_velocity
		jump_consumed = true
		is_sliding = false
		coyote_left = 0
		buffer_left = 0
		landing_time = 0
		feedback.emit("jump")
		animator.jump_started()
	var direction := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	glide_movement_intent = direction.length()
	# Movement follows the visible orbit, not its unsmoothed target yaw.
	var yaw := camera_rig.rotation.y if camera_rig else 0.0
	var desired := Vector3(direction.x, 0, direction.y).rotated(Vector3.UP, yaw)
	var target_speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	if is_glide_sprinting:
		target_speed *= glide_sprint_speed_multiplier
	var planar := Vector3(velocity.x, 0, velocity.z)
	var planar_speed_before_turn := planar.length()
	var glide_turn_amount := 0.0
	if grounded and planar.length_squared() > 0.0001:
		# Recover surface speed before accelerating; otherwise projecting to a slope
		# repeatedly shrinks the horizontal speed on every physics tick.
		planar = planar.normalized() * previous_motion.length()
	if not is_gliding:
		glide_motion_heading = Vector3.ZERO
	elif glide_motion_heading.length_squared() <= 0.0001:
		glide_motion_heading = planar.normalized() if planar.length_squared() > 0.0001 else Vector3.FORWARD.rotated(Vector3.UP, model.rotation.y)
	if is_gliding and desired.length_squared() > 0.0001:
		# Limita el cambio de dirección real, no solo la aceleración. Así mantener
		# la dirección opuesta dibuja una curva y nunca voltea instantáneamente.
		# Si apenas se mueve, usa el frente actual del modelo para impedir también
		# un giro instantáneo desde reposo durante Glide.
		var speed_ratio := clampf(planar.length() / maxf(0.1, target_speed), 0.0, 1.0)
		var turn_rate_scale := lerpf(1.0, glide_high_speed_turn_rate_multiplier, speed_ratio)
		# Hasta 0,7 se dosifica el giro configurado. De 0,7 a 1 el rumbo
		# gana seguimiento directo, para que 1 signifique control físico total.
		var direct_control := smoothstep(0.7, 1.0, glide_air_control)
		var turn_rate_control := minf(glide_air_control / 0.7, 1.0)
		var max_turn_angle := deg_to_rad(glide_turn_rate_degrees) * turn_rate_scale * turn_rate_control * delta
		var current_heading := planar.normalized() if planar.length_squared() > 0.0001 else glide_motion_heading
		var requested_heading := desired.normalized()
		var requested_turn := current_heading.signed_angle_to(requested_heading, Vector3.UP)
		glide_signed_turn_angle = requested_turn
		# La animación responde al rumbo pedido al instante, aunque la trayectoria
		# se limite abajo para conservar una curva física amplia.
		glide_facing_direction = requested_heading
		glide_turn_intent = clampf(requested_turn / (PI * 0.5), -1.0, 1.0) * glide_visual_turn_follow
		var limited_heading := current_heading.rotated(Vector3.UP, clampf(requested_turn, -max_turn_angle, max_turn_angle))
		var controlled_heading := limited_heading.slerp(requested_heading, direct_control).normalized()
		desired = controlled_heading * desired.length()
	else:
		glide_facing_direction = Vector3.ZERO
		glide_turn_intent = 0.0
		glide_signed_turn_angle = 0.0
	var braking := direction.length_squared() < 0.0025 or planar.length() > target_speed * direction.length() + 0.1
	# En tierra, invertir dirección desacelera antes de avanzar. Durante Glide,
	# el rumbo ya se curva arriba: no aplicar ese freno extra mantiene la inercia.
	if not is_gliding:
		braking = braking or planar.dot(desired) < -0.05
	var rate := deceleration if braking else acceleration
	var air_steering := glide_air_control if is_gliding else air_control
	if is_gliding and planar.length_squared() > 0.0001 and desired.length_squared() > 0.0001:
		# A alta velocidad, cambiar mucho de rumbo requiere una curva más amplia.
		# Avanzar recto conserva el control completo; solo se atenúan los giros.
		var speed_ratio := clampf(planar.length() / maxf(0.1, target_speed), 0.0, 1.0)
		var direction_change := clampf(1.0 - planar.normalized().dot(desired.normalized()), 0.0, 1.0)
		glide_turn_amount = direction_change
		var direct_control := smoothstep(0.7, 1.0, glide_air_control)
		air_steering *= 1.0 - glide_high_speed_turn_reduction * (1.0 - direct_control) * speed_ratio * direction_change
	planar = planar.move_toward(desired * target_speed, rate * (1.0 if grounded else air_steering) * delta)
	if is_gliding and glide_turn_amount > 0.001 and planar.length_squared() > 0.0001:
		var retained_speed := planar_speed_before_turn * glide_turn_speed_retention
		planar = planar.normalized() * maxf(planar.length(), retained_speed)
	velocity.x = planar.x
	velocity.z = planar.z
	if grounded and not jump_consumed and planar.length_squared() > 0.0001:
		var normal := get_floor_normal()
		# Enter the next triangle along the floor tangent, not horizontally into it.
		# Resetting Y to zero each tick made convex seams act like tiny walls.
		var tangent := Vector3(planar.x, -(normal.x * planar.x + normal.z * planar.z) / maxf(normal.y, 0.01), planar.z)
		velocity = tangent.normalized() * planar.length()
	if is_sliding:
		var downhill := Vector3.DOWN.slide(steep_normal).normalized()
		slide_velocity = slide_velocity.slide(steep_normal).move_toward(downhill * slide_max_speed, slide_acceleration * delta)
		# Steering is across the slope only: pushing uphill cannot defeat the slide.
		var steering := desired.slide(steep_normal)
		steering -= downhill * steering.dot(downhill)
		velocity = (slide_velocity + steering * walk_speed * slide_steering).limit_length(slide_max_speed) - steep_normal * 0.35
	else:
		slide_velocity = Vector3.ZERO
	var impact_speed := maxf(0, -velocity.y)
	var position_before_move := global_position
	move_and_slide()
	if is_on_floor(): is_gliding = false
	if grounded and not jump_consumed and not is_sliding:
		# Tangential uphill velocity is positive Y. Explicit snapping keeps contact
		# across a shallower triangle, without cancelling an intentional jump.
		apply_floor_snap()
	var actual := (global_position - position_before_move) / delta
	var actual_planar := Vector3(actual.x, 0, actual.z)
	if is_gliding and actual_planar.length_squared() > 0.0001:
		glide_motion_heading = actual_planar.normalized()
	horizontal_speed = actual_planar.length()
	motion_acceleration = motion_acceleration.lerp((actual_planar - previous_motion) / delta, 1.0 - exp(-12.0 * delta))
	previous_motion = actual if is_on_floor() else actual_planar
	angular_velocity = 0
	var facing_planar := actual_planar
	if is_gliding and glide_facing_direction.length_squared() > 0.0001:
		var motion_heading := glide_motion_heading if glide_motion_heading.length_squared() > 0.0001 else Vector3.FORWARD.rotated(Vector3.UP, model.rotation.y)
		var visual_turn := motion_heading.signed_angle_to(glide_facing_direction, Vector3.UP) * glide_visual_turn_follow
		facing_planar = motion_heading.rotated(Vector3.UP, visual_turn)
	if facing_planar.length_squared() > 0.0001:
		var old_yaw := model.rotation.y
		var target_angle := atan2(-facing_planar.x, -facing_planar.z)
		var visual_turn_speed := glide_visual_turn_speed if is_gliding else turn_speed
		var angle_step := wrapf(target_angle - old_yaw, -PI, PI) * (1.0 - exp(-visual_turn_speed * delta))
		model.rotation.y = wrapf(old_yaw + angle_step, -PI, PI)
		angular_velocity = angle_step / delta
	if not grounded and is_on_floor():
		last_landing_speed = impact_speed
		if impact_speed >= landing_threshold:
			landing_strength = lerpf(0.25, 1.0, clampf((impact_speed - landing_threshold) / maxf(0.1, hard_landing_speed - landing_threshold), 0, 1))
			landing_time = animator.landing_duration
			feedback.emit("land")
	if is_on_floor() and not is_sliding and horizontal_speed > 0.3:
		step_time += delta * horizontal_speed
		var step_distance := animator.stride_length * 0.5 / maxf(0.1, animator.cadence_multiplier)
		if step_time > step_distance:
			step_time = fmod(step_time, step_distance)
			feedback.emit("step")
	if global_position.y < -12.0:
		respawn()
		return
	animator.tick(delta, horizontal_speed)
	if not is_gliding:
		model.update_handmade_run(horizontal_speed, walk_member_animation_speed, run_member_animation_speed, Input.is_action_pressed("sprint"))
