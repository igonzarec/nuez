class_name TrailCamera
extends Node3D

@export_group("Laboratorio de apariencia")
## Override general: sustituye perfiles locales de mundo, terreno, personaje y detalles. Apagado recupera los valores particulares. En vivo durante ejecución, incluso en pausa; primer uso puede compilar shaders.
@export var toon_enabled := false
## Perfil general. Enabled del recurso se ignora: manda Toon Enabled. Expandir para bandas, suavidad, umbral, contraste y normales. En vivo durante ejecución.
@export var toon_general: TrailToonLook = TrailToonLook.new()
## Objetos y vegetación. Enabled apagado conserva materiales originales. El general activo tiene prioridad. En vivo durante ejecución.
@export var toon_world: TrailToonLook = TrailToonLook.new()
## Terrain3D. Enabled apagado conserva los valores de cada material, incluido grass_terrain. El general tiene prioridad. En vivo durante ejecución.
@export var toon_terrain: TrailToonLook = TrailToonLook.new()
## Ardillas player y NPC. Enabled apagado conserva su iluminación original. El general tiene prioridad. En vivo durante ejecución.
@export var toon_character: TrailToonLook = TrailToonLook.new()
@export_subgroup("Personaje · acabado mate")
## Prueba acabado mate en las ardillas conservando texturas y colores. Independiente de toon; sin toon mantiene PBR. En vivo durante ejecución, incluso en pausa; sólo materiales en memoria.
@export var character_matte_enabled := false
## Rugosidad del personaje con acabado mate, 0 pulido y 1 mate. En toon no altera suavidad de bandas. En vivo.
@export_range(0.0, 1.0, 0.01) var character_matte_roughness := 1.0
## Especular con acabado mate, 0 sin reflejo y 1 intenso. Toon elimina especular directo. En vivo.
@export_range(0.0, 1.0, 0.01) var character_matte_specular := 0.0
## Metalicidad con acabado mate, 0 dieléctrico y 1 metálico. 0 conserva mejor el color del personaje. En vivo.
@export_range(0.0, 1.0, 0.01) var character_matte_metallic := 0.0
@export_group("")

# Compatibilidad con escenas y preferencias anteriores.
var toon_softness: float:
	get:
		ensure_appearance_profiles()
		return toon_general.softness
	set(value):
		ensure_appearance_profiles()
		toon_general.softness = value

func ensure_appearance_profiles() -> void:
	for category in ["general", "world", "terrain", "character"]:
		if get("toon_" + category) == null: set("toon_" + category, TrailToonLook.new())

func apply_appearance_settings(values: Dictionary) -> void:
	ensure_appearance_profiles()
	toon_enabled = values.get("toon_enabled", false)
	toon_softness = values.get("toon_softness", 0.08)
	# No sustituir autoría nueva con defaults de preferencias ausentes.
	for key in ["toon_bands", "toon_light_offset", "toon_contrast", "toon_normal_strength"]:
		if values.has(key): toon_general.set(key.trim_prefix("toon_"), values[key])
	for category in ["world", "terrain", "character"]:
		var profile: TrailToonLook = get("toon_" + category)
		for property in ["enabled", "bands", "softness", "light_offset", "contrast", "normal_strength"]:
			var key: String = "toon_" + category + "_" + property
			if values.has(key): profile.set(property, values[key])
	for key in ["character_matte_enabled", "character_matte_roughness", "character_matte_specular", "character_matte_metallic"]:
		if values.has(key): set(key, values[key])

func appearance_settings() -> Dictionary:
	ensure_appearance_profiles()
	var values := {"toon_enabled": toon_enabled, "toon_softness": toon_softness}
	for property in ["bands", "light_offset", "contrast", "normal_strength"]:
		values["toon_" + property] = toon_general.get(property)
	for category in ["world", "terrain", "character"]:
		var profile: TrailToonLook = get("toon_" + category)
		for property in ["enabled", "bands", "softness", "light_offset", "contrast", "normal_strength"]:
			values["toon_" + category + "_" + property] = profile.get(property)
	for key in ["character_matte_enabled", "character_matte_roughness", "character_matte_specular", "character_matte_metallic"]:
		values[key] = get(key)
	return values

var _toon_preview: Node

