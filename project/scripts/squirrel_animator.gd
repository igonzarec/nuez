class_name SquirrelAnimator
extends Node
## Estado visual común del jugador. Las extremidades se animan en playertest2.

@export_group("Ritmo y transiciones")
## Mantiene la frecuencia de pasos lógicos y de los sonidos ya existentes.
@export_range(0.5, 4.0) var stride_length := 2.1
@export_range(0.5, 1.5) var cadence_multiplier := 1.0
@export_range(1.0, 30.0) var blend_speed := 14.0

@export_group("Cuerpo")
@export_range(0.0, 0.06) var body_bounce := 0.022
@export_range(0.0, 0.05) var body_sway := 0.014
@export_range(0.0, 10.0) var run_lean_degrees := 3.0
@export_range(0.0, 0.2) var acceleration_lean := 0.045
@export_range(0.0, 0.2) var turn_lean := 0.055
@export_range(0.0, 0.05) var run_squash := 0.012

@export_group("Salto y aterrizaje")
@export_range(0.05, 0.3) var landing_duration := 0.16
@export_range(0.0, 0.2) var landing_squash := 0.09

@export_group("Salto procedural · postura")
## Activa poses graduales de salto, caída y contracción al aterrizar. Se actualiza en vivo; al apagarlo el aire usa la pose base, sin Run.
@export var air_pose_enabled := true
## Apertura lateral de cada pierna al despegar, en grados. Más alto abre más las patas. Se actualiza en vivo.
@export_range(0.0, 40.0, 0.5) var air_leg_spread_degrees := 40.0
## Segundos desde el despegue hasta cerrar las piernas. Mayor valor mantiene la apertura más tiempo. Se actualiza en vivo.
@export_range(0.05, 1.5, 0.01, "suffix:s") var air_leg_close_duration := 1.5
## Apertura lateral máxima de cada pierna durante una caída prolongada, en grados. Mayor valor abre más las patas; 0 desactiva esta apertura sin alterar el despegue. Se actualiza en vivo y se mezcla al abandonar la zancada de avance.
@export_range(0.0, 70.0, 0.5) var air_fall_leg_spread_degrees := 25.0
## Segundos cayendo antes de empezar a abrir las piernas lateralmente. Mayor valor reserva el efecto para caídas más largas. Se actualiza en vivo; no cuenta el tiempo de subida, planeo ni escalada.
@export_range(0.0, 2.0, 0.01, "suffix:s") var air_fall_leg_spread_delay := 0.18
## Segundos desde que empieza la apertura hasta alcanzar Fall Leg Spread Degrees. Mayor valor abre las piernas más despacio; menor responde antes. Se actualiza en vivo y la mezcla general Air Pose Response también suaviza el resultado.
@export_range(0.05, 3.0, 0.01, "suffix:s") var air_fall_leg_spread_duration := 0.6
## Elevación de cada brazo respecto al reposo al despegar, en grados. Mayor valor separa más los brazos del cuerpo. Se actualiza en vivo.
@export_range(0.0, 150.0, 0.5) var air_arm_start_degrees := 5.0
## Elevación de brazos al llegar al punto más alto, en grados. Mayor valor eleva más las manos. Se actualiza en vivo.
@export_range(0.0, 150.0, 0.5) var air_arm_apex_degrees := 56.0
## Límite de elevación de brazos en caída, en grados. Mayor valor acerca las manos a la cabeza. Se actualiza en vivo.
@export_range(0.0, 170.0, 0.5) var air_arm_fall_degrees := 93.5
## Desplazamiento máximo de cada hombro hacia el centro del torso, en metros, al elevar el brazo. 0 desactiva la corrección; mayor valor oculta más la unión redondeada. Se actualiza en vivo y vuelve a la posición original al bajar los brazos.
@export_range(0.0, 0.15, 0.005, "suffix:m") var air_arm_inset := 0.08
## Elevación de brazos, en grados desde reposo, a la que se alcanza todo Arm Inset. Menor valor mete los hombros antes; mayor lo reparte a lo largo del giro. Se actualiza en vivo; no afecta el ángulo de los brazos.
@export_range(5.0, 170.0, 0.5) var air_arm_inset_full_angle := 90.0
## Rapidez de caída en m/s que alcanza la postura y el temblor máximos. Menor valor los activa antes. Se actualiza en vivo.
@export_range(0.1, 20.0, 0.1, "suffix:m/s") var air_full_fall_speed := 5.0
## Amplitud máxima de temblor de brazos en grados, escalada con la caída. 0 lo desactiva. Se actualiza en vivo.
@export_range(0.0, 15.0, 0.1) var air_tremor_degrees := 10.6
## Oscilaciones de brazos por segundo. Mayor valor vibra más rápido; 0 desactiva el temblor. Se actualiza en vivo.
@export_range(0.0, 20.0, 0.1, "suffix:Hz") var air_tremor_frequency := 7.0
## Rapidez de mezcla de huesos por segundo al entrar y salir de la pose. Mayor valor responde antes; menor suaviza. Se actualiza en vivo.
@export_range(1.0, 40.0, 0.5) var air_pose_response := 18.0

