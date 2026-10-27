extends Node
## Laboratorio reversible. Materiales temporales, con ajustes numéricos por uniforms.
const STANDARD_CODE = preload("res://shaders/toon_standard.gdshader")
const INCLUDE = '#include "res://shaders/toon_lighting.gdshaderinc"'
var source: Node
var _signature: Array = []
var _values: Array = []
var _changes: Array[Dictionary] = []
var _bindings: Array[Dictionary] = []
var _materials: Dictionary = {}
var _shaders: Dictionary = {}
var _pending := false
var _native_assets: Array[Dictionary] = []
var _visited_assets: Dictionary = {}
var _meshes: Dictionary = {}
var _scanned: Dictionary = {}
var _new_nodes: Array[Node] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_node_added)

func profile(category: String) -> Resource:
	return source.toon_general if source.toon_enabled else source.get("toon_" + category)

func active(category: String) -> bool:
	return source.toon_enabled or profile(category).enabled

func _process(_delta: float) -> void:
	source.ensure_appearance_profiles()
	var structure := [active("world"), active("terrain"), active("character"), source.character_matte_enabled]
	var values := [source.toon_enabled, source.toon_general.signature(), source.toon_world.signature(), source.toon_terrain.signature(), source.toon_character.signature(), source.character_matte_roughness, source.character_matte_specular, source.character_matte_metallic]
	if structure != _signature:
		_signature = structure
		_rebuild()
	if values != _values:
		_values = values
		_update_values()

func _node_added(node: Node) -> void:
	_new_nodes.append(node)
	if not _pending:
		_pending = true
		_refresh.call_deferred()

func _refresh() -> void:
	_pending = false
	var nodes := _new_nodes.duplicate()
	_new_nodes.clear()
	var scene := get_tree().current_scene
	if not is_instance_valid(scene): return
	for node in nodes:
		if is_instance_valid(node) and node.is_inside_tree() and (node == scene or scene.is_ancestor_of(node)):
			_scan(node)
	_update_values()

func _rebuild() -> void:
	_restore()
	_scan(get_tree().current_scene)
	_update_values()

func _character(node: Node) -> bool:
	var ancestor := node
	while ancestor:
		if ancestor is SquirrelRig: return true
		ancestor = ancestor.get_parent()
	return false

func _scan(node: Node) -> void:
	if not is_instance_valid(node) or _scanned.has(node.get_instance_id()): return
	_scanned[node.get_instance_id()] = true
	if node is Terrain3D:
		_terrain(node)
		_assets(node)
	var category := "character" if _character(node) else "world"
	if node is GeometryInstance3D and (active(category) or (category == "character" and source.character_matte_enabled)):
		_property(node, "material_override", _material(node.material_override, category))
		_property(node, "material_overlay", _material(node.material_overlay, category))
		if node is MeshInstance3D and node.mesh and node.material_override == null:
			for surface in node.mesh.get_surface_count():
				var original: Material = node.get_surface_override_material(surface)
				var effective: Material = original if original else node.mesh.surface_get_material(surface)
				var replacement := _material(effective, category)
				if replacement != effective:
					_changes.append({"target": node, "surface": surface, "original": original, "replacement": replacement})
					node.set_surface_override_material(surface, replacement)
		if node is MultiMeshInstance3D and node.multimesh:
			var multi := node.multimesh.duplicate() as MultiMesh
			multi.mesh = _mesh(multi.mesh, category)
			_property(node, "multimesh", multi)
		if node is GPUParticles3D:
			for i in node.draw_passes:
				_property(node, "draw_pass_" + str(i + 1), _mesh(node.get_draw_pass_mesh(i), category))
	for child in node.get_children(): _scan(child)

func _mesh(original: Mesh, category: String) -> Mesh:
	if not original: return null
	var key := str(original.get_instance_id()) + category
	if _meshes.has(key): return _meshes[key]
	var copy := original.duplicate() as Mesh
	_meshes[key] = copy
	for surface in copy.get_surface_count():
		copy.surface_set_material(surface, _material(original.surface_get_material(surface), category))
	return copy

