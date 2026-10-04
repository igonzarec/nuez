extends Node
## Pausa automática para cualquier escena de trabajo con ExplorerPlayer.
## La partida principal ya tiene estados y utiliza la misma TrailUI.
var _scene: Node
var _ui: TrailUI
var _player: ExplorerPlayer
var _camera: TrailCamera
var _audio: TrailAudio
var _settings: Dictionary
var _store := TrailSave.new()
var _open := false
var _clock := 0.0
var _pixel_material: ShaderMaterial

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	TrailInput.install()
	_settings = _store.load_settings()

func _process(delta: float) -> void:
	_clock += delta
	if _clock < 0.25: return
	_clock = 0.0
	var scene := get_tree().current_scene
	if scene != _scene:
		if _open: get_tree().paused = false
		_open = false
		_scene = scene
		_player = null
		_camera = null
		_audio = null
		if is_instance_valid(_ui): _ui.queue_free()
		_ui = null
		_pixel_material = null
	if not scene or _is_main_game(scene): return
	if not is_instance_valid(_player):
		_discover(scene)
		if not _player: return
		_ui = TrailUI.new()
		_ui.layer = 30
		add_child(_ui)
		_ui.hud.hide()
		_ui.action.connect(_action)
		_ui.setting_changed.connect(_setting)
		_apply_settings()

func _is_main_game(scene: Node) -> bool:
	return scene.get_script() == load("res://scripts/game.gd")

func _discover(node: Node) -> void:
	if node is ExplorerPlayer: _player = node
	if node is TrailCamera: _camera = node
	if node is TrailAudio: _audio = node
	for child in node.get_children(): _discover(child)

func _input(event: InputEvent) -> void:
	if not is_instance_valid(_ui): return
	if event is InputEventKey and event.echo: return
	if event.is_action_pressed("pause") or (_open and event.is_action_pressed("ui_cancel")):
		if not _open:
			_open = true
			get_tree().paused = true
			_ui.pause_menu(true)
		elif _ui.panel_name == "controls":
			_ui.settings(_settings)
		elif _ui.panel_name == "settings":
			_save_settings()
			_ui.pause_menu(true)
		else:
			_resume()
		get_viewport().set_input_as_handled()

func _resume() -> void:
	_open = false
	_ui.close()
	get_tree().paused = false

func _action(command: String) -> void:
	if is_instance_valid(_audio): _audio.play("ui")
	match command:
		"resume": _resume()
		"settings", "controls_back": _ui.settings(_settings)
		"controls": _ui.controls_menu()
		"settings_back":
			_save_settings()
			_ui.pause_menu(true)
		"title":
			_save_settings()
			_resume()
			get_tree().change_scene_to_file("res://main.tscn")

func _setting(key: String, value: Variant) -> void:
	_settings[key] = value
	_apply_settings()
	if key == "pixel_size":
		if not _pixel_material:
			var finish := CanvasLayer.new()
			finish.layer = 1
			_scene.add_child(finish)
			var screen := ColorRect.new()
			screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_pixel_material = ShaderMaterial.new()
			_pixel_material.shader = preload("res://shaders/pixel_finish.gdshader")
			screen.material = _pixel_material
			finish.add_child(screen)
		_pixel_material.set_shader_parameter("pixel_size", value)

func _apply_settings() -> void:
	if is_instance_valid(_audio): _audio.apply(_settings)
	if is_instance_valid(_camera):
		_camera.sensitivity = _settings.sensitivity
		_camera.glide_forward_enabled = _settings.get("glide_forward_enabled", false)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if _settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func _save_settings() -> void:
	if not _store.write_json(_store.settings_path, _settings):
		_ui.toast("No se pudieron guardar los ajustes.")
