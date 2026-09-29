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

@export_group("Postura de planeo")
## Inclinación base hacia delante durante Glide, incluso sin entrada de movimiento.
## Ejemplo: 20° es planeo tranquilo; 45° es marcado; cerca de 85° es una postura extrema.
@export_range(0.0, 85.0, 0.5) var glide_lean_degrees := 20.0
@export_range(3.0, 25.0) var glide_blend_speed := 12.0
## Inclinación añadida mientras mantienes una dirección durante Glide.
## Ejemplo: 0 conserva la misma postura; 6° da intención de avance; 15° es una picada clara.
@export_range(0.0, 40.0, 0.5) var glide_movement_extra_lean_degrees := 6.0
## Inclinación adicional al mantener R1/Shift y moverse durante el planeo.
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

func jump_started() -> void:
	jump_start = 0.10

func reset() -> void:
	glide_blend = 0.0
	run_blend = 0.0
	jump_start = 0.0
	actor.model.glide_amount = 0.0
	actor.model.position = Vector3.ZERO
	actor.model.scale = Vector3.ONE
	body_pitch = 0.0
	body_roll = 0.0
	actor.model.reset_body_tilt()
	actor.model.reset_interpolation()

func tick(delta: float, speed: float) -> void:
	clock += delta
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
	var squash := sin(landing_phase * PI) * landing_squash * actor.landing_strength if actor.landing_time > 0.0 else 0.0
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
	body_roll = lerp_angle(body_roll, run_roll + glide_roll, roll_blend)
	actor.model.set_body_tilt(body_pitch, body_roll)
	actor.model.position.x = lerpf(actor.model.position.x, sin(gait_phase) * body_sway * run_blend, blend)
	actor.model.position.y = lerpf(actor.model.position.y, (0.5 - 0.5 * cos(gait_phase * 2.0)) * body_bounce * run_blend, blend)
	actor.model.glide_amount = glide_blend
	actor.model.update_handmade_glide(glide_blend, handmade_glide_flutter_speed, handmade_glide_start_speed, handmade_glide_tremor_degrees, handmade_glide_tremor_speed)
