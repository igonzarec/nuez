@tool
class_name WaterBody
extends Path3D
## Base de WaterRiver y WaterLake: superficie de agua generada desde la curva (Path3D), su material y el tallado del cauce
## en Terrain3D. La malla se rehace sola al editar la curva y no se guarda en la escena (sin bake ni coste de disco).
## Tallar solo baja el terreno hasta el perfil del agua y nunca lo sube: volver a tallar conserva lo que hayas cavado a mano
## mas hondo. Restaurar devuelve las alturas (y la pintura) de antes del primer tallado. Guia: docs/water.md.

const SHADER := preload("res://shaders/water/water_surface.gdshader")
const EDITOR_SHADER := preload("res://shaders/water/water_editor_preview.gdshader")
const DEFAULT_STYLE := "res://assets/water/water_style_default.tres"

@export_group("Aspecto")
## Estilo del agua (color, transparencia, ondas, destellos, espuma, cascada...). Vacio usa water_style_default.tres. Varios
## cuerpos de agua pueden compartirlo; para un aspecto propio usa Make Unique. En vivo.
@export var style: WaterStyle:
	set(value):
		if style != null and style.changed.is_connected(_apply_style):
			style.changed.disconnect(_apply_style)
		style = value
		if style != null:
			style.changed.connect(_apply_style)
		_apply_style()

@export_group("Nado")
## Permite nadar y bucear en este cuerpo de agua. Apagado, el jugador camina por el fondo como si no hubiera agua. En vivo.
@export var swimmable := true
## Multiplicador del empuje de la corriente sobre quien nada (sobre Flow Speed del estilo, que tambien mueve las ondas).
## 0 = agua quieta para el nado aunque las ondas avancen; 2 = corriente que arrastra el doble. Los lagos no tienen corriente.
## En vivo.
@export_range(0.0, 4.0, 0.05) var current_strength := 1.0
## Profundidad maxima en metros bajo la superficie a la que se considera que algo esta dentro de esta agua. Mas que el
## fondo real no cambia nada; menos impide bucear mas hondo que ese valor. En vivo.
@export_range(0.5, 50.0, 0.5, "suffix:m") var swim_depth_limit := 12.0

@export_group("Cauce (Terrain3D)")
## Terrain3D donde se talla el cauce. Debe estar en la misma escena. Sin terreno, el agua se dibuja igual pero no talla.
@export var terrain: Terrain3D
## Profundidad en metros del fondo bajo la superficie del agua. Mayor = agua mas oscura y nado mas libre. Al tallar.
@export_range(0.1, 12.0, 0.05, "suffix:m") var carve_depth := 1.6
## Inclinacion en grados de la orilla por encima del agua. Mayor = margen cortada (con la textura de roca o tierra del Auto
## Shader); menor = playa suave y ancha. En rios es la margen exterior y los tramos rectos; ver Bank Angle Inner. Al tallar.
@export_range(5.0, 80.0, 0.5, "suffix:degrees") var bank_angle := 55.0
## Solo con pintura de orilla: la arena cubre la orilla sobre el agua solo donde es mas suave que este angulo (playas); las
## margenes mas empinadas quedan con la textura del terreno. Bajo el agua siempre se pinta. Al tallar.
@export_range(0.0, 90.0, 0.5, "suffix:degrees") var sand_max_angle := 35.0
## Metros desde el borde del agua hasta donde la orilla puede bajar el terreno. Mayor deja margenes largas en terreno alto.
## Coste: solo al tallar (mas celdas que revisar).
@export_range(0.0, 30.0, 0.25, "suffix:m") var bank_reach := 6.0
## ID de textura de Terrain3D que se pinta en el fondo y la orilla (arena, grava). -1 = no pinta. Se mezcla hacia la
## textura de pasto del Auto Shader en la parte alta. Restaurar la quita. Al tallar.
@export_range(-1, 31, 1) var bank_texture_id := -1
## Metros por encima del agua hasta donde llega la pintura de orilla. Mayor = playa mas alta.
@export_range(0.0, 5.0, 0.05, "suffix:m") var bank_paint_height := 0.6
## Metros de altura en que la pintura de orilla se funde con el pasto. Mayor = transicion mas suave.
@export_range(0.05, 5.0, 0.05, "suffix:m") var bank_paint_blend := 1.0
## Baja el terreno a lo largo del agua (solo baja, nunca sube) y pinta la orilla. Guarda las alturas originales la primera
## vez para Restaurar. Coste: unos segundos en rios largos con vertex_spacing pequeno. Guarda la escena con Ctrl+S despues.
@export_tool_button("Tallar cauce") var carve_button: Callable = carve
## Devuelve las alturas y la pintura de antes del primer tallado de este nodo. Lo que retocaste a mano dentro de esa zona
## tambien se pierde. Guarda la escena con Ctrl+S despues.
@export_tool_button("Restaurar terreno") var restore_button: Callable = restore_terrain

