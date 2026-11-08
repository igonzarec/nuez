class_name SquirrelFaceLife
extends Node
## Vida sutil para la ardilla: parpadeo, gestos de orejas y balanceo de cabeza,
## brazos, panza (spine) y piernas. Hijo de un ExplorerPlayer con SquirrelRig; sirve
## igual para el player y los NPC (el NPC instancia player.tscn como Body).
## Todo se actualiza en vivo durante el juego. Los balanceos se suman a la pose final
## (clip + SquirrelRig) sin acumularse entre frames.

@export_group("Parpadeo")
## Activa el parpadeo automático. Al desactivarlo los ojos quedan abiertos.
@export var blink_enabled := true
## Tiempo mínimo entre parpadeos, en segundos. Menor = parpadea más a menudo.
@export_range(0.5, 20.0, 0.1, "suffix:s") var blink_interval_min := 2.5
## Tiempo máximo entre parpadeos, en segundos. Cada espera se elige al azar entre mínimo y máximo.
@export_range(0.5, 30.0, 0.1, "suffix:s") var blink_interval_max := 6.0
## Duración de cerrar el ojo, en segundos. Más corto = parpadeo más seco.
@export_range(0.02, 0.5, 0.01, "suffix:s") var blink_close_time := 0.05
## Tiempo con el ojo cerrado, en segundos.
@export_range(0.0, 0.5, 0.01, "suffix:s") var blink_hold_time := 0.03
## Duración de reabrir el ojo, en segundos. Algo más lento que el cierre resulta natural.
@export_range(0.02, 0.5, 0.01, "suffix:s") var blink_open_time := 0.09
## Escala vertical del ojo cerrado (1 = abierto, 0 = línea). Valores muy bajos pueden desaparecer el ojo.
@export_range(0.02, 1.0, 0.01) var blink_closed_scale := 0.1
## Probabilidad de que un parpadeo sea doble. 0 lo desactiva.
@export_range(0.0, 1.0, 0.01) var double_blink_chance := 0.15

@export_group("Orejas")
## Activa los gestos rápidos ocasionales de una oreja (giro hacia un lado y vuelta).
@export var ears_enabled := true
## Intensidad global de los gestos. 0 = quietas, 2 = el doble.
@export_range(0.0, 2.0, 0.01) var ears_intensity := 1.0
## Tiempo mínimo entre gestos rápidos de una oreja, en segundos.
@export_range(0.5, 30.0, 0.1, "suffix:s") var ear_flick_interval_min := 3.0
## Tiempo máximo entre gestos rápidos, en segundos. Más alto = gestos más raros.
@export_range(0.5, 60.0, 0.1, "suffix:s") var ear_flick_interval_max := 9.0
## Ángulo del gesto rápido, en grados. 0 desactiva los gestos.
@export_range(0.0, 45.0, 0.1, "suffix:°") var ear_flick_degrees := 14.0
## Duración total del gesto rápido, en segundos.
@export_range(0.1, 1.5, 0.01, "suffix:s") var ear_flick_duration := 0.35

@export_group("Balanceo general")
## Intensidad global de todos los balanceos de cuerpo (cabeza, brazos, panza, piernas). No afecta a orejas.
@export_range(0.0, 2.0, 0.01) var body_sway_intensity := 1.0
## Fracción del balanceo de cuerpo que se mantiene al desplazarse. 0 = sólo en reposo, 1 = siempre igual.
@export_range(0.0, 1.0, 0.01) var body_sway_while_moving := 0.3
## Velocidad horizontal, en m/s, a partir de la cual se considera que se desplaza del todo.
@export_range(0.1, 10.0, 0.1, "suffix:m/s") var body_sway_moving_speed := 2.0
## Velocidad con la que los balanceos (y orejas) se apagan/recuperan en estados que ya animan
## esas partes (patinaje, nado, buceo, planeo, escalada). Mayor = transición más rápida.
@export_range(0.5, 20.0, 0.1) var state_fade_speed := 6.0

