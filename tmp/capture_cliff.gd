extends SceneTree
var frames := 0
func _initialize():
    var scene = load("res://scenes/cliff_playground.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
func _process(_delta):
    frames += 1
    if frames == 80:
        capture.call_deferred()
    return false
func capture():
    var world = current_scene.get_world_3d().direct_space_state
    for x in [24.1,64.1,104.1]:
        var front = world.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,6,48),Vector3(x,6,35),1))
        var top = world.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,25,35),Vector3(x,-2,35),1))
        print("CLIFF INSPECTION x=",x," wall=",front.get("position")," top=",top.get("position"))
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://../tmp/cliff_comparison.png")
    quit()



