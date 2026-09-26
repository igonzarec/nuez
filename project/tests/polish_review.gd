extends SceneTree
## New regression coverage: elastic tail, steep slides, and post-effect lifecycle.
var game: Node
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for i in count: await physics_frame
	await process_frame

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
	print(("PASS: " if condition else "FAIL: ") + message)

func box(position: Vector3, size: Vector3, angle := 0.0) -> void:
	var body := StaticBody3D.new()
	body.position = position
	body.rotation.x = deg_to_rad(angle)
	var shape := CollisionShape3D.new()
	var geometry := BoxShape3D.new()
	geometry.size = size
	shape.shape = geometry
	body.add_child(shape)
	game.level.add_child(body)

func place(position: Vector3) -> void:
	game.player.position = position
	game.player.velocity = Vector3.ZERO
	game.player.previous_motion = Vector3.ZERO
	game.player.slide_velocity = Vector3.ZERO
	game.player.jump_consumed = false
	game.player.animator.reset()
	game.player.reset_physics_interpolation()
	game.camera_rig.yaw = 0
	game.camera_rig.snap()
	await frames(1)

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	game.start_game(false)
	# Fixed test calibration only: never overwrite the user's saved Inspector values.
	game.player.animator.arm_air_lift_degrees = 110
	game.player.animator.arm_air_drop = 0.035
	game.player.animator.arm_air_stretch = 0.08
	game.player.animator.arm_air_response = 12
	game.player.animator.tail_air_drop = 0.16
	game.player.animator.tail_air_stretch = 0.16
	game.player.animator.tail_air_response = 12
	box(Vector3(100, -0.5, 0), Vector3(80, 1, 80))
	box(Vector3(100, 12, 0), Vector3(12, 0.4, 20), 55)
	await place(Vector3(100, 12.75, 0))
	await frames(15)
	check(game.player.is_sliding and game.player.animation_state == "slide", "55-degree contact enters slide, not airborne/run loop")
	var initial: Vector3 = game.player.position
	var peak_speed := 0.0
	var contacts := 0
	var uphill_frames := 0
	Input.action_press("move_forward")
	for i in 60:
		await frames(1)
		peak_speed = maxf(peak_speed, game.player.get_real_velocity().length())
		if game.player.is_sliding: contacts += 1
		if game.player.velocity.y > 0.05: uphill_frames += 1
	Input.action_release("move_forward")
	check(game.player.position.y < initial.y - 1 and game.player.position.z > initial.z + 0.5, "Uphill input cannot climb an unwalkable slope")
	check(contacts >= 58 and uphill_frames == 0, "Slide maintains support without bouncing")
	check(peak_speed < game.player.slide_max_speed + 0.3, "Slide remains gently speed-limited")
	var side_start: float = game.player.position.x
	Input.action_press("move_right")
	await frames(20)
	Input.action_release("move_right")
	check(game.player.position.x > side_start + 0.1, "Player retains restrained sideways steering during slide")
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	check(game.player.velocity.y > 7 and not game.player.is_sliding, "Jump immediately releases steep-slope contact")
	await frames(270)
	check(game.player.is_on_floor() and not game.player.is_sliding, "Slide/fall recovers stable flat-ground control")
	await place(Vector3(120, 0.08, 0))
	await frames(35)
	var idle_position: Vector3 = game.player.position
	await frames(45)
	check(game.player.position.distance_to(idle_position) < 0.005, "Slide feature introduces no flat-ground idle drift")
	Input.action_press("jump")
	await frames(10)
	Input.action_release("jump")
	var rig: SquirrelRig = game.player.model
	var tip: int = rig.bone_indices["tail_tip"]
	var rest := rig.skeleton.get_bone_rest(tip).origin
	var forearm: int = rig.bone_indices["forearm_left"]
	var arm_rest := rig.skeleton.get_bone_rest(forearm).origin
	check(rig.current_positions[forearm].y < arm_rest.y - 0.005 and rig.current_scales[forearm].y > 1.01, "Arms dip and stretch on ascent")
	var shoulder: int = rig.bone_indices["arm_left"]
	var rising_spread := rig.current_rotations[shoulder].get_euler().z
	check(game.player.animator.tail_flex > 0.2 and rig.current_positions[tip].y < rest.y - 0.03, "Large tail curl dips during upward jump")
	check(rig.current_scales[tip].z > 1.02 and rig.current_scales[tip].y < 0.99, "Rising tail stretches and squashes, not rotation alone")
	check(absf(rig.current_scales[tip].x * rig.current_scales[tip].y * rig.current_scales[tip].z - 1.0) < 0.05, "Tail deformation approximately preserves volume")
	await frames(29)
	check(rig.current_positions[forearm].y > arm_rest.y + 0.005 and rig.current_scales[forearm].y > 1.01, "Arms lift and stretch on descent")
	var falling_angle := rig.current_rotations[shoulder].get_euler().z
	check(falling_angle < rising_spread - 0.1 and falling_angle < -PI / 2, "Left shoulder opens outward above horizontal while falling")
	var right_shoulder: int = rig.bone_indices["arm_right"]
	check(rig.current_rotations[right_shoulder].get_euler().z > PI / 2, "Right shoulder mirrors the raised falling pose")
	check(absf(rig.current_rotations[forearm].get_euler().x) < deg_to_rad(12), "Falling elbows extend rather than curl inward")
	check(game.player.animator.arms_falling and game.player.animator.arm_fall_blend > 0.9, "Raised arms remain active until landing")
	check(game.player.animator.tail_flex < -0.2 and rig.current_positions[tip].y > rest.y + 0.03, "Large tail curl rises during falling")
	check(rig.current_scales[tip].z < 0.98 and rig.current_scales[tip].y > 1.01, "Falling tail reverses elastic deformation")
	await frames(60)
	check(rig.current_positions[forearm].distance_to(arm_rest) < 0.001 and rig.current_scales[forearm].distance_to(Vector3.ONE) < 0.001, "Elastic arms settle after landing")
	check(not game.player.animator.arms_falling and absf(rig.current_rotations[shoulder].get_euler().z) < 0.01, "Shoulders return to their natural pose after ground contact")
	check(rig.current_positions[tip].distance_to(rest) < 0.001 and rig.current_scales[tip].distance_to(Vector3.ONE) < 0.001, "Tail settles back to rest after landing")
	game.camera_rig.distant_blur_enabled = false
	# Drive measured turn rate directly to isolate the secondary-motion response.
	game.player.set_physics_process(false)
	game.player.angular_velocity = 6.0
	for i in 40: game.player.animator.tick(1.0 / 60.0, 0)
	check(rig.current_positions[tip].x < rest.x - 0.08, "Heavy tail tip lags opposite a left turn")
	game.player.angular_velocity = -6.0
	for i in 40: game.player.animator.tick(1.0 / 60.0, 0)
	check(rig.current_positions[tip].x > rest.x + 0.08, "Tail pull reverses on a right turn")
	check(absf(game.player.animator.tail_lateral) <= game.player.animator.tail_turn_pull, "Lateral tail deformation stays within its limit")
	game.player.angular_velocity = 0.0
	for i in 180: game.player.animator.tick(1.0 / 60.0, 0)
	check(absf(game.player.animator.tail_lateral) < 0.001, "Tail settles to center after turning stops")
	game.player.set_physics_process(true)
	await frames(2)
	check(not game.camera_rig.blur_mesh.visible, "Inspector can disable distant blur")
	game.camera_rig.distant_blur_enabled = true
	await frames(2)
	check(game.camera_rig.blur_mesh.visible, "Distant blur is active in gameplay")
	game.pause_game()
	await frames(2)
	check(game.camera_rig.blur_mesh.visible, "Pause preserves the same camera effect")
	game.show_title()
	await frames(2)
	check(not game.camera_rig.blur_mesh.visible, "Gameplay post-effect is hidden on title camera while paused")
	print("POLISH SUMMARY: %d checks, %d failures" % [checks, failures.size()])
	paused = false
	game.queue_free()
	await frames(3)
	quit(0 if failures.is_empty() else 1)