func _property(target: Object, property: String, replacement: Variant) -> void:
	var original: Variant = target.get(property)
	if original == replacement: return
	_changes.append({"target": target, "property": property, "original": original, "replacement": replacement})
	target.set(property, replacement)

func _shader(code: String) -> Shader:
	if not _shaders.has(code):
		var shader := Shader.new()
		shader.code = code
		_shaders[code] = shader
	return _shaders[code]

func _material(original: Material, category: String) -> Material:
	if not original: return null
	var key := str(original.get_instance_id()) + category
	if _materials.has(key): return _materials[key]
	var replacement: Material = original
	if original is BaseMaterial3D and original.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL:
		if active(category):
			if _needs_native(original):
				replacement = original.duplicate() as BaseMaterial3D
				replacement.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
				replacement.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			else: replacement = _standard(original)
		elif category == "character" and source.character_matte_enabled: replacement = original.duplicate() as BaseMaterial3D
	elif original is ShaderMaterial and original.shader and active(category):
		var code := _toon_code(original.shader.code)
		if not code.is_empty():
			replacement = original.duplicate() as ShaderMaterial
			replacement.shader = _shader(code)
	_materials[key] = replacement
	if replacement != original:
		_bindings.append({"material": replacement, "category": category, "original": original})
	return replacement

func _needs_native(material: BaseMaterial3D) -> bool:
	# Mantener funciones de StandardMaterial que el adaptador multibanda no reproduce.
	if material is ORMMaterial3D: return true
	for flag in ["rim_enabled", "clearcoat_enabled", "anisotropy_enabled", "subsurf_scatter_enabled", "subsurf_scatter_transmittance_enabled", "backlight_enabled", "emission_on_uv2", "uv1_triplanar", "uv2_triplanar", "detail_enabled", "heightmap_enabled", "refraction_enabled", "grow", "proximity_fade_enabled", "fixed_size", "use_particle_trails", "use_point_size"]:
		if material.get(flag): return true
	return material.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED or material.distance_fade_mode != BaseMaterial3D.DISTANCE_FADE_DISABLED

