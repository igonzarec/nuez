class_name TrailLevel
extends Node3D

const ROUTE: Array[Vector2] = [Vector2(0, 25), Vector2(-10, 22), Vector2(-22, 12), Vector2(-25, -2), Vector2(-18, -19), Vector2(-3, -28), Vector2(17, -21), Vector2(26, -4), Vector2(21, 12), Vector2(9, 19), Vector2(-7, 15), Vector2(-15, 3), Vector2(-10, -10), Vector2(3, -16), Vector2(13, -5), Vector2(7, 6), Vector2(0, 2), Vector2(0, -4)]
const SEEDS: Array[Vector2] = [Vector2(-4, 23.8), Vector2(-10, 22), Vector2(-20, 13.7), Vector2(-23, -7), Vector2(-3, -28), Vector2(26, -4), Vector2(-13, -2), Vector2(3, -16), Vector2(9, 2), Vector2(-14, -22), Vector2(19, -19), Vector2(14, 17), Vector2(-9, 15), Vector2(6, -10), Vector2(0, -2)]
const LAMP_POINTS: Array[Vector2] = [Vector2(-22, 12), Vector2(-15, 3), Vector2(0, -4)]
# Punto de inicio junto al farol de la cima, con espacio para no aparecer dentro de él.
const SUMMIT_SPAWN_POINT := Vector2(2.2, -4.0)
var lamps: Array[TrailLamp] = []
var seeds: Array[LightFragment] = []
var guide: TrailInteractable
var residents: Array[Node3D] = []
var title_camera: Camera3D
var environment: Environment
var snow: CPUParticles3D
static var trail_mask: ImageTexture
@export var snowfall_amount := 500
@export var sunlight_energy := 0.65
@export var ambient_energy := 0.62

static func height_at(x: float, z: float) -> float:
	# A fixed radial mountain with asymmetric shoulders and a gently flattened summit.
	# The trail circles every side twice; there is no randomized terrain or one-sided ramp.
	var radius := Vector2(x, z + 4.0).length()
	var slope := clampf((32.0 - radius) / 29.0, 0, 1)
	var mountain := pow(slope, 1.12) * 17.0
	var irregularity := (sin(x * 0.25) * cos(z * 0.20) * 0.65 + sin(z * 0.33 + x * 0.12) * 0.32) * smoothstep(3, 8, radius) * smoothstep(34, 27, radius)
	var clearing := smoothstep(8.5, 3.0, Vector2(x + 3.0, z - 24.0).length())
	return lerpf(mountain + irregularity, 1.3, clearing)

static func point(x: float, z: float, lift := 0.0) -> Vector3:
	return Vector3(x, height_at(x, z) + lift, z)

static func summit_spawn(lift := 0.15) -> Vector3:
	return point(SUMMIT_SPAWN_POINT.x, SUMMIT_SPAWN_POINT.y, lift)

