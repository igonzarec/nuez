@tool
extends Control
## Pinceladas procedurales estables. El shader afecta al fondo, nunca al texto.
const BRUSH = preload("res://ui/dialogue/brush.gdshader")
const PagedLabel = preload("res://ui/dialogue/paged_dialogue_label.gd")
@export_group("Presentation")
## Fijo: parte inferior de pantalla. Sobre personaje: sigue al interlocutor 3D.
@export_enum("Fijo en pantalla", "Sobre personaje") var presentation_mode := 0
## Tamaño relativo en modo fijo. Ejemplo: 1.
@export_range(0.4, 1.5, 0.05) var fixed_scale := 1.0
## Tamaño relativo sobre el personaje. Ejemplo: 0.65.
@export_range(0.3, 1.2, 0.05) var overhead_scale := 0.65
## Punto sobre el origen del interlocutor, en metros. Ejemplo: (0,2.5,0).
@export var overhead_world_offset := Vector3(0, 2.5, 0)
## Ajuste en pantalla; Y negativo eleva el globo. Ejemplo: (0,-25).
@export var overhead_screen_offset := Vector2(0, -25)
## Suavizado del seguimiento; 0 sigue instantáneamente, 12 es suave.
@export_range(0, 30, 0.5) var follow_speed := 12.0
## Mantiene el globo dentro de pantalla, incluyendo espacio para nombre y sombra.
@export var keep_on_screen := true
@export_range(0, 100, 1) var screen_margin := 20.0
## Oculta el globo si el anclaje queda detrás de la cámara.
@export var hide_behind_camera := true
## Punto de anclaje simulado en el editor, relativo al tamaño de pantalla.
@export var preview_anchor := Vector2(0.5, 0.65)
@export_group("Appearance Animation")
@export var appearance_enabled := true
## Ejemplo: 0.25 segundos. 0 muestra inmediatamente.
@export_range(0, 1.5, 0.05) var appearance_duration := 0.25
@export_enum("Suave", "Rebote leve") var appearance_easing := 0
## Escala inicial relativa; 0.88 produce un pequeño crecimiento.
@export_range(0.1, 1, 0.01) var appearance_start_scale := 0.88
## Desplazamiento inicial en píxeles. Ejemplo: (0,18), entra desde abajo.
@export var appearance_slide := Vector2(0, 18)
@export var appearance_fade := true
## Repite la entrada al pasar de página; desactivado solo al abrir conversación.
@export var animate_each_page := false
## Marca para reproducir una vez la entrada en el editor; se desmarca sola.
@export var preview_appearance := false
@export_group("Ambient Loop")
## Activa respiración y flotación mientras se muestra el diálogo.
@export var ambient_enabled := true
@export var breathing_enabled := true
## Porcentaje de expansión del fondo, sin escalar el texto. Ejemplo: 0.75%.
@export_range(0, 3, 0.05) var breathing_percent := 0.75
## Duración de una respiración completa en segundos. Ejemplo: 3.5.
@export_range(1, 10, 0.1) var breathing_period := 3.5
@export var floating_enabled := false
## Desplazamiento vertical máximo del conjunto, en píxeles. Ejemplo: 1.5.
@export_range(0, 10, 0.25) var floating_amplitude := 1.5
@export_range(1, 10, 0.1) var floating_period := 4.0
## Intensidad del loop en modo fijo. Ejemplo: 1.
@export_range(0, 2, 0.05) var fixed_loop_intensity := 1.0
## Intensidad sobre personaje: menor porque ya sigue al NPC. Ejemplo: 0.5.
@export_range(0, 2, 0.05) var overhead_loop_intensity := 0.5
@export_group("Layout")
@export_range(300, 1200, 10) var cloud_width := 960.0
@export_range(120, 500, 5) var cloud_height := 240.0
@export_range(25, 400, 1) var bottom_margin := 75.0
## Márgenes izquierdo, superior, derecho e inferior. Ejemplo: (80,30,80,35).
@export var text_margins := Vector4(80, 30, 80, 35)
@export_group("Brush")
## Suave reproduce la referencia. Los otros estilos añaden grano, manchas o fibras.
@export_enum("Suave", "Gis / Tiza", "Acuarela", "Pincel seco") var brush_style := 0
@export var cloud_color := Color("ffffce")
@export_range(1, 12, 1) var stroke_count := 5
## Grosor en píxeles. Ejemplo: 65.
@export_range(10, 160, 1) var stroke_thickness := 65.0
## Distancia entre centros. Menor que el grosor une trazos. Ejemplo: 40.
@export_range(0, 100, 1) var stroke_spacing := 40.0
## Variación proporcional del largo. Ejemplo: 0.12.
@export_range(0, 0.4, 0.01) var length_variation := 0.12
## Desplazamiento horizontal irregular, en píxeles. Ejemplo: 35.
@export_range(0, 100, 1) var horizontal_variation := 35.0
## Difuminado. Ejemplo: 12 suave; 2 para tiza.
@export_range(0, 30, 0.5) var edge_softness := 12.0
## Intensidad de grano, manchas o fibras. No afecta al estilo Suave.
@export_range(0, 1, 0.05) var texture_strength := 0.45
## Cambia la distribución sin parpadeos entre frames.
@export_range(0, 1000, 1) var brush_seed := 7
@export_group("Drop Shadow")
@export var shadow_enabled := true
@export var shadow_color := Color(0.20, 0.14, 0.09, 0.22)
## Ejemplo: (5,7); valores negativos desplazan arriba o izquierda.
@export var shadow_offset := Vector2(5, 7)
@export_range(0, 30, 0.5) var shadow_softness := 12.0
@export_group("Text")
@export var text_color := Color("40392e")
@export_range(16, 42, 1) var text_size := 28
@export_range(0, 20, 1) var line_spacing := 4
## Arrastra una fuente; vacío conserva la del tema.
@export var text_font: Font
## 400 normal, 600 seminegrita, 700 negrita. Se aplica también a la vista previa.
@export_range(100, 900, 50) var text_font_weight := 400
@export_group("Speaker")
@export var name_color := Color("8508ee")
@export var name_text_color := Color.WHITE
## Color de la segunda línea, por ejemplo amarillo suave.
@export var subtitle_text_color := Color("ffe36d")
## Ajusta el fondo morado al nombre, respetando los límites inferiores y superiores.
@export var name_auto_size := true
@export_range(80, 500, 5) var name_min_width := 140.0
@export_range(100, 600, 5) var name_max_width := 350.0
@export_range(24, 160, 1) var name_min_height := 48.0
@export_range(30, 240, 1) var name_max_height := 100.0
## Espacio a ambos lados y arriba/abajo del nombre.
@export var name_text_margins := Vector4(24, 8, 20, 8)
## Posición relativa al fondo. Ejemplo: (-25,-15) solapa la pincelada beige.
## Aumenta Y para bajar la etiqueta y aumentar el solapamiento.
@export var name_offset := Vector2(-25, -15)
## Inclina la pincelada morada y el nombre juntos, en grados.
## Ejemplo: -6 eleva el extremo derecho; 6 lo baja; 0 la deja horizontal.
@export_range(-45, 45, 0.5) var name_tilt := -6.0
@export_range(16, 42, 1) var name_text_size := 26
## Fuente del título. Vacío hereda Text Font.
@export var name_font: Font
@export_range(100, 900, 50) var name_font_weight := 400
## Tamaño independiente del subtítulo amarillo.
@export_range(12, 42, 1) var subtitle_text_size := 20
## Fuente del subtítulo. Vacío hereda la fuente del título.
@export var subtitle_font: Font
@export_range(100, 900, 50) var subtitle_font_weight := 400
## Separación entre título y subtítulo, en píxeles. Valores negativos acercan
## los renglones y permiten solaparlos. Ejemplos: -4 compacto, -10 muy próximo.
@export_range(-40, 40, 1) var name_line_spacing := 2
## Trazos morados automáticos según renglones visibles.
@export var name_brush_auto_strokes := true
@export_range(1, 8, 1) var name_brush_strokes := 2
## Irregularidad del largo de las pinceladas moradas.
@export_range(0, 0.25, 0.01) var name_brush_variation := 0.08
## Mueve juntos el subtítulo y la segunda pincelada morada.
## Ejemplo: 12 hacia la derecha, -12 hacia la izquierda, 0 sin desplazamiento.
@export_range(-100, 100, 1) var subtitle_brush_offset := 12.0
## Separación mínima entre la etiqueta inclinada y el contenido beige.
@export_range(0, 40, 1) var title_content_gap := 10.0
@export_group("Arrow")
@export var arrow_enabled := true
@export var arrow_color := Color("ffc21c")
@export var arrow_size := Vector2(36, 24)
@export_range(0, 15, 0.5) var arrow_float_amplitude := 4.0
## Ciclos por segundo. Ejemplo: 0.8.
@export_range(0, 3, 0.05) var arrow_float_speed := 0.8
@export_group("Editor Preview")
@export var animate_editor_preview := true
@export_multiline var preview_text := "Hola, aquí va el texto que yo quisiera que tú leas cuando esté el personaje hablando."
@export var preview_name := "Mara"
@export var preview_subtitle := "Guardiana"
## Página del contenido que se muestra en el editor; empieza en 1.
@export_range(1, 100, 1) var preview_content_page := 1

