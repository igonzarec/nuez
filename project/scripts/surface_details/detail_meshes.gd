@tool
extends RefCounted
## Geometría pequeña generada en código: sin dependencias de imágenes externas.

const LeafGeometry = preload("res://scripts/surface_details/leaf_geometry.gd")

static func build(style: Resource) -> ArrayMesh:
	if style.kind == 1: return LeafGeometry.build(style)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	if style.kind == 3:
		_grass(tool, style)
	else:
		_granule(tool, style)
	tool.generate_normals()
	return tool.commit()

static func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2) -> void:
	for pair in [[a,uv_a],[b,uv_b],[c,uv_c]]:
		tool.set_uv(pair[1])
		tool.add_vertex(pair[0])

static func _granule(tool: SurfaceTool, style: Resource) -> void:
	var segments := 7
	var rings := 3
	tool.set_smooth_group(-1)
	for ring in rings:
		for segment in segments:
			var a := _dome(float(ring)/rings, float(segment)/segments, style)
			var b := _dome(float(ring+1)/rings, float(segment)/segments, style)
			var c := _dome(float(ring+1)/rings, float(segment+1)/segments, style)
			var d := _dome(float(ring)/rings, float(segment+1)/segments, style)
			_triangle(tool,a,b,c,Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z))
			if ring > 0:
				_triangle(tool,a,c,d,Vector2(a.x,a.z),Vector2(c.x,c.z),Vector2(d.x,d.z))

static func _dome(v: float, u: float, style: Resource) -> Vector3:
	var angle := u * TAU
	var latitude := v * PI * 0.5
	var irregularity := 0.18
	var radius := sin(latitude) * 0.5 * (1.0 + sin(angle*3.0+0.7)*irregularity + cos(angle*5.0+v)*irregularity*0.5)
	return Vector3(cos(angle)*radius,cos(latitude)*style.thickness*0.5,sin(angle)*radius)

static func _grass(tool: SurfaceTool, style: Resource) -> void:
	for cross_index in 2:
		var basis := Basis(Vector3.UP, cross_index*PI*0.5)
		for section in 4:
			var t0 := float(section)/4.0
			var t1 := float(section+1)/4.0
			var width0: float = style.thickness*(1.0-t0)*0.5
			var width1: float = style.thickness*(1.0-t1)*0.5
			var a := basis*Vector3(-width0,t0,t0*t0*0.12)
			var b := basis*Vector3(width0,t0,t0*t0*0.12)
			var c := basis*Vector3(width1,t1,t1*t1*0.12)
			var d := basis*Vector3(-width1,t1,t1*t1*0.12)
			_triangle(tool,a,b,c,Vector2(0,t0),Vector2(1,t0),Vector2(1,t1))
			_triangle(tool,a,c,d,Vector2(0,t0),Vector2(1,t1),Vector2(0,t1))