## Se emite al pedir un recentrado manual con R2/RT o C.
signal recenter_requested

@export_range(10.0, 30.0) var distance := 14.4
@export var pitch_degrees := -48.0
## Margen vertical alrededor de Pitch Degrees cuando Full Vertical Orbit está apagado.
@export_range(0.0, 180.0) var vertical_range_degrees := 6.0
## Permite mirar desde arriba o abajo del personaje con ratón o stick derecho.
@export var full_vertical_orbit := false
## Límites de inclinación manual. ±89 evita la singularidad de mirar exactamente vertical.
@export_range(-89.0, 89.0, 1.0) var minimum_pitch := -89.0
@export_range(-89.0, 89.0, 1.0) var maximum_pitch := 89.0
@export var follow_speed := 8.0
## Suavizado de cambios automáticos de inclinación; el giro manual responde directamente.
@export var orbit_smoothing := 10.0
@export var field_of_view := 52.0
@export var stick_speed := 1.8
@export_group("Vista durante planeo")
## Mantiene la órbita manual al planear sin alinearse automáticamente con el personaje. Ignora Glide Forward Enabled, pero admite la perspectiva inicial opcional Glide Initial Pitch Enabled. Respeta los límites de planeo si están activos. En vivo; conserva recentrado manual y protección contra obstáculos.
@export var glide_free_camera_enabled := true
## Al empezar cada planeo adopta suavemente Glide Pitch Degrees una sola vez, incluso con cámara libre. Después permite mirar manualmente sin regresar a ese ángulo. Mover verticalmente la cámara cancela la transición. Activación aplicada en el siguiente planeo; desactivar interrumpe la transición actual.
@export var glide_initial_pitch_enabled := true
## Limita la órbita manual al planear sin seguir automáticamente al personaje. Requiere Glide Free Camera Enabled. En vivo; desactivar recupera la libertad anterior. La protección contra obstáculos puede mover la vista fuera de estos límites para evitar colisión.
@export var glide_orbit_limits_enabled := true
## Giro horizontal permitido a cada lado del ángulo de cámara al iniciar planeo, en grados. 120 permite 240° en total; 180 deja vuelta completa. 0 bloquea giro manual horizontal. Recentrar manualmente redefine ese centro. En vivo; no sigue giros del personaje.
@export_range(0.0, 180.0, 1.0, "suffix:°") var glide_horizontal_range_degrees := 120.0
## Inclinación vertical mínima de cámara durante planeo, en grados. Más negativo permite mirar más desde arriba; -80 evita llegar a la vertical. Se combina con Glide Maximum Pitch Degrees sin importar su orden. En vivo.
@export_range(-89.0, 89.0, 1.0, "suffix:°") var glide_minimum_pitch_degrees := -80.0
## Inclinación vertical máxima durante planeo, en grados. Más positivo permite acercarse al horizonte o mirar desde abajo; -15 mantiene la cámara por encima. En vivo; no modifica la inclinación normal fuera del planeo.
@export_range(-89.0, 89.0, 1.0, "suffix:°") var glide_maximum_pitch_degrees := -15.0
## Perspectiva vertical inicial al comenzar planeo, en grados. Requiere Glide Initial Pitch Enabled, no depende de Free Camera. Más negativo mira desde arriba; los límites manuales activos pueden recortarlo. Se consulta durante la transición inicial, no fuerza la vista después.
@export_range(-85.0, -10.0, 0.5) var glide_pitch_degrees := -64.0
## Rapidez de la transición a la perspectiva inicial de planeo, en s⁻¹. Mayor llega antes; menor suaviza. No recentra continuamente ni cambia la respuesta manual. Se actualiza en vivo.
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
@export_group("Colisión de cámara")
## Evita que la cámara entre en las superficies marcadas como Camera Blocker.
@export var camera_collision_enabled := true
## Capas físicas que bloquean la cámara. Camera Blocker usa la capa 3 (valor 4).
@export_flags_3d_physics var camera_collision_mask := 4
## Radio de la esfera que comprueba el trayecto. Mayor valor evita que se cuele por bordes.
@export_range(0.05, 2.0, 0.01, "or_greater") var camera_collision_radius := 0.35
## Separación extra, en metros, entre la esfera de cámara y el obstáculo.
@export_range(0.0, 2.0, 0.01) var camera_collision_margin := 0.12
## Resolución angular de búsqueda. Menor valor hace más consultas al encontrar obstáculos.
@export_range(1.0, 10.0, 1.0) var camera_collision_angle_step := 3.0
## Inclinación máxima hacia arriba para recuperar una vista libre, conservando Distance.
@export_range(45.0, 89.0, 1.0) var camera_collision_max_elevation := 85.0
## Recupera una vista elevada al reaparecer o si el movimiento deja la cámara atrapada.
@export var camera_collision_recovery := true
## Máxima elevación adicional sobre la inclinación elegida por el jugador, en grados.
@export_range(0.0, 60.0, 1.0) var camera_obstacle_lift := 25.0
## Velocidad de subida de la cámara, en grados por segundo.
@export_range(1.0, 120.0, 1.0) var camera_lift_speed := 35.0
## Rapidez del regreso a la inclinación elegida. Valores mayores regresan antes.
@export_range(1.0, 90.0, 1.0) var camera_return_speed := 12.0
## Fracción de la velocidad anterior que se conserva como piso al llegar al objetivo.
## 0.2 = la cámara nunca baja más lento que el 20% de Camera Return Speed.
@export_range(0.0, 1.0, 0.05) var camera_return_floor := 0.2
## Espacio libre adicional exigido para bajar. Evita oscilar al rozar el borde.
@export_range(0.0, 2.0, 0.05) var camera_return_clearance := 0.4
## Tiempo continuo con espacio para bajar antes de iniciar el regreso.
@export_range(0.0, 2.0, 0.05) var camera_return_delay := 0.2
## Cuánto tiempo, en segundos, se mantiene la elevación ganada tras un obstáculo.
## Evita que la cámara baje en claros breves al descender una pendiente irregular.
## 0 = sin memoria. 0.3 ágil. 1.5 o más para montañas muy quebradas.
@export_range(0.0, 5.0, 0.1) var camera_lift_hold_time := 0.3
var sensitivity := 1.0
var target: ExplorerPlayer
var enabled := false
var yaw := 0.0
var pitch := deg_to_rad(-48.0)
var glide_view_blend := 0.0
var _glide_orbit_active := false
var _glide_orbit_center := 0.0
var _glide_initial_pitch_active := false
var _manual_vertical_override := false
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
@export_group("Separación de siluetas")
## Dibuja una línea donde una superficie cercana tapa otra lejana, aunque tengan el mismo color.
@export var depth_outline_enabled := false
## Intensidad de la línea; prueba 0,15–0,3 para un borde discreto.
@export_range(0.0, 1.0, 0.01) var depth_outline_opacity := 0.25
## Anchura de muestreo en píxeles de pantalla.
@export_range(0.5, 4.0, 0.25) var depth_outline_width := 1.0
## Salto de profundidad en metros necesario para marcar el borde. Mayor valor elimina detalles menores.
@export_range(0.05, 5.0, 0.05) var depth_outline_threshold := 0.5
## Color de los contornos.
@export var depth_outline_color := Color(0.2, 0.3, 0.35)
var _outline_mesh: MeshInstance3D
var _outline_material: ShaderMaterial
var _last_camera_direction := Vector3.ZERO
var _camera_clear_time := 0.0
var _base_view_pitch := 0.0
var _obstacle_elevation := 0.0
var _manual_orbit_pending := false
## Tiempo restante de "memoria de elevación". Mientras sea > 0, la cámara no baja.
var _lift_hold_left := 0.0