@export_group("Salto en movimiento · zancada aérea")
## Activa una pose fija de zancada al saltar avanzando. Cambia de lado sólo al iniciar otro salto; al caer se mezcla con la postura normal. Se actualiza en vivo.
@export var air_stride_enabled := true
## Giro del brazo adelantado en grados. Mayor valor lo adelanta más; 0 elimina su giro longitudinal. Cambia de lado con cada salto. Se actualiza en vivo, independiente de Backward Degrees.
@export_range(0.0, 150.0, 0.5) var air_stride_arm_forward_degrees := 67.5
## Giro del brazo retrasado en grados. Mayor valor lo lleva más atrás; 0 elimina su giro longitudinal. Cambia de lado con cada salto. Se actualiza en vivo; ángulos extremos pueden cruzar las mallas del hombro.
@export_range(0.0, 150.0, 0.5) var air_stride_arm_backward_degrees := 96.0
## Giro máximo de cada pierna, opuesto al brazo del mismo lado, en grados. Mayor valor abre más la zancada longitudinal. Se actualiza en vivo.
@export_range(0.0, 70.0, 0.5) var air_stride_leg_degrees := 70.0
## Desplazamiento de la pierna adelantada hacia el frente del personaje, en metros, además de su giro. Mayor valor adelanta más la pata; 0 desactiva sólo este desplazamiento. Se actualiza en vivo y se reduce con la zancada al caer. Valores grandes pueden separar la unión de la cadera.
@export_range(0.0, 0.2, 0.005, "suffix:m") var air_stride_leg_forward_offset := 0.125
## Desplazamiento de la pierna retrasada hacia atrás, en metros, independiente de Forward Offset. Mayor valor retrasa más la pata; 0 desactiva sólo este desplazamiento. Se actualiza en vivo y cambia de pierna en el siguiente salto. Valores grandes pueden separar la unión de la cadera.
@export_range(0.0, 0.2, 0.005, "suffix:m") var air_stride_leg_backward_offset := 0.13
## Inclinación del torso hacia el frente en la pose de salto avanzando, en grados. Mayor valor inclina más pecho y hombros; 0 conserva el torso erguido. Se actualiza en vivo y se desvanece al recuperar la postura de caída.
@export_range(0.0, 40.0, 0.5) var air_stride_torso_lean_degrees := 15.5
## Avance adicional de la cabeza respecto al torso durante la zancada aérea, en metros. Mayor valor adelanta más la cabeza; 0 elimina sólo este avance. Se actualiza en vivo; valores extremos pueden separar la unión del cuello.
@export_range(0.0, 0.15, 0.005, "suffix:m") var air_stride_head_forward_offset := 0.025
## Velocidad horizontal en m/s para toda la zancada al despegar. La intensidad se captura al entrar al aire y se conserva en ese salto; la intención de movimiento también activa la postura. Menor valor admite velocidades menores. Afecta el siguiente salto.
@export_range(0.2, 12.0, 0.1, "suffix:m/s") var air_stride_full_speed := 3.0
## Segundos cayendo antes de recuperar la postura normal. Mayor valor mantiene más tiempo la pose fija. Se actualiza en vivo; después se aplican Fall Start/End Speed.
@export_range(0.0, 1.0, 0.01, "suffix:s") var air_stride_fall_delay := 0.12
## Rapidez descendente en m/s a la que empieza a recuperar la postura de caída normal. Mayor valor conserva más tiempo la zancada. Debe ser menor que Fall End Speed. Se actualiza en vivo.
@export_range(0.0, 15.0, 0.1, "suffix:m/s") var air_stride_fall_start_speed := 1.0
## Rapidez descendente en m/s a la que termina de apagar la zancada, aunque siga avanzando horizontalmente. Mayor valor retrasa la postura normal de caída. Se actualiza en vivo.
@export_range(0.1, 25.0, 0.1, "suffix:m/s") var air_stride_fall_end_speed := 6.0
## Rapidez de mezcla por segundo entre salto quieto, zancada y caída. Menor valor suaviza y retrasa la transición; mayor responde antes. Se actualiza en vivo.
@export_range(1.0, 30.0, 0.5) var air_stride_blend_speed := 10.0