@export_group("Guias del editor")
## Muestra la curva y sus puntos aunque el nodo no este seleccionado (p. ej. al esculpir con Terrain3D), con el numero y
## la altura del agua de cada punto. Solo en el editor: no aparece en el juego. En vivo.
@export var show_editor_guides := true:
	set(value):
		show_editor_guides = value
		_update_guides()
## Dibuja las guias por encima de todo, visibles a traves del terreno. Apagado, el terreno las tapa. En vivo.
@export var guides_on_top := true:
	set(value):
		guides_on_top = value
		_update_guides()
## Color de la linea central, las marcas de los puntos y sus etiquetas. En vivo.
@export var guide_color := Color(1.0, 0.55, 0.1):
	set(value):
		guide_color = value
		_update_guides()
## Color de los bordes del agua (rios: el ancho de Width a cada lado de la curva). En vivo.
@export var guide_edge_color := Color(0.3, 0.8, 1.0):
	set(value):
		guide_edge_color = value
		_update_guides()
## Tamano en metros de la cruz de cada punto; la linea vertical baja el triple. Mayor = se ve de mas lejos. En vivo.
@export_range(0.1, 5.0, 0.05, "suffix:m") var guide_point_size := 0.6:
	set(value):
		guide_point_size = value
		_update_guides()
## Muestra junto a cada punto su numero (como en Curve > Points) y la altura Y del agua. En vivo.
@export var guide_labels := true:
	set(value):
		guide_labels = value
		_update_guides()

## Celdas de Terrain3D (x, z en pixeles globales) que este nodo cambio, con su altura y control originales.
@export_storage var carved_cells := PackedInt32Array()
@export_storage var carved_heights := PackedFloat32Array()
@export_storage var carved_controls := PackedInt64Array()

var _material: ShaderMaterial
var _editor_material: ShaderMaterial
var _terrain_link_wait := 0.0
var _terrain_link_key := 0

## Ondas reales: golpes en el agua (caidas, brazadas, pasos) compartidos por todos los cuerpos de agua. Cada golpe es un
## anillo de ondas que se expande y se apaga en el shader (WaterStyle › Ondas del jugador).
const MAX_WAVES := 16
const WAVE_MAX_AGE := 6.0
static var _wave_points: Array[Vector4] = []
static var _wave_ages: Array[float] = []
static var _wave_frame := -1
static var _wave_packed_points := PackedVector4Array()
static var _wave_packed_ages := PackedFloat32Array()
## Clock of the surface motion, shared by the shader (motion_time) and swell_at().
static var _motion_clock := 0.0
const SWELL_DIRS := [Vector2(0.957826, 0.287348), Vector2(-0.410365, 0.911922), Vector2(0.752577, -0.658505)]
const SWELL_SIZES := [1.0, 0.63, 0.41]
const SWELL_WEIGHTS := [0.5, 0.3, 0.2]
const SWELL_SPEEDS := [1.0, 1.27, 1.61]

