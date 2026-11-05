@tool
class_name WaterBody
extends Path3D
## Base de WaterRiver y WaterLake: superficie de agua generada desde la curva (Path3D), su material y el tallado del cauce
## en Terrain3D. La malla se rehace sola al editar la curva y no se guarda en la escena (sin bake ni coste de disco).
## Tallar solo baja el terreno hasta el perfil del agua y nunca lo sube: volver a tallar conserva lo que hayas cavado a mano
## mas hondo. Restaurar devuelve las alturas (y la pintura) de antes del primer tallado. Guia: docs/water.md.

const SHADER := preload("res://shaders/water/water_surface.gdshader")
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

## Celdas de Terrain3D (x, z en pixeles globales) que este nodo cambio, con su altura y control originales.
@export_storage var carved_cells := PackedInt32Array()
@export_storage var carved_heights := PackedFloat32Array()
@export_storage var carved_controls := PackedInt64Array()

var _material: ShaderMaterial
var _surface: MeshInstance3D
var _rebuild_queued := false

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
	_apply_style()
	var mesh := _build_mesh() if curve != null else null
	if mesh != null and mesh.get_surface_count() > 0:
		mesh.surface_set_material(0, _material)
	_surface.mesh = mesh

func _apply_style() -> void:
	if style != null and _material != null:
		style.apply(_material)

## Terrain profile of a bank above the waterline at a horizontal distance outside the water.
func _bank_height(waterline: float, outside: float, angle: float) -> float:
	return waterline + outside * tan(deg_to_rad(angle))

func carve() -> void:
	if not is_instance_valid(terrain) or terrain.data == null:
		push_warning("%s: asigna un Terrain3D con datos para tallar el cauce." % name)
		return
	var start := Time.get_ticks_msec()
	var targets := {}
	_collect_targets(targets)
	var spacing := terrain.vertex_spacing
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
	print("%s: cauce tallado, %d celdas bajadas, %d pintadas, %d ms." % [name, lowered, painted, Time.get_ticks_msec() - start])
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
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		var editor := Engine.get_singleton("EditorInterface")
		if editor != null:
			editor.mark_scene_as_unsaved()

static func _smooth(edge0: float, edge1: float, x: float) -> float:
	return smoothstep(edge0, edge1, x) if edge1 > edge0 else (1.0 if x >= edge1 else 0.0)