@export_group("Aterrizaje procedural")
## Descenso máximo del torso respecto a las piernas en metros, graduado por el impacto. Mayor valor contrae más el cuerpo; valores extremos pueden cruzar mallas. Se actualiza en vivo.
@export_range(0.0, 0.25, 0.005, "suffix:m") var landing_body_drop := 0.10
## Retracción adicional de cabeza hacia el torso en metros. Mayor valor esconde más el cuello; valores extremos cruzan mallas. Se actualiza en vivo.
@export_range(0.0, 0.10, 0.005, "suffix:m") var landing_head_retract := 0.035
## Inclinación de cabeza hacia delante al contraerse, en grados. Mayor valor hace más marcado el asentimiento. Se actualiza en vivo.
@export_range(0.0, 25.0, 0.5) var landing_head_pitch_degrees := 6.0
## Segundos desde el impacto hasta máxima contracción. Mayor valor hace la absorción más lenta. Se consulta al aterrizar.
@export_range(0.02, 0.3, 0.01, "suffix:s") var landing_compress_duration := 0.07
## Segundos para recuperar la postura después de contraerse. Mayor valor alarga la recuperación. Se consulta al aterrizar.
@export_range(0.05, 0.8, 0.01, "suffix:s") var landing_recover_duration := 0.22
## Rapidez por segundo para recuperar brazos y piernas de caminar/correr al tocar suelo. Mayor valor recupera antes la zancada terrestre; menor suaviza la mezcla. La contracción de torso y cabeza continúa encima del clip. Se actualiza en vivo.
@export_range(1.0, 60.0, 0.5) var landing_locomotion_response := 30.0

@export_group("Postura de planeo")
## Inclinación base hacia delante durante Glide, incluso sin entrada de movimiento.
## Ejemplo: 20° es planeo tranquilo; 45° es marcado; cerca de 85° es una postura extrema.
@export_range(0.0, 85.0, 0.5) var glide_lean_degrees := 20.0
@export_range(3.0, 25.0) var glide_blend_speed := 12.0
## Inclinación añadida mientras mantienes una dirección durante Glide.
## Ejemplo: 0 conserva la misma postura; 6° da intención de avance; 15° es una picada clara.
@export_range(0.0, 40.0, 0.5) var glide_movement_extra_lean_degrees := 6.0
## Inclinación adicional al mantener L1/Shift y moverse durante el planeo.
@export_range(0.0, 50.0, 0.5) var glide_sprint_extra_lean_degrees := 12.0

