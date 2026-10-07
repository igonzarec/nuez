extends Node3D
## Huellas visuales reutilizables para una superficie Terrain3D nevada.

@export_group("Referencias")
## Personaje que emite las pisadas. Debe ser ExplorerPlayer y tener colision con el terreno.
@export_node_path("ExplorerPlayer") var player_path: NodePath
@export_group("Huellas")
## Activa o desactiva las huellas sin eliminar los recursos ya creados.
@export var enabled := true
## Numero maximo de huellas simultaneas. Al llegar al limite se recicla la mas antigua; aumentar usa mas nodos visuales.
@export_range(8, 256, 8) var footprint_limit := 96
## Segundos que una huella permanece visible. No afecta el suelo ni la colision.
@export_range(2.0, 120.0, 1.0, "suffix:s") var footprint_seconds := 35.0
## Ancho y largo de cada marca, en metros. Cambia la malla visual en la siguiente huella.
@export var footprint_size := Vector2(0.24, 0.38)
## Tinte de la nieve compactada. Una opacidad menor hace la marca mas discreta.
@export var footprint_color := Color(0.49, 0.64, 0.72, 1.0)

var player: ExplorerPlayer
var _prints: Array[MeshInstance3D] = []
var _ages: Array[float] = []
var _next_print := 0
var _side := 1.0

func _ready() -> void:
	player = get_node_or_null(player_path) as ExplorerPlayer
	if player == null:
		push_error("Terrain3DFootprints necesita un ExplorerPlayer asignado.")
		return
	player.feedback.connect(_on_player_feedback)

func _process(delta: float) -> void:
	for i in _prints.size():
		_ages[i] += delta
		_prints[i].visible = _ages[i] < footprint_seconds
		if _prints[i].visible:
			_prints[i].material_override.set_shader_parameter("fade", 1.0 - smoothstep(footprint_seconds * 0.6, footprint_seconds, _ages[i]))

func _on_player_feedback(kind: String) -> void:
	if kind != "step" or not enabled or player == null:
		return
	_side *= -1.0
	var right := Vector3.RIGHT.rotated(Vector3.UP, player.model.rotation.y)
	var hit := _ground(player.global_position + right * _side * 0.16 + Vector3.UP * 0.65)
	if hit.is_empty():
		return
	var mark := _next_mark()
	var normal: Vector3 = hit.normal
	var tangent := right.slide(normal).normalized()
	if tangent.length_squared() < 0.001:
		tangent = Vector3.FORWARD.slide(normal).normalized()
	mark.global_transform = Transform3D(Basis(tangent, normal, tangent.cross(normal)), Vector3(hit.position) + normal * 0.015)
	mark.visible = true
	mark.material_override.set_shader_parameter("fade", 1.0)

func _ground(origin: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * 4.0, 1)
	query.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)

func _next_mark() -> MeshInstance3D:
	var mark: MeshInstance3D
	if _prints.size() < footprint_limit:
		mark = MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = footprint_size
		mark.mesh = plane
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/snow_footprint.gdshader")
		material.set_shader_parameter("print_color", footprint_color)
		mark.material_override = material
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mark)
		_prints.append(mark)
		_ages.append(0.0)
		_next_print = _prints.size() - 1
	else:
		mark = _prints[_next_print]
	_ages[_next_print] = 0.0
	_next_print = (_next_print + 1) % _prints.size()
	return mark
