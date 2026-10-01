@tool
extends Node3D
## Prompt independiente del diálogo. Abre interaction_prompt.tscn para editarlo en 3D.

@export_group("Vista previa en el editor")
## Lo mantiene junto al origen al editar esta escena. No cambia la altura en juego.
@export var preview_at_origin := true

@export_group("Burbuja")
## Ancho total en metros. Ejemplo: 0,95; 0,65 lo hace más discreto.
@export_range(0.2, 1.5, 0.01) var icon_width := 0.95
## Proporción vertical del cuerpo de la burbuja. 0,75 es compacta; 1 es más alta.
@export_range(0.45, 1.25, 0.01) var bubble_height_ratio := 0.78
## Sólo ensancha el cuerpo que contiene los puntos. No cambia la altura, puntos ni rabito.
## Ejemplo: 1 es el ancho normal; 1,4 deja más aire a los lados.
@export_range(0.55, 2.0, 0.01) var bubble_width_ratio := 1.0
## Activa o quita completamente el contorno oscuro de la burbuja.
@export var outline_enabled := true
## Grosor del contorno en píxeles. 2 es delicado; 4 más marcado.
@export_range(1.0, 8.0, 0.1) var outline_width := 3.0
## Ancho de la punta inferior en píxeles del dibujo.
@export_range(6.0, 34.0, 0.5) var tail_width := 18.0
## Largo de la punta inferior en píxeles del dibujo.
@export_range(4.0, 32.0, 0.5) var tail_height := 17.0
## Suaviza la punta del rabito. 0 es aguda; 1 es notablemente redondeada.
@export_range(0.0, 1.0, 0.05) var tail_roundness := 0.45
@export var fill_color := Color("fff8e9")
@export var outline_color := Color("353331")

@export_group("Sombra")
@export var shadow_enabled := true
@export var shadow_color := Color("171411")
@export_range(0.0, 1.0, 0.01) var shadow_opacity := 0.22
## Desplazamiento vertical de la sombra, en píxeles del dibujo.
@export_range(0.0, 16.0, 0.5) var shadow_offset := 4.0

@export_group("Contenido")
## "Tres puntos" es la burbuja de conversación de la referencia. "Botón" recupera E/X.
@export_enum("Tres puntos", "Botón") var content_style := 0
## Texto mostrado sólo en el modo Tres puntos.
@export var ellipsis_text := "..."
@export_range(2.0, 14.0, 0.5) var ellipsis_dot_radius := 4.0
@export_range(6.0, 30.0, 0.5) var ellipsis_spacing := 18.0
@export var ellipsis_color := Color("353331")
@export var button_color := Color("34343b")
## Símbolo de muestra del editor; en juego lo decide el dispositivo si eliges Botón.
@export var key_text := "X"

@export_group("Aparición · Pop-in")
## Activa la entrada con squash and stretch al aparecer cerca de un interactuable.
@export var appearance_enabled := true
## Escala inicial. 0,15 empieza muy pequeño; 0,45 es más sutil.
@export_range(0.05, 0.9, 0.01) var appearance_start_scale := 0.18
## Duración total del pop-in. 0,28 s se siente ágil; 0,45 s más juguetón.
@export_range(0.08, 1.0, 0.01) var appearance_duration := 0.28
## Cuánto se aplasta al llegar a tamaño normal. 0 lo desactiva; 0,12 es suave.
@export_range(0.0, 0.35, 0.01) var appearance_squash := 0.11
## Curva de crecimiento inicial. 1 es lineal; valores altos aceleran el final.
@export_range(1.0, 5.0, 0.1) var appearance_ease_power := 2.2

@export_group("Ubicación y movimiento")
## Elevación en juego. Cada interactuable la ajusta según su tamaño.
@export_range(0.0, 5.0, 0.05) var height := 2.5
## Altura adicional para todos los objetos en juego. Ejemplo: 0,3 eleva el icono.
@export_range(-1.0, 2.0, 0.05) var height_offset := 0.0
## Amplitud del movimiento vertical. Ejemplo: 0,06; 0 lo deja quieto.
@export_range(0.0, 0.3, 0.01) var bob_amount := 0.06
## Velocidad del movimiento. Ejemplo: 2,6.
@export_range(0.0, 8.0, 0.1) var bob_speed := 2.6

