@tool
extends EditorPlugin
func _enter_tree() -> void:
	run.call_deferred()
func run() -> void:
	for i in 20: await get_tree().process_frame
	EditorInterface.open_scene_from_path("res://preview.tscn")
	for i in 30: await get_tree().process_frame
	var scene := EditorInterface.get_edited_scene_root()
	if scene == null:
		print("EDITOR CHECK no scene")
		get_tree().quit(2)
		return
	var terrain: Terrain3D = scene.get_node("Terrain3D")
	if not terrain.data.has_region(Vector2i.ZERO): terrain.data.add_region_blank(Vector2i.ZERO)
	var details = terrain.get_node("SurfaceDetails")
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(details)
	for i in 5: await get_tree().process_frame
	var painter: Node
	for node in get_parent().get_children():
		if node.get_script() and node.get_script().resource_path == "res://addons/surface_painter/plugin.gd": painter = node
	print("EDITOR PANEL ",painter != null)
	if painter == null:
		get_tree().quit(3)
		return
	painter._edit(details)
	print("EDITOR TARGET ",painter._component == details," base_default=",painter._base.button_pressed)
	details.brush_strength = 1.0
	details.paint_layer = 0
	details.snow.texture_id = 1
	details.begin_stroke(false)
	details.dab(Vector3(8,0,8),false)
	painter._stroke = true
	painter._finish_stroke()
	var history := get_undo_redo().get_history_undo_redo(get_undo_redo().get_object_history_id(details))
	print("EDITOR PAINT ",details.paint_data.coverage(Vector2(8,8),0)," texture=",terrain.data.get_control_overlay_id(Vector3(8,0,8)))
	history.undo()
	print("EDITOR UNDO ",details.paint_data.coverage(Vector2(8,8),0)," texture=",terrain.data.get_control_overlay_id(Vector3(8,0,8)))
	history.redo()
	print("EDITOR REDO ",details.paint_data.coverage(Vector2(8,8),0)," texture=",terrain.data.get_control_overlay_id(Vector3(8,0,8)))
	EditorInterface.save_scene()
	print("EDITOR SAVED ",FileAccess.file_exists("res://resources/surface_details/grass_paint.res")," terrain=",FileAccess.file_exists("res://terrain_data/terrain3d_00_00.res"))
	for i in 5: await get_tree().process_frame
	get_tree().quit()
