extends Node3D
## Escena aislada de autoría y juego. F6 la ejecuta; R devuelve al inicio.
@export_group("Punto de prueba")
## Marker3D de inicio alternativo. Vacío usa PlayerStart. Se proyecta sobre el suelo al iniciar F6.
@export_node_path("Marker3D") var spawn_marker := NodePath("")
@export_group("Huellas")
@export var footprints_enabled := true
@export_range(8, 256, 8) var footprint_limit := 96
@export_range(2.0, 120.0, 1.0) var footprint_seconds := 35.0
@export var footprint_size := Vector2(0.24, 0.38)
@export var footprint_color := Color(0.49, 0.64, 0.72)
@export_group("Nieve profunda")
@export var slow_in_deep_snow := true
@export_range(0.2, 1.0, 0.05) var deep_speed_multiplier := 0.7
@export_range(0.3, 4.0, 0.1) var deep_snow_depth := 1.5
@onready var terrain = $SnowTerrain
@onready var player: ExplorerPlayer = $SquirrelExplorer
@onready var camera_rig: TrailCamera = $CameraRig
@onready var weather = $Snowfall
var _walk_speed := 0.0
var _sprint_speed := 0.0
var _prints: Array[MeshInstance3D] = []
var _ages: Array[float] = []
var _next_print := 0
var _side := 1.0

func _ready() -> void:
	TrailInput.install()
	player.set_controls(false)
	_walk_speed = player.walk_speed
	_sprint_speed = player.sprint_speed
	var audio := TrailAudio.new()
	audio.name = "PreviewAudio"
	add_child(audio)
	audio.bind_player(player)
	$SnowStepAudio.bind(player, audio)
	audio.bind_camera(camera_rig)
	audio.apply({"master": 1.0, "music": 0.65, "sfx": 0.8, "climb_sfx": 0.5})
	camera_rig.target = player
	camera_rig.enabled = true
	player.camera_rig = camera_rig
	weather.target = player
	player.feedback.connect(_feedback)
	# Let the physics server register the generated static surface before the ray.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var marker := get_node_or_null(spawn_marker) if not spawn_marker.is_empty() else null
	var start: Vector3 = marker.global_position if marker is Node3D else $PlayerStart.global_position
	var hit := _ground(start + Vector3.UP * 200.0, 500.0)
	if hit.is_empty():
		push_error("PlayerStart no está sobre el terreno. Muévelo dentro del mapa.")
		return
	player.spawn_position = Vector3(hit.position) + Vector3.UP * 0.15
	player.respawn()
	camera_rig.camera.make_current()
	player.set_controls(true)
	print("Snow playground ready. Spawn: ", player.spawn_position)

func _ground(origin: Vector3, distance := 4.0) -> Dictionary:
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * distance, 1))

func _snow_sample(hit: Dictionary) -> Vector2:
	if not hit.is_empty() and hit.collider.has_method("snow_sample"):
		return hit.collider.snow_sample(hit)
	return terrain.sample_hit(hit)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		player.respawn()

func _physics_process(_delta: float) -> void:
	var snow: Vector2 = _snow_sample(_ground(player.global_position + Vector3.UP * 0.7, 1.5))
	$SnowStepAudio.set_surface(snow.x)
	var factor := 1.0
	if slow_in_deep_snow and player.is_on_floor():
		factor = lerpf(1.0, deep_speed_multiplier, smoothstep(0.3, deep_snow_depth, snow.y))
	player.walk_speed = _walk_speed * factor
	player.sprint_speed = _sprint_speed * factor

func _process(delta: float) -> void:
	for i in _prints.size():
		_ages[i] += delta
		_prints[i].visible = _ages[i] < footprint_seconds
		if _prints[i].visible:
			_prints[i].material_override.set_shader_parameter("fade", 1.0 - smoothstep(footprint_seconds * 0.6, footprint_seconds, _ages[i]))

func _feedback(kind: String) -> void:
	if kind != "step" or not footprints_enabled:
		return
	_side *= -1.0
	var right := Vector3.RIGHT.rotated(Vector3.UP, player.model.rotation.y)
	var origin := player.global_position + right * _side * 0.16 + Vector3.UP * 0.65
	var hit := _ground(origin)
	if hit.is_empty():
		return
	var point: Vector3 = hit.position
	var normal: Vector3 = hit.normal
	# Usa la cobertura interpolada del terreno generado, igual que el audio.
	if _snow_sample(hit).x < 0.5:
		return
	var mark: MeshInstance3D
	if _prints.size() < footprint_limit:
		mark = MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = footprint_size
		mark.mesh = plane
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/snow_footprint.gdshader")
		material.set_shader_parameter("print_color", footprint_color)
		mark.material_override = material
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mark)
		_prints.append(mark)
		_ages.append(0.0)
		_next_print = _prints.size() - 1
	else:
		mark = _prints[_next_print]
	_ages[_next_print] = 0.0
	var tangent := right.slide(normal).normalized()
	mark.global_transform = Transform3D(Basis(tangent, normal, tangent.cross(normal)), point + normal * 0.015)
	mark.visible = true
	mark.material_override.set_shader_parameter("fade", 1.0)
	_next_print = (_next_print + 1) % footprint_limit
