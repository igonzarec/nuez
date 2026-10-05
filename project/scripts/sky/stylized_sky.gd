@tool
extends Node3D
const Cloud = preload("res://scripts/sky/stylized_cloud.gd")
const Profile = preload("res://scripts/sky/sky_profile.gd")
@export_group("Ambiente manual")
## Perfil principal. Edita el recurso para personalizar todos sus colores y luces.
@export var primary_profile: Resource = preload("res://resources/sky/day.tres")
## Segundo perfil para una transición manual; puede dejarse vacío.
@export var secondary_profile: Resource = preload("res://resources/sky/sunset.tres")
## 0 usa el principal; 1 usa el secundario. No avanza automáticamente.
@export_range(0.0, 1.0, 0.01) var profile_blend := 0.0
## Entorno existente a controlar. Vacío crea uno dentro de esta escena.
@export var environment_path: NodePath
## Sol existente a controlar. Vacío crea uno dentro de esta escena.
@export var sunlight_path: NodePath
## Curva del degradado: valores mayores extienden el color del horizonte.
@export_range(0.2, 4.0, 0.05) var horizon_curve := 0.8
@export_group("Distribución de nubes")
## Activa/desactiva las nubes generadas.
@export var clouds_enabled := true
## Cantidad. Aplicar con Regenerate Clouds; cero deja el cielo despejado.
@export_range(0, 200, 1) var cloud_count := 12
## La misma semilla conserva la distribución al regenerar.
@export var distribution_seed := 19
## Radio de distribución alrededor de este nodo, en metros.
@export_range(50.0, 3000.0, 10.0) var distribution_radius := 600.0
## Distancia mínima entre centros; si no cabe la cantidad, se generan menos.
@export_range(0.0, 300.0, 1.0) var minimum_spacing := 80.0
## Altitud mínima/máxima sobre el origen del cielo. Requiere regeneración.
@export var altitude_range := Vector2(160, 230)
## Anchura mínima/máxima de nube, en metros. Requiere regeneración.
@export var size_range := Vector2(55, 110)
## Altura y profundidad relativas a la anchura. Se actualizan en vivo.
@export var cloud_proportions := Vector2(0.4, 0.65)
## Lóbulos redondeados por nube; más lóbulos aumentan geometría. Regenerar.
@export_range(3, 24, 1) var lobes := 9
## Variación entre lóbulos: cero regular, uno más desigual. Regenerar.
@export_range(0.0, 1.0, 0.01) var irregularity := 0.5
## Semilla de formas independiente de las posiciones y anchuras. Regenerar.
@export var shape_seed := 47
## Variación de altura y profundidad entre nubes; cero usa proporciones iguales. En vivo.
@export_range(0.0, 0.8, 0.01) var proportion_variation := 0.35
## Variación del número de lóbulos por nube, alrededor de Lobes. Regenerar.
@export_range(0, 8, 1) var lobe_count_variation := 3
## Desplazamiento lateral de las cumbres; cero las centra. Regenerar.
@export_range(0.0, 1.0, 0.01) var asymmetry := 0.65
## Diferencias de tamaño entre lóbulos. Regenerar.
@export_range(0.0, 1.0, 0.01) var lobe_size_variation := 0.6
## Altura relativa de las cumbres. Regenerar.
@export_range(0.0, 1.5, 0.05) var peak_height := 0.85
## Variación de la altura de cumbres entre nubes. Regenerar.
@export_range(0.0, 0.8, 0.01) var peak_variation := 0.35
## Uniformidad de la base inferior; uno la alinea. Regenerar.
@export_range(0.0, 1.0, 0.01) var base_flatness := 0.75
## Resolución geométrica. Mayor valor cuesta más triángulos. Requiere regeneración.
@export_range(12, 48, 4) var roundness := 28
## Suavidad de fusión entre abultamientos; aumenta para hendiduras menos marcadas. Regenerar.
@export_range(0.03, 0.3, 0.01) var fusion_softness := 0.14
## Transición entre el color iluminado y la sombra; mayor valor suaviza en vivo.
@export_range(0.05, 1.0, 0.01) var shading_softness := 0.75
@export_tool_button("Regenerate Clouds") var regenerate_action = regenerate_clouds
@export_group("Viento")
## Dirección horizontal del viento, en grados.
@export_range(-180.0, 180.0, 1.0) var wind_direction := 20.0
## Metros por segundo. Cero detiene el movimiento.
@export_range(0.0, 20.0, 0.1) var wind_speed := 0.6
## Previsualiza el viento en el editor; apagado conserva posiciones mientras editas.
@export var preview_wind := false
var _environment: WorldEnvironment
var _sun: DirectionalLight3D
var _sky_material: ProceduralSkyMaterial
var _clouds: Node3D
var _profile_signature := 0

