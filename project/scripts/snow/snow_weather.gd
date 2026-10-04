@tool
extends Node3D
## Copos locales al jugador; coste acotado aunque el mapa mida 300 metros.
## Enciende o apaga la nevada local.
@export var enabled := true
## Original: sólidos angulares. Irregular: silueta lobulada. Polvo: motas suaves. Casi circular: disco limpio con leve deformación.
@export_enum("Original angular", "Copo irregular", "Polvo suave", "Casi circular") var flake_style := 1
## Color propio del copo, independiente del tono azul del ambiente.
@export var flake_color := Color(1.0, 1.0, 1.0, 1.0)
## Opacidad de los copos. Reduce este valor si destacan demasiado sobre el cielo.
@export_range(0.0, 1.0, 0.01) var opacity := 1.0
## Variación de tamaño alrededor de Flake Size; 0 produce tamaños iguales.
@export_range(0.0, 0.99, 0.01) var size_variation := 0.0
## Irregularidad del borde. 0 = forma regular; 1 = lóbulos marcados (Copo irregular) o leve deformación (Casi circular).
@export_range(0.0, 1.0, 0.05) var irregularity := 0.1
## Si está activo, las luces de la escena tiñen los copos; apagado conserva Flake Color.
@export var receive_lighting := false
## Máximo de copos vivos; la intensidad por altura usa una fracción de este total.
@export_range(0, 20000, 10, "or_greater") var flakes := 2000
## Semiancho en metros de la caja de emisión alrededor del jugador.
@export_range(1.0, 200.0, 1.0, "or_greater") var radius := 18.0
## Altura del emisor por encima del jugador, en metros.
@export_range(1.0, 150.0, 1.0, "or_greater") var ceiling := 25.0
## Tamaño aproximado del copo en metros. Rango amplio: 1 mm a 3 m (o más con "or_greater").
@export_range(0.001, 3.0, 0.001, "or_greater") var flake_size := 0.473
## Velocidad de caída en metros por segundo. No cambia el número de copos.
@export_range(0.1, 50.0, 0.1, "or_greater") var fall_speed := 2.0
## Desplazamiento horizontal del viento, en metros por segundo.
@export var wind := Vector3.ZERO
## Altura mundial Y donde se usa Low Intensity.
@export var height_start := 0.0
## Altura mundial Y donde se alcanza High Intensity.
@export var height_end := 50.0
## Fracción de Flakes que cae en la parte baja.
@export_range(0.0, 1.0, 0.05) var low_intensity := 0.5
## Fracción de Flakes que cae en la parte alta.
@export_range(0.0, 1.0, 0.05) var high_intensity := 0.5
@export_group("Nevada durante vuelo")
## Densidad al planear respecto al suelo: 0 apaga, 1 igual, 2 duplica la cantidad.
@export_range(0.0, 4.0, 0.05) var flight_intensity := 1.0
## Tamaño relativo de copos durante planeo, sin cambiar Flake Size guardado.
@export_range(0.1, 3.0, 0.05) var flight_size_multiplier := 1.0
@export_group("Respuesta al movimiento")
## Mantiene el volumen de copos centrado en el jugador al desplazarse.
@export var follow_player_motion := true
## Viento en contra inducido por la velocidad del jugador.
## 0 = solo paralaje world-space. 1 = los copos heredan -velocidad del jugador. 2 = doble.
@export_range(0.0, 2.0, 0.05) var player_motion_wind := 0.6
## Adelanto del centro de emisión en la dirección de movimiento, en segundos de recorrido.
## Compensa que al correr el frente de la caja se vacíe (efecto túnel).
## 0 = sin compensación. 0.5-1.0 = recomendado. Se limita al radio de la caja.
@export_range(0.0, 3.0, 0.05) var emitter_lead_time := 0.8
@export_group("Vista previa en editor")
## Muestra copos aunque no haya jugador ejecutando la escena.
@export var preview_enabled := true
## Centro local de la vista previa, en metros.
@export var preview_center := Vector3.ZERO
var _signature := 0
var target: Node3D
var particles: GPUParticles3D
var _prev_target_pos := Vector3.ZERO
var _target_velocity := Vector3.ZERO
var _has_prev := false

func _ready() -> void:
	particles = GPUParticles3D.new()
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)
	_rebuild()
	_signature = _configuration()
	if Engine.is_editor_hint():
		particles.global_position = to_global(preview_center + Vector3.UP * ceiling * 0.25)
		particles.emitting = preview_enabled and flakes > 0
	_apply_dynamic()

func _configuration() -> int:
	return hash([flakes, radius, ceiling, flake_size, fall_speed, wind, flake_style,
		flake_color, opacity, size_variation, irregularity, receive_lighting,
		flight_intensity, flight_size_multiplier])

func _rebuild() -> void:
	# Configuración directa de GPU: malla y material de proceso explícitos.
	# La desaparición simultánea de copos y huellas se debía al orden del blur.
	particles.amount = maxi(int(flakes * maxf(1.0, flight_intensity)), 1)
	particles.lifetime = maxf(2.0, (ceiling + 15.0) / maxf(0.1, fall_speed))
	particles.preprocess = 4.0
	particles.local_coords = false
	particles.draw_pass_1 = _make_mesh()
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(radius, ceiling, radius)
	var base_velocity := Vector3.DOWN * fall_speed + wind
	process.direction = base_velocity.normalized()
	process.initial_velocity_min = base_velocity.length()
	process.initial_velocity_max = base_velocity.length() * 1.2
	process.gravity = Vector3.ZERO
	process.spread = 8.0
	process.scale_min = 1.0
	process.scale_max = 1.0
	particles.process_material = process
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = AABB(
		Vector3(-radius - 30, -ceiling - 30, -radius - 30),
		Vector3(radius * 2 + 60, ceiling + 60, radius * 2 + 60))
	_apply_dynamic()
	# También se enciende antes del primer _process: así no depende de que el
	# padre haya asignado todavía el jugador durante la inicialización.
	particles.emitting = enabled and flakes > 0
	particles.restart()

