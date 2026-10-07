@tool
extends Marker3D
## Volumen local que autoriza escalada en el modo Selected Zones del acantilado.
## Se mueve/rota con las herramientas normales. No añade colisión física.
## Activa esta región. Se consulta durante el juego sin regenerar la roca.
@export var enabled := true
## Anchura, altura y profundidad en metros. El centro es la posición de este nodo.
@export var size := Vector3(8, 40, 6)

func contains_point(point: Vector3) -> bool:
	var p := to_local(point).abs()
	return enabled and p.x <= absf(size.x) * 0.5 and p.y <= absf(size.y) * 0.5 and p.z <= absf(size.z) * 0.5

func _process(_delta: float) -> void:
	# Un contorno sencillo en el editor permite colocar el volumen sin render pesado.
	if not Engine.is_editor_hint(): return
	var outline := get_node_or_null("Preview") as MeshInstance3D
	if outline == null:
		outline = MeshInstance3D.new()
		outline.name = "Preview"
		outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(outline)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.1, 0.85, 0.55)
		outline.material_override = mat
	if outline.get_meta("size", Vector3.ZERO) == size and outline.visible == enabled: return
	outline.visible = enabled
	outline.set_meta("size", size)
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for axis in 3:
		for a in [-1, 1]:
			for b in [-1, 1]:
				var p := Vector3.ZERO
				p[(axis + 1) % 3] = a * size[(axis + 1) % 3] * 0.5
				p[(axis + 2) % 3] = b * size[(axis + 2) % 3] * 0.5
				p[axis] = -size[axis] * 0.5
				mesh.surface_add_vertex(p)
				p[axis] *= -1
				mesh.surface_add_vertex(p)
	mesh.surface_end()
	outline.mesh = mesh
