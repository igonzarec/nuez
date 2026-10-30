extends Node
## Conversación de proximidad reutilizable con el globo y prompt existentes.

const PromptScene = preload("res://ui/interaction/interaction_prompt.tscn")
const BalloonScene = preload("res://ui/dialogue/squirrel_dialogue_balloon.tscn")

var _npc: SquirrelNPC
var _body: ExplorerPlayer
var _player: ExplorerPlayer
var _prompt: Node3D
var _balloon: SquirrelDialogueBalloon
var _clock := 0.0
var _interactable: TrailInteractable

func _ready() -> void:
	_npc = get_parent() as SquirrelNPC
	_body = _npc.get_node("Body") as ExplorerPlayer
	_prompt = PromptScene.instantiate()
	_prompt.visible = false
	_body.add_child(_prompt)
	_interactable = TrailInteractable.new()
	_interactable.display_name = _npc.display_name
	_interactable.verb = "Hablar"
	_interactable.require_facing = false
	_interactable.activation = _open_dialogue
	_interactable.eligibility = _eligible
	_interactable.collision_exclusions = [_body.get_rid()]
	_interactable.prompt_pin = _prompt
	_body.add_child(_interactable)
	_interactable.add_to_group("interactable")


func _find_player(node: Node) -> ExplorerPlayer:
	if node is ExplorerPlayer and not is_instance_valid(node.command_source):
		return node as ExplorerPlayer
	for child in node.get_children():
		var found := _find_player(child)
		if found:
			return found
	return null

func _process(delta: float) -> void:
	if is_instance_valid(_balloon):
		_npc.dialogue_speaking = _balloon.page_label.is_typing and not _balloon.page_label.waiting_for_page
		if not _npc.dialogue_enabled or not is_instance_valid(_player) or _player.npc_bounce_in_progress or _player.get_npc_support():
			_close_dialogue()
		return
	_clock -= delta
	if _clock > 0.0:
		return
	_clock = 0.15
	if not is_instance_valid(_player):
		_player = _find_player(get_tree().current_scene) if get_tree().current_scene else null
	if is_instance_valid(_player): TrailInteraction.ensure_for(_player)
	_interactable.interaction_reach = _npc.dialogue_reach
	var size := _npc.overall_size if _npc.proportions_enabled else 1.0
	_prompt.set("height", _npc.dialogue_prompt_height * size)
	_interactable.sight_height = 0.8 * size

func _eligible() -> bool:
	return is_instance_valid(_player) and _npc.dialogue_enabled and not _npc.dialogue_text.strip_edges().is_empty() and _body.is_on_floor() and not _body.is_splat and not _body.is_climbing and not is_instance_valid(_balloon)

## Abre una reacción con el mismo bloqueo, mirada y globo de la conversación normal.
## El llamador puede reintentar mientras el jugador termina de aterrizar.
func try_open_reaction(player: ExplorerPlayer, text: String) -> bool:
	if not _npc.dialogue_enabled or text.strip_edges().is_empty() or get_tree().paused:
		return false
	if is_instance_valid(_balloon) or get_tree().get_first_node_in_group("active_dialogue"):
		return false
	if not is_instance_valid(player) or not player.can_start_npc_dialogue():
		return false
	# is_on_floor conserva el último contacto hasta el siguiente move_and_slide.
	# No abrir el regaño en ese frame si el resorte acaba de impulsarlo.
	if player.velocity.y > 0.0:
		return false
	if not _body.is_on_floor() or _body.is_splat or _body.is_climbing:
		return false
	if player.global_position.distance_to(_body.global_position) > _npc.dialogue_reach:
		return false
	var ray := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 0.8, _body.global_position + Vector3.UP * 0.8, 1, [player.get_rid(), _body.get_rid()])
	if not player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		return false
	_player = player
	return _open_dialogue(text)

func _open_dialogue(text: String = "") -> bool:
	# Validar en el instante de abrir, no sólo al actualizar el prompt.
	if not is_instance_valid(_player) or not _player.can_start_npc_dialogue():
		return false
	if _npc.face_on_dialogue:
		_player.face_interaction_partner(_body)
		_body.face_interaction_partner(_player)
	_prompt.call("set_prompt_visible", false)
	_balloon = BalloonScene.instantiate() as SquirrelDialogueBalloon
	add_child(_balloon)
	_balloon.bind_interlocutors([_player, _body])
	_balloon.set_speaker_name(_npc.display_name)
	_balloon.set_follow_target(_body)
	_balloon.close_requested.connect(_close_dialogue)
	_balloon.advance_requested.connect(_close_dialogue)
	_balloon.show_manual(_npc.display_name, text if not text.is_empty() else _npc.dialogue_text)
	return true

func _close_dialogue() -> void:
	if is_instance_valid(_npc):
		_npc.dialogue_speaking = false
	if not is_instance_valid(_balloon):
		return
	_balloon.release_interlocutors()
	_balloon.queue_free()
	_balloon = null
	_clock = 0.15

func _exit_tree() -> void:
	_close_dialogue()
