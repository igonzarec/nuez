extends SceneTree
var game: Node
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for i in count: await physics_frame
	await process_frame

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
	print(("PASS: " if value else "FAIL: ") + message)

func press_jump() -> void:
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	await frames(1)

func button(pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.pressed = pressed
	Input.parse_input_event(event)

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	game.start_game(false)
	var floor_body := StaticBody3D.new()
	floor_body.position = Vector3(100, -0.5, 0)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(80, 1, 80)
	collider.shape = shape
	floor_body.add_child(collider)
	game.level.add_child(floor_body)
	game.player.position = Vector3(100, 0.08, 0)
	game.player.velocity = Vector3.ZERO
	game.camera_rig.yaw = 0
	game.camera_rig.snap()
	await frames(35)
	Input.action_press("jump")
	await frames(12)
	check(not game.player.is_gliding, "Holding initial jump never deploys glide")
	Input.action_release("jump")
	await frames(1)
	var rising_velocity: float = game.player.velocity.y
	await press_jump()
	check(game.player.is_gliding and game.player.velocity.y < rising_velocity, "Second press deploys without an extra upward impulse")
	await frames(12)
	check(game.player.animation_state == "glide" and game.player.model.glide_membrane.visible, "Glide state opens visible membranes")
	await press_jump()
	check(not game.player.is_gliding, "Third press folds glide while airborne")
	await frames(100)
	check(game.player.is_on_floor() and not game.player.model.glide_membrane.visible, "Normal landing leaves no membrane or buffered extra jump")
	# Controlled safe fall: fully test sustained glide, braking and airborne UI.
	game.player.position = Vector3(100, 9, 0)
	game.player.velocity = Vector3(0, -8, 0)
	game.player.reset_physics_interpolation()
	# Let the previous floor contact and coyote window expire after teleporting.
	await frames(10)
	game.player.velocity.y = -8
	var before: float = game.player.velocity.y
	button(true)
	await frames(1)
	button(false)
	check(game.player.is_gliding and game.player.velocity.y > before and game.player.velocity.y < -game.player.glide_fall_speed, "Gamepad A deploys and brakes a fast fall gradually")
	await frames(25)
	check(absf(game.player.velocity.y + game.player.glide_fall_speed) < 0.01, "Gliding settles to configured downward speed, never hovering")
	Input.action_press("move_right")
	await frames(10)
	check(game.player.velocity.x > 1, "Glide retains directional control")
	Input.action_release("move_right")
	game.pause_game()
	var held: Vector3 = game.player.position
	await frames(8)
	check(game.player.position == held and game.player.is_gliding, "Pause preserves gliding position and state")
	game.resume_game()
	await frames(15)
	game.open_dialogue("Prueba", ["Planeo"])
	held = game.player.position
	await frames(8)
	check(game.player.position == held and game.player.is_gliding, "Dialogue preserves gliding state")
	game.advance_dialogue()
	await frames(12)
	if "--visual" in OS.get_cmdline_user_args():
		game.player.set_physics_process(false)
		game.ui.visible = false
		var camera := Camera3D.new()
		camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		game.level.add_child(camera)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 4.3
		camera.position = game.player.position + Vector3(1.8, 1.9, -5)
		game.player.model.rotation.y = 0
		camera.look_at(game.player.position + Vector3(0, 1, 0))
		camera.make_current()
		await frames(3)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/captures/glide_reference.png")
		camera.queue_free()
		game.camera_rig.camera.make_current()
		game.ui.visible = true
		game.player.set_physics_process(true)
	var landed := false
	for i in 260:
		await frames(1)
		if game.player.is_on_floor():
			landed = true
			break
	check(landed and not game.player.is_gliding, "Touchdown automatically cancels gliding")
	await frames(40)
	check(not game.player.model.glide_membrane.visible and game.player.animation_state == "idle", "Membranes fold and idle recovers after landing")
	game.player.position.y += 4
	await frames(3)
	await press_jump()
	game.player.respawn()
	check(not game.player.is_gliding and game.player.animator.glide_blend == 0, "Respawn clears gliding and its visual blend")
	print("GLIDE SUMMARY: %d checks, %d failures" % [checks, failures.size()])
	game.queue_free()
	await frames(4)
	quit(0 if failures.is_empty() else 1)
