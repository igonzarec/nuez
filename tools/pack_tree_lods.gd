extends SceneTree
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://resources/trees/lods")
	for n in range(1,6):
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var error := doc.append_from_file(ProjectSettings.globalize_path("res://../tmp/tree_lods/PineTree_%d_far.glb" % n),state)
		if error != OK:
			push_error("GLB conversion failed")
			quit(1)
			return
		var root := doc.generate_scene(state)
		var meshes := root.find_children("*","MeshInstance3D",true,false)
		if meshes.is_empty():
			push_error("No far mesh")
			quit(1)
			return
		var mesh: ArrayMesh = load("res://scripts/tree_lod_mesh.gd").build(meshes[0].mesh, 1.0)
		mesh.resource_name = "PineTree_%d_Far" % n
		for surface in mesh.get_surface_count():
			mesh.surface_get_material(surface).resource_name = mesh.surface_get_material(surface).resource_name.get_slice(".",0)
		print(mesh.resource_name," bounds=",mesh.get_aabb()," materials=",mesh.surface_get_material(0).resource_name, "/",mesh.surface_get_material(1).resource_name)
		ResourceSaver.save(mesh,"res://resources/trees/lods/pine_%d_far.res" % n,ResourceSaver.FLAG_COMPRESS)
		root.free()
	quit()
