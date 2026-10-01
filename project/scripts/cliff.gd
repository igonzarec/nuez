extends Node3D
## Paredón norte: geometría y colisión comparten exactamente la misma superficie.

func _ready() -> void:
	name = "SnowyCliff"
	var ring := PackedVector2Array([Vector2(-17, -52), Vector2(-11, -48.5), Vector2(-6, -49.5), Vector2(-3, -48), Vector2(3, -48), Vector2(7, -49), Vector2(12, -48.8), Vector2(18, -53), Vector2(22, -59), Vector2(14, -67), Vector2(5, -71), Vector2(-8, -68), Vector2(-21, -61)])
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/cliff.gdshader")
	var rock := SurfaceTool.new()
	rock.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Estratos y triángulos de distinto tono hacen legible la pared vertical.
	for layer in 13:
		for side in ring.size():
			var a := ring[side]
			var b := ring[(side + 1) % ring.size()]
			var vertices := [_vertex(a, layer), _vertex(b, layer), _vertex(a, layer + 1), _vertex(b, layer + 1)]
			for tri in 2:
				rock.set_color(Color("797e85").lightened(sin(float(layer * 19 + side * 7 + tri)) * 0.08))
				for index in ([0, 2, 1] if tri == 0 else [1, 2, 3]):
					rock.add_vertex(vertices[index])
	# La meseta superior también tiene colisión y sirve para salir del agarre.
	for side in ring.size():
		var a := ring[side]
		var b := ring[(side + 1) % ring.size()]
		rock.set_color(Color("edf2f7"))
		for vertex in [Vector3(0, 52, -58), _vertex(b, 13), _vertex(a, 13)]:
			rock.add_vertex(vertex)
	rock.generate_normals()
	var mesh: ArrayMesh = rock.commit()
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	add_child(visual)
	var body := StaticBody3D.new()
	body.name = "ClimbableRock"
	body.add_to_group("climbable")
	var collision := CollisionShape3D.new()
	collision.shape = mesh.create_trimesh_shape()
	body.add_child(collision)
	add_child(body)
	# Contrafuertes facetados rompen la silueta de la meseta; dejan despejada
	# la cara central de roca clara que comunica la ruta de ascenso.
	for item in [Vector3(-20, 12, -55), Vector3(20, 16, -58), Vector3(-16, 30, -62), Vector3(13, 37, -65)]:
		var buttress := TrailLevel.part(self, TrailLevel.sphere(1, 2), Color("737b83"), item, Vector3(8, item.y * 0.7, 8))
		buttress.material_override = material
		var buttress_body := StaticBody3D.new()
		buttress_body.add_to_group("climbable")
		var buttress_collision := CollisionShape3D.new()
		buttress_collision.shape = buttress.mesh.create_convex_shape()
		buttress_body.add_child(buttress_collision)
		buttress.add_child(buttress_body)
	# Repisas laterales: el centro queda libre para una ascensión continua.
	for shelf in [Vector3(-9, 14, -49), Vector3(9, 29, -49), Vector3(-9, 41, -49)]:
		_box("RestLedge", shelf, Vector3(7, 0.6, 3.2), Color("c7d1db"), true)
	# Nieve facetada en la cima, fuera de la salida central.
	for p in [Vector3(-10, 52.15, -56), Vector3(10, 52.15, -58), Vector3(0, 52.15, -65)]:
		TrailLevel.part(self, TrailLevel.sphere(2.8, 0.5), Color("eaf1fa"), p)
	_box("CrossBase", Vector3(0, 52.3, -60), Vector3(2, 0.6, 2), Color("929aa6"), false)
	_box("SummitCrossVertical", Vector3(0, 55.1, -60), Vector3(0.5, 5.2, 0.5), Color("5c483b"), false)
	_box("SummitCrossHorizontal", Vector3(0, 56.1, -60), Vector3(3.1, 0.5, 0.5), Color("5c483b"), false)
	_box("CrossSnow", Vector3(0, 56.39, -60), Vector3(3.15, 0.1, 0.55), Color("f4f6ff"), false)
	var sign := Label3D.new()
	sign.text = "PAREDÓN DE LA CRUZ\nMira a la roca y mantén Brincar\nPalanca: escalar · Soltar: desprenderse"
	sign.position = Vector3(0, 2.8, -45)
	sign.font_size = 40
	sign.pixel_size = 0.012
	add_child(sign)

func _vertex(p: Vector2, layer: int) -> Vector3:
	var fraction := float(layer) / 13.0
	var taper := 1.0 - fraction * 0.18
	# El corredor central es continuo; las aristas laterales cambian por estrato.
	var roughness := smoothstep(3.0, 12.0, absf(p.x))
	var ripple := sin(float(layer) * 1.7 + p.x) * roughness * 0.4
	return Vector3(p.x * taper + ripple, fraction * 52.0, p.y + ripple)

func _box(label: String, center: Vector3, size: Vector3, color: Color, climbable: bool) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	TrailLevel.part(self, mesh, color, center)
	var body := StaticBody3D.new()
	body.name = label
	body.position = center
	if climbable:
		body.add_to_group("climbable")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