## Height of the background swell (metres, around 0) at a world XZ point, the same the shader draws. 0 when the style
## has no surface motion.
static func swell_at(xz: Vector2, water_style: WaterStyle) -> float:
	if water_style == null or not water_style.surface_motion_enabled:
		return 0.0
	var height := 0.0
	var time := _motion_clock * water_style.swell_speed
	for i in 3:
		var k := TAU / maxf(water_style.swell_scale * SWELL_SIZES[i], 0.05)
		height += sin(xz.dot(SWELL_DIRS[i]) * k + time * SWELL_SPEEDS[i] * TAU) * SWELL_WEIGHTS[i]
	return height * water_style.swell_height
var _surface: MeshInstance3D
var _rebuild_queued := false
var _guides: MeshInstance3D
var _guide_labels: Array[Label3D] = []

func _ready() -> void:
	add_to_group("water_bodies")
	if style == null and ResourceLoader.exists(DEFAULT_STYLE):
		style = load(DEFAULT_STYLE)
	if curve == null:
		curve = _default_curve()
	if not curve_changed.is_connected(_queue_rebuild):
		curve_changed.connect(_queue_rebuild)
	# Deferred: rivers trim against lakes, which must all be in the tree first.
	_queue_rebuild()

## Shape used when the node is created with an empty curve.
func _default_curve() -> Curve3D:
	return Curve3D.new()

## Subclasses return the surface mesh (one surface) or null.
func _build_mesh() -> ArrayMesh:
	return null

## Subclasses fill targets: Vector2i cell -> Vector3(target height, water surface height, bank angle in degrees).
func _collect_targets(_targets: Dictionary) -> void:
	pass

## Subclasses: water surface over a world point as {"surface": float, "flow": Vector3 (m/s), "edge": 0-1}, or {} when
## the point is outside this body in plan. Falls are not swimmable and return {}.
func _surface_at(_point: Vector3) -> Dictionary:
	return {}

## Water at a world point: {"surface", "flow", "edge", "body"} when the point is over this body, no higher than Above
## metres over its surface and no deeper than Swim Depth Limit. {} otherwise.
func water_at(point: Vector3, above := 0.5) -> Dictionary:
	if not swimmable or not is_inside_tree():
		return {}
	var info := _surface_at(point)
	if info.is_empty():
		return info
	var surface: float = info.surface
	if point.y > surface + above or point.y < surface - swim_depth_limit:
		return {}
	info.flow = info.flow * current_strength
	info.body = self
	return info

## Water under or around a world point among all water bodies, or {}. Where bodies overlap (a river entering a lake) the
## lowest surface that still covers the point wins, so a diver belongs to the water they are actually in.
## Adds a wave source at a point of a water surface. Strength 1 = a big plunge. The oldest one is replaced when full.
static func add_wave(point: Vector3, strength: float) -> void:
	if strength <= 0.0:
		return
	if _wave_points.size() >= MAX_WAVES:
		var oldest := 0
		for i in _wave_ages.size():
			if _wave_ages[i] > _wave_ages[oldest]:
				oldest = i
		_wave_points.remove_at(oldest)
		_wave_ages.remove_at(oldest)
	_wave_points.append(Vector4(point.x, point.y, point.z, strength))
	_wave_ages.append(0.0)

## Ages the shared waves once per frame (whichever body runs first) and drops the faded ones.
static func _advance_waves(delta: float) -> void:
	var frame := Engine.get_process_frames()
	if frame == _wave_frame:
		return
	_wave_frame = frame
	_motion_clock = fmod(_motion_clock + delta, 3600.0)
	for i in range(_wave_ages.size() - 1, -1, -1):
		_wave_ages[i] += delta
		if _wave_ages[i] > WAVE_MAX_AGE:
			_wave_points.remove_at(i)
			_wave_ages.remove_at(i)
	_wave_packed_points.resize(MAX_WAVES)
	_wave_packed_ages.resize(MAX_WAVES)
	for i in MAX_WAVES:
		_wave_packed_points[i] = _wave_points[i] if i < _wave_points.size() else Vector4.ZERO
		_wave_packed_ages[i] = _wave_ages[i] if i < _wave_ages.size() else 0.0