var elapsed := 0.0
var signature := ""
# El prompt no usa una escala de escena personalizada. Mantener este valor
# explícito evita que una recarga de @tool lea una escala temporal nula.
var base_scale: Vector3 = Vector3.ONE
var requested_visible := false
var appearance_clock := 0.0
var disappearance_clock := 0.0
@onready var icon: Sprite3D = $Icon
@onready var key_label: Label3D = $Key

func _ready() -> void:
	requested_visible = visible
	refresh()

## Muestra u oculta el prompt. Al ocultar conserva la visibilidad hasta que
## termine el pop-in invertido, para no cortar la animación de salida.
func set_prompt_visible(showing: bool) -> void:
	if showing == requested_visible:
		return
	requested_visible = showing
	if showing:
		visible = true
		appearance_clock = 0.0
	else:
		if not appearance_enabled:
			visible = false
			return
		disappearance_clock = 0.0

func _process(delta: float) -> void:
	refresh()
	if Engine.is_editor_hint():
		position.y = height_offset if preview_at_origin else height + height_offset
		scale = base_scale
		return
	if not visible:
		return
	if requested_visible:
		_update_appearance(delta)
	else:
		_update_disappearance(delta)
	elapsed += delta
	position.y = height + height_offset + sin(elapsed * bob_speed) * bob_amount

func _update_appearance(delta: float) -> void:
	if not appearance_enabled:
		scale = base_scale
		return
	appearance_clock = minf(appearance_clock + delta, appearance_duration)
	var duration := maxf(0.01, appearance_duration)
	var progress := appearance_clock / duration
	if progress < 0.62:
		var grow_progress := progress / 0.62
		var eased_grow := 1.0 - pow(1.0 - grow_progress, appearance_ease_power)
		scale = base_scale * lerpf(appearance_start_scale, 1.0, eased_grow)
	elif progress < 0.82:
		# El squash ocurre después de alcanzar su tamaño final, no durante el crecimiento.
		var squash_progress := (progress - 0.62) / 0.20
		var squash_amount := sin(squash_progress * PI) * appearance_squash
		scale = base_scale * Vector3(1.0 + squash_amount, 1.0 - squash_amount, 1.0)
	else:
		scale = base_scale

func _update_disappearance(delta: float) -> void:
	disappearance_clock = minf(disappearance_clock + delta, appearance_duration)
	var duration := maxf(0.01, appearance_duration)
	var progress := disappearance_clock / duration
	if progress < 0.24:
		# Primero un pequeño squash inverso, equivalente al rebote de entrada.
		var squash_amount := sin(progress / 0.24 * PI) * appearance_squash
		scale = base_scale * Vector3(1.0 + squash_amount, 1.0 - squash_amount, 1.0)
	else:
		var shrink_progress := (progress - 0.24) / 0.76
		var eased_shrink := pow(clampf(shrink_progress, 0.0, 1.0), appearance_ease_power)
		scale = base_scale * lerpf(1.0, appearance_start_scale, eased_shrink)
	if progress >= 1.0:
		scale = base_scale
		visible = false

func refresh() -> void:
	if not is_instance_valid(icon):
		return
	var next_signature := str([icon_width, bubble_height_ratio, bubble_width_ratio, outline_enabled, outline_width, tail_width, tail_height, tail_roundness, fill_color, outline_color, shadow_enabled, shadow_color, shadow_opacity, shadow_offset, content_style, ellipsis_text, ellipsis_dot_radius, ellipsis_spacing, ellipsis_color, button_color, key_text])
	if signature == next_signature:
		return
	signature = next_signature
	var image := Image.new()
	if image.load_svg_from_string(_bubble_svg(), 2.0) == OK:
		icon.texture = ImageTexture.create_from_image(image)
	icon.pixel_size = icon_width / 288.0
	key_label.visible = content_style == 1
	key_label.text = key_text
	key_label.pixel_size = icon_width / 144.0
	key_label.position.y = 0.08 * icon_width / 0.95

