class_name TrailInteractable
extends Node3D

@export var interaction_id := ""
@export var verb := "Leer"
@export var display_name := ""
@export_multiline var pages: Array[String] = []
@export var available := true
var prompt_label: Label3D

func build_prompt(height := 2.5) -> void:
	add_to_group("interactable")
	prompt_label = Label3D.new()
	prompt_label.font_size = 32
	prompt_label.pixel_size = 0.005
	prompt_label.outline_size = 8
	prompt_label.modulate = Color("fff0cc")
	prompt_label.position.y = height
	prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt_label.no_depth_test = false
	prompt_label.visible = false
	add_child(prompt_label)

func prompt_text(gamepad: bool) -> String:
	return ("[X]  " if gamepad else "[E]  ") + verb

func show_prompt(showing: bool, gamepad: bool) -> void:
	if prompt_label:
		prompt_label.text = prompt_text(gamepad)
		prompt_label.visible = showing and available
