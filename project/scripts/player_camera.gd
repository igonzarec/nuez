class_name TrailCamera
extends Node3D

## Se emite al pedir un recentrado manual con R2/RT o C.
signal recenter_requested

@export_range(10.0, 30.0) var distance := 14.4
@export var pitch_degrees := -48.0
@export_range(0.0, 10.0) var vertical_range_degrees := 6.0
@export var follow_speed := 8.0
@export var orbit_smoothing := 10.0
@export var field_of_view := 52.0
@export var stick_speed := 1.8
@export_group("Vista durante planeo")
## Ángulo de cámara mientras planea. Un valor más negativo coloca la vista más por arriba.
@export_range(-85.0, -10.0, 0.5) var glide_pitch_degrees := -64.0
## Rapidez de la transición entre la vista normal y la vista de planeo.
@export_range(1.0, 20.0, 0.1) var glide_camera_speed := 6.0
## Sigue el frente visual al planear; también se cambia en Ajustes.
@export var glide_forward_enabled := false
@export_group("Seguimiento frontal suave")
## Tiempo de respuesta en segundos. 0.65 suave; 1.2 más lento. No afecta al mando manual.
@export_range(0.1, 3.0, 0.05) var forward_response_time := 0.65
## Límite de giro automático y R2, grados por segundo. Ejemplo: 55; 30 más tranquilo.
@export_range(10, 180, 1) var forward_max_speed := 55.0
## Aceleración del giro en grados/s². 90 arranca suavemente; 45 aún más despacio.
@export_range(10, 360, 5) var forward_acceleration := 90.0
## Empieza a seguir cuando el personaje se desvía estos grados. Ignora pequeños cambios.
@export_range(0, 45, 1) var forward_start_angle := 12.0
## Deja de seguir al entrar en este margen. Menor que Start Angle evita oscilaciones.
@export_range(0, 15, 0.5) var forward_stop_angle := 3.0
## Tras mover la cámara manualmente espera estos segundos antes de seguir al personaje.
@export_range(0, 5, 0.1) var forward_manual_pause := 1.2
@export_group("Recentrar cámara · R2 / RT")
## R2 conserva una transición corta, independiente del seguimiento automático.
## Ejemplo: 0.18 s; 0.1 es casi inmediato.
@export_range(0.05, 1.5, 0.01) var recenter_response_time := 0.18
## Límite de giro al apretar R2. Ejemplo: 150 grados por segundo.
@export_range(30, 720, 5) var recenter_max_speed := 150.0
## Aceleración de R2. Un valor alto reacciona sin el latigazo de un salto.
@export_range(30, 1440, 10) var recenter_acceleration := 540.0
@export_group("Recentrar sin mareo")
## Cómo se resuelve el recentrado manual con R2/C.
@export_enum("Instantáneo", "Por tiempo con ease-out") var recenter_mode := 1
## [Modo Instantáneo] A partir de este error (grados) se salta directo al centro.
## Por debajo, recentrado normal con los parámetros de arriba.
@export_range(0, 180, 1) var recenter_snap_threshold := 75.0
## [Modo Por tiempo] Duración del giro en segundos. Siempre dura esto, sin
## importar cuánto tenga que girar. Ejemplo: 0.35 s rápido; 0.5 s visible.
@export_range(0.05, 2.0, 0.01) var recenter_timed_duration := 0.35
## [Modo Por tiempo] Exponente del ease-out. 1 = lineal; 2 suave; 3 marcado.
@export_range(1.0, 5.0, 0.1) var recenter_timed_ease_power := 2.5
@export_group("Desenfoque de distancia")
@export var distant_blur_enabled := true
## A partir de esta distancia de la camara comienza el desenfoque.
@export_range(15.0, 40.0) var blur_start := 18.0
@export_range(1.0, 30.0) var blur_transition := 12.0
@export_range(0.0, 6.0) var blur_strength := 3.0
var sensitivity := 1.0
var target: ExplorerPlayer
var enabled := false
var yaw := 0.0
var pitch := deg_to_rad(-48.0)
var glide_view_blend := 0.0
var forward_tracking := false
var forward_velocity := 0.0
var manual_pause_left := 0.0
var recenter_active := false
var recenter_yaw := 0.0
## Recentrado por tiempo con ease-out. Activo mientras dure el tween.
var recenter_timed_active := false
var recenter_timed_clock := 0.0
var recenter_timed_from := 0.0
var recenter_timed_delta := 0.0
var camera: Camera3D
var blur_mesh: MeshInstance3D
var blur_material: ShaderMaterial

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	pitch = deg_to_rad(pitch_degrees)
	# Fixed-radius orbit: a SpringArm would retract into the player near props.
	camera = Camera3D.new()
	camera.fov = field_of_view
	camera.near = 0.12
	add_child(camera)
	blur_mesh = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	blur_mesh.mesh = quad
	blur_mesh.position.z = -1
	blur_mesh.extra_cull_margin = 16384
	blur_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blur_material = ShaderMaterial.new()
	blur_material.shader = preload("res://shaders/distant_blur.gdshader")
	blur_material.render_priority = 100
	blur_mesh.material_override = blur_material
	camera.add_child(blur_mesh)
	if target:
		snap()

