extends Node3D
## Standalone material comparison, not a replacement for the playable mountain scene.

@export_group("Camera")
## Camera orbit center, in world metres. Used live.
@export var focus := Vector3(0, 0.15, 0)
## Initial orbit distance in metres. Mouse wheel adjusts it during play.
@export_range(2.0, 50.0, 0.5) var distance := 20.0
## Initial elevation, degrees. Right drag adjusts it during play.
@export_range(5.0, 85.0, 1.0) var elevation := 38.0
## Initial horizontal orbit, degrees. Right drag adjusts it during play.
@export_range(-180.0, 180.0, 1.0) var azimuth := 0.0
## Degrees of camera rotation per mouse pixel. Live.
@export_range(0.05, 1.0, 0.05) var sensitivity := 0.25
## Four-sample edge antialiasing for thin blades. Costs GPU time; updates at scene start.
@export var antialiasing := true

func _ready() -> void:
	if antialiasing:
		get_viewport().msaa_3d = Viewport.MSAA_4X
	_update_camera()
	# Optional one-shot rendered artifact for visual review; not part of game UI.
	for argument in OS.get_cmdline_user_args():
		if argument == "--grass-close":
			focus = Vector3(-6.5, 0.15, 0)
			distance = 4.0
			elevation = 18.0
			_update_camera()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--grass-capture="):
			_capture(argument.trim_prefix("--grass-capture="))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		azimuth -= event.relative.x * sensitivity
		elevation = clampf(elevation + event.relative.y * sensitivity, 5.0, 85.0)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(2.0, distance * 0.9)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(50.0, distance / 0.9)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			$Grass3D.enabled = not $Grass3D.enabled
		if event.keycode == KEY_2:
			$TextureOnly.normal_strength = 0.0 if $TextureOnly.normal_strength > 0.0 else 0.45
		if event.keycode == KEY_3 or event.keycode == KEY_4:
			focus = Vector3(-6.5 if event.keycode == KEY_3 else 6.5, 0.15, 0)
			distance = 4.0
			elevation = 18.0
			azimuth = 0.0
		if event.keycode == KEY_5:
			focus = Vector3(0, 0.15, 0)
			distance = 20.0
			elevation = 38.0
			azimuth = 0.0
	_update_camera()

func _update_camera() -> void:
	var pitch := deg_to_rad(elevation)
	var yaw := deg_to_rad(azimuth)
	$Camera3D.position = focus + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	$Camera3D.look_at(focus)

func _capture(path: String) -> void:
	for i in 60:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(path)
	print("Grass visual capture: ", result)
	get_tree().quit(result)
