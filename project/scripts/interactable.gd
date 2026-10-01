class_name TrailInteractable
extends Node3D

@export var interaction_id := ""
@export var verb := "Leer"
@export var display_name := ""
## Segunda línea amarilla debajo del nombre en el cuadro de diálogo.
@export var dialogue_subtitle := ""
@export_multiline var pages: Array[String] = []
## Archivo .dialogue con conversaciones y respuestas.
@export var dialogue_resource: DialogueResource
@export var dialogue_title := "start"
@export var available := true
var prompt_label: Label3D
var prompt_pin: Node3D

func has_dialogue() -> bool:
	return dialogue_resource != null

func build_prompt(height := 2.5) -> void:
	add_to_group("interactable")
	prompt_pin = preload("res://ui/interaction/interaction_prompt.tscn").instantiate()
	prompt_pin.height = height
	prompt_pin.visible = false
	add_child(prompt_pin)
	prompt_label = prompt_pin.get_node("Key")

func prompt_text(gamepad: bool) -> String:
	return ("[" + TrailInput.interaction_glyph() + "]  " if gamepad else "[E]  ") + verb

func show_prompt(showing: bool, gamepad: bool) -> void:
	if prompt_pin:
		prompt_pin.key_text = TrailInput.interaction_glyph() if gamepad else "E"
		prompt_pin.refresh()
		prompt_pin.call("set_prompt_visible", showing and available)