func _bubble_svg() -> String:
	var top := 12.0
	var bottom := top + 82.0 * bubble_height_ratio
	var left := 72.0 - 60.0 * bubble_width_ratio
	var right := 72.0 + 60.0 * bubble_width_ratio
	var upper_left := 72.0 - 34.0 * bubble_width_ratio
	var upper_right := 72.0 + 34.0 * bubble_width_ratio
	var lower_left := 72.0 - 37.0 * bubble_width_ratio
	var lower_right := 72.0 + 37.0 * bubble_width_ratio
	var tail_left := 72.0 - tail_width * 0.5
	var tail_right := 72.0 + tail_width * 0.5
	var tail_tip := bottom + tail_height
	# Los lados del rabito se conservan rectos. Tail Roundness sólo corta un
	# pequeño tramo cerca del vértice y redondea ese remate con una curva corta.
	var tip_round_progress := tail_roundness * 0.34
	var tail_near_left := Vector2(lerpf(72.0, tail_left, tip_round_progress), lerpf(tail_tip, bottom, tip_round_progress))
	var tail_near_right := Vector2(lerpf(72.0, tail_right, tip_round_progress), lerpf(tail_tip, bottom, tip_round_progress))
	var body_path := "M %f %f C %f %f %f 23 %f 40 L %f %f C %f %f %f %f %f %f L %f %f L %f %f Q 72 %f %f %f L %f %f L %f %f C %f %f %f %f %f %f L %f 40 C %f 23 %f %f %f %f Z" % [upper_left, top, left + 10.0, top, left, left, left, bottom - 17.0, left, bottom - 6.0, left + 9.0, bottom, lower_left, bottom, tail_left, bottom, tail_near_left.x, tail_near_left.y, tail_tip, tail_near_right.x, tail_near_right.y, tail_right, bottom, lower_right, bottom, right - 9.0, bottom, right, bottom - 7.0, right, bottom - 18.0, right, right, upper_right + 16.0, top, upper_right, top]
	var center_y := lerpf(top, bottom, 0.48)
	var dots_svg := ""
	if content_style == 0:
		var characters: int = maxi(1, ellipsis_text.length())
		for index in characters:
			var x := 72.0 + (float(index) - float(characters - 1) * 0.5) * ellipsis_spacing
			dots_svg += '<circle cx="%.2f" cy="%.2f" r="%.2f" fill="#%s"/>' % [x, center_y, ellipsis_dot_radius, ellipsis_color.to_html(false)]
	else:
		dots_svg = '<rect x="43" y="34" width="58" height="%f" rx="17" fill="#%s" stroke="#%s" stroke-width="2"/><rect x="47" y="38" width="50" height="%f" rx="14" fill="none" stroke="#f5f1ea" stroke-width="2"/>' % [bottom - 30.0, button_color.to_html(false), outline_color.to_html(false), bottom - 38.0]
	var stroke_color := "none" if not outline_enabled else "#%s" % outline_color.to_html(false)
	var stroke_width := 0.0 if not outline_enabled else outline_width
	var shadow_alpha := shadow_opacity if shadow_enabled else 0.0
	var canvas_left := minf(0.0, left - outline_width)
	var canvas_right := maxf(144.0, right + outline_width)
	var canvas_width := canvas_right - canvas_left
	return '<svg xmlns="http://www.w3.org/2000/svg" width="%.2f" height="144" viewBox="%.2f 0 %.2f 144"><path d="%s" fill="#%s" opacity="%.3f" transform="translate(0 %.2f)"/><path d="%s" fill="#%s" stroke="%s" stroke-width="%.2f" stroke-linejoin="round"/>%s</svg>' % [canvas_width, canvas_left, canvas_width, body_path, shadow_color.to_html(false), shadow_alpha, shadow_offset, body_path, fill_color.to_html(false), stroke_color, stroke_width, dots_svg]
