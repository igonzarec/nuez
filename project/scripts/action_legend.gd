@tool
extends CanvasLayer
## Muestra u oculta la leyenda de acciones en el editor y durante el juego.
@export var show_action_legend := true:
	set(value):
		show_action_legend = value
		visible = value

func _ready() -> void:
	visible = show_action_legend