func _ready() -> void:
	ensure_appearance_profiles()
	# Cada instancia de cámara conserva sus propios perfiles editables.
	toon_general = toon_general.duplicate() as TrailToonLook
	toon_world = toon_world.duplicate() as TrailToonLook
	toon_terrain = toon_terrain.duplicate() as TrailToonLook
	toon_character = toon_character.duplicate() as TrailToonLook
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("surface_detail_toon_source")
	_toon_preview = preload("res://scripts/core/toon_preview.gd").new()
	_toon_preview.source = self
	add_child(_toon_preview)
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
	# La captura de pantalla 3D contiene sólo opacos. Dibujar el blur después
	# de las transparencias las tapaba con esa captura (copos y huellas incluidos).
	# Reservamos -128 para el fondo desenfocado; transparencias normales usan 0.
	blur_material.render_priority = -128
	blur_mesh.material_override = blur_material
	camera.add_child(blur_mesh)
	_outline_mesh = MeshInstance3D.new()
	_outline_mesh.mesh = quad
	_outline_mesh.position.z = -0.5
	_outline_mesh.extra_cull_margin = 16384
	_outline_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_outline_material = ShaderMaterial.new()
	_outline_material.shader = preload("res://shaders/depth_outline.gdshader")
	_outline_material.render_priority = 101
	_outline_mesh.material_override = _outline_material
	camera.add_child(_outline_mesh)
	if target:
		snap()