func snap() -> void:
	forward_velocity = 0.0
	forward_tracking = false
	recenter_active = false
	recenter_timed_active = false
	recenter_timed_clock = 0.0
	glide_view_blend = 1.0 if target and target.is_gliding else 0.0
	pitch = _clamp_pitch(pitch)
	global_position = target.global_position + Vector3.UP * 1.15
	rotation = Vector3(pitch, yaw, 0)
	_place_camera()
	reset_physics_interpolation()

func _unhandled_input(event: InputEvent) -> void:
	# The event's button mask avoids a latched drag when focus leaves the window.
	# No capture, confinement or cursor warping, including while dragging.
	if enabled and event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
		_pause_front_follow()
		yaw = wrapf(yaw - event.relative.x * 0.0025 * sensitivity, -PI, PI)
		pitch = _clamp_pitch(pitch - event.relative.y * 0.001 * sensitivity)

func _physics_process(delta: float) -> void:
	if not target:
		return
	manual_pause_left = maxf(0, manual_pause_left - delta)
	var front_follow := false
	if enabled:
		var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		if stick.length_squared() > 0.001:
			_pause_front_follow()
		if Input.is_action_just_pressed("camera_forward"):
			recenter_yaw = target.model.rotation.y
			manual_pause_left = 0
			pitch = deg_to_rad(pitch_degrees)
			recenter_requested.emit()
			if recenter_mode == 0:
				_maybe_snap_recenter()
			else:
				_start_timed_recenter()
		if recenter_timed_active:
			# El tween manda: no se ejecuta el seguimiento frontal ni pelea con él.
			_update_timed_recenter(delta)
		else:
			front_follow = recenter_active or (glide_forward_enabled and target.is_gliding and manual_pause_left <= 0)
			if front_follow:
				_follow_front(recenter_yaw if recenter_active else target.model.rotation.y, delta)
		yaw = wrapf(yaw - stick.x * stick_speed * delta, -PI, PI)
		pitch = _clamp_pitch(pitch - stick.y * stick_speed * 0.4 * delta)
	if not front_follow:
		forward_tracking = false
		forward_velocity = 0.0
	pitch = _clamp_pitch(pitch)
	# One camera only: smoothly blend its orbit angle between the normal view
	# and the more elevated glide view. No camera is swapped or teleported.
	var glide_target := 1.0 if target.is_gliding else 0.0
	glide_view_blend = lerpf(glide_view_blend, glide_target, 1.0 - exp(-glide_camera_speed * delta))
	var view_pitch := lerp_angle(pitch, deg_to_rad(glide_pitch_degrees), glide_view_blend)
	rotation.x = lerp_angle(rotation.x, view_pitch, 1.0 - exp(-orbit_smoothing * delta))
	# El seguimiento ya limita velocidad/aceleración; no acumular dos retardos.
	if recenter_timed_active:
		# rotation.y ya fue fijado por _update_timed_recenter este mismo frame.
		pass
	elif front_follow:
		rotation.y = yaw
	else:
		rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-orbit_smoothing * delta))
	global_position = global_position.lerp(target.global_position + Vector3.UP * 1.15, 1.0 - exp(-follow_speed * delta))
	_place_camera()

func _pause_front_follow() -> void:
	manual_pause_left = forward_manual_pause
	recenter_active = false
	recenter_timed_active = false
	forward_tracking = false
	forward_velocity = 0.0

