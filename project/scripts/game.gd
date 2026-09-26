extends Node3D

enum State { TITLE, PLAYING, DIALOGUE, PAUSED, SETTINGS, ENDING, COMPLETE, CONFIRM }
var state := State.TITLE
var settings_return := State.TITLE
var level: TrailLevel
var player: ExplorerPlayer
var camera_rig: TrailCamera
var interaction: TrailInteraction
var ui: TrailUI
var audio: TrailAudio
var store := TrailSave.new()
var progress: Dictionary
var settings: Dictionary
var dialogue_pages: Array[String] = []
var dialogue_speaker := ""
var dialogue_finishes_game := false
var ending_time := 0.0
var autosave_time := 0.0
var using_gamepad := false
var save_failed := false
var pixel_material: ShaderMaterial

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	TrailInput.install()
	# QA uses isolated files, never the player's expedition.
	if "--qa" in OS.get_cmdline_user_args():
		store.save_path = "user://qa_expedition.json"
		store.settings_path = "user://qa_settings.json"
	settings = store.load_settings()
	audio = TrailAudio.new()
	add_child(audio)
	var finish := CanvasLayer.new()
	finish.layer = 1
	add_child(finish)
	var screen := ColorRect.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pixel_material = ShaderMaterial.new()
	pixel_material.shader = preload("res://shaders/pixel_finish.gdshader")
	screen.material = pixel_material
	finish.add_child(screen)
	ui = TrailUI.new()
	ui.layer = 10
	add_child(ui)
	ui.action.connect(_on_action)
	ui.setting_changed.connect(_on_setting)
	_build_session(store.fresh())
	_apply_settings()
	show_title()
	get_tree().auto_accept_quit = false

func _build_session(data: Dictionary) -> void:
	get_tree().paused = false
	if is_instance_valid(interaction):
		remove_child(interaction)
		interaction.queue_free()
	if is_instance_valid(level):
		remove_child(level)
		level.queue_free()
	progress = data.duplicate(true)
	level = load("res://scenes/mountain.tscn").instantiate() as TrailLevel
	level.name = "MountainTrail"
	add_child(level)
	player = load("res://scenes/player.tscn").instantiate() as ExplorerPlayer
	var checkpoint: Array = progress.checkpoint
	player.position = TrailLevel.point(float(checkpoint[0]), float(checkpoint[2]), 0.15)
	level.add_child(player)
	player.feedback.connect(audio.play)
	player.respawned.connect(func() -> void: ui.toast("De vuelta en un lugar seguro."))
	camera_rig = load("res://scenes/camera_rig.tscn").instantiate() as TrailCamera
	camera_rig.target = player
	level.add_child(camera_rig)
	player.camera_rig = camera_rig
	camera_rig.sensitivity = settings.sensitivity
	interaction = TrailInteraction.new()
	interaction.process_mode = Node.PROCESS_MODE_PAUSABLE
	interaction.player = player
	interaction.gamepad = using_gamepad
	add_child(interaction)
	interaction.selected_changed.connect(_on_target)
	for seed_node in level.seeds:
		seed_node.collected.connect(_on_seed)
	level.restore(progress)
	ui.update_hud(progress)
	autosave_time = 0

func _set_state(value: State) -> void:
	state = value
	var playing := state == State.PLAYING
	get_tree().paused = state not in [State.PLAYING, State.ENDING]
	player.set_controls(playing)
	camera_rig.enabled = playing
	interaction.enabled = playing
	if not playing:
		interaction.clear()
	# Keep the desktop cursor free in gameplay as well as menus.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.hud.visible = state in [State.PLAYING, State.PAUSED, State.DIALOGUE] or (state == State.SETTINGS and settings_return != State.TITLE)

func show_title() -> void:
	_set_state(State.TITLE)
	level.title_camera.make_current()
	ui.title(not store.load_progress().is_empty())

func start_game(continue_game := false) -> void:
	var data := store.load_progress() if continue_game else store.fresh()
	if data.is_empty():
		data = store.fresh()
	_build_session(data)
	ui.close()
	if progress.completed:
		_set_state(State.COMPLETE)
		level.title_camera.make_current()
		level.ending_walk(1)
		ui.completion(progress)
		return
	camera_rig.camera.make_current()
	_set_state(State.PLAYING)
	ui.toast("Lee el letrero junto al sendero y habla con Mara.")
	_save()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("pause") or (event.is_action_pressed("ui_cancel") and not event is InputEventKey):
		match state:
			State.PLAYING: pause_game()
			State.PAUSED: resume_game()
			State.DIALOGUE: _close_dialogue()
			State.SETTINGS: _settings_back()
			State.CONFIRM: show_title()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		if state == State.PLAYING:
			interact()
		elif state == State.DIALOGUE:
			advance_dialogue()
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if not is_instance_valid(ui) or not is_instance_valid(interaction):
		return
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.25):
		_set_device(true)
	elif event is InputEventKey or event is InputEventMouseButton:
		_set_device(false)

func _set_device(gamepad: bool) -> void:
	if using_gamepad == gamepad:
		return
	using_gamepad = gamepad
	ui.set_gamepad(gamepad)
	interaction.gamepad = gamepad
	if interaction.selected:
		interaction.selected.show_prompt(true, gamepad)
		_on_target(interaction.selected)

func _on_target(target: TrailInteractable) -> void:
	ui.prompt.text = target.prompt_text(using_gamepad) if target else ""