var signature := ""
var arrow_clock := 0.0
var paint: ColorRect
var name_paint: ColorRect
var follow_target: Node3D
var follow_position := Vector2.ZERO
var follow_initialized := false
var appearance_clock := 100.0
var has_appeared := false
var ambient_clock := 0.0
var current_speaker_name := ""
var current_speaker_subtitle := ""
var subtitle_label: RichTextLabel

func _weighted_font(base: Font, weight: int) -> Font:
	var variation := FontVariation.new()
	variation.base_font = base
	var weight_tag := TextServerManager.get_primary_interface().name_to_tag("wght")
	var axes := base.get_supported_variation_list()
	if axes.has(weight_tag):
		variation.variation_opentype = {weight_tag: float(weight)}
	else:
		# Fuente estática: engrosado/adelgazado sintético. 400 conserva el original.
		variation.variation_embolden = float(weight - 400) / 200.0
	return variation

func _fill_speaker_label(target: RichTextLabel, title_font: Font, role_font: Font, subtitle_only: bool) -> void:
	target.clear()
	target.push_font(title_font, name_text_size)
	target.push_color(Color.TRANSPARENT if subtitle_only else name_text_color)
	target.add_text(current_speaker_name)
	target.pop()
	target.pop()
	if not current_speaker_subtitle.is_empty():
		target.push_font(role_font, subtitle_text_size)
		target.add_text("\n")
		target.push_color(subtitle_text_color if subtitle_only else Color.TRANSPARENT)
		target.add_text(current_speaker_subtitle)
		target.pop()
		target.pop()
	target.add_theme_constant_override("line_separation", name_line_spacing)
	target.custom_minimum_size = Vector2.ZERO
	target.fit_content = false
	target.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
