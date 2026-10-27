@tool
extends EditorPlugin
const DETAILS = preload("res://scripts/surface_details/surface_details.gd")
const STYLE = preload("res://scripts/surface_details/detail_style.gd")
const NAMES := ["Nieve", "Hojas", "Tierra", "Pasto", "Nieve profunda"]
var _component: Node3D
var _known: Array[Node] = []
var _panel: VBoxContainer
var _panel_button: Button
var _paint: CheckButton
var _erase: CheckButton
var _layer: OptionButton
var _radius: SpinBox
var _strength: SpinBox
var _hardness: SpinBox
var _status: Label
var _syncing := false
var _stroke := false
var _stroke_erase := false
var _last_point := Vector3.ZERO
var _hover := Vector3.ZERO
var _hover_valid := false
var _camera: Camera3D
var _last_ui_signature := 0

func _enter_tree() -> void:
	set_input_event_forwarding_always_enabled()
	_panel = VBoxContainer.new()
	var row := HFlowContainer.new()
	_panel.add_child(row)
	_paint = CheckButton.new()
	_paint.text = "Pintar superficies"
	_paint.tooltip_text = "Activar para pintar detalle. Clic y arrastre; Ctrl borra la capa elegida. Alt/RMB conserva navegación."
	row.add_child(_paint)
	_paint.toggled.connect(func(active: bool) -> void:
		if not active: _finish_stroke()
		if not active and is_instance_valid(_component):
			_component.set_editor_brush_focus(Vector3.ZERO,false)
		_hover_valid = false
		update_overlays())
	_layer = OptionButton.new()
	for name_value in NAMES: _layer.add_item(name_value)
	row.add_child(_layer)
	_layer.item_selected.connect(func(index: int) -> void:
		if _component and not _syncing:
			_finish_stroke()
			_component.paint_layer = index
			EditorInterface.mark_scene_as_unsaved()
			_sync())
	_erase = CheckButton.new()
	_erase.text = "Borrar detalle"
	row.add_child(_erase)
	_erase.toggled.connect(func(_active: bool) -> void: _finish_stroke())
	var inspect := Button.new()
	inspect.text = "Editar apariencia"
	inspect.pressed.connect(func() -> void:
		if not _component: return
		if _component.paint_layer == 3:
			var grass_node := _component.get_node_or_null(_component.grass_particles_path)
			if grass_node: EditorInterface.inspect_object(grass_node)
		else:
			EditorInterface.inspect_object(_component.profiles()[_component.paint_layer]))
	row.add_child(inspect)
	var brush := HBoxContainer.new()
	_panel.add_child(brush)
	_radius = _spin(brush,"Radio (m)",0.25,32.0,0.25)
	_strength = _spin(brush,"Intensidad",0.01,1.0,0.01)
	_hardness = _spin(brush,"Dureza",0.0,1.0,0.01)
	_radius.value_changed.connect(func(value: float) -> void: _set_brush("brush_radius",value))
	_strength.value_changed.connect(func(value: float) -> void: _set_brush("brush_strength",value))
	_hardness.value_changed.connect(func(value: float) -> void: _set_brush("brush_hardness",value))
	_status = Label.new()
	_status.text = "Selecciona SurfaceDetails o su Terrain3D."
	_panel.add_child(_status)
	_panel_button = add_control_to_bottom_panel(_panel,"Pincel de detalles")
	set_process(true)

func _spin(row: HBoxContainer, label_text: String, low: float, high: float, step: float) -> SpinBox:
	var label := Label.new()
	label.text = label_text
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.step = step
	row.add_child(spin)
	return spin

func _set_brush(property: String, value: float) -> void:
	if _component and not _syncing:
		_component.set(property,value)
		EditorInterface.mark_scene_as_unsaved()

func _handles(object: Object) -> bool:
	return object is Terrain3D or (object is Node and object.get_script() == DETAILS) or (object is Resource and object.get_script() == STYLE and is_instance_valid(_component))

func _edit(object: Object) -> void:
	_finish_stroke()
	if is_instance_valid(_component):
		_component.set_editor_brush_focus(Vector3.ZERO,false)
	if object is Resource and object.get_script() == STYLE:
		return
	var target: Node3D
	if object is Node and object.get_script() == DETAILS:
		target = object
	elif object is Terrain3D:
		for child in object.get_children():
			if child.get_script() == DETAILS:
				target = child
	if target:
		_component = target
		if not _known.has(target): _known.append(target)
		_sync()
	else:
		_component = null
		_paint.button_pressed = false
		_status.text = "Este Terrain3D no tiene SurfaceDetails. Añade un Node3D hijo con surface_details.gd."

func _make_visible(visible: bool) -> void:
	# Editar un perfil Resource conserva el objetivo, pero el pincel sólo captura
	# clics cuando su interruptor está activo. El panel queda accesible.
	if visible and is_instance_valid(_component):
		make_bottom_panel_item_visible(_panel)

func _sync() -> void:
	if not is_instance_valid(_component): return
	_syncing = true
	_layer.select(_component.paint_layer)
	_radius.value = _component.brush_radius
	_strength.value = _component.brush_strength
	_hardness.value = _component.brush_hardness
	_status.text = "Clic y arrastra: añadir detalle · Ctrl: borrar capa elegida · Ctrl+Z: deshacer · Ctrl+S: guardar. Las texturas se pintan en Terrain3D."
	_last_ui_signature = _ui_signature()
	_syncing = false

