extends SceneTree
func _initialize() -> void:
	capture.call_deferred()
func capture() -> void:
	var scene = load("res://scenes/3D_playground.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 15:
		await process_frame
	var cameras = scene.find_children("*", "Node3D", true, false)
	var rig: Node
	for candidate in cameras:
		if candidate is TrailCamera:
			rig = candidate
	if rig == null:
		quit(2)
		return
	var terrain: Terrain3D = scene.find_child("Terrain3D", true, false)
	print("ORIGINAL TERRAIN SHADER ", RenderingServer.shader_get_code(terrain.material.get_shader_rid()).length())
	var original_material: Terrain3DMaterial = terrain.material
	rig.toon_enabled = false
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../tmp/toon_before.png")
	rig.toon_enabled = true
	for i in 12: await process_frame
	print("TOON TERRAIN ", terrain.material.shader_override_enabled, " material_changed=", terrain.material != original_material)
	print("TOON RECORDS ", rig._toon_preview._changes.size())
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../tmp/toon_after.png")
	paused = true
	rig.toon_enabled = false
	for i in 4: await process_frame
	print("RESTORED IN PAUSE ", terrain.material == original_material)
	var ui = root.get_node("ScenePause").get("_ui")
	if ui:
		ui.settings({"master":0.8,"music":0.45,"sfx":0.75,"climb_sfx":0.5,"sensitivity":1.0,"fullscreen":false,"resolution":"1280x720","toon_enabled":true})
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../tmp/toon_settings.png")
	quit()

