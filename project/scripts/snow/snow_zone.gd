@tool
extends Marker3D
## Zona elíptica sobre X/Z: añade nieve y volumen, o abre un claro. Y no limita la zona.
## Acumular añade nieve; Quitar abre un claro de suelo sin nieve ni espesor añadido.
@export_enum("Acumular", "Quitar") var operation := 0
## Habilita esta zona sin borrar sus ajustes.
@export var enabled := true
## Radio horizontal en metros. Scale X/Z permite convertir el círculo en una elipse.
@export_range(1.0, 100.0, 0.5) var radius := 15.0
## Metros adicionales en el centro. El borde siempre vuelve suavemente al terreno.
@export_range(0.0, 12.0, 0.05) var depth := 2.5
## Intensidad de cobertura al acumular o de borrado al quitar.
@export_range(0.0, 1.0, 0.05) var coverage := 1.0
## Fracción del radio usada como transición. 1 produce un montículo redondeado.
@export_range(0.1, 1.0, 0.05) var softness := 1.0
var _outline: MeshInstance3D
var _last_radius := -1.0

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		set_process(false)
		return
	if is_equal_approx(_last_radius, radius):
		return
	_last_radius = radius
	if not is_instance_valid(_outline):
		_outline = MeshInstance3D.new()
		add_child(_outline)
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in 48:
		for angle in [TAU * i / 48.0, TAU * (i + 1) / 48.0]:
			lines.surface_add_vertex(Vector3(cos(angle) * radius, 0.1, sin(angle) * radius))
	lines.surface_end()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.2, 0.8, 1.0)
	material.no_depth_test = true
	_outline.mesh = lines
	_outline.material_override = material
	_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func weight_at(world_point: Vector3) -> float:
	if not enabled:
		return 0.0
	var local_point := to_local(world_point)
	var distance := Vector2(local_point.x, local_point.z).length() / maxf(radius, 0.01)
	return 1.0 - smoothstep(1.0 - softness, 1.0, distance)

func configuration() -> Array:
	return [global_transform, operation, enabled, radius, depth, coverage, softness]