func _standard(original: BaseMaterial3D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	var code: String = STANDARD_CODE.code
	var modes := "diffuse_burley"
	if original.cull_mode == BaseMaterial3D.CULL_DISABLED: modes += ", cull_disabled"
	elif original.cull_mode == BaseMaterial3D.CULL_FRONT: modes += ", cull_front"
	if original.disable_receive_shadows: modes += ", shadows_disabled"
	if original.disable_ambient_light: modes += ", ambient_light_disabled"
	if original.blend_mode == BaseMaterial3D.BLEND_MODE_ADD: modes += ", blend_add"
	elif original.blend_mode == BaseMaterial3D.BLEND_MODE_SUB: modes += ", blend_sub"
	elif original.blend_mode == BaseMaterial3D.BLEND_MODE_MUL: modes += ", blend_mul"
	code = code.replace("render_mode diffuse_burley;", "render_mode " + modes + ";")
	if original.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		var alpha_code := "ALPHA = color.a;"
		if original.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR: alpha_code += " ALPHA_SCISSOR_THRESHOLD = alpha_scissor;"
		elif original.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_HASH: alpha_code += " ALPHA_HASH_SCALE = 1.0;"
		elif original.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS: code = code.replace("render_mode ", "render_mode depth_prepass_alpha, ")
		code = code.replace("// ALPHA_MODE", alpha_code)
	if original.texture_filter in [BaseMaterial3D.TEXTURE_FILTER_NEAREST, BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS, BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC]:
		code = code.replace("hint_default_white;", "hint_default_white, filter_nearest_mipmap;").replace("hint_normal;", "hint_normal, filter_nearest_mipmap;").replace("hint_default_black;", "hint_default_black, filter_nearest_mipmap;")
	if not original.texture_repeat:
		code = code.replace("hint_default_white", "repeat_disable, hint_default_white").replace("hint_normal", "repeat_disable, hint_normal").replace("hint_default_black", "repeat_disable, hint_default_black")
	material.shader = _shader(code)
	material.render_priority = original.render_priority
	material.next_pass = original.next_pass
	for slot in ["albedo", "normal", "roughness", "metallic", "ao", "emission"]:
		material.set_shader_parameter(slot + "_texture", original.get(slot + "_texture"))
	material.set_shader_parameter("albedo", original.albedo_color)
	material.set_shader_parameter("use_vertex_color", original.vertex_color_use_as_albedo)
	material.set_shader_parameter("use_normal", original.normal_enabled)
	material.set_shader_parameter("use_ao", original.ao_enabled)
	material.set_shader_parameter("use_uv2_ao", original.ao_on_uv2)
	material.set_shader_parameter("ao_light_affect", original.ao_light_affect)
	material.set_shader_parameter("uv_scale", original.uv1_scale)
	material.set_shader_parameter("uv_offset", original.uv1_offset)
	material.set_shader_parameter("alpha_scissor", original.alpha_scissor_threshold)
	material.set_shader_parameter("emission", original.emission if original.emission_enabled else Color.BLACK)
	material.set_shader_parameter("emission_energy", original.emission_energy_multiplier if original.emission_enabled else 0.0)
	material.set_shader_parameter("emission_multiply", original.emission_operator == BaseMaterial3D.EMISSION_OP_MULTIPLY)
	for slot in ["roughness", "metallic", "ao"]:
		var channel: int = original.get(slot + "_texture_channel")
		var weights := Vector4.ZERO
		if channel < 4: weights[channel] = 1.0
		else: weights = Vector4(0.333333, 0.333333, 0.333333, 0.0)
		material.set_shader_parameter(slot + "_channel", weights)
	return material

func _terrain(terrain: Terrain3D) -> void:
	if not active("terrain") or not terrain.material: return
	var original := terrain.material
	var code := RenderingServer.shader_get_code(original.get_shader_rid())
	# Sólo sustituir la iluminación propia del terreno conocido.
	if code.contains("uniform int toon_bands"):
		var start := code.rfind("void light()")
		if start >= 0: code = code.substr(0, start)
	var adapted := _toon_code(code)
	if adapted.is_empty(): return
	var copy := original.duplicate() as Terrain3DMaterial
	copy.shader_override = _shader(adapted)
	copy.shader_override_enabled = true
	_property(terrain, "material", copy)
	_bindings.append({"material": copy, "category": "terrain", "original": original})

func _assets(terrain: Terrain3D) -> void:
	if not terrain.assets or not active("world"): return
	# No usar setters del asset: Terrain3D 1.0.2 genera miniaturas en runtime.
	for asset in terrain.assets.mesh_list:
		if asset == null: continue
		_asset_material(asset.material_override)
		_asset_material(asset.material_overlay)
		for lod in asset.lod_count:
			var mesh: Mesh = asset.get_mesh(lod)
			if not mesh: continue
			for i in mesh.get_surface_count():
				var before := mesh.surface_get_material(i)
				var after := _material(before, "world")
				if before != after:
					_changes.append({"target": mesh, "mesh_surface": i, "original": before, "replacement": after})
					mesh.surface_set_material(i, after)

func _asset_material(material: Material) -> void:
	if material is BaseMaterial3D and material.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL:
		if _visited_assets.has(material): return
		_visited_assets[material] = true
		# Los overrides del instancer conservan toon nativo (dos niveles).
		_property(material, "diffuse_mode", BaseMaterial3D.DIFFUSE_TOON)
		_property(material, "specular_mode", BaseMaterial3D.SPECULAR_DISABLED)
		var change := {"target": material, "property": "roughness", "original": material.roughness, "replacement": material.roughness}
		_changes.append(change)
		_native_assets.append(change)

func _toon_code(code: String) -> String:
	if not code.contains("shader_type spatial") or code.contains("unshaded"): return ""
	if RegEx.create_from_string("void\\s+light\\s*\\(").search(code): return ""
	var fragment := RegEx.create_from_string("void\\s+fragment\\s*\\([^)]*\\)\\s*\\{").search(code)
	if not fragment: return ""
	var depth := 1
	var end := fragment.get_end()
	while end < code.length() and depth > 0:
		if code[end] == "{": depth += 1
		if code[end] == "}": depth -= 1
		end += 1
	if depth != 0: return ""
	code = code.insert(end - 1, "\nNORMAL_MAP_DEPTH *= trail_normal_strength;\n")
	code = code.replace("shader_type spatial;", "shader_type spatial;\n" + INCLUDE + "\nuniform float trail_normal_strength = 1.0;")
	code += "\nvoid light() { DIFFUSE_LIGHT += trail_toon_ramp(max(dot(NORMAL, LIGHT), 0.0)) * ATTENUATION * LIGHT_COLOR / PI; }\n"
	return code

func _uniform(material: Resource, key: String, value: Variant) -> void:
	if material is Terrain3DMaterial: material.set_shader_param(key, value)
	else: material.set_shader_parameter(key, value)

func _update_values() -> void:
	for receiver in get_tree().get_nodes_in_group("snow_surface_receivers"):
		if receiver.has_method("refresh_appearance"): receiver.refresh_appearance()
	for change in _native_assets:
		change.replacement = profile("world").softness
		change.target.roughness = change.replacement
	for binding in _bindings:
		var material: Resource = binding.material
		var original: Resource = binding.original
		var category: String = binding.category
		var look: Resource = profile(category)
		var matte: bool = category == "character" and source.character_matte_enabled
		if material is BaseMaterial3D:
			material.roughness = look.softness if active(category) else source.character_matte_roughness
			if matte:
				material.metallic = source.character_matte_metallic
				material.metallic_specular = source.character_matte_specular
				material.roughness_texture = null
				material.metallic_texture = null
			continue
		_uniform(material, "trail_toon_bands", look.bands)
		_uniform(material, "trail_toon_softness", look.softness)
		_uniform(material, "trail_toon_offset", look.light_offset)
		_uniform(material, "trail_toon_contrast", look.contrast)
		_uniform(material, "trail_normal_strength", look.normal_strength)
		if original is BaseMaterial3D:
			_uniform(material, "banded", active(category))
			_uniform(material, "roughness", source.character_matte_roughness if matte else original.roughness)
			_uniform(material, "specular", source.character_matte_specular if matte else original.metallic_specular)
			_uniform(material, "metallic", source.character_matte_metallic if matte else original.metallic)
			_uniform(material, "normal_strength", original.normal_scale * look.normal_strength)
		if material is Terrain3DMaterial and material.shader_override.code.contains("uniform float toon_normal_strength"):
			_uniform(material, "toon_normal_strength", 1.0)

func _restore() -> void:
	for index in range(_changes.size() - 1, -1, -1):
		var change: Dictionary = _changes[index]
		if not is_instance_valid(change.target): continue
		var target: Object = change.target
		if change.has("property"):
			if target.get(change.property) == change.replacement: target.set(change.property, change.original)
		elif change.has("mesh_surface"):
			if target.surface_get_material(change.mesh_surface) == change.replacement: target.surface_set_material(change.mesh_surface, change.original)
		elif target.get_surface_override_material(change.surface) == change.replacement:
			target.set_surface_override_material(change.surface, change.original)
	_changes.clear()
	_native_assets.clear()
	_visited_assets.clear()
	_meshes.clear()
	_scanned.clear()
	_bindings.clear()
	_materials.clear()

func _exit_tree() -> void:
	_restore()
