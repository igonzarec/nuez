@tool
extends Node
## Colores lisos y LOD lejano persistente para pinos de Terrain3D, sin texturas.

const LodMesh = preload("res://scripts/tree_lod_mesh.gd")
const TRANSITION = preload("res://shaders/tree_lod_transition.gdshader")

@export_group("Activación")
## Activa colores y LOD. Apagar restaura los materiales anteriores y retira las copias lejanas. En vivo, hasta 0.3 s.
@export var enabled := true
## Previsualiza en el editor. Apagar restaura los materiales allí; no afecta al juego. En vivo.
@export var editor_preview := true
## Terrain3D cuyos assets se decoran. Cambiar requiere recargar la escena.
@export var terrain_path := NodePath("..")
## Sólo assets cuyo nombre comienza con este texto. Vacío incluye todos los compatibles con Wood/Green. En vivo; no cambia IDs ni colocaciones.
@export var asset_prefix := "PineTree_"

@export_group("Corteza")
## Aplica el color a Wood. Apagar usa el color original, manteniendo el LOD si está activo. En vivo.
@export var bark_enabled := true
## Color liso de la corteza. Más claro ilumina el resultado; la iluminación aporta volumen. En vivo.
@export var bark_color := Color(0.46, 0.30, 0.18)

@export_group("Follaje")
## Aplica el color a Green. Apagar usa el color original, manteniendo el LOD si está activo. En vivo.
@export var foliage_enabled := true
## Color liso del follaje. Más claro ilumina el resultado; usar naranja para otoño. En vivo.
@export var foliage_color := Color(0.26, 0.40, 0.13)

@export_group("Acabado")
## Rugosidad de partes con color personalizado: 1 mate, 0 brillante. En vivo.
@export_range(0.0, 1.0, 0.01) var roughness := 1.0
## Brillo especular de partes con color personalizado. Mayor aumenta reflejos. En vivo.
@export_range(0.0, 1.0, 0.01) var specular := 0.1

@export_group("LOD lejano")
## Conserva una malla simplificada al alejarse. Apagar vuelve al árbol original y sus cortes nativos, sin desvanecerlo. En vivo; añade lotes MultiMesh para la representación lejana.
@export var lod_enabled := true
## Mallas lejanas por nombre del asset. Los cinco pinos incluyen copias reducidas por partes para preservar las puntas. Sustituir una malla regenera los lotes en vivo; debe compartir origen, escala y materiales con el original.
@export var far_mesh_overrides: Dictionary[String, ArrayMesh] = {
	"PineTree_1": preload("res://resources/trees/lods/pine_1_far.res"),
	"PineTree_2": preload("res://resources/trees/lods/pine_2_far.res"),
	"PineTree_3": preload("res://resources/trees/lods/pine_3_far.res"),
	"PineTree_4": preload("res://resources/trees/lods/pine_4_far.res"),
	"PineTree_5": preload("res://resources/trees/lods/pine_5_far.res"),
}
## Sólo para assets sin Far Mesh Override: fracción objetivo de triángulos (0.5 = 50 %). Elige el LOD importado más cercano por superficie. Mayor conserva detalle y cuesta más GPU; valores bajos pueden perder puntas. Regenera copias en hasta 0.3 s.
@export_range(0.05, 1.0, 0.05) var far_detail_ratio := 0.5
## Sombras de la versión simplificada, sujetas también al ajuste del asset y alcance de la luz. Apagar ahorra GPU pero pierde sombras lejanas. En vivo.
@export var far_shadows := true
## Capas de render del LOD lejano; deben coincidir con las que ve la cámara. No afecta al terreno ni a colisiones. En vivo.
@export_flags_3d_render var far_render_layers := 1

