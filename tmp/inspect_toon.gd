extends SceneTree
func _initialize() -> void:
	var scene = load("res://scenes/grass_terrain.tscn").instantiate()
	var terrain = scene.get_node("Terrain3D")
	var code: String = RenderingServer.shader_get_code(terrain.material.get_shader_rid())
	print("Terrain shader length=", code.length(), " modes=", code.substr(0, 260))
	FileAccess.open("res://../tmp/terrain_original_shader.txt", FileAccess.WRITE).store_string(code)
	scene.free()
	quit()