func snap() -> void:
	_glide_orbit_active = false
	_sync_glide_orbit_center()
	forward_velocity = 0.0
	forward_tracking = false
	recenter_active = false
	recenter_timed_active = false
	recenter_timed_clock = 0.0
	glide_view_blend = 0.0
	_last_camera_direction = Vector3.ZERO
	_camera_clear_time = 0.0
	_obstacle_elevation = 0.0
	_manual_orbit_pending = false
	_lift_hold_left = 0.0
	pitch = _clamp_pitch(pitch)
	_base_view_pitch = pitch
	global_position = target.global_position + Vector3.UP * 1.15
	rotation = Vector3(pitch, yaw, 0)
	_place_camera()
	reset_physics_interpolation()

func _unhandled_input(event: InputEvent) -> void:
	# The event's button mask avoids a latched drag when focus leaves the window.
	# No capture, confinement or cursor warping, including while dragging.
	if enabled and event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
		_sync_glide_orbit_center()
		if absf(event.relative.y) > 0.01:
			_glide_initial_pitch_active = false
		_pause_front_follow()
		_manual_orbit_pending = true
		if full_vertical_orbit and absf(event.relative.y) > 0.01:
			_manual_vertical_override = true
		yaw = _clamp_glide_yaw(yaw - event.relative.x * 0.0025 * sensitivity)
		pitch = _clamp_pitch(pitch - event.relative.y * 0.001 * sensitivity)

func _physics_process(delta: float) -> void:
	if not target:
		return
	_sync_glide_orbit_center()
	manual_pause_left = maxf(0, manual_pause_left - delta)
	var front_follow := false
	if enabled:
		var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		if absf(stick.y) > 0.01:
			_glide_initial_pitch_active = false
		if stick.length_squared() > 0.001:
			_pause_front_follow()
			_manual_orbit_pending = true
		if full_vertical_orbit and absf(stick.y) > 0.01:
			_manual_vertical_override = true
		if Input.is_action_just_pressed("camera_forward"):
			recenter_yaw = target.model.rotation.y
			_glide_orbit_center = recenter_yaw
			manual_pause_left = 0
			# Recentrar sólo cambia la órbita horizontal; conserva altura e
			# inclinación elegidas, incluido el override vertical de planeo.
			recenter_requested.emit()
			if recenter_mode == 0:
				_maybe_snap_recenter()
			else:
				_start_timed_recenter()
		if recenter_timed_active:
			# El tween manda: no se ejecuta el seguimiento frontal ni pelea con él.
			_update_timed_recenter(delta)
		else:
			front_follow = recenter_active or (not glide_free_camera_enabled and glide_forward_enabled and target.is_gliding and manual_pause_left <= 0)
			if front_follow:
				_follow_front(recenter_yaw if recenter_active else target.model.rotation.y, delta)
		if not recenter_timed_active and not front_follow:
			yaw = _clamp_glide_yaw(yaw - stick.x * stick_speed * delta)
		pitch = _clamp_pitch(pitch - stick.y * stick_speed * 0.4 * delta)
	if not front_follow:
		forward_tracking = false
		forward_velocity = 0.0
	pitch = _clamp_pitch(pitch)
	if _glide_initial_pitch_active and glide_initial_pitch_enabled:
		var initial_pitch := _clamp_pitch(deg_to_rad(glide_pitch_degrees))
		pitch = lerp_angle(pitch, initial_pitch, 1.0 - exp(-glide_camera_speed * delta))
		if absf(pitch - initial_pitch) < deg_to_rad(0.1):
			pitch = initial_pitch
			_glide_initial_pitch_active = false
	elif not glide_initial_pitch_enabled:
		_glide_initial_pitch_active = false
	# La perspectiva inicial pasa a ser intención manual, no un objetivo perpetuo.
	glide_view_blend = 0.0
	var view_pitch := pitch
	_base_view_pitch = view_pitch if _manual_orbit_pending else lerp_angle(_base_view_pitch, view_pitch, 1.0 - exp(-orbit_smoothing * delta))
	rotation.x = _base_view_pitch
	# El seguimiento ya limita velocidad/aceleración; no acumular dos retardos.
	if recenter_timed_active:
		# rotation.y ya fue fijado por _update_timed_recenter este mismo frame.
		pass
	elif front_follow:
		rotation.y = yaw
	else:
		rotation.y = yaw
	global_position = global_position.lerp(target.global_position + Vector3.UP * 1.15, 1.0 - exp(-follow_speed * delta))
	_place_camera(delta)
	_manual_orbit_pending = false

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
	if _glide_limits_active():
		return clampf(value, deg_to_rad(minf(glide_minimum_pitch_degrees, glide_maximum_pitch_degrees)), deg_to_rad(maxf(glide_minimum_pitch_degrees, glide_maximum_pitch_degrees)))
	if full_vertical_orbit or (target and target.is_gliding and (glide_free_camera_enabled or glide_initial_pitch_enabled)):
		return clampf(value, deg_to_rad(minf(minimum_pitch, maximum_pitch)), deg_to_rad(maxf(minimum_pitch, maximum_pitch)))
	return clampf(value, deg_to_rad(pitch_degrees - vertical_range_degrees), deg_to_rad(pitch_degrees + vertical_range_degrees))