@export_group("Transición por distancia")
## Mezcla original y simplificado con tramado complementario, sin vaciar el bosque. Apagar produce cambio directo entre LODs; requiere LOD Enabled. Añade descarte de píxeles en GPU. En vivo.
@export var fade_enabled := true
## Metros desde la cámara al origen del árbol donde empieza el cambio al LOD lejano. Menor adelanta la simplificación. En vivo; se limita al corte existente del asset.
@export_range(0.0, 1000.0, 1.0, "suffix:m") var fade_start := 60.0
## Metros donde termina el cambio: desde aquí queda el árbol simplificado, visible hasta el recorte normal de cámara. Mayor mantiene detalle más lejos. En vivo; no amplía el rango del original.
@export_range(1.0, 1000.0, 1.0, "suffix:m") var fade_end := 90.0
## Ancho mínimo en metros de la mezcla. Evita un salto si Start y End coinciden; adelanta el inicio sin cambiar sus valores guardados. Mayor suaviza durante más distancia y dibuja ambas versiones durante más recorrido. En vivo.
@export_range(1.0, 100.0, 1.0, "suffix:m") var minimum_transition_width := 20.0
## Reserva en metros antes del corte por bloques de Terrain3D. Mayor protege la transición pero puede adelantarla. 32 m es el valor inicial para bloques de 32 x 32 m; aumentar si hay árboles muy grandes. En vivo.
@export_range(0.0, 128.0, 1.0, "suffix:m") var cull_safety_margin := 32.0

var _terrain: Node
var _surfaces: Array[Dictionary] = []
var _shader_materials: Array[ShaderMaterial] = []
var _far_meshes: Dictionary = {}
var _ranges: Dictionary = {}
var _batches: Dictionary = {}
var _elapsed := 0.0
var _signature := 0

func _ready() -> void:
	_terrain = get_node_or_null(terrain_path)
	_sync()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 0.3:
		_elapsed = 0.0
		_sync()
	_update_camera()

func _exit_tree() -> void:
	_restore()

func _restore() -> void:
	for entry in _surfaces:
		if entry.mesh.surface_get_material(entry.surface) == entry.material:
			entry.mesh.surface_set_material(entry.surface, entry.original)
	_surfaces.clear()
	_shader_materials.clear()
	_far_meshes.clear()
	_ranges.clear()
	for batch in _batches.values():
		if is_instance_valid(batch.node):
			batch.node.visible = false
			batch.node.queue_free()
	_batches.clear()

func _sync() -> void:
	if not is_instance_valid(_terrain) or not _terrain is Terrain3D or _terrain.assets == null:
		return
	var active := enabled and (not Engine.is_editor_hint() or editor_preview)
	var assets: Array = []
	var geometry: Array = []
	for asset in _terrain.assets.get_mesh_list():
		if asset == null or not asset.name.begins_with(asset_prefix):
			continue
		# Native multi-LOD assets and material overrides need their own integration.
		if asset.last_lod != 0 or asset.material_override != null:
			continue
		var mesh: Mesh = asset.get_mesh()
		if not mesh is ArrayMesh or not _compatible(mesh):
			continue
		assets.append(asset)
		geometry.append([asset.id, mesh, asset.get_lod_range(asset.last_lod), asset.fade_margin, asset.cast_shadows, asset.enabled])
	var signature := hash([active, geometry, bark_enabled, bark_color, foliage_enabled,
		foliage_color, roughness, specular, lod_enabled, far_mesh_overrides, far_detail_ratio, far_shadows, far_render_layers,
		fade_enabled, fade_start, fade_end, minimum_transition_width, cull_safety_margin])
	var intact := true
	for entry in _surfaces:
		if entry.mesh.surface_get_material(entry.surface) != entry.material:
			intact = false
	if signature != _signature or not intact:
		_signature = signature
		_restore()
		if active:
			for asset in assets:
				var mesh: ArrayMesh = asset.get_mesh()
				var end := maxf(1.0, fade_end)
				var cutoff: float = asset.get_lod_range(asset.last_lod)
				if cutoff > 0.0:
					end = minf(end, maxf(1.0, cutoff - asset.fade_margin - cull_safety_margin))
				var width := maxf(maxf(1.0, minimum_transition_width), fade_end - maxf(0.0, fade_start))
				var start := minf(maxf(0.0, fade_start), maxf(0.0, end - width))
				_ranges[asset.id] = Vector2(start, end)
				if lod_enabled:
					var far_mesh: ArrayMesh
					if far_mesh_overrides.get(asset.name) != null:
						far_mesh = far_mesh_overrides[asset.name].duplicate()
					else:
						far_mesh = LodMesh.build(mesh, far_detail_ratio)
					_far_meshes[asset.id] = far_mesh
					_apply_materials(far_mesh, true, _ranges[asset.id])
				_apply_materials(mesh, false, _ranges[asset.id])
	if active and lod_enabled:
		_sync_batches(assets)
	_update_camera()

func _compatible(mesh: Mesh) -> bool:
	for i in mesh.get_surface_count():
		var mat := mesh.surface_get_material(i)
		if not mat is StandardMaterial3D and not (mat is ShaderMaterial and mat.shader == TRANSITION):
			return false
	return mesh.get_surface_count() > 0

