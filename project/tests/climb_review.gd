extends SceneTree
var game: Node
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame

func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok:
		failures.append(message)

func shot(label: String, eye: Vector3, focus: Vector3) -> void:
	if not "--visual" in OS.get_cmdline_user_args():
		return
	var camera := Camera3D.new()
	game.level.add_child(camera)
	camera.global_position = eye
	camera.look_at(focus)
	camera.make_current()
	game.ui.hud.hide()
	await frames(3)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://tests/captures")
	root.get_texture().get_image().save_png("res://tests/captures/" + label + ".png")
	camera.queue_free()
	game.camera_rig.camera.make_current()

func place(at: Vector3, facing: float = 0.0) -> void:
	Input.action_release("jump")
	Input.action_release("move_forward")
	game.player.spawn_position = at
	game.player.respawn()
	game.player.model.rotation.y = facing
	game.camera_rig.yaw = 0.0
	game.camera_rig.snap()
	await frames(20)

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	game.start_game(false)
	await shot("cliff_overview", Vector3(66, 44, 10), Vector3(0, 23, -49))
	await place(Vector3(0, 0.1, -46.0))
	Input.action_press("jump")
	await frames(4)
	check(not game.player.is_gliding, "Mantener salto no inicia Glide")
	Input.action_press("move_forward")
	await frames(35)
	check(game.player.is_climbing, "Salto sostenido se ancla automáticamente al llegar de frente")
	check(not game.player.is_gliding, "Agarre tiene prioridad sobre Glide")
	var start_y: float = game.player.position.y
	await frames(60)
	check(game.player.position.y > start_y + 2.0, "Escala verticalmente con el stick")
	Input.action_release("move_forward")
	var hang_y: float = game.player.position.y
	await frames(30)
	check(absf(game.player.position.y - hang_y) < 0.05, "Mantiene altura en reposo")
	await shot("cliff_grip", game.player.global_position + Vector3(4, 2, 6), game.player.global_position + Vector3.UP)
	check(not game.player.model.glide_membranes[0].visible, "Membranas ocultas durante escalada")
	Input.action_press("move_right")
	var side_x: float = game.player.position.x
	await frames(15)
	Input.action_release("move_right")
	check(game.player.position.x > side_x + 0.4, "Desplazamiento lateral sobre la pared")
	Input.action_press("move_back")
	var down_y: float = game.player.position.y
	await frames(15)
	Input.action_release("move_back")
	check(game.player.position.y < down_y - 0.4, "Puede bajar sin desprenderse")
	game.pause_game()
	var paused_position: Vector3 = game.player.position
	await frames(10)
	check(game.player.position.is_equal_approx(paused_position), "Pausa conserva el agarre")
	game.resume_game()
	Input.action_release("jump")
	await frames(5)
	check(not game.player.is_climbing and game.player.velocity.y < 0, "Soltar desprende y vuelve a aplicar gravedad")
	Input.action_press("jump")
	await frames(2)
	check(game.player.is_gliding, "Nueva pulsación tras soltar activa Glide")
	await place(Vector3(0, 0.1, -47.3), PI / 2.0)
	Input.action_press("jump")
	await frames(10)
	check(not game.player.is_climbing, "No se agarra mirando de lado")
	await place(Vector3(0, 0.1, -47.4))
	Input.action_press("jump")
	Input.action_press("move_forward")
	await frames(1110)
	check(game.player.position.y > 51.9 and game.player.position.z < -48.3, "Sale por el borde a la cima nevada")
	check(not game.player.is_climbing, "Termina escalada sobre la cima")
	Input.action_release("jump")
	Input.action_release("move_forward")
	await frames(10)
	check(game.player.is_on_floor(), "La cima tiene suelo sólido")
	check(game.audio.sounds.has("climb") and game.audio.sounds.climb.data != game.audio.sounds.step.data, "Escalada usa audio distinto de los pasos")
	await place(Vector3(0, 12, -47.4))
	Input.action_press("jump")
	await frames(3)
	game._fast_reset_to_summit()
	await frames(1)
	check(not game.player.is_climbing and not game.player.model.climb_active, "Fast reset cancela agarre y postura")
	Input.action_release("jump")
	print("CLIMB REVIEW failures: ", failures)
	game.queue_free()
	await frames(2)
	quit(0 if failures.is_empty() else 1)