func _ready() -> void:
	_environment = get_node_or_null(environment_path) as WorldEnvironment if not environment_path.is_empty() else null
	if _environment == null:
		_environment = WorldEnvironment.new()
		_environment.name = "GeneratedEnvironment"
		add_child(_environment)
	_environment.environment = _environment.environment.duplicate() if _environment.environment else Environment.new()
	_sun = get_node_or_null(sunlight_path) as DirectionalLight3D if not sunlight_path.is_empty() else null
	if _sun == null:
		_sun = DirectionalLight3D.new()
		_sun.name = "GeneratedSun"
		_sun.shadow_enabled = true
		add_child(_sun)
	var sky := Sky.new()
	_sky_material = ProceduralSkyMaterial.new()
	_sky_material.sky_energy_multiplier = 1.0
	_sky_material.sun_angle_max = 2.0
	sky.sky_material = _sky_material
	_environment.environment.sky = sky
	_environment.environment.background_mode = Environment.BG_SKY
	regenerate_clouds()
	_apply_profile()

func regenerate_clouds() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(_clouds):
		remove_child(_clouds)
		_clouds.queue_free()
	_clouds = Node3D.new()
	_clouds.name = "GeneratedClouds"
	add_child(_clouds)
	var rng := RandomNumberGenerator.new()
	rng.seed = distribution_seed
	var positions: Array[Vector3] = []
	for i in cloud_count:
		var point := Vector3.ZERO
		var accepted := false
		for attempt in 100:
			var angle := rng.randf() * TAU
			var radius := sqrt(rng.randf()) * distribution_radius
			point = Vector3(cos(angle) * radius, rng.randf_range(minf(altitude_range.x, altitude_range.y), maxf(altitude_range.x, altitude_range.y)), sin(angle) * radius)
			accepted = true
			for previous in positions:
				if Vector2(point.x, point.z).distance_to(Vector2(previous.x, previous.z)) < minimum_spacing:
					accepted = false
					break
			if accepted:
				break
		if not accepted:
			continue
		positions.append(point)
		var cloud := Cloud.new()
		cloud.name = "Cloud%02d" % i
		var shape_rng := RandomNumberGenerator.new()
		shape_rng.seed = shape_seed + i * 71
		cloud.shape_seed = shape_seed + i * 71
		cloud.lobes = clampi(lobes + shape_rng.randi_range(-lobe_count_variation, lobe_count_variation), 3, 24)
		cloud.irregularity = irregularity
		cloud.asymmetry = asymmetry
		cloud.lobe_size_variation = lobe_size_variation
		cloud.peak_height = peak_height * shape_rng.randf_range(1.0 - peak_variation, 1.0 + peak_variation)
		cloud.base_flatness = base_flatness
		cloud.set_meta("proportion_jitter", Vector2(shape_rng.randf_range(-1, 1), shape_rng.randf_range(-1, 1)))
		cloud.roundness = roundness
		cloud.fusion_softness = fusion_softness
		var width := rng.randf_range(maxf(1, minf(size_range.x, size_range.y)), maxf(1, maxf(size_range.x, size_range.y)))
		cloud.dimensions = Vector3(width, width * cloud_proportions.x, width * cloud_proportions.y)
		cloud.position = point
		cloud.rotation.y = rng.randf() * TAU
		_clouds.add_child(cloud)
	if positions.size() < cloud_count:
		push_warning("StylizedSky: no caben todas las nubes; reduce Minimum Spacing o aumenta Distribution Radius.")
	_profile_signature = 0
	if is_instance_valid(_environment) and is_instance_valid(_sun):
		_apply_profile()