func interact() -> void:
	var target := interaction.selected
	if not is_instance_valid(target):
		audio.play("deny")
		return
	player.react("interact")
	if target is TrailLamp:
		restore_lamp(target)
	elif target.interaction_id == "mara":
		if progress.lamps.size() == 3:
			open_dialogue(target.display_name, ["¡Mira! Los tres faroles brillan otra vez. Nuestros vecinos ya pueden bajar sin perderse.", "Gracias por cuidar el camino, pequeña exploradora. Vamos al refugio: hay algo caliente esperándonos."], true)
		else:
			open_dialogue(target.display_name, ["Soy Mara. Esta nevada nos tomó por sorpresa: los vecinos esperan arriba, sin una luz que los guíe.", "Cada farol necesita tres semillas de luz. Las encontrarás junto al sendero y en rincones tranquilos. Cuando los tres brillen, vuelve conmigo."])
	else:
		open_dialogue(target.display_name, target.pages)

func restore_lamp(lamp: TrailLamp) -> bool:
	if state != State.PLAYING or lamp.is_lit:
		return false
	var balance: int = progress.collected.size() - progress.lamps.size() * 3
	if balance < lamp.seed_cost:
		ui.toast("Faltan %d semillas de luz. Busca los destellos del sendero." % (lamp.seed_cost - balance))
		audio.play("deny")
		return false
	progress.lamps.append(lamp.interaction_id)
	lamp.activate()
	var checkpoint := lamp.global_position + Vector3(0, 0, 2)
	checkpoint.y = TrailLevel.height_at(checkpoint.x, checkpoint.z) + 0.1
	player.spawn_position = checkpoint
	progress.checkpoint = [checkpoint.x, checkpoint.y, checkpoint.z]
	player.react("interact")
	audio.play("ignite")
	ui.update_hud(progress)
	ui.toast("Los tres faroles brillan. Vuelve con Mara." if progress.lamps.size() == 3 else lamp.display_name + " restaurado · un nuevo refugio de luz")
	interaction.clear()
	_save()
	return true

func _on_seed(seed_node: LightFragment) -> void:
	if state != State.PLAYING or progress.collected.has(seed_node.seed_id):
		return
	progress.collected.append(seed_node.seed_id)
	player.react("collect")
	audio.play("collect")
	ui.update_hud(progress)
	_save()

func open_dialogue(speaker: String, pages: Array, finishes := false) -> void:
	dialogue_speaker = speaker
	dialogue_pages.assign(pages)
	dialogue_finishes_game = finishes
	_set_state(State.DIALOGUE)
	_show_dialogue_page()

func _show_dialogue_page() -> void:
	if dialogue_pages.is_empty():
		_close_dialogue()
		return
	audio.play("ui")
	ui.dialogue(dialogue_speaker, dialogue_pages.pop_front())

func advance_dialogue() -> void:
	if state == State.DIALOGUE:
		_show_dialogue_page()

func _close_dialogue() -> void:
	ui.close()
	dialogue_pages.clear()
	if dialogue_finishes_game and progress.lamps.size() == 3:
		begin_ending()
	else:
		_set_state(State.PLAYING)

func pause_game() -> void:
	_save()
	_set_state(State.PAUSED)
	ui.pause_menu()
	audio.play("back")

func resume_game() -> void:
	ui.close()
	_set_state(State.PLAYING)

func begin_ending() -> void:
	if progress.lamps.size() != 3:
		return
	progress.completed = true
	_save()
	_set_state(State.ENDING)
	ending_time = 0
	level.title_camera.global_position = Vector3(12, 10, 32)
	level.title_camera.look_at(TrailLevel.point(-1, 21, 1))
	level.title_camera.make_current()
	level.ending_walk(0)
	audio.play("complete")

func _process(delta: float) -> void:
	# This node still processes on title/pause screens; hide the gameplay-only quad
	# immediately when another camera is current, even while its rig is paused.
	if camera_rig and camera_rig.blur_mesh:
		camera_rig.blur_mesh.visible = camera_rig.distant_blur_enabled and camera_rig.camera.is_current()
	if state == State.PLAYING:
		progress.elapsed += delta
		autosave_time += delta
		if autosave_time >= 15:
			autosave_time = 0
			_save()
	elif state == State.ENDING:
		ending_time += delta
		level.ending_walk(clampf(ending_time / 6.0, 0, 1))
		if ending_time >= 6.5:
			_set_state(State.COMPLETE)
			ui.completion(progress)

func _on_action(command: String) -> void:
	audio.play("ui")
	match command:
		"new":
			if store.load_progress().is_empty():
				start_game()
			else:
				_set_state(State.CONFIRM)
				ui.confirm_new()
		"confirm_new", "again": start_game()
		"cancel_new": show_title()
		"continue": start_game(true)
		"resume": resume_game()
		"title":
			_save()
			show_title()
		"settings":
			settings_return = state
			_set_state(State.SETTINGS)
			ui.settings(settings)
		"settings_back": _settings_back()
		"advance": advance_dialogue()
		"quit":
			get_tree().quit()

func _settings_back() -> void:
	if not store.write_json(store.settings_path, settings):
		ui.toast("No se pudieron guardar los ajustes en disco.")
	if settings_return == State.TITLE:
		show_title()
	else:
		_set_state(State.PAUSED)
		ui.pause_menu()

func _on_setting(key: String, value: Variant) -> void:
	settings[key] = value
	_apply_settings()

func _apply_settings() -> void:
	audio.apply(settings)
	pixel_material.set_shader_parameter("pixel_size", settings.get("pixel_size", 2.0))
	camera_rig.sensitivity = settings.sensitivity
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)

func _save() -> void:
	save_failed = not store.write_json(store.save_path, progress)
	if save_failed:
		ui.toast("No se pudo guardar en disco. Tu partida sigue activa.")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if state not in [State.TITLE, State.CONFIRM] and not progress.is_empty():
			_save()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == State.PLAYING and not "--qa" in OS.get_cmdline_user_args():
		pause_game()
