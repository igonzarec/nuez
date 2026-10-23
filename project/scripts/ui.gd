class_name TrailUI
extends CanvasLayer

signal action(name: String)
signal setting_changed(key: String, value: Variant)
var root: Control
var hud: Control
var counts: Label
var objective: Label
var prompt: Label
var controls: Label
var toast_label: Label
var toast_time := 0.0
var overlay: Control
var page: VBoxContainer
var first_button: Button
var dialogue_label: Label
var display_status: Label
var gamepad := false
var panel_name := ""
var buttons: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme := Theme.new()
	theme.default_font_size = 19
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("304b46") if state == "normal" else Color("587565")
		if state == "disabled": style.bg_color = Color("34433e")
		style.set_corner_radius_all(10)
		style.content_margin_left = 24
		style.content_margin_right = 24
		style.content_margin_top = 12
		style.content_margin_bottom = 12
		if state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.border_color = Color("f2c978")
			style.set_border_width_all(3)
		theme.set_stylebox(state, "Button", style)
	theme.set_color("font_color", "Button", Color("f5edd9"))
	theme.set_color("font_disabled_color", "Button", Color("82928b"))
	root.theme = theme
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	var badge := PanelContainer.new()
	badge.position = Vector2(28, 26)
	badge.add_theme_stylebox_override("panel", _panel_style())
	hud.add_child(badge)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 8)
	badge.add_child(info)
	info.add_child(_label("PASO DE BRUMA", 14, Color("e1bc77")))
	counts = _label("", 22)
	info.add_child(counts)
	objective = _label("", 16, Color("d7e1cf"))
	info.add_child(objective)
	controls = _label("", 15)
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	controls.offset_top = -34
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(controls)
	prompt = _label("", 20, Color("ffe3a3"))
	prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	prompt.offset_top = -94
	prompt.offset_bottom = -62
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(prompt)
	toast_label = _label("", 22, Color("ffe6b2"))
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	toast_label.offset_top = 170
	toast_label.offset_bottom = 220
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(toast_label)
	set_gamepad(false)

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.14, 0.12, 0.94)
	style.set_corner_radius_all(16)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	style.border_color = Color("617569")
	style.set_border_width_all(1)
	return style

func _label(text: String, size: int, color := Color("f4eddc")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.06, 0.12, 0.10, 0.8))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _begin(name_value: String, width := 460.0, left_aligned := false) -> void:
	close()
	panel_name = name_value
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.07, 0.055, 0.27 if left_aligned else 0.58)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _panel_style())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if left_aligned:
		center.anchor_right = 0.48
		center.offset_left = 30
	overlay.add_child(center)
	center.add_child(frame)
	frame.custom_minimum_size.x = width
	page = VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	frame.add_child(page)
	if name_value in ["settings", "controls"]:
		frame.remove_child(page)
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(width - 56, 560)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = true
		frame.add_child(scroll)
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(page)
	first_button = null

func _heading(kicker: String, title: String, body := "") -> void:
	page.add_child(_label(kicker, 14, Color("ddba78")))
	page.add_child(_label(title, 40))
	if not body.is_empty():
		var text := _label(body, 18, Color("c9d6c6"))
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size.x = 370
		page.add_child(text)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	page.add_child(spacer)

func _button(text: String, command: String, disabled := false) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = disabled
	button.custom_minimum_size.y = 46
	button.pressed.connect(func() -> void: action.emit(command))
	page.add_child(button)
	buttons[command] = button
	if not first_button and not disabled:
		first_button = button
	return button

func _focus() -> void:
	if first_button:
		first_button.grab_focus()

func title(has_save: bool) -> void:
	hud.hide()
	_begin("title", 440, true)
	_heading("UNA PEQUEÑA EXPEDICIÓN", "Lantern\nTrail", "Hay una luz que siempre nos trae de vuelta.")
	_button("Continuar", "continue", not has_save)
	_button("Nueva expedición", "new")
	_button("Ajustes", "settings")
	_button("Salir", "quit")
	_focus()

func confirm_new() -> void:
	_begin("confirm")
	_heading("UN NUEVO CAMINO", "¿Empezar de nuevo?", "Se sustituirá el progreso de esta expedición. Los ajustes se conservarán.")
	_button("Conservar mi expedición", "cancel_new")
	_button("Empezar de nuevo", "confirm_new")
	_focus()

func pause_menu(preview := false) -> void:
	_begin("pause")
	_heading("TÓMATE TU TIEMPO", "Un respiro", "Escena de trabajo: los ajustes se comparten con el juego." if preview else "Tu progreso se guarda al recoger semillas y restaurar faroles.")
	_button("Seguir explorando", "resume")
	_button("Ajustes", "settings")
	_button("Volver al título", "title")
	_focus()

