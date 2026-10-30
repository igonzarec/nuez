class_name TrailInteractable
extends Node3D

## Identificador usado por la partida; cambiarlo puede separar el estado guardado. Reiniciar.
@export var interaction_id := ""
## Verbo mostrado en el prompt textual. En vivo al seleccionar de nuevo.
@export var verb := "Leer"
## Nombre visible del interlocutor u objeto. Al abrir la interacción.
@export var display_name := ""
## Segunda línea amarilla debajo del nombre en el cuadro de diálogo.
@export var dialogue_subtitle := ""
## Páginas manuales del diálogo; se leen al abrir.
@export_multiline var pages: Array[String] = []
## Archivo .dialogue con conversaciones y respuestas.
@export var dialogue_resource: DialogueResource
## Título inicial dentro del recurso Dialogue Resource. Al abrir.
@export var dialogue_title := "start"
## Permite seleccionar este objeto. En vivo.
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

## Distancia máxima propia en metros; 0 utiliza Reach del selector. En vivo.
@export_range(0.0, 12.0, 0.1) var interaction_reach := 0.0
var activation: Callable
var eligibility: Callable
var collision_exclusions: Array[RID] = []

func can_interact() -> bool:
	return available and (not eligibility.is_valid() or eligibility.call())

## Altura del extremo del rayo de visibilidad, en metros. Ajustar al tamaño del actor. En vivo.
@export_range(0.1, 3.0, 0.05) var sight_height := 0.8
## Exige que el objeto lejano no quede detrás del jugador. Los NPC conservan selección omnidireccional. En vivo.
@export var require_facing := true