func _apply_materials(mesh: ArrayMesh, far_mesh: bool, limits: Vector2) -> void:
	for surface in mesh.get_surface_count():
		var original := mesh.surface_get_material(surface) as StandardMaterial3D
		if original == null:
			continue
		var bark := original.resource_name == "Wood"
		var foliage := original.resource_name == "Green"
		var custom := (bark and bark_enabled) or (foliage and foliage_enabled)
		var color := (bark_color if bark else foliage_color) if custom else original.albedo_color
		var material: Material
		if lod_enabled:
			var shader_material := ShaderMaterial.new()
			shader_material.shader = TRANSITION
			shader_material.set_shader_parameter("base_color", color)
			shader_material.set_shader_parameter("base_roughness", roughness if custom else original.roughness)
			shader_material.set_shader_parameter("specular_amount", specular if custom else original.metallic_specular)
			shader_material.set_shader_parameter("transition_start", limits.x)
			shader_material.set_shader_parameter("transition_end", limits.y)
			shader_material.set_shader_parameter("far_mesh", far_mesh)
			shader_material.set_shader_parameter("smooth_transition", fade_enabled)
			_shader_materials.append(shader_material)
			material = shader_material
		else:
			var standard := original.duplicate() as StandardMaterial3D
			standard.albedo_color = color
			standard.albedo_texture = null
			standard.uv1_triplanar = false
			standard.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_DISABLED
			if custom:
				standard.roughness = roughness
				standard.metallic_specular = specular
			material = standard
		material.resource_name = original.resource_name
		mesh.surface_set_material(surface, material)
		_surfaces.append({"mesh": mesh, "surface": surface, "original": original, "material": material})

func _update_camera() -> void:
	if _shader_materials.is_empty() or not is_instance_valid(_terrain):
		return
	var camera: Camera3D = _terrain.get_camera()
	if camera == null and is_inside_tree():
		camera = get_viewport().get_camera_3d()
	for material in _shader_materials:
		material.set_shader_parameter("camera_valid", camera != null)
		if camera != null:
			material.set_shader_parameter("fade_camera", camera.global_position)

func _sync_batches(assets: Array) -> void:
	if _terrain.data == null:
		return
	var needed: Dictionary = {}
	for location: Vector2i in _terrain.data.get_region_locations():
		var region = _terrain.data.get_region(location)
		if region == null or region.is_deleted():
			continue
		var instances: Dictionary = region.get_instances()
		for asset in assets:
			if not asset.enabled or not instances.has(asset.id) or not _far_meshes.has(asset.id):
				continue
			var cells: Dictionary = instances[asset.id]
			for cell in cells:
				var triple: Array = cells[cell]
				if triple.size() < 2 or triple[0].is_empty():
					continue
				var key := "%s/%s/%s" % [location, asset.id, cell]
				needed[key] = true
				var transforms: Array = triple[0]
				var colors: PackedColorArray = triple[1]
				var stamp := hash([transforms, colors, region.region_size, _terrain.vertex_spacing])
				if _batches.has(key) and _batches[key].stamp == stamp:
					continue
				if _batches.has(key):
					_batches[key].node.visible = false
					_batches[key].node.queue_free()
				var multi := MultiMesh.new()
				multi.transform_format = MultiMesh.TRANSFORM_3D
				multi.use_colors = colors.size() == transforms.size()
				multi.mesh = _far_meshes[asset.id]
				multi.instance_count = transforms.size()
				for i in transforms.size():
					multi.set_instance_transform(i, transforms[i])
					if multi.use_colors:
						multi.set_instance_color(i, colors[i])
				var node := MultiMeshInstance3D.new()
				node.name = "Far_%d_%d_%d" % [asset.id, cell.x, cell.y]
				node.multimesh = multi
				node.top_level = true
				node.position = Vector3(location.x, 0.0, location.y) * region.region_size * _terrain.vertex_spacing
				node.cast_shadow = asset.cast_shadows if far_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				node.layers = far_render_layers
				node.visibility_range_begin = maxf(0.0, _ranges[asset.id].x - cull_safety_margin)
				add_child(node)
				_batches[key] = {"node": node, "stamp": stamp}
	for key in _batches.keys():
		if not needed.has(key):
			_batches[key].node.visible = false
			_batches[key].node.queue_free()
			_batches.erase(key)