func dialogue(speaker: String, text: String) -> void:
	_begin("dialogue", 650)
	_heading("EN EL SENDERO", speaker)
	dialogue_label = _label(text, 21)
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.custom_minimum_size = Vector2(590, 100)
	page.add_child(dialogue_label)
	_button("Continuar  ·  E / A", "advance")
	_focus()

func settings(values: Dictionary) -> void:
	_begin("settings", 680)
	_heading("A TU RITMO", "Ajustes")
	for item: Array in [["master", "Volumen general"], ["music", "Música"], ["sfx", "Sonidos"], ["climb_sfx", "Raspado de escalada"], ["sensitivity", "Sensibilidad del ratón"]]:
		var row := HBoxContainer.new()
		page.add_child(row)
		var name_label := _label(item[1], 17)
		name_label.custom_minimum_size.x = 230
		row.add_child(name_label)
		var slider := HSlider.new()
		slider.custom_minimum_size.x = 180
		slider.min_value = 0.2 if item[0] == "sensitivity" else 0
		slider.max_value = 2.5 if item[0] == "sensitivity" else 1
		slider.step = 0.05
		slider.value = values[item[0]]
		slider.focus_mode = Control.FOCUS_ALL
		slider.value_changed.connect(func(value: float) -> void: setting_changed.emit(item[0], value))
		row.add_child(slider)
	var fullscreen := CheckButton.new()
	fullscreen.text = "Pantalla completa"
	fullscreen.button_pressed = values.fullscreen
	fullscreen.toggled.connect(func(value: bool) -> void: setting_changed.emit("fullscreen", value))
	page.add_child(fullscreen)
	var resolution_row := HBoxContainer.new()
	page.add_child(resolution_row)
	var resolution_label := _label("Resolución", 17)
	resolution_label.custom_minimum_size.x = 230
	resolution_row.add_child(resolution_label)
	var resolution := OptionButton.new()
	resolution.disabled = values.get("fullscreen", false) == true
	fullscreen.toggled.connect(func(value: bool) -> void: resolution.disabled = value)
	resolution.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resolution.tooltip_text = "Se aplica al instante en modo ventana. En pantalla completa el juego usa la resolución nativa del monitor."
	var selected_resolution: String = TrailDisplay.validated_resolution(values.get("resolution", TrailDisplay.DEFAULT_RESOLUTION))
	for item: String in TrailDisplay.RESOLUTIONS:
		resolution.add_item(TrailDisplay.resolution_label(item))
		resolution.set_item_metadata(resolution.item_count - 1, item)
		if item == selected_resolution:
			resolution.select(resolution.item_count - 1)
	resolution.item_selected.connect(func(index: int) -> void: setting_changed.emit("resolution", resolution.get_item_metadata(index)))
	resolution_row.add_child(resolution)
	display_status = _label("", 15, Color("c9d6c6"))
	display_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(display_status)
	var toon := CheckButton.new()
	toon.text = "Sombreado toon · experimental"
	toon.tooltip_text = "Prueba luz y sombra con un corte de dibujo animado en terreno, personaje y materiales iluminados. Se aplica al instante."
	toon.button_pressed = values.get("toon_enabled", false)
	toon.toggled.connect(func(value: bool) -> void: setting_changed.emit("toon_enabled", value))
	page.add_child(toon)
	page.add_child(_label("Suavidad del sombreado toon", 17))
	var toon_softness := HSlider.new()
	toon_softness.min_value = 0.0
	toon_softness.max_value = 1.0
	toon_softness.step = 0.01
	toon_softness.value = values.get("toon_softness", 0.08)
	toon_softness.editable = toon.button_pressed
	toon_softness.tooltip_text = "Menor: corte más marcado entre luz y sombra. Mayor: transición más suave."
	toon.toggled.connect(func(value: bool) -> void: toon_softness.editable = value)
	toon_softness.value_changed.connect(func(value: float) -> void: setting_changed.emit("toon_softness", value))
	page.add_child(toon_softness)
	var fast_reset := CheckButton.new()
	fast_reset.text = "Reinicio rápido · Start"
	fast_reset.tooltip_text = "Durante la exploración, Start devuelve a la ardilla junto al farol de la cima en lugar de abrir la pausa."
	fast_reset.button_pressed = values.get("fast_reset_enabled", true)
	fast_reset.toggled.connect(func(value: bool) -> void: setting_changed.emit("fast_reset_enabled", value))
	page.add_child(fast_reset)
	var glide_camera := CheckButton.new()
	glide_camera.text = "Cámara al frente durante planeo"
	glide_camera.tooltip_text = "Mantiene la cámara detrás del personaje mirando hacia su frente. R2 / C recentra una vez aunque esté desactivado."
	glide_camera.button_pressed = values.get("glide_forward_enabled", false)
	glide_camera.toggled.connect(func(value: bool) -> void: setting_changed.emit("glide_forward_enabled", value))
	page.add_child(glide_camera)
	var pixel_label := _label("Acabado pixelado", 17)
	page.add_child(pixel_label)
	var pixels := HSlider.new()
	pixels.min_value = 1
	pixels.max_value = 4
	pixels.step = 1
	pixels.value = values.get("pixel_size", 2)
	pixels.value_changed.connect(func(value: float) -> void: setting_changed.emit("pixel_size", value))
	page.add_child(pixels)
	_button("Controles · teclado y mando", "controls")
	_button("Guardar y volver", "settings_back")
	_focus()

