extends SceneTree
var frames := 0
func _initialize():
	var args = OS.get_cmdline_user_args()
	var scene = load(args[0]).instantiate()
	root.add_child(scene)
	root.size = Vector2i(1100, 750)
func _process(_delta):
	frames += 1
	if frames == 49 and OS.get_cmdline_user_args()[0].contains("playertest2"):
		var cam = root.get_viewport().get_camera_3d()
		cam.global_position = Vector3(1.27, 2.0, 5.5)
		cam.look_at(Vector3(1.27, 1.8, 0.0))
	if frames == 49 and OS.get_cmdline_user_args()[0].contains("terrain_snow"):
		var overview = Camera3D.new()
		root.add_child(overview)
		overview.global_position = Vector3(150, 160, 160)
		overview.look_at(Vector3(0, 10, -50))
		overview.make_current()
	if frames == 50:
		capture.call_deferred()
func capture():
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[1])
	quit()


