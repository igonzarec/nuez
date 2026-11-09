@tool
class_name ClimbDebugView
extends Node3D
## Vista de depuración que colorea la pantalla según la pendiente de cada
## superficie: caminable, deslizante, sólo sostener agarre, agarre inicial y
## bloqueada. Usa por defecto los mismos umbrales que el player (grupo Escalada),
## así que al ajustarlos en Remote el color cambia en vivo.
##
## Límite: es una lectura por pendiente con las reglas de ClimbRules. Coincide con
## Terrain3D y con las mallas en modo Heredar; las que usan ángulo propio o zonas
## no se distinguen. Ver project/docs/climb_debug_view.md.

const SHADER := preload("res://shaders/debug/climb_slope_view.gdshader")

@export_group("Activación")
## Muestra la vista al empezar la partida. Normalmente apagado; usa Toggle Key para alternarla. En vivo.
@export var enabled := false:
	set(value):
		enabled = value
		_refresh_visibility()
## Permite alternar la vista con Toggle Key durante el juego. Desactivado ignora la tecla.
@export var toggle_key_enabled := true
## Tecla que alterna la vista durante el juego. F3 por defecto. Sólo en ejecución, no en el editor.
@export var toggle_key: Key = KEY_F3
## Dibuja la vista también en el viewport del editor, útil al esculpir Terrain3D. Usa los umbrales manuales salvo que Player Path apunte a un player de la escena. Coste: un pase de pantalla extra mientras está activo.
@export var editor_preview := false:
	set(value):
		editor_preview = value
		_refresh_visibility()
## Muestra en pantalla una leyenda con los rangos en grados de cada color. Sólo en ejecución.
@export var show_legend := true:
	set(value):
		show_legend = value
		_refresh_visibility()

@export_group("Umbrales")
## Lee en vivo del player Walkable Slope Degrees y su ClimbRules. Desactivado (o sin player, p. ej. en el editor sin Player Path)
## usa Climb Rules y Manual Walkable Degrees de abajo.
@export var read_from_player := true
## Player del que leer umbrales. Vacío: usa el target de la cámara padre o busca el primer ExplorerPlayer que no sea NPC.
@export var player_path: NodePath
## Reglas usadas sin player. Asigna el mismo .tres que el Player (resources/climb/climb_rules_default.tres) para que el editor
## muestre lo mismo que el juego. Vacío usa los valores por defecto de ClimbRules.
@export var climb_rules: ClimbRules
## Pendiente máxima caminable, en grados desde horizontal, cuando no hay player. Equivale a Walkable Slope Degrees del player.
@export_range(0.0, 89.0, 0.5, "suffix:°") var manual_walkable_degrees := 48.0

@export_group("Colores")
## Suelo caminable (≤ Walkable). Alfa 0 lo deja sin colorear para no tapar el terreno normal.
@export var walk_color := Color(0.25, 0.55, 1.0, 0.0)
## Demasiado empinado para caminar y demasiado suave para escalar: el player desliza.
@export var slide_color := Color(1.0, 0.5, 0.1, 0.35)
## Sólo sostiene un agarre ya iniciado (Sustain Min hasta Grab Min). No permite empezar a trepar aquí.
@export var sustain_color := Color(1.0, 0.9, 0.1, 0.5)
## Se puede iniciar la escalada (Grab Min hasta Grab Max).
@export var grab_color := Color(0.1, 0.95, 0.35, 0.6)
## Más vertical que Grab Max o techo/saliente: no se agarra.
@export var blocked_color := Color(0.95, 0.1, 0.15, 0.6)
## Multiplica la opacidad de todas las bandas. 0 invisible, 1 usa el alfa de cada color. En vivo.
@export_range(0.0, 1.0, 0.01) var opacity := 1.0
## Grosor en grados de las isolíneas dibujadas justo en cada umbral. 0 las desactiva; 1–2° marca bien los bordes entre bandas.
@export_range(0.0, 5.0, 0.1, "suffix:°") var threshold_line_width_degrees := 0.0
## Color de las isolíneas de umbral.
@export var threshold_line_color := Color(0.0, 0.0, 0.0, 0.6)

@export_group("Alcance")
## Distancia máxima a la cámara que se colorea, en metros. Mayor cubre más terreno, pero a mucha distancia la precisión del depth buffer genera ruido en la normal.
@export_range(5.0, 500.0, 1.0, "suffix:m") var max_distance := 60.0
## Metros antes de Max Distance en los que el color se desvanece. 0 corta en seco.
@export_range(0.0, 100.0, 0.5, "suffix:m") var fade_distance := 15.0
## Radio alrededor del player (centro a 0,7 m de altura) que no se colorea, para que la ardilla no se tiña. 0 lo desactiva. Valores > 0,5 pueden ocultar la pared a la que se agarra.
@export_range(0.0, 3.0, 0.05, "suffix:m") var ignore_player_radius := 0.0
## Orden de dibujo del overlay. 102 queda encima del contorno (101) y de la vista submarina (100).
@export_range(-128, 127) var render_priority := 102:
	set(value):
		render_priority = value
		if _material: _material.render_priority = value

var _mesh: MeshInstance3D
var _material: ShaderMaterial
var _legend_layer: CanvasLayer
var _legend: RichTextLabel
var _player: Node
var _lookup_wait := 0.0
var _default_rules := ClimbRules.new()