@export_group("Banking de planeo")
## Inclinación lateral máxima al cambiar de dirección mientras planea.
## Ejemplo: 10° es apenas visible; 22° es natural; 40° se siente como un giro agresivo de ave.
@export_range(0.0, 75.0, 0.5) var glide_bank_degrees := 22.0
## Diferencia de rumbo pedida que alcanza el bank máximo.
## Ejemplo: 35° reacciona con fuerza en curvas breves; 70° es más gradual; 120° reserva el máximo para cambios cerrados.
@export_range(10.0, 180.0, 1.0) var glide_bank_full_turn_angle_degrees := 65.0
## Rapidez de giro real (grados/s) que refuerza el banking iniciado por la palanca. Menor valor lo refuerza antes.
## Ejemplo: 150 refuerza curvas suaves; 300 es equilibrado; 600 reserva ese refuerzo para curvas muy cerradas.
@export_range(45.0, 1080.0, 1.0) var glide_bank_full_turn_rate_degrees := 300.0
## Rapidez con que el cuerpo entra y sale de la inclinación lateral.
## Ejemplo: 4 se siente pesado y suave; 10 es equilibrado; 20 responde casi de inmediato.
@export_range(1.0, 30.0, 0.1) var glide_bank_blend_speed := 10.0
## Actívalo si el rig se inclina hacia el exterior de la curva en vez de hacia el interior.
## Ejemplo: déjalo apagado normalmente; actívalo solo para corregir una orientación de ejes invertida del modelo importado.
@export var glide_bank_invert := false

@export_group("Planeo · modelo artesanal")
## Velocidad de la vibración incluida en la acción Glide de Blender.
@export_range(0.1, 3.0, 0.01) var handmade_glide_flutter_speed := 1.0
## Velocidad de la animación de despliegue GlideStart de Blender.
@export_range(0.1, 3.0, 0.01) var handmade_glide_start_speed := 1.0
## Amplitud adicional de vibración de brazos y piernas mientras planea.
@export_range(0.0, 20.0, 0.1) var handmade_glide_tremor_degrees := 2.5
## Frecuencia de esa vibración. Cero la deja quieta.
@export_range(0.0, 30.0, 0.1) var handmade_glide_tremor_speed := 12.0

var actor: ExplorerPlayer
var glide_blend := 0.0
var clock := 0.0
var gait_phase := 0.0
var run_blend := 0.0
var jump_start := 0.0
var locomotion_state := "idle"
var body_pitch := 0.0
var body_roll := 0.0
var body_bank := 0.0
var was_glide_landing := false
var glide_landing_entry_angles := Vector3.ZERO
var air_elapsed := 0.0
var air_launch_speed := 1.0
var landing_elapsed := -1.0
var landing_compress_time := 0.07
var landing_recover_time := 0.22
var air_stride_side := -1.0
var air_stride_weight := 0.0
var air_stride_fall_weight := 0.0
var air_stride_launch_weight := 0.0
var air_stride_capture_pending := true
var air_was_airborne := false
var air_stride_fall_elapsed := 0.0

func landed() -> void:
	landing_elapsed = 0.0
	landing_compress_time = landing_compress_duration
	landing_recover_time = landing_recover_duration

func jump_started() -> void:
	jump_start = 0.10
	air_elapsed = 0.0
	air_launch_speed = maxf(0.1, actor.velocity.y)
	air_stride_side = -air_stride_side
	air_stride_capture_pending = true
	air_stride_fall_elapsed = 0.0
	air_stride_fall_weight = 0.0
	landing_elapsed = -1.0

func reset() -> void:
	was_glide_landing = false
	glide_blend = 0.0
	run_blend = 0.0
	jump_start = 0.0
	air_elapsed = 0.0
	landing_elapsed = -1.0
	air_stride_side = -1.0
	air_stride_weight = 0.0
	air_stride_fall_weight = 0.0
	air_stride_launch_weight = 0.0
	air_stride_capture_pending = true
	air_was_airborne = false
	air_stride_fall_elapsed = 0.0
	actor.model.glide_amount = 0.0
	actor.model.position = Vector3.ZERO
	actor.model.scale = Vector3.ONE
	body_pitch = 0.0
	body_roll = 0.0
	body_bank = 0.0
	actor.model.reset_body_tilt()
	actor.model.reset_interpolation()