static func mat(color: Color, emission := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	material.metallic_specular = 0.15
	if emission > 0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material

static func part(parent: Node3D, mesh: Mesh, color: Color, location: Vector3, size := Vector3.ONE) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat(color)
	instance.position = location
	instance.scale = size
	parent.add_child(instance)
	return instance

static func sphere(radius: float, height: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 4
	return mesh

static func cylinder(bottom: float, top: float, height: float, sides := 8) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = sides
	return mesh

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_lighting()
	_terrain()
	_decorate()
	add_child(preload("res://scripts/cliff.gd").new())
	_objects()
	_weather()
	title_camera = Camera3D.new()
	add_child(title_camera)
	title_camera.position = point(7, 16, 4.8)
	title_camera.look_at(point(-1, 23, 1.4))
	title_camera.fov = 51

func _lighting() -> void:
	var world_env := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("7399a0")
	sky_material.sky_horizon_color = Color("d3d6bd")
	sky_material.ground_bottom_color = Color("7b948a")
	sky_material.ground_horizon_color = Color("d3d6bd")
	sky_material.sun_angle_max = 3.0
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d6e0db")
	environment.ambient_light_energy = ambient_energy
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.fog_enabled = true
	environment.fog_light_color = Color("a4bdc4")
	environment.fog_density = 0.006
	world_env.environment = environment
	add_child(world_env)
	var sunlight := DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-35, -35, 0)
	sunlight.light_color = Color("fff0d6")
	sunlight.light_energy = sunlight_energy
	sunlight.shadow_enabled = true
	sunlight.directional_shadow_max_distance = 100
	add_child(sunlight)

func _path_distance(p: Vector2) -> float:
	var distance := 1000.0
	for i in ROUTE.size() - 1:
		distance = minf(distance, p.distance_to(Geometry2D.get_closest_point_to_segment(p, ROUTE[i], ROUTE[i + 1])))
	return distance

func _terrain() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# El terreno natural continúa hasta el paredón, sin plataforma artificial.
	for z in range(-74, 38, 2):
		for x in range(-38, 38, 2):
			var corners: Array[Vector3] = [point(x, z), point(x + 2, z), point(x, z + 2), point(x + 2, z + 2)]
			for index in [0, 1, 2, 1, 3, 2]:
				var vertex := corners[index]
				var dist := _path_distance(Vector2(vertex.x, vertex.z))
				var path_color := Color("ac783f")
				var patch := smoothstep(0.1, 0.72, sin(vertex.x * 0.28) * cos(vertex.z * 0.22) + maxf(0, -vertex.z) * 0.023)
				var snow_color := Color("66762e").lerp(Color("b7bfe2"), patch)
				var shade := sin(float(x) * 2.1 + float(z) * 1.2) * 0.025
				surface.set_color(path_color.lerp(snow_color, smoothstep(1.3, 3.1, dist)).lightened(shade))
				surface.add_vertex(vertex)
	surface.generate_normals()
	var mesh := surface.commit()
	var ground := MeshInstance3D.new()
	ground.mesh = mesh
	var ground_mat := ShaderMaterial.new()
	ground_mat.shader = preload("res://shaders/ground.gdshader")
	if trail_mask == null:
		var mask_image := Image.create(256, 256, false, Image.FORMAT_RF)
		for v in 256:
			for u in 256:
				var location := Vector2((float(u) + 0.5) / 256 * 76 - 38, (float(v) + 0.5) / 256 * 78 - 40)
				mask_image.set_pixel(u, v, Color(minf(1, _path_distance(location) / 6.0), 0, 0))
		trail_mask = ImageTexture.create_from_image(mask_image)
	ground_mat.set_shader_parameter("trail_mask", trail_mask)
	ground.material_override = ground_mat
	add_child(ground)
	# A distant valley skirt keeps the playable heightfield's square edge out of view.
	var valley := part(self, cylinder(90, 90, 0.8, 32), Color.WHITE, Vector3(0, -0.62, -4))
	valley.material_override = ground_mat
	var body := StaticBody3D.new()
	body.collision_layer = 1 | 4 # Mundo caminable + Camera Blocker.
	var collision := CollisionShape3D.new()
	collision.shape = mesh.create_trimesh_shape()
	body.add_child(collision)
	add_child(body)
	# Boundaries sit behind the perimeter boulders and trees.
	for item: Array in [[Vector3(-35, 9, -18), Vector3(1, 140, 116)], [Vector3(35, 9, -18), Vector3(1, 140, 116)], [Vector3(-25, 9, -37), Vector3(20, 140, 1)], [Vector3(25, 9, -37), Vector3(20, 140, 1)], [Vector3(0, 9, -74), Vector3(76, 140, 1)], [Vector3(0, 9, 35), Vector3(76, 140, 1)]]:
		var wall := StaticBody3D.new()
		wall.collision_layer = 1 | 4
		wall.position = item[0]
		var box := BoxShape3D.new()
		box.size = item[1]
		var shape := CollisionShape3D.new()
		shape.shape = box
		wall.add_child(shape)
		add_child(wall)

func _tree(x: float, z: float, size: float) -> void:
	if _path_distance(Vector2(x, z)) < 2.5:
		return
	var tree := Node3D.new()
	tree.position = point(x, z)
	tree.scale = Vector3.ONE * size
	add_child(tree)
	part(tree, cylinder(0.22, 0.16, 2.4), Color("655c55"), Vector3(0, 1.2, 0))
	for layer in 3:
		var width := 1.45 - layer * 0.31
		part(tree, cylinder(width, 0, 2.0), Color("41683b").lightened(layer * 0.05), Vector3(0, 2.0 + layer * 0.85, 0))
		part(tree, cylinder(width * 0.48, 0, 0.92), Color("dbe7dd"), Vector3(0, 2.55 + layer * 0.85, 0))
	var body := StaticBody3D.new()
	body.collision_layer = 1 | 4
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.23
	shape.height = 3
	collision.position.y = 1.5
	collision.shape = shape
	body.add_child(collision)
	tree.add_child(body)

func _rock(x: float, z: float, size: Vector3, solid := true) -> void:
	if _path_distance(Vector2(x, z)) < maxf(size.x, size.z) + 2.0 or Vector2(x, z + 4).length() < 8.0:
		return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var source := sphere(1, 2).get_faces()
	for i in range(0, source.size(), 3):
		var top := (source[i].y + source[i + 1].y + source[i + 2].y) / 3.0
		surface.set_color(Color("c3cebe") if top > 0.48 else Color("747b70").lightened(sin(float(i)) * 0.04))
		for j in 3:
			var v := source[i + j]
			v.x += sin(v.y * 3 + v.z) * 0.13
			v.z += sin(v.x * 4 + v.y) * 0.1
			surface.add_vertex(v)
	surface.generate_normals()
	var rock := part(self, surface.commit(), Color.WHITE, point(x, z, size.y * 0.32), size)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/rock.gdshader")
	rock.material_override = material
	rock.rotation.y = x * 1.71
	rock.rotation.z = sin(x + z) * 0.18
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1 | 4
		var collision := CollisionShape3D.new()
		collision.shape = rock.mesh.create_convex_shape()
		body.add_child(collision)
		rock.add_child(body)

func _decorate() -> void:
	# Pinos alrededor del paredón; el acceso central a la roca queda libre.
	for pine: Vector3 in [Vector3(-7, -42, 1.25), Vector3(8, -43, 1.4), Vector3(-14, -44, 1.6), Vector3(15, -44, 1.35), Vector3(-23, -46, 1.5), Vector3(25, -47, 1.7), Vector3(-29, -54, 1.6), Vector3(29, -57, 1.45), Vector3(-28, -63, 1.8), Vector3(27, -66, 1.6), Vector3(-20, -70, 1.3), Vector3(17, -71, 1.5)]:
		_tree(pine.x, pine.y, pine.z)
	for p: Vector3 in [Vector3(-7, 23, 1.05), Vector3(-13, 21, 1.1), Vector3(-19, 18, 1.4), Vector3(-22, 7, 1.2), Vector3(-20, 0, 1.3), Vector3(-21, -6, 1.0), Vector3(-17, -18, 1.25), Vector3(-11, -22, 1.3), Vector3(-3, -23, 1.1), Vector3(2, -28, 1.2), Vector3(20, -23, 1.0), Vector3(24, -14, 1.15), Vector3(24, -1, 1.0), Vector3(21, 8, 1.2), Vector3(17, 19, 1.25), Vector3(10, 25, 1.1), Vector3(7, -4, 1.1), Vector3(2, 4, 1.2), Vector3(-3, -2, 0.9)]:
		_tree(p.x, p.y, p.z)
	# Fixed clusters frame the route without covering its central sightline.
	for p: Vector3 in [Vector3(-22, 23, 1.1), Vector3(-18, 25, 1.3), Vector3(-12, 29, 1.0), Vector3(19, 26, 1.3), Vector3(22, 22, 1.3), Vector3(23, 17, 1.2), Vector3(20, 14, 0.9), Vector3(-23, 14, 1.3), Vector3(-24, 10, 1.0), Vector3(-21, 4, 1.0), Vector3(-23, -14, 1.3), Vector3(-22, -20, 1.1), Vector3(-16, -25, 1.5), Vector3(-7, -27, 1.2), Vector3(1, -24, 0.9), Vector3(24, -26, 1.3), Vector3(23, -20, 1.1), Vector3(23, -8, 1.3), Vector3(22, 3, 1.2), Vector3(8, 1, 1.2), Vector3(6, 5, 1.3), Vector3(6, -7, 1.0), Vector3(0, -5, 1.4), Vector3(-3, 7, 0.9)]:
		_tree(p.x, p.y, p.z)
	for i in 16:
		var z := -29.0 + i * 4
		_rock(-33, z, Vector3(2.4, 2.7 + (i % 3), 2.4))
		_rock(33, z, Vector3(2.1, 2.0 + (i % 2), 2.3))
	for i in 10:
		if absf(-25 + i * 5) > 10:
			_rock(-25 + i * 5, -35, Vector3(3.2, 3.6, 2.4))
		_tree(-25 + i * 5, 33, 1.3)
	_rock(-5, 5, Vector3(1.8, 1.2, 1.7))
	_rock(-18, -10, Vector3(1.8, 1.0, 2.0))
	_rock(4, -21, Vector3(1.2, 0.7, 1.4))
	_rock(9, -26, Vector3(3.0, 1.5, 2.2))
	# A layered outcrop divides the two trails and gives the climb a readable landmark.
	_rock(-1.0, -5.5, Vector3(4.3, 4.4, 5.5))
	_rock(2.5, -8.0, Vector3(3.4, 5.0, 3.5))
	_rock(6.0, -6.0, Vector3(2.0, 2.5, 2.0))
	var water_material := ShaderMaterial.new()
	water_material.shader = preload("res://shaders/water.gdshader")
	var pool_mesh := cylinder(2.8, 2.8, 0.03, 18)
	var pond := part(self, pool_mesh, Color.WHITE, point(27, 22, 0.02), Vector3(1, 1, 0.8))
	pond.material_override = water_material
	var pool_collision := StaticBody3D.new()
	var pool_shape := CollisionShape3D.new()
	pool_shape.shape = pool_mesh.create_convex_shape()
	pool_collision.add_child(pool_shape)
	pond.add_child(pool_collision)
	for p: Vector2 in [Vector2(-5, 20), Vector2(-17, 12), Vector2(-17, -4), Vector2(-7, -17), Vector2(15, -18), Vector2(14, 8), Vector2(6, 18)]:
		for i in 3:
			part(self, sphere(0.5, 0.9), Color("749487"), point(p.x + i * 0.4, p.y, 0.25))
	_grass_and_waymarks()
	# Trailhead lodge, its pitched roof, chimney, and glowing windows.
	var cabin := Node3D.new()
	cabin.position = point(-7, 27)
	add_child(cabin)
	var walls := BoxMesh.new()
	walls.size = Vector3(5.0, 3.2, 3.8)
	part(cabin, walls, Color("856e5e"), Vector3(0, 1.6, 0))
	var roof := PrismMesh.new()
	roof.size = Vector3(6.2, 2.1, 5.0)
	part(cabin, roof, Color("dce6df"), Vector3(0, 3.9, 0))
	for x in [-1.35, 1.35]:
		var window := BoxMesh.new()
		window.size = Vector3(0.85, 1.0, 0.07)
		part(cabin, window, Color("ffd18a"), Vector3(x, 1.8, -1.94)).material_override = mat(Color("ffc579"), 0.6)
	var door := BoxMesh.new()
	door.size = Vector3(0.9, 2, 0.08)
	part(cabin, door, Color("394e50"), Vector3(0, 1, -1.96))
	for x in [-2.35, 2.35]:
		part(cabin, cylinder(0.12, 0.12, 3.2), Color("544935"), Vector3(x, 1.6, -1.94))
	for y in [0.5, 1.1, 1.7, 2.3, 2.9]:
		var beam := BoxMesh.new()
		beam.size = Vector3(5.02, 0.035, 0.04)
		part(cabin, beam, Color("645544"), Vector3(0, y, -1.93))
	var chimney := BoxMesh.new()
	chimney.size = Vector3(0.7, 1.5, 0.65)
	part(cabin, chimney, Color("737d71"), Vector3(-1.5, 4.6, 0.5))
	var welcome_light := OmniLight3D.new()
	welcome_light.position = Vector3(0, 2.2, -2.3)
	welcome_light.light_color = Color("ffc270")
	welcome_light.light_energy = 0.9
	welcome_light.omni_range = 5
	cabin.add_child(welcome_light)
	var cabin_body := StaticBody3D.new()
	cabin_body.collision_layer = 1 | 4
	var cabin_shape := CollisionShape3D.new()
	var cabin_box := BoxShape3D.new()
	cabin_box.size = Vector3(5.1, 5, 4)
	cabin_shape.shape = cabin_box
	cabin_shape.position.y = 2.5
	cabin_body.add_child(cabin_shape)
	cabin.add_child(cabin_body)
	for i in 6:
		var post := point(4.5 + i * 1.6, 25)
		part(self, cylinder(0.10, 0.08, 1.0), Color("7c7968"), post + Vector3.UP * 0.5)
		if i < 5:
			var rail := part(self, cylinder(0.055, 0.055, 1.65), Color("7c7968"), post + Vector3(0.8, 0.75, 0))
			rail.rotation.z = PI / 2
	# Optional low jump across a fallen log; the main trail remains accessible around it.
	var log_mesh := cylinder(0.32, 0.32, 3.6)
	var log_node := part(self, log_mesh, Color("8a7565"), point(-24.5, -1.0, 0.3))
	log_node.rotation.z = PI / 2
	var log_body := StaticBody3D.new()
	log_body.collision_layer = 1 | 4
	var log_shape := CollisionShape3D.new()
	log_shape.shape = log_mesh.create_convex_shape()
	log_body.add_child(log_shape)
	log_node.add_child(log_body)

func _grass_and_waymarks() -> void:
	var grass_mesh := SurfaceTool.new()
	grass_mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p: Vector2 in ROUTE:
		for offset: float in [-3.6, 3.8]:
			for i in 7:
				var x := p.x + offset + sin(float(i) * 2.1) * 0.55
				var z := p.y + i * 0.45
				var base := point(x, z, 0.02)
				var height := 0.23 + float(i % 3) * 0.12
				for turn in 2:
					var axis := Vector3.RIGHT if turn == 0 else Vector3.FORWARD
					grass_mesh.set_color(Color("526c2c").lightened(float(i % 3) * 0.04))
					for v: Vector3 in [base - axis * 0.08, base + Vector3.UP * height + axis * 0.14, base + axis * 0.08]:
						grass_mesh.add_vertex(v)
	grass_mesh.generate_normals()
	var grass_material := mat(Color.WHITE)
	grass_material.vertex_color_use_as_albedo = true
	grass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var grass := MeshInstance3D.new()
	grass.mesh = grass_mesh.commit()
	grass.material_override = grass_material
	add_child(grass)
	for p: Vector2 in [Vector2(-6, 13), Vector2(-15, -3), Vector2(2, -18), Vector2(16, 9)]:
		part(self, cylinder(0.055, 0.055, 0.85, 6), Color("82694b"), point(p.x, p.y, 0.42))
		var marker := PrismMesh.new()
		marker.size = Vector3(0.42, 0.22, 0.08)
		part(self, marker, Color("dcac5a"), point(p.x, p.y, 0.76)).rotation.z = PI / 2

func _sign(location: Vector2, id: String, heading: String, text: Array[String]) -> TrailInteractable:
	var sign := TrailInteractable.new()
	sign.interaction_id = id
	sign.display_name = heading
	sign.pages = text
	sign.position = point(location.x, location.y)
	add_child(sign)
	part(sign, cylinder(0.08, 0.08, 1.5), Color("736350"), Vector3(0, 0.75, 0))
	var board := BoxMesh.new()
	board.size = Vector3(1.7, 0.85, 0.16)
	part(sign, board, Color("537777"), Vector3(0, 1.5, 0))
	var camera_body := StaticBody3D.new()
	camera_body.collision_layer = 4
	var camera_shape := CollisionShape3D.new()
	var board_shape := BoxShape3D.new()
	board_shape.size = board.size
	camera_shape.shape = board_shape
	camera_shape.position.y = 1.5
	camera_body.add_child(camera_shape)
	sign.add_child(camera_body)
	var label := Label3D.new()
	label.text = heading
	label.font_size = 32
	label.pixel_size = 0.004
	label.position = Vector3(0, 1.5, 0.09)
	sign.add_child(label)
	sign.build_prompt(2.2)
	return sign

func _resident(location: Vector2, color: Color, rabbit := false) -> Node3D:
	var resident := TrailResident.new()
	resident.coat_color = color
	resident.rabbit = rabbit
	resident.motion_offset = residents.size() * 1.7
	resident.position = point(location.x, location.y)
	add_child(resident)
	residents.append(resident)
	return resident

func _objects() -> void:
	var welcome := _sign(Vector2(1.4, 20.5), "welcome", "PASO DE BRUMA", ["La montaña se ha tornado peligrosa. La nieve apagó los faroles y nuestros vecinos esperan para regresar.", "Recoge semillas de luz y restaura los tres faroles. Cada uno necesita 3 semillas. Después vuelve con Mara, junto al refugio."])
	welcome.dialogue_resource = load("res://dialogue/paso_de_bruma.dialogue") as DialogueResource
	welcome.dialogue_title = "start"
	_sign(Vector2(-27, -1), "log", "HUELLAS EN LA NIEVE", ["Un tronco caído, un salto pequeño. Espacio / A para saltar. También puedes rodearlo: aquí nadie tiene prisa."])
	_sign(Vector2(2, -4), "overlook", "CIMA DEL ECO", ["La montaña se puede rodear entera. Abajo está el refugio; el sendero en espiral te lleva de vuelta. Gracias por traer la luz hasta aquí."])
	guide = TrailInteractable.new()
	guide.interaction_id = "mara"
	guide.display_name = "Mara"
	guide.dialogue_subtitle = "Guardiana"
	guide.verb = "Hablar con Mara"
	guide.position = point(-3, 21)
	add_child(guide)
	guide.build_prompt(2.5)
	var mara_model := _resident(Vector2(-3, 21), Color("ba795c"), true)
	mara_model.reparent(guide, true)
	for i in LAMP_POINTS.size():
		var lamp := TrailLamp.new()
		lamp.interaction_id = ["clearing", "pines", "summit"][i]
		lamp.display_name = ["Farol del claro", "Farol del pinar", "Farol del mirador"][i]
		add_child(lamp)
		lamp.setup(point(LAMP_POINTS[i].x, LAMP_POINTS[i].y), lamp.display_name)
		lamps.append(lamp)
	for i in SEEDS.size():
		var seed_node := LightFragment.new()
		seed_node.seed_id = "seed_%02d" % i
		seed_node.setup(point(SEEDS[i].x, SEEDS[i].y, 0.85))
		add_child(seed_node)
		seeds.append(seed_node)
	_resident(Vector2(15, -24), Color("6e8e99"))
	_resident(Vector2(-17, -11), Color("b49655"), true)

func _weather() -> void:
	snow = CPUParticles3D.new()
	snow.amount = snowfall_amount
	snow.lifetime = 12
	snow.preprocess = 6
	snow.position = Vector3(0, 18, 0)
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(29, 6, 32)
	snow.direction = Vector3(0.1, -1, 0.1)
	snow.spread = 12
	snow.gravity = Vector3(0.08, -0.12, 0)
	snow.initial_velocity_min = 0.7
	snow.initial_velocity_max = 1.2
	snow.scale_amount_min = 0.035
	snow.scale_amount_max = 0.065
	var flake := sphere(0.5, 1)
	flake.material = mat(Color("e7eeeb"), 0.25)
	snow.mesh = flake
	add_child(snow)

func restore(data: Dictionary) -> void:
	for lamp in lamps:
		if data.lamps.has(lamp.interaction_id):
			lamp.activate(false)
	for seed_node in seeds:
		if data.collected.has(seed_node.seed_id):
			seed_node.claimed = true
			seed_node.hide()
			seed_node.set_deferred("monitoring", false)

func ending_walk(progress: float) -> void:
	for i in range(1, residents.size()):
		var resident := residents[i]
		var start := Vector2(3 + i * 1.4, 16 - i)
		var finish := Vector2(-5 + i * 0.7, 24)
		var p := start.lerp(finish, progress)
		resident.position = point(p.x, p.y, absf(sin(progress * 32)) * 0.05)
		resident.rotation.y = -0.65