## Hands the Terrain3D heightmap to the water shader (WaterStyle > Distancia > Shore Mask). Reads the textures the terrain
## already keeps on the GPU, so brush edits show up with no baking. Checked twice a second: the terrain loads after the water.
func _update_terrain_link(delta: float) -> void:
	if _editor_simple():
		return
	_terrain_link_wait -= delta
	if _terrain_link_wait > 0.0 or _material == null:
		return
	_terrain_link_wait = 0.5
	var land := terrain
	if not is_instance_valid(land):
		var search_root: Node = owner if is_instance_valid(owner) else get_tree().root
		var found := search_root.find_children("*", "Terrain3D", true, false)
		land = found[0] if not found.is_empty() else null
	if not is_instance_valid(land) or land.material == null:
		_material.set_shader_parameter("shore_mask_ready", false)
		return
	var source: RID = land.material.get_material_rid()
	var heights: Variant = RenderingServer.material_get_param(source, "_height_maps")
	var region_map: Variant = RenderingServer.material_get_param(source, "_region_map")
	if not (heights is RID and heights.is_valid() and region_map != null):
		_material.set_shader_parameter("shore_mask_ready", false)
		return
	var link_key := hash([heights, region_map, land.vertex_spacing])
	if link_key == _terrain_link_key:
		return
	_terrain_link_key = link_key
	var target := _material.get_rid()
	RenderingServer.material_set_param(target, "terrain_heights", heights)
	RenderingServer.material_set_param(target, "terrain_region_map", region_map)
	RenderingServer.material_set_param(target, "terrain_region_size", RenderingServer.material_get_param(source, "_region_size"))
	RenderingServer.material_set_param(target, "terrain_density", 1.0 / land.vertex_spacing)
	_material.set_shader_parameter("shore_mask_ready", true)

func _process(delta: float) -> void:
	_update_terrain_link(delta)
	if Engine.is_editor_hint() or _material == null:
		return
	_advance_waves(delta)
	var count := _wave_points.size()
	_material.set_shader_parameter("motion_time", _motion_clock)
	_material.set_shader_parameter("wave_count", count)
	if count > 0:
		_material.set_shader_parameter("wave_points", _wave_packed_points)
		_material.set_shader_parameter("wave_ages", _wave_packed_ages)

static func find_water(tree: SceneTree, point: Vector3, above := 0.5) -> Dictionary:
	var best := {}
	for body in tree.get_nodes_in_group("water_bodies"):
		var info: Dictionary = body.water_at(point, above)
		if not info.is_empty() and (best.is_empty() or info.surface < best.surface):
			best = info
	return best

## Draw order among water surfaces (0 = lakes). Rivers draw after lakes so their mouth can fade over them.
func _render_priority() -> int:
	return 0

func _style_flow_speed() -> float:
	return style.flow_speed if style != null else 1.2

func _queue_rebuild() -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild.call_deferred()

func _rebuild() -> void:
	_rebuild_queued = false
	if not is_inside_tree():
		return
	if not is_instance_valid(_surface):
		_surface = MeshInstance3D.new()
		_surface.name = "WaterSurface"
		_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_surface, false, Node.INTERNAL_MODE_FRONT)
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		# After the camera's distant blur (-128), which repaints the screen with opaque geometry only.
		_material.render_priority = _render_priority()
	_built_motion_key = _motion_key()
	_apply_style()
	var mesh := _build_mesh() if curve != null else null
	if mesh != null and mesh.get_surface_count() > 0:
		mesh.surface_set_material(0, _material)
	_surface.mesh = mesh
	_after_rebuild()
	_update_guides()

