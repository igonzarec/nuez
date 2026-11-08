@tool
extends EditorPlugin
## Boton "Seleccionar cliff" en la barra de la vista 3D, visible con CliffFolds (o un CliffZone suyo) seleccionado.
## Activo: clic = seleccionar el cliff bajo el cursor (en el suelo sin cliff cercano, vacia la seleccion),
## Shift+clic = anadir/quitar, Esc = salir. Alt, clic derecho y central siguen navegando. Los botones del
## Inspector de CliffFolds regeneran o restauran la seleccion.

var _generator: Node3D
var _bar: HBoxContainer
var _pick: Button
var _status: Label
var _clicks := 0

func _enter_tree() -> void:
	# Other plugins (Terrain3D) may take the "visible" slot while CliffFolds stays selected: keep receiving clicks.
	set_input_event_forwarding_always_enabled()
	_bar = HBoxContainer.new()
	_pick = Button.new()
	_pick.text = "Seleccionar cliff"
	_pick.toggle_mode = true
	_pick.tooltip_text = "Clic: seleccionar el cliff bajo el cursor (clic en suelo sin cliff: vaciar). Shift+clic: anadir o quitar. Esc: salir.\n" + \
		"Luego usa Regenerar seleccion o Restaurar seleccion en el Inspector de CliffFolds."
	_bar.add_child(_pick)
	_status = Label.new()
	_bar.add_child(_status)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, _bar)
	_bar.visible = false

func _exit_tree() -> void:
	if is_instance_valid(_bar):
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, _bar)
		_bar.queue_free()

# Duck typing instead of class names: the plugin loads before a fresh project has scanned its global classes.
func _is_generator(object: Object) -> bool:
	return object is Node3D and object.has_method("pick") and object.has_method("regenerate_selection")

func _is_zone(object: Object) -> bool:
	return object is Node3D and object.has_method("contains_xz") and _is_generator(object.get_parent())

func _handles(object: Object) -> bool:
	return _is_generator(object) or _is_zone(object)

func _edit(object: Object) -> void:
	if object == null:
		return
	if _is_zone(object):
		object = object.get_parent()
	_generator = object as Node3D

func _make_visible(visible: bool) -> void:
	if visible:
		_bar.visible = true
		return
	# Hidden only when CliffFolds (or its zone) is really no longer selected, not when another plugin shows its panel.
	if not _generator_selected():
		_bar.visible = false
		_pick.button_pressed = false
		_status.text = ""
		_generator = null

func _generator_selected() -> bool:
	if not is_instance_valid(_generator):
		return false
	for node in EditorInterface.get_selection().get_selected_nodes():
		if node == _generator or (_is_zone(node) and node.get_parent() == _generator):
			return true
	return false

func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if not _pick.button_pressed or not _generator_selected():
		return AFTER_GUI_INPUT_PASS
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_pick.button_pressed = false
		_status.text = ""
		return AFTER_GUI_INPUT_STOP
	if Input.is_key_pressed(KEY_ALT):
		return AFTER_GUI_INPUT_PASS
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return AFTER_GUI_INPUT_PASS
	if not event.pressed:
		return AFTER_GUI_INPUT_STOP
	var mouse_position: Vector2 = event.position
	var container := camera.get_parent().get_parent()
	if container is SubViewportContainer:
		mouse_position /= float(container.stretch_shrink)
	var terrain = _generator.get("terrain")
	if is_instance_valid(terrain):
		terrain.set_camera(camera)
	_clicks += 1
	_status.text = "[%d] %s" % [_clicks, _generator.pick(camera.project_ray_origin(mouse_position),
		camera.project_ray_normal(mouse_position), event.shift_pressed)]
	return AFTER_GUI_INPUT_STOP