func _glide_limits_active() -> bool:
	return glide_free_camera_enabled and glide_orbit_limits_enabled and target != null and target.is_gliding

func _sync_glide_orbit_center() -> void:
	var active := target != null and target.is_gliding
	if active and not _glide_orbit_active:
		_glide_orbit_center = yaw
		_glide_initial_pitch_active = glide_initial_pitch_enabled
	if not active:
		_glide_initial_pitch_active = false
	_glide_orbit_active = active

func _clamp_glide_yaw(value: float) -> float:
	if _glide_limits_active():
		var limit := deg_to_rad(glide_horizontal_range_degrees)
		return wrapf(_glide_orbit_center + clampf(wrapf(value - _glide_orbit_center, -PI, PI), -limit, limit), -PI, PI)
	return wrapf(value, -PI, PI)

func _place_camera(delta := 0.0) -> void:
	var anchor := target.global_position + Vector3.UP * 1.15
	# El retraso posicional del rig no debe modificar la dirección solicitada.
	var orbit_yaw := rotation.y
	# rotation.x is already the smoothly blended normal/glide orbit angle.
	var orbit_pitch := rotation.x
	var direction := Basis.from_euler(Vector3(orbit_pitch, orbit_yaw, 0)).z
	var resolved := _camera_safe_direction(anchor, direction, delta)
	rotation.y = atan2(resolved.x, resolved.z)
	rotation.x = -asin(clampf(resolved.y, -1.0, 1.0))
	_obstacle_elevation = maxf(0.0, orbit_pitch - rotation.x)
	# Conservar una intención de giro pequeña mientras se eleva, sin acumular vueltas.
	if absf(wrapf(orbit_yaw - rotation.y, -PI, PI)) > 0.001:
		yaw = rotation.y + clampf(wrapf(yaw - rotation.y, -PI, PI), -deg_to_rad(8.0), deg_to_rad(8.0))
	_last_camera_direction = resolved
	camera.global_position = anchor + resolved * distance
	camera.look_at(anchor)
	camera.fov = field_of_view
	blur_mesh.visible = distant_blur_enabled and camera.is_current()
	blur_material.set_shader_parameter("focus_distance", blur_start)
	blur_material.set_shader_parameter("far_transition", blur_transition)
	blur_material.set_shader_parameter("blur_radius", blur_strength)
	_outline_mesh.visible = depth_outline_enabled and camera.is_current()
	_outline_material.set_shader_parameter("line_opacity", depth_outline_opacity)
	_outline_material.set_shader_parameter("line_width", depth_outline_width)
	_outline_material.set_shader_parameter("depth_threshold", depth_outline_threshold)
	_outline_material.set_shader_parameter("line_color", depth_outline_color)

