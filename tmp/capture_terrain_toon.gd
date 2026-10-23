extends SceneTree

func _initialize() -> void:
    capture.call_deferred()

func capture() -> void:
    var scene: Node = load("res://scenes/3D_playground.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    for frame in 80:
        await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("C:/Users/USER/Documents/Game Development/games/explorer squirrel/tmp/terrain_toon_preview.png")
    quit()