var speaker_lines := 1

func set_speaker_name(speaker_name: String, subtitle := "") -> void:
	current_speaker_name = speaker_name
	current_speaker_subtitle = subtitle
	signature = ""
	refresh()

func _speaker_dimensions(title_font: Font, role_font: Font) -> Vector2:
	var paragraph := TextParagraph.new()
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	paragraph.add_string(current_speaker_name, title_font, name_text_size)
	if not current_speaker_subtitle.is_empty():
		paragraph.add_string("\n", title_font, name_text_size)
		paragraph.add_string(current_speaker_subtitle, role_font, subtitle_text_size)
	var minimum := Vector2(maxf(1, name_min_width), maxf(1, name_min_height))
	var maximum := Vector2(maxf(minimum.x, name_max_width), maxf(minimum.y, name_max_height))
	var horizontal_padding := name_text_margins.x + name_text_margins.z
	var width := minimum.x
	if name_auto_size:
		width = clampf(paragraph.get_size().x + horizontal_padding, minimum.x, maximum.x)
	paragraph.width = maxf(1, width - horizontal_padding)
	speaker_lines = maxi(1, paragraph.get_line_count())
	var height := minimum.y
	if name_auto_size:
		height = clampf(paragraph.get_size().y + (speaker_lines - 1) * name_line_spacing + name_text_margins.y + name_text_margins.w, minimum.y, maximum.y)
	return Vector2(width, height)

