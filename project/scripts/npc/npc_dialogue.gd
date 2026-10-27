extends Node
## Conversación de proximidad reutilizable con el globo y prompt existentes.

const PromptScene = preload("res://ui/interaction/interaction_prompt.tscn")
const BalloonScene = preload("res://ui/dialogue/squirrel_dialogue_balloon.tscn")

var _npc: SquirrelNPC
var _body: ExplorerPlayer
var _player: ExplorerPlayer
var _prompt: Node3D
var _balloon: SquirrelDialogueBalloon
var _near := false
var _clock := 0.0
var _gamepad := false

func _ready() -> void:
	_npc = get_parent() as SquirrelNPC
	_body = _npc.get_node("Body") as ExplorerPlayer
	_prompt = PromptScene.instantiate()
	_prompt.visible = false
	_body.add_child(_prompt)

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
		if not _npc.dialogue_enabled or not is_instance_valid(_player):
			_close_dialogue()
		return
	_clock -= delta
	if _clock > 0.0:
		return
	_clock = 0.15
	_near = false
	if not is_instance_valid(_player):
		_player = _find_player(get_tree().current_scene) if get_tree().current_scene else null
	if is_instance_valid(_player) and _player.control_enabled and not get_tree().paused and not get_tree().get_first_node_in_group("active_dialogue"):
		var best := INF
		var nearest: SquirrelNPC
		for item in get_tree().get_nodes_in_group("npcs"):
			var candidate := item as SquirrelNPC
			if not candidate or not candidate.dialogue_enabled or candidate.dialogue_text.strip_edges().is_empty():
				continue
			var actor := candidate.get_node("Body") as ExplorerPlayer
			if not actor.is_on_floor() or actor.is_splat or actor.is_climbing:
				continue
			var distance := _player.global_position.distance_to(actor.global_position)
			if distance > candidate.dialogue_reach or distance >= best:
				continue
			var size := candidate.overall_size if candidate.proportions_enabled else 1.0
			var ray := PhysicsRayQueryParameters3D.create(_player.global_position + Vector3.UP * 0.8, actor.global_position + Vector3.UP * 0.8 * size, 1, [_player.get_rid(), actor.get_rid()])
			if _player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
				nearest = candidate
				best = distance
		_near = nearest == _npc
	var size := _npc.overall_size if _npc.proportions_enabled else 1.0
	_prompt.set("height", _npc.dialogue_prompt_height * size)
	_prompt.set("key_text", TrailInput.interaction_glyph() if _gamepad else "E")
	_prompt.call("set_prompt_visible", _near)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event is InputEventJoypadButton:
		_gamepad = true
		TrailInput.active_device = event.device
	elif event is InputEventKey or event is InputEventMouseButton:
		_gamepad = false
	if is_instance_valid(_balloon) or not _near or get_tree().paused or not is_instance_valid(_player) or not _player.control_enabled:
		return
	if get_tree().get_first_node_in_group("active_dialogue"):
		return
	var contextual_accept := event is InputEventJoypadButton and event.is_action_pressed("ui_accept") and _player.is_on_floor()
	if event.is_action_pressed("interact") or contextual_accept:
		if contextual_accept:
			_player.consume_interaction_press()
		get_viewport().set_input_as_handled()
		_open_dialogue()

func _open_dialogue() -> void:
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
	_balloon.show_manual(_npc.display_name, _npc.dialogue_text)

func _close_dialogue() -> void:
	if is_instance_valid(_npc):
		_npc.dialogue_speaking = false
	if not is_instance_valid(_balloon):
		return
	_balloon.release_interlocutors()
	_balloon.queue_free()
	_balloon = null
	_near = false
	_clock = 0.15

func _exit_tree() -> void:
	_close_dialogue()