func _ui_signature() -> int:
	if not is_instance_valid(_component): return 0
	return hash([_component.paint_layer,_component.brush_radius,
		_component.brush_strength,_component.brush_hardness])

func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if not is_instance_valid(_component) or not _paint.button_pressed:
		return AFTER_GUI_INPUT_PASS
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_paint.button_pressed = false
		return AFTER_GUI_INPUT_STOP
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_stroke()
		return AFTER_GUI_INPUT_STOP
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) or Input.is_key_pressed(KEY_ALT):
		_finish_stroke()
		_hover_valid = false
		_component.set_editor_brush_focus(Vector3.ZERO,false)
		update_overlays()
		return AFTER_GUI_INPUT_PASS
	if not (event is InputEventMouseMotion or event is InputEventMouseButton):
		return AFTER_GUI_INPUT_PASS
	var terrain: Terrain3D = _component.terrain
	if terrain == null or terrain.data == null: return AFTER_GUI_INPUT_PASS
	terrain.set_camera(camera)
	_camera = camera
	var mouse_position: Vector2 = event.position
	var container := camera.get_parent().get_parent()
	if container is SubViewportContainer:
		mouse_position /= float(container.stretch_shrink)
	var point := terrain.get_intersection(camera.project_ray_origin(mouse_position),camera.project_ray_normal(mouse_position),true)
	_hover_valid = point.is_finite() and absf(point.z) < 1e30 and terrain.data.has_regionp(point)
	if _hover_valid: _hover = point
	_component.set_editor_brush_focus(point,_hover_valid)
	update_overlays()
	var left_press: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	if left_press:
		if not _hover_valid: return AFTER_GUI_INPUT_STOP
		_stroke = true
		_stroke_erase = _erase.button_pressed or Input.is_key_pressed(KEY_CTRL)
		_component.begin_stroke(_stroke_erase)
		_component.dab(point,_stroke_erase)
		_last_point = point
		return AFTER_GUI_INPUT_STOP
	if _stroke and event is InputEventMouseMotion:
		if _hover_valid:
			var distance := Vector2(point.x-_last_point.x,point.z-_last_point.z).length()
			var spacing := maxf(0.15,_component.brush_radius*0.2)
			if distance >= spacing:
				var steps := mini(48,ceili(distance/spacing))
				for index in range(1,steps+1):
					_component.dab(_last_point.lerp(point,float(index)/steps),_stroke_erase)
				_last_point = point
		return AFTER_GUI_INPUT_STOP
	return AFTER_GUI_INPUT_PASS

func _finish_stroke() -> void:
	if not _stroke: return
	_stroke = false
	if not is_instance_valid(_component): return
	var snapshot: Dictionary = _component.end_stroke()
	if snapshot.before_tiles.is_empty(): return
	var undo := get_undo_redo()
	undo.create_action("Pintar detalle: " + NAMES[_component.paint_layer],UndoRedo.MERGE_DISABLE,_component)
	undo.add_do_method(_component,"apply_snapshot",snapshot.after_tiles,{},snapshot.layer)
	undo.add_undo_method(_component,"apply_snapshot",snapshot.before_tiles,{},snapshot.layer)
	undo.commit_action(false)

func _forward_3d_draw_over_viewport(overlay: Control) -> void:
	if not _hover_valid or not is_instance_valid(_camera) or not is_instance_valid(_component) or not _paint.button_pressed: return
	var points := PackedVector2Array()
	for index in 49:
		var angle := float(index)/48.0*TAU
		var point: Vector3 = _hover+Vector3(cos(angle),0,sin(angle))*_component.brush_radius
		var height: float = _component.terrain.data.get_height(point)
		if not is_finite(height): return
		point.y = height+0.04
		if _camera.is_position_behind(point): return
		var scale := overlay.size/_camera.get_viewport().get_visible_rect().size.max(Vector2.ONE)
		points.append(_camera.unproject_position(point)*scale)
	overlay.draw_polyline(points,Color(1,0.45,0.25) if _erase.button_pressed or Input.is_key_pressed(KEY_CTRL) else Color(0.5,1,0.8),2.0,true)

func _process(_delta: float) -> void:
	if _stroke and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): _finish_stroke()
	if is_instance_valid(_component) and _last_ui_signature != _ui_signature(): _sync()

func _apply_changes() -> void:
	_finish_stroke()

func _save_external_data() -> void:
	_finish_stroke()
	for component in _known:
		if is_instance_valid(component) and component.is_inside_tree():
			var result: Error = component.save_paint()
			if result != OK: push_error("No se pudo guardar la cobertura de superficies: " + error_string(result))
			for profile in component.profiles():
				if profile and profile.resource_path.begins_with("res://") and not profile.resource_path.contains("::"):
					profile.repair_missing_values()
					var profile_result := ResourceSaver.save(profile,profile.resource_path)
					if profile_result != OK: push_error("No se pudo guardar un perfil de detalle: " + error_string(profile_result))
			# Terrain3D guarda los mapas modificados con su NOTIFICATION_EDITOR_PRE_SAVE.

func _exit_tree() -> void:
	_finish_stroke()
	remove_control_from_bottom_panel(_panel)
	_panel.queue_free()
