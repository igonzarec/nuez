extends SceneTree
## Isolated art-review viewport, independent of the fixed gameplay camera.

var actor: ExplorerPlayer

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	TrailInput.install()
	root.size = Vector2i(720, 720)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	shape.shape = box
	shape.position.y = -0.5
	ground.add_child(shape)
	root.add_child(ground)
	actor = load("res://scenes/player.tscn").instantiate()
	root.add_child(actor)
	var camera := Camera3D.new()
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	root.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.0
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -25, 0)
	root.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("8eaba4")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.65
	root.add_child(environment)
	for i in 25: await physics_frame
	Input.action_press("move_forward")
	Input.action_press("sprint")
	for i in 25: await physics_frame
	DirAccess.make_dir_recursive_absolute("res://tests/captures")
	for i in 6:
		for frame in 3: await physics_frame
		if DisplayServer.get_name() == "headless": continue
		camera.position = actor.position + Vector3(3.2, 1.9, -4.2)
		camera.look_at(actor.position + Vector3(0, 1.0, 0.3))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/captures/run_pose_%d.png" % i)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	for i in 50: await physics_frame
	var animator := actor.animator
	var configured_arm_spread := animator.arm_spread_degrees
	assert(animator.run_blend < 0.01)
	assert(actor.model.skeleton.get_bone_count() == 15)
	# Inspector controls should independently suppress arm swing at runtime.
	animator.left_arm_multiplier = 0
	animator.right_arm_multiplier = 0
	animator.arm_spread_degrees = 0
	Input.action_press("move_forward")
	for i in 45: await physics_frame
	for bone in ["arm_left", "arm_right"]:
		var pose: Quaternion = actor.model.current_rotations[actor.model.bone_indices[bone]]
		assert(absf(pose.get_euler().x) < 0.01)
	animator.left_arm_multiplier = 1
	animator.right_arm_multiplier = 1
	animator.arm_spread_degrees = configured_arm_spread
	for i in 35: await physics_frame
	var left_run_pose: Vector3 = actor.model.current_rotations[actor.model.bone_indices["arm_left"]].get_euler()
	var right_run_pose: Vector3 = actor.model.current_rotations[actor.model.bone_indices["arm_right"]].get_euler()
	assert(is_equal_approx(left_run_pose.x, -right_run_pose.x), "Run arm swing remains mirrored")
	assert(is_equal_approx(left_run_pose.z, -right_run_pose.z), "Shoulder spread remains mirrored")
	Input.action_release("move_forward")
	for i in 45: await physics_frame
	for pose_name in ["rest", "rise", "fall"]:
		if "--stress-arms" in OS.get_cmdline_user_args():
			animator.arm_air_lift_degrees = 150
			animator.arm_air_drop = 0.08
			animator.arm_air_stretch = 0.15
			animator.arm_air_response = 25
		if pose_name == "rise":
			Input.action_press("jump")
			for i in 10: await physics_frame
			Input.action_release("jump")
		elif pose_name == "fall":
			for i in 29: await physics_frame
		actor.set_physics_process(false)
		if DisplayServer.get_name() == "headless":
			actor.set_physics_process(true)
			continue
		print("POSE ", pose_name, " state=", actor.animation_state, " vy=", actor.velocity.y, " arm=", actor.model.current_rotations[2].get_euler())
		camera.position = actor.position + Vector3(4.5, 1.6, 0.1)
		camera.look_at(actor.position + Vector3(0, 1.05, 0.25))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/captures/tail_" + pose_name + ".png")
		if pose_name == "fall":
			camera.position = actor.position + Vector3(1.0, 1.5, -4.5)
			camera.look_at(actor.position + Vector3(0, 1.05, 0))
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://tests/captures/arms_falling.png")
		actor.set_physics_process(true)
	print("ANIMATION REVIEW: idle recovery, independent arm controls, and outward mirrored run poses passed")
	actor.queue_free()
	await process_frame
	quit()