func _canvas_size() -> Vector2:
	if Engine.is_editor_hint():
		# El tamaño del viewport del editor no equivale al lienzo del juego.
		return Vector2(
			ProjectSettings.get_setting("display/window/size/viewport_width", 1280),
			ProjectSettings.get_setting("display/window/size/viewport_height", 720))
	return get_viewport_rect().size

func _loop_intensity() -> float:
	if not ambient_enabled or (Engine.is_editor_hint() and not animate_editor_preview):
		return 0.0
	return overhead_loop_intensity if presentation_mode == 1 else fixed_loop_intensity

func _update_breathing() -> void:
	if not is_instance_valid(paint):
		return
	var amount := 0.0
	if breathing_enabled:
		amount = sin(ambient_clock * TAU / breathing_period) * breathing_percent * 0.01 * _loop_intensity()
	# Solo las pinceladas crema y su sombra respiran; letras y nombre no se deforman.
	paint.pivot_offset = paint.size * 0.5
	paint.scale = Vector2.ONE * (1.0 + amount)

func set_follow_target(target: Node3D) -> void:
	follow_target = target
	follow_initialized = false

func play_appearance() -> void:
	if not has_appeared or animate_each_page or Engine.is_editor_hint():
		appearance_clock = 0.0
		has_appeared = true
		_update_presentation(0.0)

func _update_presentation(delta: float) -> void:
	var viewport_size := _canvas_size()
	var factor := fixed_scale
	var desired := Vector2((viewport_size.x - size.x * factor) * 0.5, viewport_size.y - bottom_margin - size.y * factor)
	visible = true
	if presentation_mode == 1:
		factor = overhead_scale
		var anchor_point := viewport_size * preview_anchor
		var camera := get_viewport().get_camera_3d()
		if not Engine.is_editor_hint() and is_instance_valid(follow_target) and camera:
			var world_point := follow_target.global_position + overhead_world_offset
			if camera.is_position_behind(world_point):
				visible = not hide_behind_camera
			else:
				anchor_point = camera.unproject_position(world_point)
		elif not Engine.is_editor_hint():
			# Sin interlocutor válido se conserva la lectura en modo fijo.
			factor = fixed_scale
			anchor_point = Vector2(viewport_size.x * 0.5, viewport_size.y - bottom_margin)
		desired = anchor_point + overhead_screen_offset - Vector2(size.x * 0.5, size.y) * factor
	if keep_on_screen:
		var padding := Vector2(65, 65) * factor + Vector2.ONE * screen_margin
		var maximum := viewport_size - size * factor - padding
		desired.x = clampf(desired.x, minf(padding.x, maximum.x), maxf(padding.x, maximum.x))
		desired.y = clampf(desired.y, minf(padding.y, maximum.y), maxf(padding.y, maximum.y))
	if not follow_initialized or presentation_mode == 0 or follow_speed <= 0 or Engine.is_editor_hint():
		follow_position = desired
		follow_initialized = true
	else:
		follow_position = follow_position.lerp(desired, 1.0 - exp(-follow_speed * delta))
	appearance_clock += delta
	var t := 1.0
	if appearance_enabled and appearance_duration > 0:
		t = clampf(appearance_clock / appearance_duration, 0, 1)
	var eased := 1.0 - pow(1.0 - t, 3)
	if appearance_easing == 1:
		eased = 1.0 + 2.70158 * pow(t - 1.0, 3) + 1.70158 * pow(t - 1.0, 2)
	var animated_factor := factor * lerpf(appearance_start_scale, 1.0, eased)
	scale = Vector2.ONE * animated_factor
	position = follow_position + size * (factor - animated_factor) * 0.5 + appearance_slide * (1.0 - t)
	if floating_enabled:
		position.y += sin(ambient_clock * TAU / floating_period) * floating_amplitude * _loop_intensity() * t
	modulate.a = t if appearance_fade else 1.0

func _ready() -> void:
	refresh()

