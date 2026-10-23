@tool
extends RefCounted
## Instancias persistentes: el viento vive en el shader; no hay ciclos de emisión ni reinicios.

static func build(mesh: Mesh, positions: Array[Color], orientations: Array[Color], style: Resource, terrain: Terrain3D, origin: Vector2) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = positions.size()
	for index in positions.size():
		var p := positions[index]
		var o := orientations[index]
		var up := Vector3(o.r,o.g,o.b).normalized()
		var reference := Vector3.BACK if absf(up.z) < 0.99 else Vector3.RIGHT
		var right := up.cross(reference).normalized()
		var basis := Basis(right, up, right.cross(up)) * Basis(Vector3.UP, o.a * TAU)
		var position := Vector3(p.r,p.g,p.b)
		if style.kind == 1:
			# Apoyo bajo el contorno, no sólo el centro. El viento sólo levanta la hoja.
			var lift := 0.0
			for sample_index in 8:
				var angle := sample_index * TAU / 8.0
				var probe := basis * Vector3(cos(angle)*p.a*0.36,0,sin(angle)*p.a*0.5)
				var height := terrain.data.get_height(Vector3(origin.x+position.x+probe.x,0,origin.y+position.z+probe.z))
				if is_finite(height): lift = maxf(lift,height+style.leaf_clearance-position.y-probe.y)
			position.y += lift
		multimesh.set_instance_transform(index,Transform3D(basis.scaled(Vector3.ONE*p.a),position))
		multimesh.set_instance_custom_data(index,Color(o.a,fposmod(o.a*37.79,1.0),0,1))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.extra_cull_margin = 1.0
	return instance