@export_group("Cabeza")
## Activa el balanceo de cabeza.
@export var head_sway_enabled := true
## Cabeceo (arriba/abajo), en grados.
@export_range(0.0, 20.0, 0.1, "suffix:°") var head_nod_degrees := 2.0
## Inclinación lateral (hacia los hombros), en grados.
@export_range(0.0, 20.0, 0.1, "suffix:°") var head_tilt_degrees := 3.0
## Giro (mirar a los lados), en grados.
@export_range(0.0, 30.0, 0.1, "suffix:°") var head_turn_degrees := 4.0
## Velocidad del balanceo, en ciclos por segundo.
@export_range(0.02, 2.0, 0.01, "suffix:Hz") var head_sway_speed := 0.2

@export_group("Brazos")
## Activa el balanceo de brazos.
@export var arms_sway_enabled := true
## Vaivén adelante/atrás, en grados.
@export_range(0.0, 30.0, 0.1, "suffix:°") var arm_swing_degrees := 4.0
## Apertura hacia fuera del cuerpo, en grados.
@export_range(0.0, 30.0, 0.1, "suffix:°") var arm_out_degrees := 2.0
## Velocidad del balanceo, en ciclos por segundo. Cada brazo usa una frecuencia ligeramente distinta.
@export_range(0.02, 2.0, 0.01, "suffix:Hz") var arm_sway_speed := 0.3

@export_group("Panza")
## Activa el balanceo del tronco (hueso spine): respiración y vaivén lateral.
@export var belly_sway_enabled := true
## Inclinación adelante/atrás, como una respiración, en grados.
@export_range(0.0, 15.0, 0.1, "suffix:°") var belly_breath_degrees := 1.5
## Vaivén lateral, en grados.
@export_range(0.0, 15.0, 0.1, "suffix:°") var belly_side_degrees := 1.0
## Velocidad del balanceo, en ciclos por segundo (respiración ~0,25–0,4).
@export_range(0.02, 2.0, 0.01, "suffix:Hz") var belly_sway_speed := 0.3

@export_group("Piernas")
## Activa el balanceo de piernas.
@export var legs_sway_enabled := true
## Vaivén adelante/atrás, en grados. Valores altos pueden despegar los pies del suelo.
@export_range(0.0, 20.0, 0.1, "suffix:°") var leg_swing_degrees := 1.5
## Apertura hacia fuera, en grados.
@export_range(0.0, 20.0, 0.1, "suffix:°") var leg_out_degrees := 1.0
## Velocidad del balanceo, en ciclos por segundo.
@export_range(0.02, 2.0, 0.01, "suffix:Hz") var leg_sway_speed := 0.25

@export_group("Cola")
## Activa el balanceo de cola (huesos tail_base y tail_tip).
@export var tail_sway_enabled := true
## Vaivén lateral de la base, en grados.
@export_range(0.0, 30.0, 0.1, "suffix:°") var tail_swing_degrees := 5.0
## Subida/bajada de la base, en grados.
@export_range(0.0, 30.0, 0.1, "suffix:°") var tail_lift_degrees := 3.0
## Velocidad del balanceo, en ciclos por segundo.
@export_range(0.02, 2.0, 0.01, "suffix:Hz") var tail_sway_speed := 0.3
## Amplitud de la punta relativa a la base. 0 = la punta sólo sigue a la base; >1 = látigo más marcado.
@export_range(0.0, 3.0, 0.01) var tail_tip_amount := 1.2
## Retraso de la punta respecto a la base, en fracción de ciclo. Mayor = onda más visible a lo largo de la cola.
@export_range(0.0, 0.5, 0.01) var tail_tip_lag := 0.15

var _actor: ExplorerPlayer
var _eyes: Array[Node3D] = []
var _eye_base_scale: Array[Vector3] = []
var _blink_wait := 0.0
var _blink_time := -1.0
var _blink_pending_double := false
var _modifier: SwayModifier
var _time := 0.0
var _phases := PackedFloat32Array()
var _state_weight := 1.0
var _move_weight := 1.0
var _flick_wait := 0.0
var _flick_time := -1.0
var _flick_side := 0
var _flick_sign := 1.0


func _ready() -> void:
	# Después de SquirrelRig (100), como GlideMembranes.
	process_priority = 110
	for i in 16:
		_phases.append(randf() * TAU)
	_blink_wait = randf_range(0.3, blink_interval_max)
	_flick_wait = randf_range(ear_flick_interval_min, ear_flick_interval_max)
	_attach.call_deferred()


