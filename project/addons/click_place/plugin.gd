@tool
extends EditorPlugin
## Boton "Colocar con clic" en la barra de la vista 3D. Activo: clic izquierdo = mueve los nodos 3D seleccionados al punto
## del terreno o de la malla bajo el cursor (varios a la vez conservan su separacion). Esc = salir. Clic derecho, central y
## Alt siguen navegando. Ctrl+Z deshace. Guia: docs/click_place.md.

const Ray := preload("res://addons/click_place/click_place_ray.gd")
const META := "click_place"

var _bar: HBoxContainer
var _place: Button
var _keep_height: CheckBox
var _meshes: CheckBox
var _offset: SpinBox
var _status: Label

func _enter_tree() -> void:
	# Before the other 3D tools: while active the click must not add a Path3D point or paint.
	set_input_event_forwarding_always_enabled()
	var settings := EditorInterface.get_editor_settings()
	_bar = HBoxContainer.new()
	_place = Button.new()
	_place.text = "Colocar con clic"
	_place.toggle_mode = true
	_place.tooltip_text = "Clic izquierdo: mueve lo seleccionado a ese punto del terreno o la malla. Esc: salir.\nClic derecho, central y Alt siguen navegando. Ctrl+Z deshace."
	_place.toggled.connect(_on_place_toggled)
	_bar.add_child(_place)
	_keep_height = CheckBox.new()
	_keep_height.text = "Conservar altura"
	_keep_height.tooltip_text = "Solo cambia X y Z; la altura del nodo no se toca. Util para un WaterLake, cuya Y es el nivel del agua."
	_keep_height.button_pressed = settings.get_project_metadata(META, "keep_height", false)
	_keep_height.toggled.connect(func(on: bool) -> void: settings.set_project_metadata(META, "keep_height", on))
	_bar.add_child(_keep_height)
	_meshes = CheckBox.new()
	_meshes.text = "Mallas"
	_meshes.tooltip_text = "Encendido: tambien coloca sobre mallas visibles (rocas, acantilados, agua).\nApagado: solo sobre Terrain3D."
	_meshes.button_pressed = settings.get_project_metadata(META, "meshes", true)
	_meshes.toggled.connect(func(on: bool) -> void: settings.set_project_metadata(META, "meshes", on))
	_bar.add_child(_meshes)
	_offset = SpinBox.new()
	_offset.min_value = -50.0
	_offset.max_value = 50.0
	_offset.step = 0.05
	_offset.suffix = "m"
	_offset.tooltip_text = "Metros que se suman a la altura del punto de clic. Positivo = por encima de la superficie. Sin efecto con Conservar altura."
	_offset.value = settings.get_project_metadata(META, "offset", 0.0)
	_offset.value_changed.connect(func(value: float) -> void: settings.set_project_metadata(META, "offset", value))
	_bar.add_child(_offset)
	_status = Label.new()
	_bar.add_child(_status)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, _bar)
	EditorInterface.get_selection().selection_changed.connect(_refresh)
	_refresh()

func _exit_tree() -> void:
	EditorInterface.get_selection().selection_changed.disconnect(_refresh)
	if is_instance_valid(_bar):
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, _bar)
		_bar.queue_free()

func _on_place_toggled(_on: bool) -> void:
	_status.text = ""
	_refresh()

## The selected 3D nodes that can be moved. Terrain3D stays out: it does not move, it is what gets clicked.
func _targets() -> Array:
	var targets := []
	for node in EditorInterface.get_selection().get_top_selected_nodes():
		if node is Node3D and not node.is_class("Terrain3D"):
			targets.append(node)
	return targets

func _refresh() -> void:
	_bar.visible = _place.button_pressed or not _targets().is_empty()
	_keep_height.visible = _place.button_pressed
	_meshes.visible = _place.button_pressed
	_offset.visible = _place.button_pressed

func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if not _place.button_pressed:
		return AFTER_GUI_INPUT_PASS
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_place.button_pressed = false
		return AFTER_GUI_INPUT_STOP
	if Input.is_key_pressed(KEY_ALT):
		return AFTER_GUI_INPUT_PASS
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return AFTER_GUI_INPUT_PASS
	if not event.pressed:
		return AFTER_GUI_INPUT_STOP
	var targets := _targets()
	if targets.is_empty():
		_status.text = "Selecciona un nodo 3D"
		return AFTER_GUI_INPUT_STOP
	var mouse_position: Vector2 = event.position
	var container := camera.get_parent().get_parent()
	if container is SubViewportContainer:
		mouse_position /= float(container.stretch_shrink)
	var root := EditorInterface.get_edited_scene_root()
	var terrains := root.find_children("*", "Terrain3D", true, false)
	if root.is_class("Terrain3D"):
		terrains.append(root)
	for terrain in terrains:
		terrain.set_camera(camera)
	var hit := Ray.find_point(camera.get_world_3d(), camera.project_ray_origin(mouse_position),
		camera.project_ray_normal(mouse_position), camera.far, terrains, _meshes.button_pressed, targets)
	if hit.is_empty():
		_status.text = "Sin superficie bajo el cursor"
		return AFTER_GUI_INPUT_STOP
	_move(targets, hit.point)
	var moved: Node3D = targets[0]
	_status.text = "%s en (%.1f, %.1f, %.1f) sobre %s" % [moved.name, moved.global_position.x, moved.global_position.y,
		moved.global_position.z, hit.name]
	return AFTER_GUI_INPUT_STOP

## The first selected node goes to the point; the others keep their distance to it.
func _move(targets: Array, point: Vector3) -> void:
	var anchor: Node3D = targets[0]
	var goal := point + Vector3.UP * _offset.value
	if _keep_height.button_pressed:
		goal.y = anchor.global_position.y
	var shift := goal - anchor.global_position
	var undo := get_undo_redo()
	undo.create_action("Colocar con clic")
	for node: Node3D in targets:
		undo.add_do_property(node, "global_position", node.global_position + shift)
		undo.add_undo_property(node, "global_position", node.global_position)
	undo.commit_action()