## Editor-only lines and labels for the curve, drawn while the node is not selected too.
func _update_guides() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	var on := show_editor_guides and curve != null and curve.point_count > 0
	if not on:
		if is_instance_valid(_guides):
			_guides.queue_free()
		_guides = null
		for label in _guide_labels:
			if is_instance_valid(label):
				label.queue_free()
		_guide_labels.clear()
		return
	if not is_instance_valid(_guides):
		_guides = MeshInstance3D.new()
		_guides.name = "EditorGuides"
		_guides.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_guides, false, Node.INTERNAL_MODE_BACK)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = guides_on_top
	material.render_priority = 120
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	var edges := PackedVector3Array()
	_guide_edges(edges)
	mesh.surface_set_color(guide_edge_color)
	for v in edges:
		mesh.surface_add_vertex(v)
	mesh.surface_set_color(guide_color)
	var baked := curve.get_baked_points()
	for i in baked.size() - 1:
		mesh.surface_add_vertex(baked[i])
		mesh.surface_add_vertex(baked[i + 1])
	var r := guide_point_size
	for i in curve.point_count:
		var p := curve.get_point_position(i)
		for axis in [Vector3(r, 0, 0), Vector3(0, 0, r), Vector3(0, r, 0)]:
			mesh.surface_add_vertex(p - axis)
			mesh.surface_add_vertex(p + axis)
		mesh.surface_add_vertex(p)
		mesh.surface_add_vertex(p - Vector3(0, r * 3.0, 0))
	mesh.surface_end()
	_guides.mesh = mesh
	var count := curve.point_count if guide_labels else 0
	while _guide_labels.size() > count:
		var label: Label3D = _guide_labels.pop_back()
		if is_instance_valid(label):
			label.queue_free()
	while _guide_labels.size() < count:
		var label := Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.fixed_size = true
		label.pixel_size = 0.0012
		label.font_size = 18
		label.outline_size = 6
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(label, false, Node.INTERNAL_MODE_BACK)
		_guide_labels.append(label)
	for i in count:
		var label := _guide_labels[i]
		var p := curve.get_point_position(i)
		label.position = p + Vector3(0, r * 1.6, 0)
		label.text = "%d   y %.2f" % [i, to_global(p).y]
		label.modulate = guide_color
		label.no_depth_test = guides_on_top
		label.render_priority = 121
		label.outline_render_priority = 120

## Subclasses add pairs of local points (segments) for the water's edges to the editor guides.
func _guide_edges(_lines: PackedVector3Array) -> void:
	pass

## Hook for subclasses: runs after the surface mesh is rebuilt (rivers place their bed pebbles here).
func _after_rebuild() -> void:
	pass

## Hook for subclasses: runs after carving or restoring the terrain changed the bed.
func _terrain_changed() -> void:
	pass

## True while the editor shows this water with the flat stand-in (WaterStyle > Vista en editor).
func _editor_simple() -> bool:
	return Engine.is_editor_hint() and style != null and style.editor_simple_preview

## Swaps the drawn material only: the real one keeps receiving the style, so switching back is immediate.
func _update_editor_preview() -> void:
	if not is_instance_valid(_surface):
		return
	if not _editor_simple():
		_surface.material_override = null
		return
	if _editor_material == null:
		_editor_material = ShaderMaterial.new()
		_editor_material.shader = EDITOR_SHADER
		_editor_material.render_priority = _render_priority()
	_editor_material.set_shader_parameter("water_color", style.editor_water_color)
	_editor_material.set_shader_parameter("fall_color", style.editor_fall_color)
	_surface.material_override = _editor_material

func _apply_style() -> void:

	_update_editor_preview()
	if style != null and _material != null:
		style.apply(_material)
		# Surface motion needs a denser mesh: rebuild when it is switched or its resolution changes.
		if _motion_key() != _built_motion_key and _surface != null and _surface.mesh != null:
			_queue_rebuild()
	_after_style()

## Hook after the style is applied (rivers rebuild their fall effects when those values change).
func _after_style() -> void:
	pass

var _built_motion_key := Vector2(-1.0, -1.0)

func _motion_key() -> Vector2:
	if style == null or not style.surface_motion_enabled:
		return Vector2.ZERO
	return Vector2(1.0, style.surface_resolution)

## Mesh spacing in metres when the surface moves, 0 when it stays flat.
func _motion_spacing() -> float:
	return style.surface_resolution if style != null and style.surface_motion_enabled else 0.0

## Terrain profile of a bank above the waterline at a horizontal distance outside the water.
func _bank_height(waterline: float, outside: float, angle: float) -> float:
	return waterline + outside * tan(deg_to_rad(angle))