## Conserva el radio completo. Si no existe un ángulo libre, conserva el último
## encuadre: un espacio cerrado menor que Distance no puede resolverse con zoom.
func _camera_safe_direction(anchor: Vector3, desired: Vector3, delta: float) -> Vector3:
	if not camera_collision_enabled or camera_collision_mask == 0:
		_camera_clear_time = 0.0
		return desired
	var sphere := SphereShape3D.new()
	sphere.radius = maxf(0.01, camera_collision_radius + camera_collision_margin)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.collision_mask = camera_collision_mask
	query.exclude = [target.get_rid()]
	var base_yaw := atan2(desired.x, desired.z)
	var base_elevation := asin(clampf(desired.y, -1.0, 1.0))
	# Sin corrección previa, una vista libre nunca pasa por velocidades de retorno.
	# El usuario también puede salir de una corrección hacia una dirección libre.
	if _camera_direction_clear(anchor, desired, query):
		if _last_camera_direction.is_zero_approx() or _camera_arc_clear(anchor, _last_camera_direction, desired, query):
			# Solo atajo cuando NO estamos elevados por un obstáculo.
			# Si _obstacle_elevation > 0, caemos al descenso suave de abajo,
			# incluso si el jugador está girando manualmente. Antes el bypass
			# de _manual_orbit_pending hacía que la cámara saltara al pitch
			# original en cuanto el giro sacaba la vista del hueco.
			if _obstacle_elevation <= 0.0001:
				_camera_clear_time = 0.0
				return desired
	var max_elevation := maxf(base_elevation, minf(deg_to_rad(camera_collision_max_elevation), base_elevation + deg_to_rad(camera_obstacle_lift)))
	var required := base_elevation
	var found := false
	var steps := maxi(1, int(ceil(rad_to_deg(max_elevation - base_elevation) / maxf(1.0, camera_collision_angle_step))))
	# Buscar sólo elevación sobre el giro solicitado; nunca saltar a otro lado.
	for i in range(steps + 1):
		required = lerpf(base_elevation, max_elevation, float(i) / steps)
		if _camera_direction_clear(anchor, _orbit_direction(base_yaw, required), query):
			found = true
			break
	if _last_camera_direction.is_zero_approx():
		return _orbit_direction(base_yaw, required) if found and camera_collision_recovery else desired
	var previous := _last_camera_direction
	var previous_yaw := atan2(previous.x, previous.z)
	# Sólo la elevación añadida por obstáculos tiene histéresis, no el pitch manual.
	var elevation := minf(base_elevation + _obstacle_elevation, max_elevation)
	if not _camera_direction_clear(anchor, previous, query):
		# La traslación del jugador o un respawn invalidó la vista anterior.
		# En lugar de saltar a 'required', avanzar con move_toward para que
		# el cambio de elevación nunca sea abrupto.
		_camera_clear_time = 0.0
		if not found or not camera_collision_recovery:
			return previous
		# Forzar subida: renovar la memoria de elevación para que no baje
		# inmediatamente tras escapar.
		_lift_hold_left = camera_lift_hold_time
		var smooth_elev := move_toward(elevation, required, deg_to_rad(camera_lift_speed) * delta)
		var smooth_dir := _orbit_direction(base_yaw, smooth_elev)
		if _camera_direction_clear(anchor, smooth_dir, query):
			return smooth_dir
		# El paso suave cae dentro del obstáculo (hueco muy justo):
		# último recurso, ir al punto libre encontrado.
		return _orbit_direction(base_yaw, required)
	if not found:
		_camera_clear_time = 0.0
		return previous
	if required < elevation:
		# Hay margen para bajar. La memoria de elevación manda: si aún no ha
		# expirado, mantenemos la altura ganada aunque haya hueco, para no
		# bajar y volver a subir en cada bache de una pendiente.
		_lift_hold_left = maxf(0.0, _lift_hold_left - delta)
		# Histéresis espacial y temporal para cada descenso, incluso parcial.
		sphere.radius += camera_return_clearance
		var roomy := _camera_direction_clear(anchor, _orbit_direction(base_yaw, required), query)
		sphere.radius -= camera_return_clearance
		_camera_clear_time = _camera_clear_time + delta if roomy else 0.0
		if _lift_hold_left > 0.0 or _camera_clear_time < camera_return_delay or not roomy:
			required = elevation
	else:
		# No hay margen para bajar (required >= elevation). Mantener la memoria
		# llena: seguimos elevados, no toca devolver.
		_camera_clear_time = 0.0
		_lift_hold_left = camera_lift_hold_time
	var next_elevation: float
	if required > elevation:
		# Subida: velocidad constante. Escapar de un obstáculo prima sobre la estética.
		next_elevation = move_toward(elevation, required, deg_to_rad(camera_lift_speed) * delta)
	else:
		# Bajada ease-out: rápida al principio, frena al acercarse al objetivo.
		# 1 - exp(-k * delta) es un ease-out natural e independiente del framerate:
		# la fracción avanzada por frame depende sólo de k, y el paso absoluto
		# queda proporcional a la distancia restante. Resultado: al alejarse del
		# objetivo (mucha distancia) avanza mucho; al acercarse, avanza poco.
		var t := 1.0 - exp(-camera_return_speed * delta)
		next_elevation = lerpf(elevation, required, t)
		# El exponencial nunca alcanza el objetivo (asíntota). Un piso de
		# velocidad garantiza que llegue en tiempo finito y que la histéresis
		# de 'required < elevation' deje de dispararse.
		var floor_step := deg_to_rad(camera_return_speed) * camera_return_floor * delta
		if floor_step > 0.0 and absf(elevation - next_elevation) < floor_step and absf(elevation - required) > floor_step:
			next_elevation = move_toward(elevation, required, floor_step)
	var candidate := _orbit_direction(base_yaw, next_elevation)
	if _camera_arc_clear(anchor, previous, candidate, query):
		return candidate
	# Todavía no alcanza la altura necesaria: subir donde está y continuar el giro
	# en los próximos frames. Nunca avanzar por dentro de la superficie.
	candidate = _orbit_direction(previous_yaw, next_elevation)
	if _camera_arc_clear(anchor, previous, candidate, query):
		return candidate
	return previous

