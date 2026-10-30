extends Node
## Menú de pausa único para cualquier escena con ExplorerPlayer: partida principal y escenas de trabajo.
## Gestiona pausa, ajustes, controles, vestuario y reinicio rápido, y es la única fuente de ajustes.
## Una escena puede registrarse como anfitrión con attach_host() para decidir cuándo se puede pausar
## y qué hacen "Volver al título" y "Reinicio rápido". Métodos opcionales del anfitrión:
## pause_allowed(), pause_opened(), pause_closed(), pause_to_title(), pause_fast_reset().

var settings: Dictionary
var store := TrailSave.new()
var host: Node
var _scene: Node
var _ui: TrailUI
var _player: ExplorerPlayer
var _camera: TrailCamera
var _audio: TrailAudio
var _hat_choice: CanvasLayer
var _hat_from_pause := false
var _hat_origin := ""
var _hat_equip: TrailSoundCue
var _hat_unequip: TrailSoundCue
var _hat_audio: AudioStreamPlayer
var _open := false
var _from_title := false
var _clock := 0.0
var _pixel_layer: CanvasLayer
var _pixel_material: ShaderMaterial

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	TrailInput.install()
	# QA usa archivos aislados, nunca los ajustes del jugador.
	if "--qa" in OS.get_cmdline_user_args():
		store.save_path = "user://qa_expedition.json"
		store.settings_path = "user://qa_settings.json"
	settings = store.load_settings()

## Registra la escena principal como anfitrión. Crea la interfaz y el acabado pixelado al instante.
func attach_host(scene: Node) -> void:
	_reset()
	_scene = scene
	host = scene
	_build_ui()
	_ensure_pixel_finish()
	refresh()

## Vuelve a buscar jugador, cámara y audio (p. ej. tras reconstruir la sesión) y aplica los ajustes.
func refresh() -> void:
	_player = null
	_camera = null
	_audio = null
	if is_instance_valid(_scene): _discover(_scene)
	_apply_settings()

func is_open() -> bool:
	return _open

## Reproduce un efecto con el TrailAudio de la escena (respeta volúmenes de Ajustes). False si no hay TrailAudio.
func play_cue(cue: TrailSoundCue) -> bool:
	if not is_instance_valid(_audio): return false
	_audio.play_cue(cue)
	return true

func _process(delta: float) -> void:
	_clock += delta
	if _clock < 0.25: return
	_clock = 0.0
	var scene := get_tree().current_scene
	if scene and scene != _scene:
		_reset()
		_scene = scene
	if not scene or host or is_instance_valid(_player): return
	_discover(scene)
	if not _player: return
	_build_ui()
	_apply_settings()

func _reset() -> void:
	if is_instance_valid(_hat_choice):
		_hat_choice.queue_free()
		_hat_choice = null
	if _open: get_tree().paused = false
	_open = false
	_from_title = false
	host = null
	_scene = null
	_player = null
	_camera = null
	_audio = null
	if is_instance_valid(_ui): _ui.queue_free()
	_ui = null
	if is_instance_valid(_pixel_layer): _pixel_layer.queue_free()
	_pixel_layer = null
	_pixel_material = null

func _build_ui() -> void:
	if is_instance_valid(_ui): return
	_ui = TrailUI.new()
	_ui.layer = 30
	add_child(_ui)
	_ui.hud.hide()
	_ui.action.connect(_action)
	_ui.setting_changed.connect(set_setting)

func _discover(node: Node) -> void:
	if node is ExplorerPlayer and not is_instance_valid(node.command_source) and not _player: _player = node
	if node is TrailCamera and not _camera: _camera = node
	if node is TrailAudio and not _audio: _audio = node
	for child in node.get_children(): _discover(child)

func _pause_allowed() -> bool:
	if get_tree().get_first_node_in_group("active_dialogue"): return false
	if host and host.has_method("pause_allowed"): return host.pause_allowed()
	return is_instance_valid(_player) and not get_tree().get_first_node_in_group("active_dialogue")

func _input(event: InputEvent) -> void:
	if is_instance_valid(_hat_choice): return
	if not is_instance_valid(_ui): return
	if event is InputEventKey and event.echo: return
	if not _open:
		# Esc / Start abren; en mando, círculo / B también, como en la partida principal.
		var opens := event.is_action_pressed("pause") or (event is InputEventJoypadButton and event.is_action_pressed("ui_cancel"))
		if not opens or not _pause_allowed(): return
		open()
	elif event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_back()
	else:
		return
	get_viewport().set_input_as_handled()

## Abre la pausa. El anfitrión, si existe, decide su estado y pausa el árbol.
func open() -> void:
	if _open or not is_instance_valid(_ui): return
	_open = true
	_from_title = false
	if host and host.has_method("pause_opened"): host.pause_opened()
	else: get_tree().paused = true
	_show_pause()

## Abre los ajustes fuera de la pausa (pantalla de título). Al volver avisa con pause_closed().
func open_settings() -> void:
	if not is_instance_valid(_ui): return
	_open = true
	_from_title = true
	_ui.settings(_appearance_menu_values())

func resume() -> void:
	if not _open: return
	_open = false
	_from_title = false
	_ui.close()
	if host and host.has_method("pause_closed"): host.pause_closed()
	else: get_tree().paused = false

func _back() -> void:
	match _ui.panel_name:
		"controls": _ui.settings(_appearance_menu_values())
		"settings":
			_save_settings()
			if _from_title: resume()
			else: _show_pause()
		_: resume()

