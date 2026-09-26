extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for i in count: await physics_frame
	await process_frame

func run() -> void:
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(5)
	game.start_game(false)
	await frames(30)
	game.player.position = TrailLevel.point(-15, 3, 0.1)
	game.camera_rig.yaw = -0.5
	game.camera_rig.snap()
	await frames(45)
	game.pause_game()
	game.ui.visible = false
	var pictures: Array[Image] = []
	for enabled in [false, true]:
		game.camera_rig.distant_blur_enabled = enabled
		await frames(3)
		await RenderingServer.frame_post_draw
		var picture := root.get_texture().get_image()
		pictures.append(picture)
		picture.save_png("res://tests/captures/blur_%s.png" % ("on" if enabled else "off"))
	# Player and nearby path should retain identical color/exposure, not just detail.
	var error := 0.0
	for y in range(350, 440):
		for x in range(540, 740):
			var a := pictures[0].get_pixel(x, y)
			var b := pictures[1].get_pixel(x, y)
			error += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
	error /= 200 * 90 * 3
	print("BLUR REVIEW: near-field mean color error=", error)
	game.ui.visible = true
	game.resume_game()
	await frames(10)
	game.queue_free()
	await frames(10)
	quit(0 if error < 0.015 else 1)
