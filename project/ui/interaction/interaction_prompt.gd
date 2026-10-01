@tool
extends Node3D
## Prompt independiente del diálogo. Abre interaction_prompt.tscn para editarlo en 3D.
## Ancho en metros. Ejemplo: 0,95; 0,65 lo hace más discreto.
@export_range(0.2, 1.5, 0.01) var icon_width := 0.95
## Elevación de la vista previa. En juego cada interactuable fija la altura según su tamaño.
@export_range(0, 5, 0.05) var height := 2.5
## Altura adicional para todos los objetos en juego. Ejemplo: 0,3 eleva el icono.
@export_range(-1, 2, 0.05) var height_offset := 0.0
## Amplitud del movimiento vertical. Ejemplo: 0,06; 0 lo deja quieto.
@export_range(0, 0.3, 0.01) var bob_amount := 0.06
## Velocidad del movimiento. Ejemplo: 2,6.
@export_range(0, 8, 0.1) var bob_speed := 2.6
@export var fill_color := Color("fff3df")
@export var outline_color := Color("453c3a")
@export var button_color := Color("34343b")
## Símbolo de muestra del editor; en juego lo decide el dispositivo.
@export var key_text := "X"
var elapsed := 0.0
var signature := ""
@onready var icon: Sprite3D = $Icon
@onready var key_label: Label3D = $Key

func _ready() -> void:
	refresh()

func _process(delta: float) -> void:
	refresh()
	if Engine.is_editor_hint() or not is_visible_in_tree():
		return
	elapsed += delta
	position.y = height + height_offset + sin(elapsed * bob_speed) * bob_amount

func refresh() -> void:
	if not is_instance_valid(icon):
		return
	var next_signature := str([icon_width, height, height_offset, fill_color, outline_color, button_color, key_text])
	if signature == next_signature:
		return
	signature = next_signature
	position.y = height + height_offset
	# Vector propio: pequeña burbuja crema, punta inferior y botón oscuro.
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="144" height="160" viewBox="0 0 144 160"><defs><linearGradient id="cream" x2="0" y2="1"><stop stop-color="#ffffff"/><stop offset="1" stop-color="#%s"/></linearGradient></defs><path d="M35 15 Q17 15 17 37 L17 102 Q17 118 34 119 L49 119 L65 145 Q72 155 79 144 L94 119 L109 119 Q127 118 127 101 L127 37 Q127 15 107 15 Z" fill="#000000" opacity=".16" transform="translate(0 4)"/><path d="M35 11 Q17 11 17 33 L17 98 Q17 114 34 115 L49 115 L65 141 Q72 151 79 140 L94 115 L109 115 Q127 114 127 97 L127 33 Q127 11 107 11 Z" fill="url(#cream)" stroke="#%s" stroke-width="3"/><rect x="43" y="34" width="58" height="62" rx="17" fill="#%s" stroke="#%s" stroke-width="2"/><rect x="47" y="38" width="50" height="54" rx="14" fill="none" stroke="#f5f1ea" stroke-width="2"/></svg>' % [fill_color.to_html(false), outline_color.to_html(false), button_color.to_html(false), outline_color.to_html(false)]
	var image := Image.new()
	if image.load_svg_from_string(svg, 2.0) == OK:
		icon.texture = ImageTexture.create_from_image(image)
	icon.pixel_size = icon_width / 288.0
	key_label.text = key_text
	key_label.pixel_size = icon_width / 144.0
	key_label.position.y = (80.0 - 65.0) * icon_width / 144.0