func controls_menu() -> void:
	_begin("controls", 660)
	_heading("REFERENCIA", "Controles")
	_button("Volver a ajustes", "controls_back")
	for entry: Array in [
		["Moverse", "WASD / flechas · stick izquierdo"],
		["Cámara", "Clic derecho + arrastrar · stick derecho"],
		["Cámara al frente", "C · R2 / RT (una vez por pulsación)"],
		["Saltar", "Espacio · cruz (PlayStation) / A (Xbox)"],
		["Planear", "En el aire: pulsa y mantén R1 / RB; en teclado, pulsa otra vez Espacio y mantén. Suelta para caer."],
		["Escalar", "Mantén salto cerca de roca escalable, mirando hacia ella.\nMuévete con WASD / stick; suelta salto para desprenderte."],
		["Correr / planeo rápido", "Mantén Shift · L1 / LB. En mando, R1 + L1 para planeo rápido."],
		["Interactuar", "E · cuadrado / X (Xbox). Cerca y en el suelo, cruz / A también habla en lugar de saltar."],
		["Diálogo", "E / Enter / Espacio · cuadrado o cruz / X o A.\nCompleta la página mientras escribe; después avanza.\nFlechas / cruceta: respuestas. Esc / círculo / B: cerrar."],
		["Pausa / volver", "Esc · círculo / B. Start también, si reinicio rápido está desactivado."],
		["Reinicio rápido", "Start: vuelve a la cima junto al farol durante exploración, si el ajuste está activado."],
		["Menús", "Flechas / cruceta: navegar; Enter / cruz / A: aceptar.\nIzquierda / derecha: ajustar deslizadores."]]:
		page.add_child(_label(entry[0], 21, Color("e4c582")))
		var detail := _label(entry[1], 17)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.custom_minimum_size.x = 540
		# Permite recorrer la referencia con cruceta; el scroll sigue el foco.
		detail.focus_mode = Control.FOCUS_ALL
		page.add_child(detail)
	_button("Volver a ajustes", "controls_back")
	_focus()

func completion(data: Dictionary) -> void:
	hud.hide()
	_begin("completion", 590)
	_heading("TODOS HAN VUELTO", "El camino a casa", "Los faroles ya brillan. Mara prepara una taza caliente y, entre la nieve, las últimas huellas llegan al refugio.")
	var seconds := int(data.elapsed)
	page.add_child(_label("3 faroles   ·   %d / 15 semillas   ·   %d:%02d" % [data.collected.size(), seconds / 60, seconds % 60], 19, Color("e4c582")))
	_button("Volver al título", "title")
	_button("Jugar de nuevo", "again")
	_focus()

func close() -> void:
	display_status = null
	if is_instance_valid(overlay):
		root.remove_child(overlay)
		overlay.queue_free()
	overlay = null
	panel_name = ""
	buttons.clear()

func set_gamepad(value: bool) -> void:
	gamepad = value
	controls.text = "Stick izq. mover   Stick der. cámara   A/cruz saltar o hablar cerca   X/cuadrado interactuar   R1 planear   L1 correr" if value else "WASD mover    Clic derecho + arrastrar: cámara    Espacio salto/planeo    E interactuar    Shift correr    Esc pausa"

func update_hud(data: Dictionary) -> void:
	counts.text = "Semillas  %02d     ·     Faroles  %d / 3" % [data.collected.size() - data.lamps.size() * 3, data.lamps.size()]
	objective.text = "Vuelve con Mara junto al refugio" if data.lamps.size() == 3 else "Restaura los faroles · 3 semillas por farol"

func toast(message: String) -> void:
	toast_label.text = message
	toast_time = 3.5

func _process(delta: float) -> void:
	if is_instance_valid(display_status) and DisplayServer.get_name() != "headless":
		var actual := DisplayServer.window_get_size()
		display_status.text = "Tamaño actual de ventana: %d × %d.\nLas resoluciones que no caben se ajustan al espacio disponible." % [actual.x, actual.y]
		if Engine.is_embedded_in_editor():
			display_status.text += "\nEl juego está integrado en el editor. Para comprobar el tamaño de ventana, ejecútalo en una ventana independiente."
	toast_time = maxf(0, toast_time - delta)
	toast_label.visible = toast_time > 0
