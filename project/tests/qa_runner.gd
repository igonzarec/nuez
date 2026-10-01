extends SceneTree

var game: Node
var failures: Array[String] = []
var checks := 0
var visual := false

func _initialize() -> void:
	visual = "--visual" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("QA FAIL: " + message)
	else:
		print("PASS: " + message)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame

func capture(label: String) -> void:
	if not visual:
		return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://tests/captures")
	root.get_texture().get_image().save_png("res://tests/captures/" + label + ".png")

func move_to(destination: Vector3) -> bool:
	var arrived := false
	for i in 1000:
		var offset: Vector3 = destination - game.player.global_position
		offset.y = 0
		if offset.length() < 0.35:
			arrived = true
			break
		var direction := offset.normalized().rotated(Vector3.UP, -game.camera_rig.yaw)
		Input.action_press("move_right", maxf(0, direction.x))
		Input.action_press("move_left", maxf(0, -direction.x))
		Input.action_press("move_back", maxf(0, direction.z))
		Input.action_press("move_forward", maxf(0, -direction.z))
		# The intentionally low fallen log teaches jumping, with room to walk around.
		if i % 110 == 80:
			Input.action_press("jump")
		elif i % 110 == 81:
			Input.action_release("jump")
		await physics_frame
	for action: String in ["move_left", "move_right", "move_forward", "move_back", "jump"]:
		Input.action_release(action)
	await frames(42)
	return arrived

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(4)
	check(game.state == game.State.TITLE and paused, "Main scene starts on title with gameplay frozen")
	await capture("01_title")
	game.start_game(false)
	await frames(30)
	check(game.progress.collected.is_empty() and game.progress.lamps.is_empty(), "New Game clears all progress")
	check(game.player.is_on_floor(), "Player spawns grounded on terrain")
	check(game.level.lamps.size() == 3 and game.level.seeds.size() == 15, "Three lanterns and fifteen collectible seeds")
	check(not game.restore_lamp(game.level.lamps[0]), "Lantern rejects insufficient seeds")
	await capture("02_trailhead")
	var start_y: float = game.player.position.y
	Input.action_press("jump")
	await frames(1)
	Input.action_release("jump")
	await frames(10)
	check(game.player.position.y > start_y + 0.6, "Jump rises above ground")
	var airborne_velocity: float = game.player.velocity.y
	Input.action_press("jump")
	await frames(1)
	Input.action_release("jump")
	check(game.player.velocity.y < airborne_velocity, "Second airborne press does not double-jump")
	await frames(65)
	check(game.player.is_on_floor(), "Jump lands reliably")
	game.pause_game()
	var paused_position: Vector3 = game.player.position
	var paused_time: float = game.progress.elapsed
	await frames(20)
	check(game.player.position == paused_position and game.progress.elapsed == paused_time, "Pause freezes movement and expedition clock")
	game._on_action("settings")
	game._on_setting("sensitivity", 1.35)
	game._settings_back()
	check(game.state == game.State.PAUSED and is_equal_approx(game.store.load_settings().sensitivity, 1.35), "Settings persist and return to pause")
	await capture("03_pause")
	game.resume_game()
	game.open_dialogue("Prueba", ["Primera página", "Segunda página"])
	check(not game.player.control_enabled and paused, "Dialogue blocks movement and camera")
	game.advance_dialogue()
	game.advance_dialogue()
	check(game.state == game.State.PLAYING and game.player.control_enabled and not paused, "Dialogue pages close and restore controls")
	game.begin_ending()
	check(game.state == game.State.PLAYING, "Ending cannot start before restoring all lanterns")
	# Traverse the actual mesh with CharacterBody3D and collect through Area3D overlap signals.
	for i in 9:
		var detours: Array[Vector2] = []
		match i:
			3: detours = [Vector2(-25, -2)]
			4: detours = [Vector2(-18, -19)]
			5: detours = [Vector2(17, -21)]
			7: detours = [Vector2(-10, -10)]
			8: detours = [Vector2(13, -5)]
		for waypoint in detours:
			check(await move_to(TrailLevel.point(waypoint.x, waypoint.y)), "Mountain spiral traversable: " + str(waypoint))
		var p: Vector2 = TrailLevel.SEEDS[i]
		var arrived := await move_to(TrailLevel.point(p.x, p.y))
		check(arrived, "Physical traversal reaches seed %02d" % i)
		check(game.progress.collected.has("seed_%02d" % i), "Overlap collects seed %02d exactly once" % i)
		if i in [2, 5, 8]:
			if i == 5:
				for waypoint: Vector2 in [Vector2(21, 12), Vector2(9, 19), Vector2(-7, 15)]:
					check(await move_to(TrailLevel.point(waypoint.x, waypoint.y)), "Full circuit around mountain: " + str(waypoint))
			var lamp_index := int(i / 3)
			var lamp: TrailLamp = game.level.lamps[lamp_index]
			check(await move_to(lamp.global_position + Vector3(0, 0, 0.8)), "Route reaches lantern %d" % lamp_index)
			await frames(4)
			check(game.interaction.selected == lamp, "Lantern prompt selected in range")
			check(game.restore_lamp(lamp), "Lantern spends three seeds and activates")
			check(not game.restore_lamp(lamp), "Lit lantern cannot charge twice")
			check(lamp.beacon_light.light_energy > 0 and lamp.embers.emitting, "Lantern light and particles activate")
			if i == 2:
				game.show_title()
				game.start_game(true)
				await frames(15)
				check(game.progress.lamps == ["clearing"] and game.progress.collected.size() == 3, "Continue restores exact lantern and collected seed IDs")
				check(game.level.seeds[0].claimed and not game.level.seeds[0].visible, "Loaded seeds stay collected")
	await capture("04_overlook")
	check(game.progress.lamps.size() == 3 and not game.progress.completed, "Restoring lanterns requires returning to Mara")
	var checkpoint: Vector3 = game.player.spawn_position
	game.player.position = Vector3(0, -20, 0)
	await frames(4)
	check(game.player.position.distance_to(checkpoint) < 1, "Falling respawns at the latest safe lantern")
	# Return along the eastern path to verify the full circuit.
	for p: Vector2 in [Vector2(0, 2), Vector2(7, 6), Vector2(13, -5), Vector2(3, -16), Vector2(-10, -10), Vector2(-15, 3), Vector2(-7, 15), Vector2(9, 19), Vector2(0, 25), Vector2(-2.4, 21)]:
		check(await move_to(TrailLevel.point(p.x, p.y)), "Return route traversable: " + str(p))
	await frames(3)
	check(game.interaction.selected == game.level.guide, "Mara selected on return")
	game.interact()
	game.advance_dialogue()
	game.advance_dialogue()
	check(game.state == game.State.ENDING and game.progress.completed, "Final conversation begins the ending")
	await frames(410)
	check(game.state == game.State.COMPLETE, "Ending transitions to completion screen")
	await capture("05_completion")
	game.show_title()
	game.start_game(true)
	check(game.state == game.State.COMPLETE, "Completed expedition persists across Continue")
	game.start_game(false)
	await frames(4)
	check(game.progress.lamps.is_empty() and game.progress.collected.is_empty(), "Replay resets seeds and lamps")
	check(game.get_children().filter(func(n: Node) -> bool: return n is TrailLevel).size() == 1, "Scene rebuild does not duplicate level")
	check(game.audio.get_child_count() == 10, "Scene rebuild does not duplicate audio loops or voices")
	game._set_device(true)
	check(game.ui.controls.text.contains("Stick"), "Gamepad prompts switch correctly")
	# Input events test the real action map, including UI consumption and jump suppression.
	var original_position: Vector3 = game.player.position
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 0.8
	Input.parse_input_event(stick)
	await frames(24)
	stick = InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 0
	Input.parse_input_event(stick)
	await frames(25)
	check(game.player.position.distance_to(original_position) > 0.6, "Injected left stick moves player through action map")
	var yaw_before: float = game.camera_rig.yaw
	stick = InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_RIGHT_X
	stick.axis_value = 0.6
	Input.parse_input_event(stick)
	await frames(20)
	stick = InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_RIGHT_X
	stick.axis_value = 0
	Input.parse_input_event(stick)
	check(absf(game.camera_rig.yaw - yaw_before) > 0.1, "Injected right stick orbits camera")
	await joy_button(JOY_BUTTON_START)
	await frames(2)
	check(game.player.global_position.distance_to(TrailLevel.summit_spawn()) < 0.35, "Gamepad Start performs the configured fast reset")
	game._on_setting("fast_reset_enabled", false)
	await joy_button(JOY_BUTTON_START)
	check(game.state == game.State.PAUSED, "Gamepad Start opens pause when fast reset is disabled")
	var focused: Control = root.gui_get_focus_owner()
	await joy_button(JOY_BUTTON_DPAD_DOWN)
	check(root.gui_get_focus_owner() != focused, "Gamepad D-pad navigates visible menu focus")
	game.ui.buttons.resume.grab_focus()
	await joy_button(JOY_BUTTON_A)
	check(game.state == game.State.PLAYING and game.player.velocity.y <= 0.1, "Gamepad confirm resumes without leaking a jump")
	game._on_setting("fast_reset_enabled", true)
	if game.state != game.State.PLAYING:
		game.resume_game()
	await frames(20)
	# Test duplicate Area events within the same physics tick.
	var seed_node: LightFragment = game.level.seeds[0]
	var seed_count: int = game.progress.collected.size()
	seed_node._on_body_entered(game.player)
	seed_node._on_body_entered(game.player)
	check(game.progress.collected.size() == seed_count + 1, "Duplicate overlap events cannot award a seed twice")
	await frames(2)
	# Check camera obstruction with an actual physics body behind the character.
	game.player.position = TrailLevel.point(0, 22, 0.1)
	game.player.reset_physics_interpolation()
	game.camera_rig.yaw = 0
	game.camera_rig.snap()
	await frames(15)
	var camera_anchor: Vector3 = game.player.global_position + Vector3.UP * 1.15
	var camera_distance: float = game.camera_rig.camera.global_position.distance_to(camera_anchor)
	var obstacle := StaticBody3D.new()
	obstacle.position = game.camera_rig.global_position + game.camera_rig.global_basis.z * 4.0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4, 4, 1)
	collision.shape = shape
	obstacle.add_child(collision)
	game.level.add_child(obstacle)
	await frames(8)
	check(absf(game.camera_rig.camera.global_position.distance_to(camera_anchor) - camera_distance) < 0.02, "Obstructing prop cannot pull camera closer")
	obstacle.queue_free()
	await frames(8)
	check(absf(game.camera_rig.camera.global_position.distance_to(camera_anchor) - game.camera_rig.distance) < 0.02, "Camera retains default radius after obstruction")
	await frames(30)
	check(game.player.animation_state == "idle" and game.player.model.idle_active, "Idle returns to the upright fixed rest pose")
	check(game.player.animator.run_blend < 0.1, "Run cycle blends back to idle without sticking")
	var imported_skeleton: Skeleton3D = game.player.model.playertest2_skeleton
	check(is_instance_valid(imported_skeleton) and imported_skeleton.find_bone("arm_left") >= 0 and imported_skeleton.find_bone("leg_right") >= 0, "Imported model exposes the weighted limb bones")
	Input.action_press("move_right")
	await frames(24)
	var gait_before: float = game.player.animator.gait_phase
	game.player.react("collect")
	await frames(6)
	check(game.player.animator.gait_phase > gait_before and game.player.animator.run_blend > 0.7, "Collection overlay preserves a continuous running cycle")
	Input.action_release("move_right")
	await frames(42)
	check(game.player.animation_state == "idle" and game.player.animator.run_blend < 0.1, "Locomotion eases back into idle after stopping")
	var resident: TrailResident = game.level.residents[1]
	var resident_head: float = resident.head.rotation.y
	await frames(24)
	check(absf(resident.head.rotation.y - resident_head) > 0.001, "Residents retain independent idle animation")
	# Gameplay captures always use the production fixed-distance orbit.
	if visual:
		game.player.position = TrailLevel.point(4, 17)
		game.player.model.rotation.y = 0.35
		game.camera_rig.yaw = PI - 0.5
		game.camera_rig.pitch = deg_to_rad(game.camera_rig.pitch_degrees)
		await frames(8)
		await capture("06_squirrel")
	print("QA SUMMARY: %d checks, %d failures" % [checks, failures.size()])
	for failure in failures: print("FAILED: " + failure)
	paused = false
	game.queue_free()
	await frames(3)
	quit(0 if failures.is_empty() else 1)

func joy_button(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await frames(1)
	event = InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)