func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.render_priority = render_priority
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = quad
	_mesh.material_override = _material
	_mesh.extra_cull_margin = 16384
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh, false, Node.INTERNAL_MODE_BACK)
	if not Engine.is_editor_hint():
		_legend_layer = CanvasLayer.new()
		_legend_layer.layer = 90
		_legend = RichTextLabel.new()
		_legend.bbcode_enabled = true
		_legend.fit_content = true
		_legend.autowrap_mode = TextServer.AUTOWRAP_OFF
		_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_legend.position = Vector2(16, 16)
		_legend.add_theme_font_size_override("normal_font_size", 15)
		_legend.add_theme_font_size_override("bold_font_size", 15)
		_legend.add_theme_color_override("font_outline_color", Color.BLACK)
		_legend.add_theme_constant_override("outline_size", 5)
		_legend_layer.add_child(_legend)
		add_child(_legend_layer, false, Node.INTERNAL_MODE_BACK)
	_refresh_visibility()

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not toggle_key_enabled:
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and (key.physical_keycode == toggle_key or key.keycode == toggle_key):
		enabled = not enabled
		get_viewport().set_input_as_handled()

func _active() -> bool:
	return editor_preview if Engine.is_editor_hint() else enabled

func _refresh_visibility() -> void:
	if not is_inside_tree() or not _mesh:
		return
	var active := _active()
	_mesh.visible = active
	if _legend_layer:
		_legend_layer.visible = active and show_legend
	set_process(active)

func _process(delta: float) -> void:
	var t := _thresholds(delta)
	var walk: float = t.walk
	var sustain_on: bool = t.sustain_enabled
	var sustain: float = t.sustain
	var grab_min: float = minf(t.grab_min, t.grab_max)
	var grab_max: float = maxf(t.grab_min, t.grab_max)
	_material.set_shader_parameter("walkable_max_deg", walk)
	_material.set_shader_parameter("sustain_enabled", sustain_on)
	_material.set_shader_parameter("sustain_min_deg", sustain)
	_material.set_shader_parameter("grab_min_deg", grab_min)
	_material.set_shader_parameter("grab_max_deg", grab_max)
	_material.set_shader_parameter("walk_color", walk_color)
	_material.set_shader_parameter("slide_color", slide_color)
	_material.set_shader_parameter("sustain_color", sustain_color)
	_material.set_shader_parameter("grab_color", grab_color)
	_material.set_shader_parameter("blocked_color", blocked_color)
	_material.set_shader_parameter("opacity", opacity)
	_material.set_shader_parameter("threshold_line_width_deg", threshold_line_width_degrees)
	_material.set_shader_parameter("threshold_line_color", threshold_line_color)
	_material.set_shader_parameter("max_distance", max_distance)
	_material.set_shader_parameter("fade_distance", fade_distance)
	var ignore := ignore_player_radius > 0.0 and _player is Node3D
	_material.set_shader_parameter("ignore_radius", ignore_player_radius if ignore else 0.0)
	if ignore:
		_material.set_shader_parameter("ignore_center", (_player as Node3D).global_position + Vector3.UP * 0.7)
	if _legend and _legend_layer.visible:
		_legend.text = _legend_text(t.from_player, walk, sustain_on, sustain, grab_min, grab_max)

func _legend_text(from_player: bool, walk: float, sustain_on: bool, sustain: float, grab_min: float, grab_max: float) -> String:
	var lines: Array[String] = ["[b]Escalada debug[/b] (%s)%s" % [OS.get_keycode_string(toggle_key), "" if from_player else " · manual"]]
	var slide_top := minf(sustain, grab_min) if sustain_on else grab_min
	lines.append(_legend_line(walk_color, "Caminable", "0°–%.1f°" % walk))
	if slide_top > walk:
		lines.append(_legend_line(slide_color, "Desliza", "%.1f°–%.1f°" % [walk, slide_top]))
	if sustain_on and maxf(sustain, walk) < grab_min:
		lines.append(_legend_line(sustain_color, "Sólo sostener", "%.1f°–%.1f°" % [maxf(sustain, walk), grab_min]))
	lines.append(_legend_line(grab_color, "Agarre", "%.1f°–%.1f°" % [grab_min, grab_max]))
	lines.append(_legend_line(blocked_color, "Bloqueado", "> %.1f°" % grab_max))
	return "\n".join(lines)

func _legend_line(color: Color, label: String, range_text: String) -> String:
	var swatch := Color(color, 1.0) if color.a > 0.0 else Color(color, 0.35)
	return "[color=#%s]■[/color] %s  %s" % [swatch.to_html(true), label, range_text]

func _thresholds(delta: float) -> Dictionary:
	if read_from_player:
		_lookup_wait -= delta
		if not is_instance_valid(_player) and _lookup_wait <= 0.0:
			_lookup_wait = 1.0
			_player = _find_player()
		if is_instance_valid(_player) and _player.has_method("get_climb_rules"):
			return _from_rules(true, float(_player.get("walkable_slope_degrees")), _player.get_climb_rules())
	return _from_rules(false, manual_walkable_degrees, climb_rules if climb_rules else _default_rules)

func _from_rules(from_player: bool, walk: float, rules: ClimbRules) -> Dictionary:
	return {
		"from_player": from_player,
		"walk": walk,
		"sustain_enabled": rules.sustain_enabled,
		"sustain": rules.sustain_min_slope_degrees,
		"grab_min": rules.grab_min_slope_degrees,
		"grab_max": rules.grab_max_slope_degrees,
	}

func _find_player() -> Node:
	if not player_path.is_empty():
		return get_node_or_null(player_path)
	if Engine.is_editor_hint():
		return null
	var parent_target = get_parent().get("target") if get_parent() else null
	if parent_target is ExplorerPlayer:
		return parent_target
	for node in get_tree().root.find_children("*", "CharacterBody3D", true, false):
		if node is ExplorerPlayer and not node.is_in_group("npc_actors"):
			return node
	return null
