extends SceneTree

var game: Node

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame

func shot(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://tests/captures")
	root.get_texture().get_image().save_png("res://tests/captures/" + label + ".png")

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(8)
	await shot("title")
	game.start_game()
	await frames(30)
	var cam: Camera3D = game.camera_rig.camera
	var top := cam.unproject_position(game.player.global_position + Vector3.UP * 2.15)
	var bottom := cam.unproject_position(game.player.global_position)
	print("CAMERA FRAME: squirrel height=", absf(bottom.y - top.y) / root.size.y * 100, "% radius=", cam.global_position.distance_to(game.player.global_position + Vector3.UP * 1.15))
	await shot("trailhead")
	game.player.position = TrailLevel.point(0, -4, 0.1)
	game.player.reset_physics_interpolation()
	game.camera_rig.yaw = -PI * 0.65
	game.camera_rig.snap()
	await frames(30)
	await shot("summit")
	game.camera_rig.yaw = 0
	game.player.position = TrailLevel.point(4, 17)
	game.player.model.rotation.y = 0.35
	game.camera_rig.yaw = PI - 0.5
	game.camera_rig.pitch = deg_to_rad(game.camera_rig.pitch_degrees)
	await frames(20)
	game.ui.toast_time = 0
	await shot("squirrel")
	game.open_dialogue("Mara · guardiana del sendero", ["Soy Mara. Esta nevada nos tomó por sorpresa. Cada farol necesita tres semillas de luz. Cuando los tres brillen, vuelve conmigo."])
	await frames(2)
	await shot("dialogue")
	game._close_dialogue()
	game.pause_game()
	game._on_action("settings")
	await frames(2)
	await shot("settings")
	game.resume_game()
	game.camera_rig.pitch = deg_to_rad(game.camera_rig.pitch_degrees)
	game.camera_rig.yaw = -0.5
	game.player.position = TrailLevel.point(-15, 3, 0.1)
	game.player.reset_physics_interpolation()
	game.camera_rig.snap()
	await frames(30)
	game.ui.toast_time = 0
	await shot("gameplay")
	var timings: Array[float] = []
	var last_tick := Time.get_ticks_usec()
	for i in 120:
		await process_frame
		var tick := Time.get_ticks_usec()
		timings.append(float(tick - last_tick) / 1000.0)
		last_tick = tick
	timings.sort()
	print("RENDER METRICS: median_ms=", timings[60], " p95_ms=", timings[114], " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	paused = false
	game.queue_free()
	await frames(8)
	quit()
