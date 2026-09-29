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
## Inclinación hacia delante al planear. Cerca de 85° es una postura muy extrema.
@export_range(0.0, 85.0, 0.5) var glide_lean_degrees := 20.0
@export_range(3.0, 25.0) var glide_blend_speed := 12.0
## Inclinación adicional al mantener R1/Shift durante el planeo.
@export_range(0.0, 50.0, 0.5) var glide_sprint_extra_lean_degrees := 12.0

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

func jump_started() -> void:
	jump_start = 0.10

func reset() -> void:
	glide_blend = 0.0
	run_blend = 0.0
	jump_start = 0.0
	actor.model.glide_amount = 0.0
	actor.model.position = Vector3.ZERO
	actor.model.scale = Vector3.ONE
	actor.model.rotation.x = 0.0
	actor.model.rotation.z = 0.0
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
	var glide_lean := glide_lean_degrees + (glide_sprint_extra_lean_degrees if actor.is_glide_sprinting else 0.0)
	lean = lerpf(lean, -deg_to_rad(glide_lean), glide_blend)
	actor.model.rotation.x = lerp_angle(actor.model.rotation.x, lean, blend)
	actor.model.rotation.z = lerp_angle(actor.model.rotation.z, clampf(-actor.angular_velocity * 0.018, -turn_lean, turn_lean) * run_blend, blend)
	actor.model.position.x = lerpf(actor.model.position.x, sin(gait_phase) * body_sway * run_blend, blend)
	actor.model.position.y = lerpf(actor.model.position.y, (0.5 - 0.5 * cos(gait_phase * 2.0)) * body_bounce * run_blend, blend)
	actor.model.glide_amount = glide_blend
	actor.model.update_handmade_glide(glide_blend, handmade_glide_flutter_speed, handmade_glide_start_speed, handmade_glide_tremor_degrees, handmade_glide_tremor_speed)
