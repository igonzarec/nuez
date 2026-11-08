@tool
class_name CliffZone
extends Node3D
## Zona para regenerar o restaurar solo algunos cliffs. Anadela como hijo de CliffFolds, muevela y escalala con el gizmo
## (o cambia Size) y pulsa Regenerar zonas / Restaurar zonas en CliffFolds. Elige cliffs enteros: basta con que la caja
## toque un trozo de la pared. Solo cuenta su planta (x, z); la altura es solo visual. Solo editor: no hace nada en juego.

## Incluye esta zona en Regenerar zonas / Restaurar zonas y en el resaltado. Apagada se conserva para usarla luego.
@export var enabled := true:
	set(value):
		enabled = value
		_changed()
## Tamano de la caja en metros (x, alto, z), antes de la escala del nodo. En vivo.
@export var size := Vector3(30.0, 40.0, 30.0):
	set(value):
		size = value.max(Vector3(0.5, 0.5, 0.5))
		_changed()
## Color de las aristas de la caja en el editor. En vivo.
@export var color := Color(0.2, 0.75, 1.0):
	set(value):
		color = value
		_draw_box()

var _lines: MeshInstance3D

func _ready() -> void:
	set_notify_transform(true)
	_draw_box()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_notify_parent()

func _changed() -> void:
	_draw_box()
	_notify_parent()

func _notify_parent() -> void:
	var parent := get_parent()
	if Engine.is_editor_hint() and parent != null and parent.has_method("zones_changed"):
		parent.zones_changed()

## World-space bounding box of the zone (rotation and scale included).
func world_aabb() -> AABB:
	return global_transform * AABB(-size * 0.5, size)

## True when the world point (x, z) lies inside the zone in plan.
func contains_xz(point: Vector2) -> bool:
	var local := global_transform.affine_inverse() * Vector3(point.x, global_position.y, point.y)
	return absf(local.x) <= size.x * 0.5 and absf(local.z) <= size.z * 0.5

func _draw_box() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if not is_instance_valid(_lines):
		_lines = MeshInstance3D.new()
		_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_lines, false, Node.INTERNAL_MODE_BACK)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.albedo_color = color if enabled else Color(color, 0.35)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.render_priority = 100
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	var h := size * 0.5
	var corners := []
	for k in 8:
		corners.append(Vector3(h.x if k & 1 else -h.x, h.y if k & 2 else -h.y, h.z if k & 4 else -h.z))
	for pair in [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]:
		mesh.surface_add_vertex(corners[pair[0]])
		mesh.surface_add_vertex(corners[pair[1]])
	mesh.surface_end()
	_lines.mesh = mesh