## [Modo Instantáneo] Salta directo al centro si el error supera el umbral.
## Por debajo del umbral, deja que el recentrado normal de arriba lo resuelva.
func _maybe_snap_recenter() -> void:
	var error := wrapf(recenter_yaw - rotation.y, -PI, PI)
	var error_deg := absf(rad_to_deg(error))
	if error_deg < recenter_snap_threshold:
		return
	yaw = wrapf(recenter_yaw, -PI, PI)
	rotation.y = yaw
	forward_velocity = 0.0
	forward_tracking = false
	recenter_active = false

## [Modo Por tiempo] Arranca el tween de giro. Dura exactamente
## recenter_timed_duration, independientemente de cuánto tenga que girar.
func _start_timed_recenter() -> void:
	recenter_timed_active = true
	recenter_timed_clock = 0.0
	recenter_timed_from = rotation.y
	# Camino más corto entre el ángulo actual y el objetivo.
	recenter_timed_delta = wrapf(recenter_yaw - rotation.y, -PI, PI)
	forward_velocity = 0.0
	forward_tracking = false
	recenter_active = false

func _update_timed_recenter(delta: float) -> void:
	recenter_timed_clock += delta
	var duration := maxf(0.01, recenter_timed_duration)
	var t := clampf(recenter_timed_clock / duration, 0.0, 1.0)
	# Ease-out: empieza rápido, frena al final. 1 = lineal, mayor = más marcado.
	var eased := 1.0 - pow(1.0 - t, recenter_timed_ease_power)
	rotation.y = wrapf(recenter_timed_from + recenter_timed_delta * eased, -PI, PI)
	yaw = rotation.y
	if t >= 1.0:
		recenter_timed_active = false

func _follow_front(target_yaw: float, delta: float) -> void:
	# Histéresis: umbral distinto para iniciar y detener. R2 ignora el umbral inicial.
	var error := wrapf(target_yaw - rotation.y, -PI, PI)
	var stop_angle := deg_to_rad(minf(forward_stop_angle, forward_start_angle))
	if recenter_active or absf(error) > deg_to_rad(forward_start_angle):
		forward_tracking = true
	if absf(error) <= (deg_to_rad(0.5) if recenter_active else stop_angle):
		forward_tracking = false
		recenter_active = false
		error = 0.0
	yaw = rotation.y
	var desired_speed := 0.0
	if forward_tracking:
		var response_time := recenter_response_time if recenter_active else forward_response_time
		var max_speed := recenter_max_speed if recenter_active else forward_max_speed
		desired_speed = clampf(error / response_time, -deg_to_rad(max_speed), deg_to_rad(max_speed))
	var acceleration := recenter_acceleration if recenter_active else forward_acceleration
	forward_velocity = move_toward(forward_velocity, desired_speed, deg_to_rad(acceleration) * delta)
	if forward_tracking:
		var step := forward_velocity * delta
		# No sobrepasar el objetivo al cambiar de sentido o detenerse.
		if signf(step) == signf(error):
			yaw = wrapf(yaw + signf(error) * minf(absf(step), absf(error)), -PI, PI)

func _clamp_pitch(value: float) -> float:
	return clampf(value, deg_to_rad(pitch_degrees - vertical_range_degrees), deg_to_rad(pitch_degrees + vertical_range_degrees))

func _place_camera() -> void:
	var anchor := target.global_position + Vector3.UP * 1.15
	var offset := global_position + global_basis.z * distance - anchor
	# Project the smoothed follow position onto a sphere around the real player.
	# Follow lag, sprinting, jumps and nearby geometry can never shorten the radius.
	var orbit_yaw := atan2(offset.x, offset.z)
	# rotation.x is already the smoothly blended normal/glide orbit angle.
	var orbit_pitch := rotation.x
	var direction := Basis.from_euler(Vector3(orbit_pitch, orbit_yaw, 0)).z
	camera.global_position = anchor + direction * distance
	camera.look_at(anchor)
	camera.fov = field_of_view
	blur_mesh.visible = distant_blur_enabled and camera.is_current()
	blur_material.set_shader_parameter("focus_distance", blur_start)
	blur_material.set_shader_parameter("far_transition", blur_transition)
	blur_material.set_shader_parameter("blur_radius", blur_strength)
