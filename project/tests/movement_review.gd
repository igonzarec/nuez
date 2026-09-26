extends SceneTree

var game: Node
var checks := 0
var failures: Array[String] = []
var jumps := 0
var arena: StaticBody3D
var visual := false

func _initialize() -> void:
	visual = "--visual" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
	print(("PASS: " if value else "FAIL: ") + label)

func frames(count: int) -> void:
	for i in count: await physics_frame
	await process_frame

func stick(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)

func button(index: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = pressed
	Input.parse_input_event(event)

func place(height := 0.0) -> void:
	game.player.position = Vector3(100, 3.02 + height, 0)
	game.player.velocity = Vector3.ZERO
	game.player.previous_motion = Vector3.ZERO
	game.player.animator.reset()
	game.player.reset_physics_interpolation()
	game.camera_rig.yaw = 0
	game.camera_rig.pitch = deg_to_rad(game.camera_rig.pitch_degrees)
	game.camera_rig.snap()
	await frames(30 if height == 0 else 1)

func drop(height: float) -> float:
	await place(height)
	for i in 180:
		await frames(1)
		if game.player.is_on_floor(): break
	check(game.player.is_on_floor(), "Safe fall %.1f lands reliably" % height)
	var strength: float = game.player.landing_strength
	Input.action_press("move_right")
	await frames(2)
	check(game.player.velocity.x > 0.2, "Landing %.1f does not lock input" % height)
	Input.action_release("move_right")
	await frames(45)
	check(game.player.animation_state == "idle", "Landing %.1f returns to idle" % height)
	return strength

func shot(label: String) -> void:
	if not visual: return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/captures/motion_" + label + ".png")

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	game.start_game(false)
	arena = StaticBody3D.new()
	arena.position = Vector3(100, 2.5, 0)
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	collider.shape = box
	arena.add_child(collider)
	var mesh := BoxMesh.new()
	mesh.size = box.size
	TrailLevel.part(arena, mesh, Color("8b9c72"), Vector3.ZERO)
	game.level.add_child(arena)
	game.player.feedback.connect(func(kind: String) -> void:
		if kind == "jump": jumps += 1)
	await place()
	Input.action_press("move_right")
	await frames(1)
	check(game.player.velocity.x > 0.1 and game.player.velocity.x < game.player.walk_speed, "Input accelerates on the first physics tick")
	await frames(24)
	check(absf(game.player.horizontal_speed - game.player.walk_speed) < 0.05, "Walk reaches configured speed")
	Input.action_release("move_right")
	await frames(1)
	check(game.player.velocity.x > 0 and game.player.velocity.x < game.player.walk_speed, "Release brakes over multiple frames")
	await frames(30)
	var idle_position: Vector3 = game.player.position
	await frames(60)
	check(game.player.position.distance_to(idle_position) < 0.005, "No idle drift")
	Input.action_press("move_right")
	await frames(20)
	Input.action_release("move_right")
	Input.action_press("move_left")
	await frames(2)
	check(game.player.velocity.x > 0, "Reversal brakes existing momentum before changing direction")
	await frames(28)
	var travel_yaw := atan2(-game.player.velocity.x, -game.player.velocity.z)
	check(game.player.horizontal_speed > 5 and absf(wrapf(game.player.model.rotation.y - travel_yaw, -PI, PI)) < 0.05, "Reversal settles facing actual travel without spinning")
	Input.action_release("move_left")
	await place()
	stick(JOY_AXIS_LEFT_X, 1.0)
	await frames(24)
	var walking: float = game.player.horizontal_speed
	button(JOY_BUTTON_LEFT_SHOULDER, true)
	await frames(24)
	check(game.player.horizontal_speed > walking + 2 and absf(game.player.horizontal_speed - game.player.sprint_speed) < 0.05, "Holding LB/L1 with left stick reaches sprint speed")
	await shot("sprint")
	button(JOY_BUTTON_A, true)
	await frames(1)
	button(JOY_BUTTON_A, false)
	check(game.player.velocity.y > 7 and game.player.velocity.x > 7, "Gamepad sprint and jump work together")
	var jump_velocity: Vector3 = game.player.velocity
	game.pause_game()
	await frames(10)
	check(game.player.velocity == jump_velocity, "Pause preserves airborne velocity")
	game.resume_game()
	await frames(2)
	check(game.player.velocity.y > 6 and game.player.velocity.x > 7, "Resume preserves the jump arc and sprint")
	button(JOY_BUTTON_LEFT_SHOULDER, false)
	stick(JOY_AXIS_LEFT_X, 0)
	await frames(75)
	await place()
	var before_jumps := jumps
	Input.action_press("jump")
	await frames(2)
	check(game.player.animator.locomotion_state == "jump_start", "Immediate jump-start state")
	await frames(30)
	check(game.player.animator.locomotion_state == "fall", "Jump transitions to falling")
	await shot("fall")
	await frames(65)
	check(jumps == before_jumps + 1 and game.player.is_on_floor(), "Holding jump cannot cause repeated jumps")
	Input.action_release("jump")
	var small := await drop(0.65)
	var large := await drop(4.0)
	check(large > small + 0.2, "Larger fall produces stronger landing")
	await place()
	Input.action_press("move_forward")
	await frames(20)
	game.open_dialogue("Test", ["Test"])
	var frozen: Vector3 = game.player.position
	Input.action_release("move_forward")
	await frames(12)
	check(game.player.position == frozen, "Dialogue freezes moving player")
	game.advance_dialogue()
	await frames(30)
	check(game.player.control_enabled and game.player.animation_state == "idle", "Dialogue resume releases movement and animation correctly")
	game.player.react("collect")
	await frames(3)
	check(game.player.animation_state == "collect", "Collect overlay has its own active state")
	await frames(32)
	check(game.player.animation_state == "idle", "Collect overlay exits without getting stuck")
	# Camera invariants under movement, orbit, occlusion and extreme input.
	var distance_error := 0.0
	var rotation_step := 0.0
	var old_yaw: float = game.player.model.rotation.y
	for i in 180:
		var angle := i * 0.075
		stick(JOY_AXIS_LEFT_X, sin(angle))
		stick(JOY_AXIS_LEFT_Y, cos(angle))
		stick(JOY_AXIS_RIGHT_X, 0.6)
		stick(JOY_AXIS_RIGHT_Y, 1.0 if i < 90 else -1.0)
		await frames(1)
		var anchor: Vector3 = game.player.global_position + Vector3.UP * 1.15
		distance_error = maxf(distance_error, absf(game.camera_rig.camera.global_position.distance_to(anchor) - game.camera_rig.distance))
		rotation_step = maxf(rotation_step, absf(wrapf(game.player.model.rotation.y - old_yaw, -PI, PI)))
		old_yaw = game.player.model.rotation.y
	for axis: JoyAxis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]: stick(axis, 0)
	check(distance_error < 0.005, "Camera keeps its exact default radius while moving and orbiting")
	check(rotation_step < 0.8, "Circles and rapid turns remain bounded without pose snapping")
	check(absf(game.player.animator.tail_angle.x) <= 0.18 and absf(game.player.animator.tail_angle.y) <= 0.18, "Tail follow-through stays bounded")
	var allowed_min := deg_to_rad(-54)
	var allowed_max := deg_to_rad(-42)
	check(game.camera_rig.pitch >= allowed_min - 0.001 and game.camera_rig.pitch <= allowed_max + 0.001, "Gamepad vertical orbit stays within six degrees of default")
	var free_yaw: float = game.camera_rig.yaw
	var free_pitch: float = game.camera_rig.pitch
	var free_mouse := InputEventMouseMotion.new()
	free_mouse.relative = Vector2(300, 300)
	game.camera_rig._unhandled_input(free_mouse)
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and game.camera_rig.yaw == free_yaw and game.camera_rig.pitch == free_pitch, "Free cursor movement does not orbit or capture the mouse")
	for amount: float in [-100000, 100000]:
		var mouse := InputEventMouseMotion.new()
		mouse.relative = Vector2(100, amount)
		mouse.button_mask = MOUSE_BUTTON_MASK_RIGHT
		var drag_yaw: float = game.camera_rig.yaw
		game.camera_rig._unhandled_input(mouse)
		await frames(25)
		check(game.camera_rig.yaw != drag_yaw and game.camera_rig.pitch >= allowed_min - 0.001 and game.camera_rig.pitch <= allowed_max + 0.001, "Right-button drag orbits and respects vertical limit")
	free_yaw = game.camera_rig.yaw
	free_pitch = game.camera_rig.pitch
	game.camera_rig._unhandled_input(free_mouse)
	check(game.camera_rig.yaw == free_yaw and game.camera_rig.pitch == free_pitch and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Releasing right button immediately stops mouse orbit input")
	game.pause_game()
	free_mouse.button_mask = MOUSE_BUTTON_MASK_RIGHT
	game.camera_rig._unhandled_input(free_mouse)
	check(game.camera_rig.yaw == free_yaw and game.camera_rig.pitch == free_pitch, "Right-button drag cannot move camera while paused")
	game.resume_game()
	await frames(40)
	var player_yaw: float = game.player.model.rotation.y
	stick(JOY_AXIS_RIGHT_X, 1)
	await frames(40)
	stick(JOY_AXIS_RIGHT_X, 0)
	check(absf(wrapf(game.player.model.rotation.y - player_yaw, -PI, PI)) < 0.001, "Orbiting while idle never turns the squirrel")
	# Repeat at real terrain slopes, then approach common occluding props.
	for point: Vector2 in [Vector2(-15, 3), Vector2(13, -5), Vector2(-7, 24), Vector2(-7, 22.5)]:
		game.player.position = TrailLevel.point(point.x, point.y, 0.1)
		game.player.velocity = Vector3.ZERO
		game.player.reset_physics_interpolation()
		game.camera_rig.snap()
		await frames(40)
		var settled: Vector3 = game.player.position
		await frames(45)
		check(game.player.is_on_floor() and game.player.position.distance_to(settled) < 0.015, "Stable ground contact near " + str(point))
		var anchor: Vector3 = game.player.global_position + Vector3.UP * 1.15
		check(absf(game.camera_rig.camera.global_position.distance_to(anchor) - 14.4) < 0.01, "No camera zoom near " + str(point))
		Input.action_press("jump")
		await frames(1)
		Input.action_release("jump")
		await frames(80)
		check(game.player.is_on_floor() and game.player.animator.locomotion_state == "idle", "Jump on slope/near prop recovers idle at " + str(point))
	await shot("fixed_camera")
	print("MOVEMENT SUMMARY: %d checks, %d failures" % [checks, failures.size()])
	for failure in failures: print("FAILED: " + failure)
	paused = false
	game.queue_free()
	await frames(3)
	quit(0 if failures.is_empty() else 1)