func _show_pause(focus_command := "") -> void:
	var extras: Array = []
	for item_id in TrailWardrobe.owned_items():
		var verb := "Quitarse" if TrailWardrobe.is_equipped(item_id) else "Ponerse"
		extras.append(["%s el %s" % [verb, TrailWardrobe.display_name(item_id)], "wardrobe:" + item_id])
	_ui.pause_menu(extras)
	if _ui.buttons.has(focus_command): _ui.buttons[focus_command].grab_focus()

func _action(command: String) -> void:
	if is_instance_valid(_audio): _audio.play("ui")
	if command == "wardrobe:christmas_hat":
		open_hat_choice()
		return
	if command.begins_with("wardrobe:"):
		TrailWardrobe.toggle(command.trim_prefix("wardrobe:"))
		_show_pause(command)
		return
	match command:
		"resume": resume()
		"fast_reset":
			resume()
			if host and host.has_method("pause_fast_reset"): host.pause_fast_reset()
			elif is_instance_valid(_player): _player.respawn()
		"settings", "controls_back": _ui.settings(_appearance_menu_values())
		"controls": _ui.controls_menu()
		"settings_back": _back()
		"title":
			_save_settings()
			if host and host.has_method("pause_to_title"):
				_open = false
				_ui.close()
				host.pause_to_title()
			else:
				resume()
				get_tree().change_scene_to_file("res://main.tscn")

func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	if key == "pixel_size": _ensure_pixel_finish()
	_apply_settings(key in ["resolution", "fullscreen"])

## Las escenas de trabajo sólo crean el acabado pixelado si se ajusta desde el menú.
func _ensure_pixel_finish() -> void:
	if _pixel_material: return
	_pixel_layer = CanvasLayer.new()
	_pixel_layer.layer = 1
	add_child(_pixel_layer)
	var screen := ColorRect.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pixel_material = ShaderMaterial.new()
	_pixel_material.shader = preload("res://shaders/pixel_finish.gdshader")
	screen.material = _pixel_material
	_pixel_layer.add_child(screen)

func _apply_settings(update_display := true) -> void:
	if is_instance_valid(_audio): _audio.apply(settings)
	else:
		# Las escenas ligeras también respetan SFX/Master para el selector.
		if AudioServer.get_bus_index("SFX") < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
		for pair in [["Master", "master"], ["SFX", "sfx"]]:
			var index := AudioServer.get_bus_index(pair[0])
			AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.0001, settings[pair[1]])))
			AudioServer.set_bus_mute(index, settings[pair[1]] <= 0.001)
	if is_instance_valid(_camera):
		_camera.apply_appearance_settings(settings)
		_camera.sensitivity = settings.sensitivity
		_camera.glide_forward_enabled = settings.get("glide_forward_enabled", false)
	if _pixel_material: _pixel_material.set_shader_parameter("pixel_size", settings.get("pixel_size", 2.0))
	if update_display:
		# Godot termina la configuración inicial de ventana después de _ready.
		TrailDisplay.apply.call_deferred(settings)

func _save_settings() -> void:
	if not store.write_json(store.settings_path, settings):
		push_warning("No se pudieron guardar los ajustes en disco.")

func _appearance_menu_values() -> Dictionary:
	var values := settings.duplicate()
	if is_instance_valid(_camera): values.merge(_camera.appearance_settings(), true)
	return values

## Abre el selector exclusivo desde pickup o vestuario; conserva quién era dueño de la pausa.
func open_hat_choice(origin := "", equip_cue: TrailSoundCue = null, unequip_cue: TrailSoundCue = null) -> void:
	if is_instance_valid(_hat_choice) or not is_instance_valid(_player): return
	if not _open and (get_tree().paused or not _pause_allowed()): return
	if _open and _ui.panel_name != "pause": return
	_hat_from_pause = _open
	_hat_origin = origin
	configure_hat_audio(equip_cue, unequip_cue)
	if not _hat_equip: _hat_equip = preload("res://resources/accessories/green_hat_equip_sound.tres")
	if not _hat_unequip: _hat_unequip = preload("res://resources/accessories/green_hat_unequip_sound.tres")
	_player.consume_interaction_press()
	if not _open:
		_open = true
		if host and host.has_method("pause_opened"): host.pause_opened()
		else: get_tree().paused = true
	for selector in get_tree().get_nodes_in_group("interaction_controllers"): selector.clear()
	_ui.close()
	_hat_choice = preload("res://ui/accessories/hat_choice.tscn").instantiate()
	_hat_choice.chosen.connect(_hat_chosen)
	_hat_choice.cancelled.connect(_close_hat_choice)
	add_child.call_deferred(_hat_choice)

func _hat_chosen(equipped: bool) -> void:
	if not TrailWardrobe.set_hat_equipped(equipped, _hat_origin):
		_hat_choice.show_save_error()
		return
	var cue := _hat_equip if equipped else _hat_unequip
	if cue and cue.enabled and cue.stream and not play_cue(cue):
		if not is_instance_valid(_hat_audio):
			_hat_audio = AudioStreamPlayer.new()
			_hat_audio.bus = "SFX"
			add_child(_hat_audio)
		_hat_audio.stream = cue.stream
		_hat_audio.volume_db = cue.volume_db
		_hat_audio.pitch_scale = cue.pitch_scale
		_hat_audio.play()
	_close_hat_choice()

func _close_hat_choice() -> void:
	if is_instance_valid(_hat_choice):
		_hat_choice.queue_free()
		_hat_choice = null
	if is_instance_valid(_player): _player.consume_interaction_press()
	if _hat_from_pause: _show_pause("wardrobe:christmas_hat")
	else: resume()

## Conserva los recursos del origen autorizado también para quitar desde el menú de pausa.
func configure_hat_audio(equip_cue: TrailSoundCue, unequip_cue: TrailSoundCue) -> void:
	if equip_cue: _hat_equip = equip_cue
	if unequip_cue: _hat_unequip = unequip_cue
