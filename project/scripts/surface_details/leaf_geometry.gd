@tool
extends RefCounted
## Hojas independientes del material de nieve: silueta curva y caras superiores coherentes.

static func build(style: Resource) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for section in 8:
		var t0 := float(section) / 8.0
		var t1 := float(section + 1) / 8.0
		var center0 := Vector3(0, sin(t0 * PI) * style.thickness * 0.18 + t0 * t0 * 0.07, t0 - 0.5)
		var center1 := Vector3(0, sin(t1 * PI) * style.thickness * 0.18 + t1 * t1 * 0.07, t1 - 0.5)
		for side in [-1.0, 1.0]:
			var edge0 := Vector3(side * _width(t0), t0 * t0 * 0.07, t0 - 0.5)
			var edge1 := Vector3(side * _width(t1), t1 * t1 * 0.07, t1 - 0.5)
			_triangle(tool, [center0, edge0, edge1], [Vector2(0.5,t0), Vector2(0.5+side*0.5,t0), Vector2(0.5+side*0.5,t1)])
			_triangle(tool, [center0, edge1, center1], [Vector2(0.5,t0), Vector2(0.5+side*0.5,t1), Vector2(0.5,t1)])
	tool.generate_normals()
	return tool.commit()

static func _triangle(tool: SurfaceTool, vertices: Array, uvs: Array) -> void:
	var normal: Vector3 = (vertices[2] - vertices[0]).cross(vertices[1] - vertices[0])
	if normal.length_squared() < 0.00000001: return
	# Godot usa orden horario; ambas mitades deben mirar hacia arriba.
	var order := [0, 1, 2] if normal.y >= 0 else [0, 2, 1]
	for index in order:
		tool.set_uv(uvs[index])
		tool.add_vertex(vertices[index])

static func _width(t: float) -> float:
	return sin(t * PI) * 0.36 * (0.8 + 0.2 * cos(t * PI * 8.0))
