extends Node3D

## Standalone viewer for the handmade Nuez model. It does not replace the
## existing player scene; open this scene to inspect the exported Run clip.

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	# Use the actual run action exported by Blender, even if Godot prefixes it.
	var animation_player := _find_animation_player($Model)
	if animation_player:
		for animation_name in animation_player.get_animation_list():
			if String(animation_name).ends_with("Run"):
				animation_player.play(animation_name)
				break
	camera.look_at(Vector3(0.0, 0.3, 0.0), Vector3.UP)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null
