class_name TrailInteraction
extends Node
## Selección común de carteles, NPC y objetos. Un selector por jugador.
signal selected_changed(target: TrailInteractable)
## Distancia por defecto en metros; cada objetivo puede sobrescribirla. En vivo.
@export_range(0.1, 12, 0.1) var reach := 2.8
var player: ExplorerPlayer
var selected: TrailInteractable
var enabled := false
var gamepad := false
var standalone := false

func _ready() -> void:
	add_to_group("interaction_controllers")
	process_mode = Node.PROCESS_MODE_PAUSABLE

static func ensure_for(actor: ExplorerPlayer) -> TrailInteraction:
	for node in actor.get_tree().get_nodes_in_group("interaction_controllers"):
		if node.player == actor: return node
	var controller := TrailInteraction.new()
	controller.player = actor
	controller.enabled = true
	controller.standalone = true
	actor.add_child(controller)
	return controller

func refresh_target() -> void:
	var next: TrailInteractable
	var best := INF
	if enabled and is_instance_valid(player) and player.control_enabled and player.can_start_npc_dialogue() and not get_tree().paused and not get_tree().get_first_node_in_group("active_dialogue"):
		for item: Node in get_tree().get_nodes_in_group("interactable"):
			if not item is TrailInteractable or not item.can_interact(): continue
			var offset: Vector3 = item.global_position - player.global_position
			var distance := offset.length()
			var limit: float = item.interaction_reach if item.interaction_reach > 0 else reach
			var facing := -player.model.global_basis.z
			if distance > limit or distance >= best or (item.require_facing and distance >= 1.5 and facing.dot(offset.normalized()) <= -0.15): continue
			var excluded: Array[RID] = [player.get_rid()]
			excluded.append_array(item.collision_exclusions)
			var ray := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 0.8, item.global_position + Vector3.UP * item.sight_height, 1, excluded)
			if player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
				next = item
				best = distance
	if next != selected:
		if is_instance_valid(selected): selected.show_prompt(false, gamepad)
		selected = next
		selected_changed.emit(selected)
	if is_instance_valid(selected): selected.show_prompt(true, gamepad)

func _physics_process(_delta: float) -> void:
	refresh_target()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo: return
	if event is InputEventJoypadButton:
		gamepad = true
		TrailInput.active_device = event.device
	elif event is InputEventKey or event is InputEventMouseButton: gamepad = false
	if not standalone: return
	if event.is_action_pressed("interact") or (event is InputEventJoypadButton and event.is_action_pressed("ui_accept")):
		refresh_target()
		if is_instance_valid(selected) and selected.activation.is_valid():
			player.consume_interaction_press()
			get_viewport().set_input_as_handled()
			selected.activation.call()

func clear() -> void:
	if is_instance_valid(selected): selected.show_prompt(false, gamepad)
	selected = null
	selected_changed.emit(null)