func _process(delta: float) -> void:
	refresh()
	if is_visible_in_tree() and (not Engine.is_editor_hint() or animate_editor_preview):
		ambient_clock = fmod(ambient_clock + delta, 3600.0)
	if Engine.is_editor_hint() and preview_appearance:
		preview_appearance = false
		play_appearance()
	_update_presentation(delta)
	_update_breathing()
	if not has_node("ArrowAnchor/Progress"):
		return
	if not Engine.is_editor_hint() or animate_editor_preview:
		arrow_clock += delta
	$ArrowAnchor.visible = arrow_enabled
	if is_instance_valid(name_paint):
		name_paint.visible = $SpeakerPill.visible
	$ArrowAnchor/Progress.position.y = -7.0 + sin(arrow_clock * TAU * arrow_float_speed) * arrow_float_amplitude

func _make_paint(parent: Node) -> ColorRect:
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.show_behind_parent = true
	var mat := ShaderMaterial.new()
	mat.shader = BRUSH
	rect.material = mat
	parent.add_child(rect)
	return rect

func _configure(rect: ColorRect, dimensions: Vector2, color: Color, is_name: bool) -> void:
	var padding := 50.0 + maxf(absf(shadow_offset.x), absf(shadow_offset.y))
	if is_name:
		padding += absf(subtitle_brush_offset)
	if not is_name:
		padding += maxf(0, (stroke_count - 1) * stroke_spacing + stroke_thickness - dimensions.y) * 0.5
	rect.position = Vector2(-padding, -padding)
	rect.size = dimensions + Vector2.ONE * padding * 2.0
	var mat := rect.material as ShaderMaterial
	var count := clampi(speaker_lines if name_brush_auto_strokes else name_brush_strokes, 1, 8)
	var name_thickness := dimensions.y / (1.0 + (count - 1) * 0.65)
	var values := {
		"panel_size": dimensions, "padding": padding, "paint_color": color,
		"brush_style": brush_style, "stroke_count": count if is_name else stroke_count,
		"thickness": name_thickness if is_name else stroke_thickness,
		"spacing": name_thickness * 0.65 if is_name else stroke_spacing,
		"length_variation": name_brush_variation if is_name else length_variation,
		"horizontal_variation": 6.0 if is_name else horizontal_variation,
		"second_stroke_offset": subtitle_brush_offset if is_name else 0.0,
		"softness": edge_softness, "texture_strength": texture_strength,
		"seed": float(brush_seed), "shadow_enabled": shadow_enabled,
		"shadow_color": shadow_color, "shadow_offset": shadow_offset, "shadow_softness": shadow_softness
	}
	for key in values:
		mat.set_shader_parameter(key, values[key])