func _make_mesh() -> PrimitiveMesh:
	var flake: PrimitiveMesh
	if flake_style == 0:
		var angular := SphereMesh.new()
		angular.radial_segments = 4
		angular.rings = 1
		angular.radius = flake_size * 0.5
		angular.height = flake_size
		flake = angular
	else:
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * flake_size
		flake = quad
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(flake_color, flake_color.a * opacity)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if flake_style != 0:
		material.albedo_texture = _flake_texture()
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if receive_lighting else BaseMaterial3D.SHADING_MODE_UNSHADED
	flake.material = material
	return flake

func _track_velocity(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		_has_prev = false
		_target_velocity = _target_velocity.lerp(Vector3.ZERO, clampf(delta * 6.0, 0.0, 1.0))
		return
	var new_pos := target.global_position
	if _has_prev and delta > 0.0001:
		var inst := (new_pos - _prev_target_pos) / delta
		if inst.length() > 200.0:
			_has_prev = false
		else:
			var k := clampf(delta * 8.0, 0.0, 1.0)
			_target_velocity = _target_velocity.lerp(inst, k)
	_prev_target_pos = new_pos
	_has_prev = true

func _apply_dynamic() -> void:
	if particles == null:
		return
	var process := particles.process_material as ParticleProcessMaterial
	if process == null:
		return
	var mult := 1.0
	if target and target is ExplorerPlayer and target.is_gliding:
		mult = flight_size_multiplier
	process.scale_min = mult * (1.0 - size_variation)
	process.scale_max = mult * (1.0 + size_variation)
	var dyn_wind := wind - _target_velocity * player_motion_wind
	var base_vel := Vector3.DOWN * fall_speed + dyn_wind
	if base_vel.length_squared() > 0.0001:
		process.direction = base_vel.normalized()
		process.initial_velocity_min = base_vel.length()
		process.initial_velocity_max = base_vel.length() * 1.2

## Adelanto del emisor en la dirección del movimiento, saturado al radio de la caja
## para que el jugador nunca quede fuera del volumen de emisión.
func _emitter_lead() -> Vector3:
	if emitter_lead_time <= 0.0:
		return Vector3.ZERO
	var lead := _target_velocity * emitter_lead_time
	var max_lead := radius * 0.9
	if lead.length() > max_lead:
		lead = lead.normalized() * max_lead
	return lead

func _flake_texture() -> ImageTexture:
	var pixels := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var p := (Vector2(x, y) + Vector2.ONE * 0.5) / 32.0 - Vector2.ONE
			var r := p.length()
			var angle := p.angle()
			var alpha := 0.0
			match flake_style:
				1:
					var edge_a := 0.55 + irregularity * (0.12 * sin(angle * 5.0) + 0.08 * cos(angle * 9.0))
					alpha = 1.0 - smoothstep(edge_a - 0.12, edge_a, r)
				2:
					alpha = exp(-r * r * 5.0) * (0.7 + 0.3 * sin(p.x * 7.0 + p.y * 3.0))
					alpha *= 1.0 - smoothstep(0.75, 1.0, r)
				3:
					var wobble := 0.06 * irregularity
					var edge_c := 0.65 + wobble * (sin(angle * 6.0) + 0.5 * cos(angle * 10.0))
					alpha = 1.0 - smoothstep(edge_c - 0.06, edge_c, r)
				_:
					alpha = 1.0 - smoothstep(0.55, 0.65, r)
			pixels.set_pixel(x, y, Color(1, 1, 1, alpha))
	pixels.generate_mipmaps()
	return ImageTexture.create_from_image(pixels)

func _process(delta: float) -> void:
	var signature := _configuration()
	if signature != _signature:
		_signature = signature
		_rebuild()
	_track_velocity(delta)
	if not target:
		if Engine.is_editor_hint():
			particles.global_position = to_global(preview_center + Vector3.UP * ceiling * 0.25)
			particles.emitting = preview_enabled and flakes > 0
			_apply_dynamic()
		return
	var center := target.global_position
	if target is ExplorerPlayer and is_instance_valid(target.camera_rig):
		center = center.lerp(target.camera_rig.camera.global_position, 0.5)
	if follow_player_motion:
		# Centro + adelanto en dirección de movimiento: rellena el frente de la caja
		# cuando corres, en vez de dejar un túnel vacío delante del jugador.
		particles.global_position = center + Vector3.UP * ceiling * 0.25 + _emitter_lead()
	var altitude := smoothstep(height_start, maxf(height_start + 0.01, height_end), target.global_position.y)
	var flying: bool = target is ExplorerPlayer and target.is_gliding
	particles.amount_ratio = lerpf(low_intensity, high_intensity, altitude) * (flight_intensity if flying else 1.0) / maxf(1.0, flight_intensity)
	_apply_dynamic()
	particles.emitting = enabled and flakes > 0