func _attach() -> void:
	_actor = get_parent() as ExplorerPlayer
	if not _actor or not is_instance_valid(_actor.model) or not _actor.model.playertest2_skeleton:
		push_warning("SquirrelFaceLife: necesita ser hijo de un ExplorerPlayer con SquirrelRig.")
		_actor = null
		return
	var skeleton: Skeleton3D = _actor.model.playertest2_skeleton
	for eye_name in ["nuez_ojo_izquierdo", "nuez_ojo_derecho"]:
		var eye := skeleton.get_parent().find_child(eye_name, true, false) as Node3D
		if eye:
			_eyes.append(eye)
			_eye_base_scale.append(eye.scale)
	_modifier = SwayModifier.new()
	_modifier.name = "FaceLifeModifier"
	skeleton.add_child(_modifier)


func _process(delta: float) -> void:
	if not _actor:
		return
	_time += delta
	_update_blink(delta)
	if not is_instance_valid(_modifier):
		return
	_modifier.offsets.clear()
	# Estados que ya animan cuerpo y orejas desde SquirrelRig: los balanceos se apagan suavemente.
	var busy := _actor.is_skating or _actor.is_swimming or _actor.is_water_diving \
		or _actor.is_gliding or _actor.is_climbing
	var fade := 1.0 - exp(-state_fade_speed * delta)
	_state_weight = lerpf(_state_weight, 0.0 if busy else 1.0, fade)
	var speed := Vector2(_actor.velocity.x, _actor.velocity.z).length()
	var moving := clampf(speed / body_sway_moving_speed, 0.0, 1.0)
	_move_weight = lerpf(_move_weight, lerpf(1.0, body_sway_while_moving, moving), fade)
	_update_ears(delta)
	_update_body()


func _update_blink(delta: float) -> void:
	var closed := 0.0
	if blink_enabled:
		if _blink_time < 0.0:
			_blink_wait -= delta
			if _blink_wait <= 0.0:
				_blink_time = 0.0
				_blink_pending_double = randf() < double_blink_chance
		else:
			_blink_time += delta
			var t := _blink_time
			if t < blink_close_time:
				closed = t / blink_close_time
			elif t < blink_close_time + blink_hold_time:
				closed = 1.0
			elif t < blink_close_time + blink_hold_time + blink_open_time:
				closed = 1.0 - (t - blink_close_time - blink_hold_time) / blink_open_time
			else:
				_blink_time = -1.0
				if _blink_pending_double:
					_blink_pending_double = false
					_blink_wait = 0.08
				else:
					_blink_wait = randf_range(blink_interval_min, maxf(blink_interval_min, blink_interval_max))
	var y_factor := lerpf(1.0, blink_closed_scale, smoothstep(0.0, 1.0, closed))
	for i in _eyes.size():
		if is_instance_valid(_eyes[i]):
			var base := _eye_base_scale[i]
			_eyes[i].scale = Vector3(base.x, base.y * y_factor, base.z)


func _update_ears(delta: float) -> void:
	var flick := 0.0
	if _flick_time < 0.0:
		_flick_wait -= delta
		if _flick_wait <= 0.0 and ear_flick_degrees > 0.0:
			_flick_time = 0.0
			_flick_side = randi() % 2
			_flick_sign = -1.0 if randf() < 0.5 else 1.0
	else:
		_flick_time += delta
		var p := _flick_time / ear_flick_duration
		if p >= 1.0:
			_flick_time = -1.0
			_flick_wait = randf_range(ear_flick_interval_min, maxf(ear_flick_interval_min, ear_flick_interval_max))
		else:
			# Subida rápida y vuelta más suave.
			flick = sin(PI * pow(p, 0.6)) * _flick_sign
	if not ears_enabled or is_zero_approx(flick):
		return
	var side_name := "ear_left" if _flick_side == 0 else "ear_right"
	var mirror := 1.0 if _flick_side == 0 else -1.0
	var angle := deg_to_rad(flick * ear_flick_degrees) * ears_intensity * _state_weight
	_add(side_name, Vector3.ZERO, Vector3(0.0, angle * mirror, 0.0))


