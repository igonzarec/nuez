extends Node3D

## Vista aislada para recorrer un GLB de montaña antes de integrarlo al nivel.

@onready var terrain: Node3D = $mountain_v01_blockout
@onready var player: ExplorerPlayer = $SquirrelExplorer
var preview_audio: TrailAudio

func _ready() -> void:
	TrailInput.install()
	_add_environment()
	_add_terrain_collision()
	_add_snowfall()
	_add_audio()
	_add_camera()

func _add_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("87a4b8")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("dce7e6")
	environment.ambient_light_energy = 0.7
	world_environment.environment = environment
	add_child(world_environment)

	var sunlight := DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sunlight.light_color = Color("fff0d6")
	sunlight.light_energy = 1.4
	sunlight.shadow_enabled = true
	add_child(sunlight)

func _add_terrain_collision() -> void:
	var mesh_instance := _find_mesh_instance(terrain)
	if not mesh_instance or not mesh_instance.mesh:
		push_error("Mountain preview could not find a mesh to use as collision.")
		return
	var body := StaticBody3D.new()
	body.name = "MountainCollision"
	mesh_instance.add_child(body)
	var collision := CollisionShape3D.new()
	collision.shape = mesh_instance.mesh.create_trimesh_shape()
	body.add_child(collision)

func _add_snowfall() -> void:
	var snow := CPUParticles3D.new()
	snow.name = "Snowfall"
	snow.amount = 500
	snow.lifetime = 12.0
	snow.preprocess = 6.0
	# Cubre el área donde empieza la ardilla y permanece visible al recorrer la ladera baja.
	snow.position = Vector3(-85.0, 20.0, 0.0)
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(42.0, 10.0, 42.0)
	snow.direction = Vector3(0.1, -1.0, 0.1)
	snow.spread = 12.0
	snow.gravity = Vector3(0.08, -0.12, 0.0)
	snow.initial_velocity_min = 0.7
	snow.initial_velocity_max = 1.2
	snow.scale_amount_min = 0.035
	snow.scale_amount_max = 0.065
	var flake := SphereMesh.new()
	flake.radius = 0.5
	flake.height = 1.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("e7eeeb")
	material.emission_enabled = true
	material.emission = Color("e7eeeb")
	material.emission_energy_multiplier = 0.25
	flake.material = material
	snow.mesh = flake
	add_child(snow)

func _add_audio() -> void:
	preview_audio = TrailAudio.new()
	preview_audio.name = "PreviewAudio"
	add_child(preview_audio)
	preview_audio.bind_player(player)
	preview_audio.apply({
		"master": 1.0,
		"music": 0.65,
		"sfx": 0.8,
		"climb_sfx": 0.5,
	})

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var mesh_instance := _find_mesh_instance(child)
		if mesh_instance:
			return mesh_instance
	return null

func _add_camera() -> void:
	var camera_rig := preload("res://scenes/camera_rig.tscn").instantiate() as TrailCamera
	camera_rig.target = player
	camera_rig.enabled = true
	add_child(camera_rig)
	player.camera_rig = camera_rig
	preview_audio.bind_camera(camera_rig)
	camera_rig.snap()
	camera_rig.camera.make_current()