func tick(delta: float, speed: float) -> void:
	clock += delta
	if actor.is_glide_landing:
		# El aterrizaje usa el ángulo normal de Glide, sin intención ni Sprint.
		locomotion_state = "glide_land"
		actor.animation_state = locomotion_state
		if not was_glide_landing:
			glide_landing_entry_angles = Vector3(body_pitch, body_roll, body_bank)
		was_glide_landing = true
		var pose_mix := smoothstep(actor.glide_landing_pose_delay, actor.glide_landing_pose_delay + actor.glide_landing_pose_blend_duration, actor.glide_landing_elapsed)
		body_pitch = lerp_angle(glide_landing_entry_angles.x, -deg_to_rad(glide_lean_degrees), pose_mix)
		body_roll = lerp_angle(glide_landing_entry_angles.y, 0.0, pose_mix)
		body_bank = lerp_angle(glide_landing_entry_angles.z, 0.0, pose_mix)
		actor.model.set_body_tilt(body_pitch, body_roll, body_bank)
		actor.model.hold_glide_landing_pose()
		return
	was_glide_landing = false
	var grounded := actor.is_on_floor() or actor.is_sliding
	var blend := 1.0 - exp(-blend_speed * delta)
	glide_blend = lerpf(glide_blend, 1.0 if actor.is_gliding else 0.0, 1.0 - exp(-glide_blend_speed * delta))
	run_blend = lerpf(run_blend, 1.0 if speed > 0.12 and grounded and not actor.is_sliding else 0.0, blend)
	if grounded and not actor.is_sliding:
		gait_phase += actor.previous_motion.length() * delta * TAU * cadence_multiplier / maxf(0.1, stride_length)
	jump_start = maxf(0.0, jump_start - delta)
	actor.reaction_time = maxf(0.0, actor.reaction_time - delta)
	actor.landing_time = maxf(0.0, actor.landing_time - delta)
	if actor.is_gliding:
		locomotion_state = "glide"
	elif actor.is_sliding:
		locomotion_state = "slide"
	elif jump_start > 0.0 and not grounded:
		locomotion_state = "jump_start"
	elif not grounded:
		locomotion_state = "rise" if actor.velocity.y > 0.5 else "fall"
	elif actor.landing_time > 0.0:
		locomotion_state = "land"
	elif speed > 0.12:
		locomotion_state = "run"
	else:
		locomotion_state = "idle"
	actor.animation_state = actor.reaction_kind if actor.reaction_time > 0.0 else locomotion_state

	var landing_phase := 1.0 - actor.landing_time / maxf(0.01, landing_duration)
	var squash := sin(landing_phase * PI) * landing_squash * actor.landing_strength if actor.landing_time > 0.0 and not air_pose_enabled else 0.0
	squash += cos(gait_phase * 2.0) * run_squash * run_blend
	actor.model.scale = actor.model.scale.lerp(Vector3(1.0 + squash * 0.4, 1.0 - squash, 1.0 + squash * 0.4), blend)
	var forward := Vector3.FORWARD.rotated(Vector3.UP, actor.model.rotation.y)
	var acceleration := clampf(actor.motion_acceleration.dot(forward) / maxf(0.01, actor.acceleration), -1.0, 1.0)
	var lean := -acceleration * acceleration_lean - deg_to_rad(run_lean_degrees) * run_blend
	# Conserva una postura base de planeo. La entrada y Sprint añaden inclinación
	# para comunicar intención de avanzar y ganar velocidad.
	var glide_intent := clampf(actor.glide_movement_intent, 0.0, 1.0)
	var glide_lean := glide_lean_degrees + glide_movement_extra_lean_degrees * glide_intent + (glide_sprint_extra_lean_degrees if actor.is_glide_sprinting else 0.0) * glide_intent
	lean = lerpf(lean, -deg_to_rad(glide_lean), glide_blend)
	body_pitch = lerp_angle(body_pitch, lean, blend)
	var run_roll := clampf(-actor.angular_velocity * 0.018, -turn_lean, turn_lean) * run_blend
	var bank_direction := 1.0 if glide_bank_invert else -1.0
	var glide_turn_rate := rad_to_deg(actor.angular_velocity)
	var max_glide_roll := deg_to_rad(glide_bank_degrees) * glide_blend
	# El yaw sigue el rumbo en Player. Aquí el roll es puramente visual: toma el
	# ángulo firmado de la curva y, al soltar la palanca, conserva solo el giro
	# que aún ocurra de verdad. Cuando vuela recto ambos valores llegan a cero.
	var requested_bank := clampf(actor.glide_signed_turn_angle / deg_to_rad(glide_bank_full_turn_angle_degrees), -1.0, 1.0)
	var turning_bank := clampf(glide_turn_rate / maxf(1.0, glide_bank_full_turn_rate_degrees), -1.0, 1.0)
	var bank_signal := requested_bank
	if absf(bank_signal) < 0.01:
		bank_signal = turning_bank
	elif signf(turning_bank) == signf(bank_signal):
		bank_signal = signf(bank_signal) * maxf(absf(bank_signal), absf(turning_bank))
	var glide_roll := clampf(bank_signal * max_glide_roll * bank_direction, -max_glide_roll, max_glide_roll)
	var roll_blend := 1.0 - exp(-(glide_bank_blend_speed if glide_blend > 0.001 else blend_speed) * delta)
	body_roll = lerp_angle(body_roll, run_roll, roll_blend)
	body_bank = lerp_angle(body_bank, glide_roll, roll_blend)
	actor.model.set_body_tilt(body_pitch, body_roll, body_bank)
	actor.model.position.x = lerpf(actor.model.position.x, sin(gait_phase) * body_sway * run_blend, blend)
	actor.model.position.y = lerpf(actor.model.position.y, (0.5 - 0.5 * cos(gait_phase * 2.0)) * body_bounce * run_blend, blend)
	actor.model.glide_amount = glide_blend
	actor.model.update_handmade_glide(glide_blend, handmade_glide_flutter_speed, handmade_glide_start_speed, handmade_glide_tremor_degrees, handmade_glide_tremor_speed)
	_tick_air_pose(delta, grounded)