func _update_body() -> void:
	var w := body_sway_intensity * _state_weight * _move_weight
	if w <= 0.001:
		return
	if head_sway_enabled:
		var s := TAU * head_sway_speed
		_add("head", Vector3(
			_wave(s, 0) * head_nod_degrees,
			_wave(s * 0.7, 1) * head_turn_degrees,
			_wave(s * 0.85, 2) * head_tilt_degrees) * w)
	if belly_sway_enabled:
		var s := TAU * belly_sway_speed
		_add("spine", Vector3(sin(_time * s + _phases[3]) * belly_breath_degrees, 0.0,
			_wave(s * 0.6, 4) * belly_side_degrees) * w)
	for side in 2:
		var suffix := "_left" if side == 0 else "_right"
		var mirror := 1.0 if side == 0 else -1.0
		var freq := 1.0 + 0.13 * side
		if arms_sway_enabled:
			var s := TAU * arm_sway_speed * freq
			_add("arm" + suffix, Vector3(_wave(s, 5 + side) * arm_swing_degrees, 0.0,
				(0.5 + 0.5 * _wave(s * 0.8, 7 + side)) * arm_out_degrees * mirror) * w)
		if legs_sway_enabled:
			var s := TAU * leg_sway_speed * freq
			_add("leg" + suffix, Vector3(_wave(s, 9 + side) * leg_swing_degrees, 0.0,
				(0.5 + 0.5 * _wave(s * 0.8, 11 + side)) * leg_out_degrees * mirror) * w)
	if tail_sway_enabled:
		var s := TAU * tail_sway_speed
		var lag := tail_tip_lag * TAU
		_add("tail_base", Vector3(_wave(s * 0.7, 14) * tail_lift_degrees,
			_wave(s, 13) * tail_swing_degrees, 0.0) * w)
		_add("tail_tip", Vector3(_wave(s * 0.7, 14, lag * 0.7) * tail_lift_degrees,
			_wave(s, 13, lag) * tail_swing_degrees, 0.0) * tail_tip_amount * w)


## Onda suave no repetitiva (dos senos), rango aproximado -1..1.
## `lag` (radianes) retrasa la onda, p. ej. para que la punta de la cola siga a la base.
func _wave(omega: float, phase_index: int, lag := 0.0) -> float:
	var p := _phases[phase_index] - lag
	return (sin(_time * omega + p) + 0.35 * sin(_time * omega * 2.3 + p * 1.7)) / 1.35


## Suma una rotación en ejes del cuerpo (x = cabeceo, y = giro, z = inclinación lateral).
## `degrees` se convierte a radianes; `radians` se suma tal cual.
func _add(bone_name: String, degrees: Vector3, radians := Vector3.ZERO) -> void:
	var r := Vector3(deg_to_rad(degrees.x), deg_to_rad(degrees.y), deg_to_rad(degrees.z)) + radians
	if r.is_zero_approx():
		return
	_modifier.offsets[bone_name] = _modifier.offsets.get(bone_name, Vector3.ZERO) + r


## Aplica las rotaciones como SkeletonModifier3D: se suman a la pose final
## (clip + SquirrelRig) sin acumularse entre frames.
class SwayModifier extends SkeletonModifier3D:
	## bone_name -> Vector3 (radianes en ejes del cuerpo).
	var offsets := {}
	var _local_axes := {}

	func _axes(skeleton: Skeleton3D, bone: int) -> Basis:
		if not _local_axes.has(bone):
			_local_axes[bone] = skeleton.get_bone_global_rest(bone).basis.orthonormalized().inverse()
		return _local_axes[bone]

	func _process_modification() -> void:
		var skeleton := get_skeleton()
		if not skeleton:
			return
		for bone_name: String in offsets:
			var bone := skeleton.find_bone(bone_name)
			if bone < 0:
				continue
			var r: Vector3 = offsets[bone_name]
			var to_local := _axes(skeleton, bone)
			var offset := Quaternion((to_local * Vector3.RIGHT).normalized(), r.x) \
				* Quaternion((to_local * Vector3.UP).normalized(), r.y) \
				* Quaternion((to_local * Vector3.FORWARD).normalized(), r.z)
			skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_pose_rotation(bone) * offset)
