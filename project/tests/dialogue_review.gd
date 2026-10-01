extends SceneTree

var failures: Array[String] = []
var checks := 0
var visual := false

func _initialize() -> void:
	visual = "--visual" in OS.get_cmdline_user_args()
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("DIALOGUE FAIL: " + message)

func frames(count: int) -> void:
	for _i in count:
		await physics_frame
	await process_frame

func joy(button: JoyButton, pressed := true) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	await frames(2)

func capture(label: String) -> void:
	if not visual:
		return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://tests/captures")
	root.get_texture().get_image().save_png("res://tests/captures/" + label + ".png")

func run() -> void:
	var game: Variant = load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(4)
	game.start_game(false)
	await frames(8)
	var sign: TrailInteractable = null
	for item: Node in get_nodes_in_group("interactable"):
		if item is TrailInteractable and (item as TrailInteractable).interaction_id == "welcome":
			sign = item as TrailInteractable
			break
	check(sign != null, "El letrero del sendero está disponible para diálogo")
	if sign != null:
		check(sign.has_dialogue(), "El letrero usa un recurso .dialogue de Dialogue Manager")
		sign.show_prompt(true, false)
		check(sign.prompt_pin.visible and sign.prompt_label.text == "E", "El pin 3D muestra el atajo de teclado")
		game.player.position = TrailLevel.point(sign.global_position.x, sign.global_position.z + 1.1, 0.1)
		game.player.velocity = Vector3.ZERO
		game.camera_rig.snap()
		await frames(40)
		check(game.interaction.selected == sign, "La detección real selecciona el letrero cercano")
		game._set_device(true)
		await capture("interaction_prompt")
		await joy(JOY_BUTTON_A)
		check(game.state == game.State.DIALOGUE and game.player.velocity.y <= 0.1, "Cruz/A abre el diálogo cercano sin saltar")
		await joy(JOY_BUTTON_A, false)
		await joy(JOY_BUTTON_A)
		await joy(JOY_BUTTON_A, false)
		check(not game.dialogue_manager_balloon.dialogue_label.is_typing, "Cruz/A revela la línea completa")
		await capture("dialogue_choices")
		check(game.state == game.State.DIALOGUE and not game.player.control_enabled, "El diálogo bloquea el control de la ardilla")
		check(not paused, "El globo sigue procesando aunque el control esté bloqueado")
		check(is_instance_valid(game.dialogue_manager_balloon), "Dialogue Manager creó el globo personalizado")
		await joy(JOY_BUTTON_A)
		await joy(JOY_BUTTON_A, false)
		await joy(JOY_BUTTON_X)
		await joy(JOY_BUTTON_X, false)
		check(game.dialogue_manager_balloon.dialogue_line.text.begins_with("Explora"), "El mando elige la respuesta y continúa la rama")
		await capture("dialogue_balloon")
		await joy(JOY_BUTTON_B)
		await joy(JOY_BUTTON_B, false)
		await frames(3)
		check(game.state == game.State.PLAYING and game.player.control_enabled, "Cerrar diálogo restaura la exploración")
		await frames(15)
		await joy(JOY_BUTTON_X)
		await joy(JOY_BUTTON_X, false)
		check(game.state == game.State.DIALOGUE, "X de Xbox también abre el diálogo")
		await joy(JOY_BUTTON_X)
		await joy(JOY_BUTTON_X, false)
		await joy(JOY_BUTTON_B)
		await joy(JOY_BUTTON_B, false)
		game.open_dialogue("Mara", ["Soy Mara. Esta nevada nos tomó por sorpresa: los vecinos esperan arriba, sin una luz que los guíe.", "También funciona con páginas antiguas."])
		check(game.dialogue_manager_balloon.manual_mode, "Mara y páginas antiguas usan el mismo globo")
		await frames(3)
		await capture("dialogue_mara")
		var arrow: Polygon2D = game.dialogue_manager_balloon.get_node("Balloon/DialogueBox/ArrowAnchor/Progress")
		var arrow_start := arrow.position.y
		await frames(12)
		check(absf(arrow.position.y - arrow_start) > 0.1, "La flecha flota incluso durante el diálogo pausado")
		await joy(JOY_BUTTON_A)
		await joy(JOY_BUTTON_A, false)
		check(game.dialogue_manager_balloon.dialogue_label.text.begins_with("También"), "Cruz/A avanza las páginas antiguas")
		await joy(JOY_BUTTON_A)
		await joy(JOY_BUTTON_A, false)
		check(game.state == game.State.PLAYING, "La última página libera al jugador")
		game.player.position = TrailLevel.summit_spawn()
		game.player.velocity = Vector3.ZERO
		await frames(45)
		game.interaction.clear()
		game.interaction.enabled = false
		await joy(JOY_BUTTON_A)
		check(game.player.velocity.y > 0, "Fuera del contexto de interacción Cruz/A conserva el salto")
		await joy(JOY_BUTTON_A, false)
	print("DIALOGUE REVIEW: %d checks, %d failures" % [checks, failures.size()])
	game.queue_free()
	await frames(2)
	quit(0 if failures.is_empty() else 1)
