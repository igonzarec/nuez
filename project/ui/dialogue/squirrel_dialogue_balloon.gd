@tool
class_name SquirrelDialogueBalloon
extends DialogueManagerExampleBalloon
const PagedLabel = preload("res://ui/dialogue/paged_dialogue_label.gd")
## Tono por nombre exacto del hablante. 1 normal, 0.8 grave, 1.3 agudo.
## También cubre conversaciones con varios personajes en un mismo .dialogue.
@export var character_voice_pitches: Dictionary[String, float] = {"Mara": 1.15}
@export_range(0.5, 2.5, 0.05) var default_voice_pitch := 1.0
## Perfiles por nombre exacto. Guarda un .tres distinto por personaje para separar ajustes.
## El pitch del perfil se multiplica por Character Voice Pitches (1 = sin cambio extra).
@export var character_voice_profiles: Dictionary[String, AnimaleseProfile] = {"Mara": preload("res://audio/animalese/mara.tres")}

## Globo de Lantern Trail. Es nuestro archivo, no una modificación del plugin.
## El motor entrega personaje, texto y respuestas; aquí solo decidimos diseño e input.

@onready var speaker_pill: PanelContainer = %SpeakerPill
@onready var page_label: PagedLabel = %DialogueLabel
signal close_requested
signal advance_requested
var manual_mode := false
var speaker_subtitle := ""

func set_follow_target(target: Node3D) -> void:
	$Balloon/DialogueBox.set_follow_target(target)

func set_speaker_name(speaker_name: String, subtitle := "") -> void:
	speaker_subtitle = subtitle
	$Balloon/DialogueBox.set_speaker_name(speaker_name, subtitle)

func _ready() -> void:
	if Engine.is_editor_hint():
		show()
		%Balloon.show()
		%Balloon.modulate = Color.WHITE
		$Balloon/DialogueBox.show()
		%ResponsesMenu.hide()
		return
	# El mismo botón abre, avanza y confirma diálogos: E en teclado, X/cuadrado
	# en control. ui_cancel mantiene Esc / B como salida.
	next_action = &"interact"
	skip_action = &"interact"
	super._ready()

func apply_dialogue_line() -> void:
	page_label.active_voice_profile = character_voice_profiles.get(dialogue_line.character)
	page_label.speaker_pitch = character_voice_pitches.get(dialogue_line.character, default_voice_pitch)
	super.apply_dialogue_line()
	speaker_pill.visible = not dialogue_line.character.is_empty()
	$Balloon/DialogueBox.set_speaker_name(dialogue_line.character)
	$Balloon/DialogueBox.play_appearance()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if manual_mode:
		progress.visible = not page_label.is_typing or page_label.waiting_for_page
	else:
		super._process(delta)
		if page_label.waiting_for_page:
			progress.show()
	var box := $Balloon/DialogueBox as Control
	# Respuestas independientes de la escala del globo, para conservar legibilidad.
	var rect := box.get_global_rect()
	responses_menu.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var menu_size := responses_menu.get_combined_minimum_size()
	var viewport_size := get_viewport().get_visible_rect().size
	var menu_y := rect.position.y - menu_size.y - 65
	if menu_y < 15:
		menu_y = rect.end.y + 30
	responses_menu.position = Vector2(
		clampf(rect.end.x - menu_size.x, 15, maxf(15, viewport_size.x - menu_size.x - 15)),
		clampf(menu_y, 15, maxf(15, viewport_size.y - menu_size.y - 15)))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if Engine.is_editor_hint() or not visible or (not manual_mode and not is_instance_valid(dialogue_line)):
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_requested.emit()
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_advance_content()

func _advance_content() -> void:
	if page_label.waiting_for_page and page_label.next_page():
		return
	if dialogue_label.is_typing:
		dialogue_label.skip_typing()
	elif manual_mode:
		advance_requested.emit()
	elif dialogue_line.responses.size() > 0:
		var focused := get_viewport().gui_get_focus_owner()
		if focused in responses_menu.get_menu_items():
			_on_responses_menu_response_selected(focused.get_meta("response"))
	elif is_waiting_for_input:
		next(dialogue_line.next_id)

func show_manual(speaker: String, text: String) -> void:
	page_label.active_voice_profile = character_voice_profiles.get(speaker)
	page_label.speaker_pitch = character_voice_pitches.get(speaker, default_voice_pitch)
	manual_mode = true
	balloon.show()
	speaker_pill.visible = not speaker.is_empty()
	character_label.text = speaker
	$Balloon/DialogueBox.set_speaker_name(speaker, speaker_subtitle)
	page_label.show_manual_text(text)
	dialogue_label.show()
	responses_menu.hide()
	progress.show()
	balloon.focus_mode = Control.FOCUS_ALL
	balloon.grab_focus()
	$Balloon/DialogueBox.play_appearance()

func _on_balloon_gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled()
		_advance_content()