func refresh() -> void:
	if not has_node("Content"):
		return
	var values: Array = [_canvas_size()]
	for property in get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.usage & PROPERTY_USAGE_EDITOR:
			values.append(get(property.name))
	var next_signature := str(values)
	if signature == next_signature:
		return
	signature = next_signature
	if not is_instance_valid(paint):
		paint = _make_paint(self)
	if not is_instance_valid(name_paint):
		name_paint = _make_paint(self)
	var width := maxf(200, minf(cloud_width, _canvas_size().x - 100.0))
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = Vector2(width, cloud_height)
	_configure(paint, Vector2(width, cloud_height), cloud_color, false)
	var label := $Content/TextViewport/DialogueLabel as PagedLabel
	var name_label := $SpeakerPill/CharacterLabel as RichTextLabel
	if Engine.is_editor_hint():
		current_speaker_name = preview_name
		current_speaker_subtitle = preview_subtitle
	var plain_speaker := current_speaker_name
	if not current_speaker_subtitle.is_empty():
		plain_speaker += "\n" + current_speaker_subtitle
	var title_font: Font = name_font if name_font else (text_font if text_font else ThemeDB.fallback_font)
	var role_font: Font = subtitle_font if subtitle_font else title_font
	title_font = _weighted_font(title_font, name_font_weight)
	role_font = _weighted_font(role_font, subtitle_font_weight)
	if not is_instance_valid(subtitle_label):
		subtitle_label = RichTextLabel.new()
		subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		subtitle_label.scroll_active = false
		name_label.add_child(subtitle_label)
		subtitle_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fill_speaker_label(name_label, title_font, role_font, false)
	_fill_speaker_label(subtitle_label, title_font, role_font, true)
	subtitle_label.offset_left = subtitle_brush_offset
	subtitle_label.offset_right = subtitle_brush_offset
	subtitle_label.visible = not current_speaker_subtitle.is_empty()
	# La capa del subtítulo mantiene exactamente el mismo salto de línea y ancho;
	# se traslada en el eje local de la etiqueta, igual que la pincelada inclinada.
	name_label.clip_contents = false
	name_label.add_theme_constant_override("line_separation", name_line_spacing)
	name_label.custom_minimum_size = Vector2.ZERO
	name_label.fit_content = false
	var pill := $SpeakerPill as PanelContainer
	pill.position = name_offset
	var name_dimensions := _speaker_dimensions(title_font, role_font)
	pill.size = name_dimensions
	pill.rotation = deg_to_rad(name_tilt)
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = name_text_margins.x
	empty.content_margin_right = name_text_margins.z
	empty.content_margin_top = name_text_margins.y
	empty.content_margin_bottom = name_text_margins.w
	pill.add_theme_stylebox_override("panel", empty)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.tooltip_text = plain_speaker if name_dimensions.y >= name_max_height else ""
	_configure(name_paint, name_dimensions, name_color, true)
	name_paint.position = name_offset + name_paint.position.rotated(deg_to_rad(name_tilt))
	name_paint.rotation = deg_to_rad(name_tilt)
	var content := $Content as MarginContainer
	content.add_theme_constant_override("margin_left", int(text_margins.x))
	# La parte beige empieza siempre debajo de la etiqueta morada, con un pequeño aire.
	var title_bottom := name_offset.y
	for corner in [Vector2.ZERO, Vector2(name_dimensions.x, 0), name_dimensions, Vector2(0, name_dimensions.y)]:
		title_bottom = maxf(title_bottom, name_offset.y + (corner as Vector2).rotated(deg_to_rad(name_tilt)).y)
		title_bottom = maxf(title_bottom, name_offset.y + ((corner as Vector2) + Vector2(subtitle_brush_offset, 0)).rotated(deg_to_rad(name_tilt)).y)
	title_bottom += title_content_gap + edge_softness
	var top_padding := maxi(maxi(0, int(text_margins.y)), ceili(title_bottom))
	content.add_theme_constant_override("margin_top", top_padding)
	content.add_theme_constant_override("margin_right", int(text_margins.z))
	content.add_theme_constant_override("margin_bottom", int(text_margins.w))
	label.add_theme_color_override("default_color", text_color)
	label.add_theme_font_size_override("normal_font_size", text_size)
	label.add_theme_constant_override("line_separation", line_spacing)
	name_label.add_theme_color_override("default_color", name_text_color)
	name_label.add_theme_font_size_override("normal_font_size", name_text_size)
	var content_font := _weighted_font(text_font if text_font else ThemeDB.fallback_font, text_font_weight)
	label.add_theme_font_override("normal_font", content_font)
	name_label.add_theme_font_override("normal_font", title_font)
	subtitle_label.add_theme_font_override("normal_font", title_font)
	subtitle_label.add_theme_font_size_override("normal_font_size", name_text_size)
	# Siempre reservar al menos un renglón completo, incluso con padding muy alto.
	var minimum_height := top_padding + maxf(0, text_margins.w) + content_font.get_height(text_size) + maxf(0, line_spacing) + 2
	if size.y < minimum_height:
		size.y = minimum_height
		_configure(paint, size, cloud_color, false)
	label.invalidate_pages()
	var arrow := $ArrowAnchor/Progress as Polygon2D
	arrow.polygon = PackedVector2Array([Vector2(-0.5, 0), Vector2(0.5, 0),
		Vector2(0.52, 0.15), Vector2(0.12, 0.9), Vector2(0, 1),
		Vector2(-0.12, 0.9), Vector2(-0.52, 0.15)])
	arrow.scale = arrow_size
	arrow.antialiased = true
	arrow.color = arrow_color
	if Engine.is_editor_hint():
		show()
		$Content.show()
		$SpeakerPill.show()
		label.show()
		name_label.show()
		arrow.show()
		label.show_manual_text(preview_text, preview_content_page - 1)
		# El nombre ya se asignó antes de calcular sus dimensiones.