func _process(delta: float) -> void:
	if not is_instance_valid(_environment) or not is_instance_valid(_sun):
		return
	_apply_profile()
	if not is_instance_valid(_clouds):
		return
	_clouds.visible = clouds_enabled
	var wind := Vector3(cos(deg_to_rad(wind_direction)), 0, sin(deg_to_rad(wind_direction))) * wind_speed * delta
	for cloud in _clouds.get_children():
		var jitter: Vector2 = cloud.get_meta("proportion_jitter", Vector2.ZERO)
		cloud.dimensions.y = cloud.dimensions.x * cloud_proportions.x * (1.0 + jitter.x * proportion_variation)
		cloud.dimensions.z = cloud.dimensions.x * cloud_proportions.y * (1.0 + jitter.y * proportion_variation)
		cloud.shading_softness = shading_softness
		if not Engine.is_editor_hint() or preview_wind:
			cloud.position += wind
			# Recirculación lejos del centro del mapa. Para mapas mayores amplía el radio.
			if Vector2(cloud.position.x, cloud.position.z).length() > distribution_radius:
				cloud.position.x -= wind.normalized().x * distribution_radius * 2.0
				cloud.position.z -= wind.normalized().z * distribution_radius * 2.0

func _apply_profile() -> void:
	if not primary_profile is Profile:
		return
	var a = primary_profile
	var b = secondary_profile if secondary_profile is Profile else a
	var t := clampf(profile_blend, 0, 1)
	var state: Array = [t, horizon_curve]
	for profile in [a, b]:
		for field in ["zenith", "horizon", "cloud_color", "cloud_shadow", "sun_color", "sun_energy", "shadow_opacity", "sun_elevation", "sun_azimuth", "ambient_color", "ambient_energy", "fog_color", "fog_density", "overcast"]:
			state.append(profile.get(field))
	var signature := hash(state)
	# Evita pedir actualizaciones del cielo y sus reflejos cada frame sin cambios.
	if signature == _profile_signature:
		return
	_profile_signature = signature
	_sky_material.sky_top_color = a.zenith.lerp(b.zenith, t)
	_sky_material.sky_horizon_color = a.horizon.lerp(b.horizon, t)
	_sky_material.ground_horizon_color = _sky_material.sky_horizon_color
	_sky_material.ground_bottom_color = _sky_material.sky_horizon_color.darkened(0.25)
	_sky_material.sky_curve = horizon_curve
	_sun.light_color = a.sun_color.lerp(b.sun_color, t)
	_sun.light_energy = lerpf(a.sun_energy, b.sun_energy, t)
	_sun.shadow_opacity = lerpf(a.shadow_opacity, b.shadow_opacity, t)
	_sun.rotation_degrees = Vector3(-lerpf(a.sun_elevation, b.sun_elevation, t), rad_to_deg(lerp_angle(deg_to_rad(a.sun_azimuth), deg_to_rad(b.sun_azimuth), t)), 0)
	var env := _environment.environment
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = a.ambient_color.lerp(b.ambient_color, t)
	env.ambient_light_energy = lerpf(a.ambient_energy, b.ambient_energy, t)
	env.fog_light_color = a.fog_color.lerp(b.fog_color, t)
	env.fog_density = lerpf(a.fog_density, b.fog_density, t)
	env.fog_enabled = env.fog_density > 0.0
	var overcast := lerpf(a.overcast, b.overcast, t)
	_sky_material.sky_top_color = _sky_material.sky_top_color.lerp(_sky_material.sky_horizon_color, overcast)
	if is_instance_valid(_clouds):
		for cloud in _clouds.get_children():
			cloud.cloud_color = a.cloud_color.lerp(b.cloud_color, t)
			cloud.shadow_color = a.cloud_shadow.lerp(b.cloud_shadow, t)
			cloud.sun_direction = _sun.global_basis.z
