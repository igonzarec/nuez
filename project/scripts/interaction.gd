class_name TrailInteraction
extends Node

signal selected_changed(target: TrailInteractable)
@export var reach := 2.8
var player: ExplorerPlayer
var selected: TrailInteractable
var enabled := false
var gamepad := false

func _physics_process(_delta: float) -> void:
	var next: TrailInteractable = null
	var best := reach
	if enabled:
		for item: Node in get_tree().get_nodes_in_group("interactable"):
			if not item is TrailInteractable or not item.available:
				continue
			var offset: Vector3 = item.global_position - player.global_position
			var distance := offset.length()
			var facing := -player.model.global_basis.z
			if distance < best and (distance < 1.5 or facing.dot(offset.normalized()) > -0.15):
				var ray := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP, item.global_position + Vector3.UP, 1, [player.get_rid()])
				if player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
					next = item
					best = distance
	if next != selected:
		if is_instance_valid(selected):
			selected.show_prompt(false, gamepad)
		selected = next
		if selected:
			selected.show_prompt(true, gamepad)
		selected_changed.emit(selected)

func clear() -> void:
	if is_instance_valid(selected):
		selected.show_prompt(false, gamepad)
	selected = null
	selected_changed.emit(null)