## Is a world point (x, z) at a fall of any river: in front of the cliff between the lip and the foot (Side Margin metres
## past its sides, Foot Margin past its foot; negative = same as Side Margin), or up to Back Margin metres behind the lip
## when the water there (Below Y) is lower than the lip (the pool or the river below, whose banks would cut into the
## cliff). Used so carving never cuts the cliff there.
static func under_fall(tree: SceneTree, q: Vector2, side_margin := 1.0, back_margin := 0.0, below_y := -INF,
		foot_margin := -1.0) -> bool:
	var past := side_margin if foot_margin < 0.0 else foot_margin
	for body in tree.get_nodes_in_group("water_bodies"):
		var zones = body.get("_fall_zones")
		if zones == null:
			continue
		for zone in zones:
			var p: Vector2 = q - zone[0]
			var along: float = p.dot(zone[1])
			if absf(p.cross(zone[1])) >= zone[3] + side_margin:
				continue
			if along > 0.0 and along < zone[2] + past:
				return true
			if along <= 0.0 and along > -back_margin and below_y < zone[4] - 0.5:
				return true
	return false

## Terrain targets of this body ({cell: Vector3(height, water surface, bank angle)}), without banks that would cut into the
## cliff under or behind a fall (beds below the water are still carved there).
func _carve_targets() -> Dictionary:
	var targets := {}
	if not is_instance_valid(terrain) or terrain.data == null:
		return targets
	_collect_targets(targets)
	if not is_inside_tree():
		return targets
	var spacing := terrain.vertex_spacing
	# Banks reach Bank Reach metres out from the water: beside a fall that slope would bite into the cliff top and wall
	# (notches on both sides of the lip), so they are left out across the whole reach. Past the foot they carve again.
	var margin := bank_reach + 1.0
	for cell: Vector2i in targets.keys():
		var target: Vector3 = targets[cell]
		if target.x > target.y - 0.1 and under_fall(get_tree(), Vector2(cell.x * spacing, cell.y * spacing), margin,
				margin, target.y, 1.0):
			targets.erase(cell)
	return targets