func _orbit_direction(orbit_yaw: float, elevation: float) -> Vector3:
	return Basis.from_euler(Vector3(-elevation, orbit_yaw, 0.0)).z

## Comprueba el arco real a radio constante y barre las cuerdas entre muestras.
func _camera_arc_clear(anchor: Vector3, start: Vector3, finish: Vector3, query: PhysicsShapeQueryParameters3D) -> bool:
	var angle := start.angle_to(finish)
	var steps := maxi(1, int(ceil(angle / deg_to_rad(2.0))))
	var previous := anchor + start * distance
	var sphere := query.shape as SphereShape3D
	var radius_before := sphere.radius
	# La flecha del arco amplía la esfera para cubrir el hueco entre arco y cuerda.
	sphere.radius += distance * (1.0 - cos(angle / steps * 0.5))
	for i in range(1, steps + 1):
		var direction := start.slerp(finish, float(i) / steps).normalized()
		if not _camera_direction_clear(anchor, direction, query):
			sphere.radius = radius_before
			return false
		var next := anchor + direction * distance
		query.transform = Transform3D(Basis.IDENTITY, previous)
		query.motion = next - previous
		var result := get_world_3d().direct_space_state.cast_motion(query)
		if result.is_empty() or result[0] < 1.0:
			sphere.radius = radius_before
			return false
		previous = next
	sphere.radius = radius_before
	return true

func _camera_direction_clear(anchor: Vector3, direction: Vector3, query: PhysicsShapeQueryParameters3D) -> bool:
	var space := get_world_3d().direct_space_state
	query.motion = Vector3.ZERO
	query.transform = Transform3D(Basis.IDENTITY, anchor + direction * distance)
	if not space.intersect_shape(query, 1).is_empty():
		return false
	# La visibilidad usa un rayo; la esfera protege la cámara y su arco, no un
	# tubo grueso que roce el suelo junto a los pies y provoque falsas correcciones.
	var sight := PhysicsRayQueryParameters3D.create(anchor, query.transform.origin, camera_collision_mask, query.exclude)
	return space.intersect_ray(sight).is_empty()
