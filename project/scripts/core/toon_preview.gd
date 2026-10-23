extends Node
## Vista toon reversible. Sólo modifica recursos en memoria durante la ejecución.

var source: Node
var _signature := Vector2(-1, -1)
var _changes: Array[Dictionary] = []
var _materials: Dictionary = {}
var _meshes: Dictionary = {}
var _pending := false
var _new_nodes: Array[Node] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_node_added)

func _process(_delta: float) -> void:
	var signature := Vector2(float(source.toon_enabled), source.toon_softness)
	if signature == _signature:
		return
	_restore()
	_signature = signature
	if source.toon_enabled:
		_scan(get_tree().current_scene)

func _node_added(node: Node) -> void:
	if source.toon_enabled:
		_new_nodes.append(node)
		if not _pending:
			_pending = true
			_refresh.call_deferred()

func _refresh() -> void:
	_pending = false
	var nodes := _new_nodes.duplicate()
	_new_nodes.clear()
	var scene := get_tree().current_scene
	if source.toon_enabled and is_instance_valid(scene):
		for node in nodes:
			if is_instance_valid(node) and node.is_inside_tree() and (node == scene or scene.is_ancestor_of(node)):
				_scan(node)

func _scan(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node is Terrain3D:
		_terrain(node)
	if node is GeometryInstance3D:
		_property(node, "material_override", _material(node.material_override))
		_property(node, "material_overlay", _material(node.material_overlay))
	if node is MeshInstance3D and node.mesh:
		_mesh(node.mesh)
		for surface in node.mesh.get_surface_count():
			var original: Material = node.get_surface_override_material(surface)
			var replacement := _material(original)
			if replacement != original:
				_changes.append({"target": node, "surface": surface, "override": true,
					"original": original, "replacement": replacement})
				node.set_surface_override_material(surface, replacement)
	if node is MultiMeshInstance3D and node.multimesh:
		_mesh(node.multimesh.mesh)
	if node is GPUParticles3D:
		for pass_index in node.draw_passes:
			_mesh(node.get_draw_pass_mesh(pass_index))
	for child in node.get_children():
		_scan(child)

func _mesh(mesh: Mesh) -> void:
	if mesh == null or _meshes.has(mesh):
		return
	_meshes[mesh] = true
	for surface in mesh.get_surface_count():
		var original := mesh.surface_get_material(surface)
		var replacement := _material(original)
		if replacement != original:
			_changes.append({"target": mesh, "surface": surface, "override": false,
				"original": original, "replacement": replacement})
			mesh.surface_set_material(surface, replacement)

func _property(target: Object, property: String, replacement: Variant) -> void:
	var original: Variant = target.get(property)
	if original == replacement:
		return
	_changes.append({"target": target, "property": property,
		"original": original, "replacement": replacement})
	target.set(property, replacement)

func _material(original: Material) -> Material:
	if original == null:
		return null
	if _materials.has(original):
		return _materials[original]
	var replacement: Material = original
	if original is BaseMaterial3D and original.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL:
		var toon := original.duplicate() as BaseMaterial3D
		toon.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		toon.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		toon.roughness = source.toon_softness
		replacement = toon
	elif original is ShaderMaterial and original.shader:
		var code := _toon_code(original.shader.code)
		if not code.is_empty():
			var toon := original.duplicate() as ShaderMaterial
			var shader := Shader.new()
			shader.code = code
			toon.shader = shader
			toon.set_shader_parameter("trail_toon_softness", source.toon_softness)
			replacement = toon
	_materials[original] = replacement
	_materials[replacement] = replacement
	return replacement

func _terrain(terrain: Terrain3D) -> void:
	var original := terrain.material
	if original == null or _materials.has(original):
		return
	var code := RenderingServer.shader_get_code(original.get_shader_rid())
	code = _toon_code(code)
	if code.is_empty():
		return
	var toon := original.duplicate() as Terrain3DMaterial
	var shader := Shader.new()
	shader.code = code
	toon.shader_override = shader
	toon.shader_override_enabled = true
	toon.set_shader_param("trail_toon_softness", source.toon_softness)
	_materials[toon] = toon
	_property(terrain, "material", toon)
	# Los árboles pintados usan los materiales de estas mallas, también con LOD.
	if terrain.assets:
		for asset in terrain.assets.mesh_list:
			if asset == null:
				continue
			_asset_material(asset.material_override)
			_asset_material(asset.material_overlay)
			for lod in asset.lod_count:
				_mesh(asset.get_mesh(lod))

func _asset_material(material: Material) -> void:
	# Cambiar el asset dispara la generación de miniaturas del editor en 1.0.2.
	# Ajustar el material en memoria evita ese camino y conserva el instancer.
	if material is BaseMaterial3D and material.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL:
		_property(material, "diffuse_mode", BaseMaterial3D.DIFFUSE_TOON)
		_property(material, "specular_mode", BaseMaterial3D.SPECULAR_DISABLED)
		_property(material, "roughness", source.toon_softness)

func _toon_code(code: String) -> String:
	if not code.contains("shader_type spatial") or code.contains("unshaded"):
		return ""
	# Respetar shaders que ya definen su propio modelo de iluminación.
	var light_pattern := RegEx.create_from_string("void\\s+light\\s*\\(")
	if light_pattern.search(code):
		return ""
	var modes_pattern := RegEx.create_from_string("render_mode\\s+([^;]+);")
	var modes_match := modes_pattern.search(code)
	var modes := PackedStringArray()
	if modes_match:
		for mode in modes_match.get_string(1).split(","):
			var clean := mode.strip_edges()
			if not clean.begins_with("diffuse_") and not clean.begins_with("specular_"):
				modes.append(clean)
	modes.append("diffuse_toon")
	modes.append("specular_disabled")
	var declaration := "render_mode " + ", ".join(modes) + ";"
	if modes_match:
		code = code.substr(0, modes_match.get_start()) + declaration + code.substr(modes_match.get_end())
	else:
		code = code.replace("shader_type spatial;", "shader_type spatial;\n" + declaration)
	# La rugosidad controla la suavidad del modelo toon nativo.
	var fragment_pattern := RegEx.create_from_string("void\\s+fragment\\s*\\([^)]*\\)\\s*\\{")
	var fragment_match := fragment_pattern.search(code)
	if fragment_match == null:
		return ""
	var depth := 1
	var end := fragment_match.get_end()
	while end < code.length() and depth > 0:
		if code[end] == "{": depth += 1
		if code[end] == "}": depth -= 1
		end += 1
	if depth != 0:
		return ""
	code = code.insert(end - 1, "\nROUGHNESS = trail_toon_softness;\n")
	return code.replace("shader_type spatial;", "shader_type spatial;\nuniform float trail_toon_softness : hint_range(0.0, 1.0) = 0.08;")

func _restore() -> void:
	for index in range(_changes.size() - 1, -1, -1):
		var change: Dictionary = _changes[index]
		# Validar el Variant antes de convertirlo a Object: un nodo liberado
		# provoca un error en la propia asignación tipada.
		if not is_instance_valid(change.target):
			continue
		var target: Object = change.target
		if change.has("property"):
			if target.get(change.property) == change.replacement:
				target.set(change.property, change.original)
		elif change.override:
			if target.get_surface_override_material(change.surface) == change.replacement:
				target.set_surface_override_material(change.surface, change.original)
		elif target.surface_get_material(change.surface) == change.replacement:
			target.surface_set_material(change.surface, change.original)
	_changes.clear()
	_materials.clear()
	_meshes.clear()

func _exit_tree() -> void:
	_restore()
