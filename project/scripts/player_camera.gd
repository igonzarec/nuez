class_name TrailCamera
extends Node3D

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
@export_group("Desenfoque de distancia")
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
		yaw = wrapf(yaw - event.relative.x * 0.0025 * sensitivity, -PI, PI)
		pitch = _clamp_pitch(pitch - event.relative.y * 0.001 * sensitivity)

func _physics_process(delta: float) -> void:
	if not target:
		return
	if enabled:
		var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		yaw = wrapf(yaw - stick.x * stick_speed * delta, -PI, PI)
		pitch = _clamp_pitch(pitch - stick.y * stick_speed * 0.4 * delta)
	pitch = _clamp_pitch(pitch)
	# One camera only: smoothly blend its orbit angle between the normal view
	# and the more elevated glide view. No camera is swapped or teleported.
	var glide_target := 1.0 if target.is_gliding else 0.0
	glide_view_blend = lerpf(glide_view_blend, glide_target, 1.0 - exp(-glide_camera_speed * delta))
	var view_pitch := lerp_angle(pitch, deg_to_rad(glide_pitch_degrees), glide_view_blend)
	rotation.x = lerp_angle(rotation.x, view_pitch, 1.0 - exp(-orbit_smoothing * delta))
	rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-orbit_smoothing * delta))
	global_position = global_position.lerp(target.global_position + Vector3.UP * 1.15, 1.0 - exp(-follow_speed * delta))
	_place_camera()

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