func carve() -> void:
	if not is_instance_valid(terrain) or terrain.data == null:
		push_warning("%s: asigna un Terrain3D con datos para tallar el cauce." % name)
		return
	var start := Time.get_ticks_msec()
	var targets := _carve_targets()
	var spacing := terrain.vertex_spacing
	var sheltered := 0
	if is_inside_tree():
		# Cells this node cut around a fall before are carved again from their original height (or put back when no longer
		# needed), so older cuts into the cliff go away. What the other water on the same terrain carves there is kept, so
		# the order in which the bodies are carved does not matter.
		var margin := bank_reach + 1.0
		var others := {}
		for body in get_tree().get_nodes_in_group("water_bodies"):
			if body != self and body is WaterBody and body.terrain == terrain:
				var theirs: Dictionary = body._carve_targets()
				for cell: Vector2i in theirs:
					if not others.has(cell) or theirs[cell].x < others[cell]:
						others[cell] = theirs[cell].x
		var keep_cells := PackedInt32Array()
		var keep_heights := PackedFloat32Array()
		var keep_controls := PackedInt64Array()
		for i in carved_heights.size():
			var cell := Vector2i(carved_cells[i * 2], carved_cells[i * 2 + 1])
			var p := Vector3(cell.x * spacing, 0.0, cell.y * spacing)
			if under_fall(get_tree(), Vector2(p.x, p.z), margin, margin):
				var base := maxf(carved_heights[i], terrain.data.get_height(p))
				if others.has(cell):
					base = minf(base, others[cell])
				terrain.data.set_height(p, base)
				terrain.data.set_control(p, carved_controls[i])
				if not targets.has(cell):
					sheltered += 1
					continue
			keep_cells.append_array(PackedInt32Array([cell.x, cell.y]))
			keep_heights.append(carved_heights[i])
			keep_controls.append(carved_controls[i])
		carved_cells = keep_cells
		carved_heights = keep_heights
		carved_controls = keep_controls
	var known := {}
	for i in carved_heights.size():
		known[Vector2i(carved_cells[i * 2], carved_cells[i * 2 + 1])] = true
	var overlay := 0
	if terrain.material != null and terrain.material.get_shader_param("auto_overlay_texture") != null:
		overlay = int(terrain.material.get_shader_param("auto_overlay_texture"))
	var lowered := 0
	var painted := 0
	var flooded := 0
	for cell: Vector2i in targets:
		var p := Vector3(cell.x * spacing, 0.0, cell.y * spacing)
		var current := terrain.data.get_height(p)
		if is_nan(current):
			continue
		var target: Vector3 = targets[cell]
		var height := minf(current, target.x)
		# Ground lower than the water right at the edge: the water would float above the bank there.
		if current < target.y - 0.05 and target.x > target.y - 0.1:
			flooded += 1
		var sand := 0.0
		# Sand on the bed and on gentle banks (beaches); steep cut banks keep the terrain texture.
		if bank_texture_id >= 0 and (height < target.y or target.z <= sand_max_angle):
			var top := target.y + bank_paint_height
			sand = 1.0 - smoothstep(top - bank_paint_blend, top, height)
		if height >= current - 0.001 and sand <= 0.01:
			continue
		if not known.has(cell):
			known[cell] = true
			carved_cells.append_array(PackedInt32Array([cell.x, cell.y]))
			carved_heights.append(current)
			carved_controls.append(terrain.data.get_control(p))
		if height < current - 0.001:
			terrain.data.set_height(p, height)
			lowered += 1
		if sand > 0.01:
			terrain.data.set_control_auto(p, false)
			terrain.data.set_control_base_id(p, bank_texture_id)
			terrain.data.set_control_overlay_id(p, overlay)
			terrain.data.set_control_blend(p, 1.0 - sand)
			painted += 1
	_refresh_terrain()
	print("%s: cauce tallado, %d celdas bajadas, %d pintadas, %d restauradas bajo cascadas, %d ms." % [name, lowered, painted, sheltered, Time.get_ticks_msec() - start])
	if flooded > 0:
		push_warning("%s: en %d celdas de la orilla el terreno queda por debajo del agua y el agua flotaria sobre el borde. Baja la curva o sube esa orilla." % [name, flooded])

func restore_terrain() -> void:
	if not is_instance_valid(terrain) or terrain.data == null or carved_heights.is_empty():
		return
	var spacing := terrain.vertex_spacing
	for i in carved_heights.size():
		var p := Vector3(carved_cells[i * 2] * spacing, 0.0, carved_cells[i * 2 + 1] * spacing)
		terrain.data.set_height(p, carved_heights[i])
		terrain.data.set_control(p, carved_controls[i])
	print("%s: terreno restaurado (%d celdas)." % [name, carved_heights.size()])
	_refresh_terrain()
	carved_cells = PackedInt32Array()
	carved_heights = PackedFloat32Array()
	carved_controls = PackedInt64Array()

func _refresh_terrain() -> void:
	var spacing := terrain.vertex_spacing
	var regions := {}
	for i in range(0, carved_cells.size(), 2):
		regions[terrain.data.get_region_location(Vector3(carved_cells[i] * spacing, 0.0, carved_cells[i + 1] * spacing))] = true
	for location: Vector2i in regions:
		terrain.data.set_region_modified(location, true)
	terrain.data.update_maps(Terrain3DRegion.TYPE_HEIGHT, true, false)
	terrain.data.update_maps(Terrain3DRegion.TYPE_CONTROL, true, false)
	terrain.data.calc_height_range(true)
	if terrain.get_collision() != null:
		terrain.get_collision().build()
	_terrain_changed()
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		var editor := Engine.get_singleton("EditorInterface")
		if editor != null:
			editor.mark_scene_as_unsaved()

static func _smooth(edge0: float, edge1: float, x: float) -> float:
	return smoothstep(edge0, edge1, x) if edge1 > edge0 else (1.0 if x >= edge1 else 0.0)