func _tick_air_pose(delta: float, grounded: bool) -> void:
	var airborne := not grounded and not actor.is_gliding and not actor.is_climbing
	var compression := 0.0
	if airborne:
		air_elapsed += delta
		landing_elapsed = -1.0
	else:
		air_elapsed = 0.0
	if actor.is_gliding or actor.is_climbing or actor.is_sliding:
		landing_elapsed = -1.0
	if landing_elapsed >= 0.0:
		landing_elapsed += delta
		if landing_elapsed < landing_compress_time:
			compression = smoothstep(0.0, landing_compress_time, landing_elapsed)
		else:
			compression = 1.0 - smoothstep(0.0, landing_recover_time, landing_elapsed - landing_compress_time)
		if landing_elapsed >= landing_compress_time + landing_recover_time:
			landing_elapsed = -1.0
	compression *= actor.landing_strength
	var rise_progress := 1.0 - clampf(actor.velocity.y / maxf(0.1, air_launch_speed), 0.0, 1.0)
	var fall_progress := smoothstep(0.0, air_full_fall_speed, maxf(0.0, -actor.velocity.y))
	var lift := lerpf(air_arm_start_degrees, air_arm_apex_degrees, smoothstep(0.0, 1.0, rise_progress))
	lift = lerpf(lift, air_arm_fall_degrees, fall_progress) if airborne else 0.0
	var spread := air_leg_spread_degrees * (1.0 - smoothstep(0.0, air_leg_close_duration, air_elapsed)) if airborne and actor.velocity.y > 0.0 else 0.0
	var tremor := air_tremor_degrees * fall_progress if airborne and air_tremor_frequency > 0.0 else 0.0
	var stride_target := 0.0
	if airborne:
		if air_stride_capture_pending or not air_was_airborne:
			# La intensidad y el lado quedan fijos durante este salto, aunque
			# cambie su velocidad horizontal. No existe un ciclo de piernas.
			air_stride_launch_weight = maxf(smoothstep(0.0, air_stride_full_speed, actor.horizontal_speed), actor.glide_movement_intent)
			air_stride_capture_pending = false
			air_stride_fall_weight = 0.0
			air_stride_fall_elapsed = 0.0
		air_stride_fall_elapsed = air_stride_fall_elapsed + delta if actor.velocity.y < 0.0 else 0.0
		var fall_end := maxf(air_stride_fall_start_speed + 0.01, air_stride_fall_end_speed)
		# Una caída larga no vuelve a activar la zancada al rozar una pared.
		if air_stride_fall_elapsed >= air_stride_fall_delay:
			air_stride_fall_weight = maxf(air_stride_fall_weight, smoothstep(air_stride_fall_start_speed, fall_end, maxf(0.0, -actor.velocity.y)))
		if air_stride_enabled:
			stride_target = air_stride_launch_weight * (1.0 - air_stride_fall_weight)
	else:
		air_stride_fall_weight = 0.0
		air_stride_fall_elapsed = 0.0
	air_was_airborne = airborne
	air_stride_weight = lerpf(air_stride_weight, stride_target, 1.0 - exp(-air_stride_blend_speed * delta))
	var stride := air_stride_side * air_stride_weight if airborne else 0.0
	# +X lleva el extremo del brazo hacia atrás; -X hacia delante.
	var arm_pitches := Vector2(-air_stride_arm_forward_degrees, air_stride_arm_backward_degrees) if stride >= 0.0 else Vector2(air_stride_arm_backward_degrees, -air_stride_arm_forward_degrees)
	arm_pitches *= absf(stride)
	var leg_swing := -stride * air_stride_leg_degrees
	# En el esqueleto importado el frente es +Z. Un giro +X lleva la pata
	# hacia -Z: se desplaza cada cadera en el mismo sentido de su giro.
	var leg_offsets := Vector2(-air_stride_leg_backward_offset, air_stride_leg_forward_offset) if stride >= 0.0 else Vector2(air_stride_leg_forward_offset, -air_stride_leg_backward_offset)
	leg_offsets *= absf(stride)
	var lateral_weight := 1.0 - air_stride_weight if airborne else 1.0
	lift *= lateral_weight
	spread *= lateral_weight
	if airborne and actor.velocity.y < 0.0:
		var leg_fall_progress := smoothstep(air_fall_leg_spread_delay, air_fall_leg_spread_delay + air_fall_leg_spread_duration, air_stride_fall_elapsed)
		spread += air_fall_leg_spread_degrees * leg_fall_progress * lateral_weight
	tremor *= lateral_weight
	var arm_inset := air_arm_inset * smoothstep(0.0, air_arm_inset_full_angle, maxf(absf(lift), maxf(absf(arm_pitches.x), absf(arm_pitches.y))))
	var stride_amount := absf(stride)
	var torso_lean := air_stride_torso_lean_degrees * stride_amount
	var head_forward := air_stride_head_forward_offset * stride_amount
	actor.model.update_air_pose(airborne, air_pose_enabled, lift, spread, tremor, air_tremor_frequency, compression, landing_body_drop, landing_head_retract, landing_head_pitch_degrees, air_pose_response, arm_inset, Vector2(0.0, leg_swing), leg_offsets, torso_lean, head_forward, landing_locomotion_response, arm_pitches)
