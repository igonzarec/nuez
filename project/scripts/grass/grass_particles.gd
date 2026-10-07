@tool
extends Node3D
## Pasto vivo por particulas sobre Terrain3D, con controles de autoria.
##
## Derivado del ejemplo Terrain3DParticles del addon (c) 2023-2026 Cory
## Petkovsek, Roope Palmroos y colaboradores. La logica de rejilla es la misma:
## una cuadricula de emisores GPUParticles3D que sigue a la camara y lee los
## mapas de altura, control y color de Terrain3D en el shader.
##
## La diferencia es que aqui todo lo que el ejemplo dejaba en el material o
## escrito a mano en el shader se expone como propiedad del Inspector: alto de
## las hojas, densidad, frecuencia y tamano de las manchas, pendiente maxima,
## colores, viento y distancia de dibujado. Los cambios se aplican en vivo.
##
## El pasto no se guarda en ningun sitio: se genera cada fotograma en la GPU a
## partir del relieve. No hay nada que pintar ni que regenerar, pero tampoco se
## puede decidir mata a mata donde va. Para eso estan los otros dos sistemas.

const PROCESS_SHADER := preload("res://shaders/grass_particles_process.gdshader")
const BLADE_SHADER := preload("res://shaders/grass_particles_blade.gdshader")

@export_group("Terreno")
## Nodo Terrain3D del que se leen altura, pendiente y color. Si se deja vacio y
## este nodo es hijo de un Terrain3D, se asigna solo al iniciar.
@export var terrain: Terrain3D:
	set(value):
		terrain = value
		_rebuild()

## Apaga todo el pasto sin borrar la configuracion. Util para medir cuanto cuesta.
@export var enabled := true:
	set(value):
		enabled = value
		_rebuild()

@export_group("Vista previa en el editor")
## Dibuja el pasto dentro del editor y lo actualiza al cambiar cualquier control,
## siguiendo la camara del viewport. Desactivalo si el editor va lento: el pasto
## seguira apareciendo al ejecutar la escena. No afecta al juego.
@export var editor_preview := true:
	set(value):
		editor_preview = value
		_rebuild()

@export_group("Densidad y alcance")
## Matas por metro cuadrado. Es el control que mas afecta al rendimiento: el
## coste crece con el cuadrado del valor. El sistema lo convierte a separacion
## entre instancias, limitada entre 0.125 m y 2 m, asi que valores por encima de
## 64 o por debajo de 0.25 se recortan.
@export_range(0.25, 64.0, 0.25) var density := 16.0:
	set(value):
		density = value
		_recalculate_grid()

## Radio en metros hasta donde se dibuja el pasto. Mas lejos cuesta mas y obliga
## a repartir las mismas particulas en mas superficie. Se reparte entre las
## celdas de la rejilla.
@export_range(10.0, 400.0, 1.0, "suffix:m") var draw_distance := 60.0:
	set(value):
		draw_distance = value
		_recalculate_grid()

## Numero de celdas por lado de la rejilla que sigue a la camara. Debe ser impar.
## Mas celdas descartan mejor lo que queda fuera de pantalla, con mas nodos.
@export_range(1, 15, 2) var grid_width := 9:
	set(value):
		grid_width = value if value % 2 == 1 else value + 1
		_rebuild()

## Tope de particulas totales. Si densidad y distancia piden mas, se reduce la
## densidad efectiva para no congelar el editor. Subelo solo si tu GPU aguanta.
@export_range(10000, 2000000, 10000) var max_particles := 400000:
	set(value):
		max_particles = value
		_recalculate_grid()

## Solo informativo: particulas que se estan procesando ahora mismo. Es de solo
## lectura; lo calculan Density, Draw Distance, Grid Width y Max Particles.
@export var particle_count := 0:
	set(_value):
		# Ignora lo que se escriba y recalcula: el campo es solo informativo.
		particle_count = _amount * grid_width * grid_width

@export_group("Forma de la hoja")
## Todas las matas con la misma altura exacta, la de Blade Height. Anula las tres
## fuentes de variacion de alto: el azar entre minimo y maximo, el penacho de
## Clump Boost y el encogido junto a las calvas. El borde de las calvas pasa a ser
## un corte limpio, porque una mata a medio tamano es una mata mas baja.
@export var uniform_height := false:
	set(value):
		uniform_height = value
		notify_property_list_changed()
		_apply_process_params()

## Altura unica de todas las matas, cuando Uniform Height esta activo. Admite 0
## para dejarlas invisibles sin apagar el sistema.
@export_range(0.0, 3.0, 0.01, "suffix:m") var blade_height := 0.3:
	set(value):
		blade_height = value
		_apply_process_params()

## Alto minimo de la hoja. Cada mata toma un valor al azar entre el minimo y el
## maximo, asi que juntarlos da un pasto parejo y separarlos uno desigual.
@export_range(0.02, 3.0, 0.01, "suffix:m") var height_min := 0.5:
	set(value):
		height_min = value
		height_max = maxf(height_max, height_min)
		_apply_process_params()

## Alto maximo de la hoja. Nunca baja del minimo.
@export_range(0.02, 3.0, 0.01, "suffix:m") var height_max := 1.0:
	set(value):
		height_max = maxf(value, height_min)
		_apply_process_params()

## Ancho de la hoja en metros. Valores altos dan un pasto mas carnoso y tapan
## mejor el suelo con menos matas.
@export_range(0.02, 0.6, 0.005, "suffix:m") var blade_width := 0.125:
	set(value):
		blade_width = value
		_apply_process_params()

## Perfil de ancho de la hoja a lo largo de su altura. Por defecto va de 1 en la
## base a 0 en la punta, lo que da un triangulo. Edita la curva para otras
## siluetas: plana arriba da una tira, convexa da una hoja mas carnosa.
## Cambiarla reconstruye la malla.
@export var taper_curve: Curve:
	set(value):
		taper_curve = value
		_rebuild_mesh()

## Numero de tramos de la hoja. Mas tramos afinan el triangulo y permiten que se
## doble con suavidad al moverse; tambien son mas vertices por mata.
@export_range(1, 12, 1) var blade_sections := 5:
	set(value):
		blade_sections = value
		_rebuild_mesh()

## Cruza dos planos en vez de uno. Da volumen desde cualquier angulo, al doble de
## triangulos. Desactivado, la hoja es plana y desaparece vista de canto.
@export var cross_shape := true:
	set(value):
		cross_shape = value
		_rebuild_mesh()

## Afilado extra aplicado por el shader, encima de la curva. 0 lo desactiva.
@export_range(0.0, 1.0, 0.01) var pinch := 0.3:
	set(value):
		pinch = value
		_apply_blade_params()

## Altura a la que se ancla la base de la hoja respecto al suelo. Se escala con
## el alto, asi que las hojas altas y bajas siguen apoyadas.
@export_range(0.0, 1.0, 0.01) var base_offset := 0.45:
	set(value):
		base_offset = value
		_apply_process_params()

@export_group("Manchas y variacion")
## Frecuencia del ruido que decide donde hay pasto espeso y donde ralo. Valores
## altos dan manchas pequenas y repetidas; bajos, manchas amplias.
@export_range(0.001, 0.1, 0.001) var patch_frequency := 0.01:
	set(value):
		patch_frequency = value
		_apply_process_params()

## Valor del ruido por debajo del cual no crece nada. Subirlo abre mas calvas.
@export_range(0.0, 1.0, 0.005) var patch_start := 0.025:
	set(value):
		patch_start = value
		patch_full = maxf(patch_full, patch_start)
		_apply_process_params()

## Valor del ruido a partir del cual la mata alcanza su tamano pleno. Acercarlo a
## Patch Start endurece el borde entre calva y pasto.
@export_range(0.0, 1.0, 0.005) var patch_full := 0.2:
	set(value):
		patch_full = maxf(value, patch_start)
		_apply_process_params()

## Cuanto mas altas son las matas en los nucleos del ruido. 0 deja el pasto
## parejo; valores altos crean penachos destacados.
@export_range(0.0, 8.0, 0.1) var clump_boost := 2.0:
	set(value):
		clump_boost = value
		_apply_process_params()

## Valor del ruido donde empiezan esos nucleos mas altos.
@export_range(0.0, 1.0, 0.005) var clump_start := 0.2:
	set(value):
		clump_start = value
		clump_full = maxf(clump_full, clump_start)
		_apply_process_params()

## Valor del ruido donde el penacho alcanza su altura extra completa.
@export_range(0.0, 1.0, 0.005) var clump_full := 0.8:
	set(value):
		clump_full = maxf(value, clump_start)
		_apply_process_params()

## Cuanto se desordena la posicion de cada mata dentro de su casilla. 0 deja una
## rejilla visible; 1 la desordena del todo.
@export_range(0.0, 1.0, 0.01) var random_spacing := 0.5:
	set(value):
		random_spacing = value
		_apply_process_params()

## Gira cada mata al azar sobre su eje. Desactivarlo alinea todas igual.
@export var random_rotation := true:
	set(value):
		random_rotation = value
		_apply_process_params()

@export_group("Colocacion en el terreno")
## Inclina las matas siguiendo la pendiente del terreno.
@export var align_to_normal := true:
	set(value):
		align_to_normal = value
		_apply_process_params()

## Cuanto siguen la pendiente. 0 las deja verticales aunque el suelo baje; 1 las
## pone perpendiculares al suelo.
@export_range(0.01, 1.0, 0.01) var normal_strength := 0.3:
	set(value):
		normal_strength = value
		_apply_process_params()

## Pendiente maxima en grados sobre la que crece pasto. Por encima, la roca
## queda pelada.
@export_range(0.0, 89.0, 1.0, "suffix:°") var maximum_slope := 30.0:
	set(value):
		maximum_slope = value
		_apply_process_params()

## Difumina el corte por pendiente para que el borde no sea una linea recta.
@export_range(0.0, 1.0, 0.01) var slope_dither := 0.15:
	set(value):
		slope_dither = value
		_apply_process_params()

## Parte del alcance en la que las hojas se encogen antes de desaparecer. 0 las
## corta de golpe en el borde; valores altos alargan la transicion.
@export_range(0.0, 1.0, 0.01) var distance_fade := 0.66:
	set(value):
		distance_fade = value
		_apply_process_params()

## ID de textura pintada sobre la que no crece pasto, por ejemplo un camino o
## roca. -1 desactiva el filtro y deja crecer pasto sobre cualquier superficie.
@export_range(-1, 31, 1) var excluded_texture_id := -1:
	set(value):
		excluded_texture_id = value
		_apply_process_params()

@export_group("Color")
## Color de la base de la hoja, el mas oscuro.
@export var root_color := Color(0.13, 0.20, 0.06):
	set(value):
		root_color = value
		_apply_blade_params()

## Color de la punta de la hoja. Separarlo del color de raiz da profundidad.
@export var tip_color := Color(0.38, 0.52, 0.16):
	set(value):
		tip_color = value
		_apply_blade_params()

## Cuanto se aclara el extremo final de la punta hacia el blanco.
@export_range(0.0, 1.0, 0.01) var tip_highlight := 0.35:
	set(value):
		tip_highlight = value
		_apply_blade_params()

## Cuanto se oscurece la base, para simular la sombra entre matas.
@export_range(0.0, 1.0, 0.01) var root_shading := 0.25:
	set(value):
		root_shading = value
		_apply_blade_params()

## Variacion de tono al azar entre hojas. 0 las deja todas identicas.
@export_range(0.0, 1.0, 0.01) var color_variation := 0.3:
	set(value):
		color_variation = value
		_apply_blade_params()

@export_group("Iluminacion")
## Rugosidad base. Alta deja el pasto mate; baja le da brillo especular.
@export_range(0.0, 1.0, 0.01) var roughness := 1.0:
	set(value):
		roughness = value
		_apply_blade_params()

## Reflejo maximo de las hojas agitadas por el viento.
@export_range(0.0, 0.5, 0.01) var specular := 0.15:
	set(value):
		specular = value
		_apply_blade_params()

## Luz que atraviesa la hoja desde atras, para el aspecto translucido a contraluz.
@export var backlight := Color(0.33, 0.33, 0.33):
	set(value):
		backlight = value
		_apply_blade_params()

## Si las hojas proyectan sombra. Con mucha densidad es de lo mas caro que hay.
@export var cast_shadows := false:
	set(value):
		cast_shadows = value
		_apply_particle_nodes()

@export_group("Viento")
## Activa el movimiento. Desactivado deja el pasto quieto y ahorra el calculo.
@export var wind_enabled := true:
	set(value):
		wind_enabled = value
		_apply_process_params()
		_apply_blade_params()

## Cuanto se doblan las hojas con el viento.
@export_range(0.0, 1.0, 0.01) var wind_strength := 1.0:
	set(value):
		wind_strength = value
		_apply_process_params()

## Velocidad a la que avanzan las rachas sobre el terreno.
@export_range(0.0, 0.5, 0.001) var wind_speed := 0.025:
	set(value):
		wind_speed = value
		_apply_process_params()

## Direccion del viento en grados sobre el plano del suelo.
@export_range(-180.0, 180.0, 1.0, "suffix:°") var wind_direction := 45.0:
	set(value):
		wind_direction = value
		_apply_process_params()
		_apply_blade_params()

## Tamano de las rachas. Valores bajos dan olas amplias; altos, agitacion menuda.
@export_range(0.0005, 0.05, 0.0005) var wind_scale := 0.0041:
	set(value):
		wind_scale = value
		_apply_process_params()

## Desfase entre hojas vecinas para que no se muevan todas a la vez.
@export_range(0.0, 16.0, 0.1) var wind_dithering := 4.0:
	set(value):
		wind_dithering = value
		_apply_process_params()

## Amplitud del bamboleo lateral, el temblor que tienen incluso sin racha.
@export_range(0.0, 1.0, 0.01) var wobble_amount := 0.25:
	set(value):
		wobble_amount = value
		_apply_blade_params()

## Velocidad de ese bamboleo.
@export_range(0.0, 8.0, 0.1) var wobble_speed := 2.0:
	set(value):
		wobble_speed = value
		_apply_blade_params()

@export_group("Rendimiento")
## Veces por segundo que se recalcula el viento. Bajarlo ahorra GPU a costa de
## un movimiento mas entrecortado.
@export_range(1, 120, 1) var process_fps := 30:
	set(value):
		process_fps = value
		_apply_particle_nodes()

var _process_material: ShaderMaterial
var _blade_material: ShaderMaterial
var _mesh: Mesh
var _particle_nodes: Array[GPUParticles3D] = []
var _offsets: Array[Vector3] = []
var _rows := 1
var _amount := 1
var _cell_width := 24.0
var _instance_spacing := 0.25
var _last_pos := Vector3.ZERO


func _ready() -> void:
	if terrain == null:
		var parent := get_parent()
		if parent is Terrain3D:
			terrain = parent
	_rebuild()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_destroy_grid()


func _physics_process(_delta: float) -> void:
	if terrain == null or _particle_nodes.is_empty():
		return
	var camera := terrain.get_camera()
	if camera and _last_pos.distance_squared_to(camera.global_position) > 1.0:
		var pos: Vector3 = camera.global_position.snapped(Vector3.ONE)
		_position_grid(pos)
		RenderingServer.material_set_param(_process_material.get_rid(), "camera_position", pos)
		_last_pos = camera.global_position
	_push_terrain_maps()


## Reconstruye materiales, malla y rejilla. Lo llaman los setters que cambian la
## estructura; los que solo cambian apariencia usan _apply_* y no reconstruyen.
func _rebuild() -> void:
	_destroy_grid()
	if not enabled or terrain == null or terrain.data == null:
		set_physics_process(false)
		return
	# Los emisores se crean sin owner, asi que nunca se guardan en la escena.
	if Engine.is_editor_hint() and not editor_preview:
		set_physics_process(false)
		return
	_ensure_resources()
	_recalculate_grid()
	_create_grid()
	set_physics_process(true)


func _ensure_resources() -> void:
	if _process_material == null:
		_process_material = ShaderMaterial.new()
		_process_material.shader = PROCESS_SHADER
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_CELLULAR
		noise.frequency = 0.0145
		noise.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
		var noise_texture := NoiseTexture2D.new()
		noise_texture.noise = noise
		noise_texture.seamless = true
		_process_material.set_shader_parameter("main_noise", noise_texture)
	if _blade_material == null:
		_blade_material = ShaderMaterial.new()
		_blade_material.shader = BLADE_SHADER
	if _mesh == null:
		_build_mesh()
	_apply_process_params()
	_apply_blade_params()


## Traduce densidad y alcance a la separacion y el tamano de celda que espera el
## shader, respetando el tope de particulas.
func _recalculate_grid() -> void:
	_instance_spacing = clampf(1.0 / sqrt(maxf(density, 0.01)), 0.125, 2.0)
	# Redondeo que exige el ejemplo original para que la rejilla case.
	_instance_spacing = clampf(round(_instance_spacing * 64.0) * 0.015625, 0.125, 2.0)
	_cell_width = clampf(draw_distance * 2.0 / float(grid_width), 8.0, 256.0)
	_rows = maxi(int(_cell_width / _instance_spacing), 1)
	var total := _rows * _rows * grid_width * grid_width
	if total > max_particles:
		# Recorta las filas por celda antes que el alcance: perder densidad se
		# nota menos que ver aparecer el pasto a pocos metros.
		var allowed := maxi(int(sqrt(float(max_particles) / float(grid_width * grid_width))), 1)
		_rows = mini(_rows, allowed)
	_amount = _rows * _rows
	particle_count = 0 # el setter lo recalcula con el valor real
	_set_offsets()
	_apply_process_params()
	for p in _particle_nodes:
		p.amount = _amount
	_last_pos = Vector3.ZERO


## La hoja es una cinta cuyo ancho sigue taper_curve: de 1 en la base a 0 en la
## punta da el triangulo. Sin curva, la cinta seria un rectangulo.
func _build_mesh() -> void:
	var ribbon := RibbonTrailMesh.new()
	ribbon.shape = (RibbonTrailMesh.SHAPE_CROSS if cross_shape
		else RibbonTrailMesh.SHAPE_FLAT)
	ribbon.sections = blade_sections
	ribbon.section_length = 0.9 / float(blade_sections)
	ribbon.section_segments = 1
	ribbon.curve = taper_curve if taper_curve != null else _default_taper_curve()
	_mesh = ribbon


func _default_taper_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	return curve


func _rebuild_mesh() -> void:
	_build_mesh()
	for p in _particle_nodes:
		p.draw_pass_1 = _mesh


## Vuelve a emitir conservando la semilla, para que las matas no salten de sitio.
func _restart_particles() -> void:
	for p in _particle_nodes:
		if is_instance_valid(p):
			p.restart(true)


func _apply_process_params() -> void:
	if _process_material == null:
		return
	var m := _process_material
	m.set_shader_parameter("main_noise_scale", patch_frequency)
	m.set_shader_parameter("position_offset", Vector3(0.0, base_offset, 0.0))
	m.set_shader_parameter("align_to_normal", align_to_normal)
	m.set_shader_parameter("normal_strength", normal_strength)
	m.set_shader_parameter("random_rotation", random_rotation)
	m.set_shader_parameter("random_spacing", random_spacing)
	# Con altura uniforme, minimo y maximo valen lo mismo y no queda azar.
	var low := blade_height if uniform_height else height_min
	var high := blade_height if uniform_height else height_max
	m.set_shader_parameter("min_scale", Vector3(blade_width, low, blade_width))
	m.set_shader_parameter("max_scale", Vector3(blade_width, high, blade_width))
	m.set_shader_parameter("noise_scale", wind_scale)
	m.set_shader_parameter("wind_speed", wind_speed)
	m.set_shader_parameter("wind_strength", wind_strength if wind_enabled else 0.0)
	m.set_shader_parameter("wind_dithering", wind_dithering)
	m.set_shader_parameter("wind_direction", _wind_vector())
	# El penacho sumaria altura por encima del maximo, asi que se anula.
	m.set_shader_parameter("clod_scale_boost", 0.0 if uniform_height else clump_boost)
	m.set_shader_parameter("clod_min_threshold", clump_start)
	m.set_shader_parameter("clod_max_threshold", clump_full)
	# El patch escala la mata entera: un valor intermedio la deja mas baja. Para
	# que la altura sea uniforme, el umbral tiene que ser un corte, no un degradado.
	m.set_shader_parameter("patch_min_threshold", patch_start)
	m.set_shader_parameter("patch_max_threshold", patch_start if uniform_height else patch_full)
	m.set_shader_parameter("condition_dither_range", slope_dither)
	# El shader compara contra la componente Y de la normal, no contra el angulo.
	m.set_shader_parameter("surface_slope_min", cos(deg_to_rad(maximum_slope)))
	m.set_shader_parameter("distance_fade_ammount", distance_fade)
	m.set_shader_parameter("excluded_texture_id", excluded_texture_id)
	m.set_shader_parameter("instance_spacing", _instance_spacing)
	m.set_shader_parameter("instance_rows", _rows)
	m.set_shader_parameter("max_dist", _cell_width * float(grid_width) * 0.5)
	# start() solo se ejecuta al emitir, y con lifetime de 600 s eso pasa una vez.
	# Sin reiniciar, los cambios de tamano o colocacion no se verian hasta que la
	# camara se moviese. Los parametros de color y viento no necesitan esto.
	_restart_particles()


func _apply_blade_params() -> void:
	if _blade_material == null:
		return
	var m := _blade_material
	m.set_shader_parameter("root_color", root_color)
	m.set_shader_parameter("tip_color", tip_color)
	m.set_shader_parameter("tip_highlight", tip_highlight)
	m.set_shader_parameter("root_shading", root_shading)
	m.set_shader_parameter("color_variation", color_variation)
	m.set_shader_parameter("base_roughness", roughness)
	m.set_shader_parameter("specular_amount", specular)
	m.set_shader_parameter("backlight_color", backlight)
	m.set_shader_parameter("pinch", pinch)
	m.set_shader_parameter("wind_direction", _wind_vector())
	m.set_shader_parameter("wobble_amount", wobble_amount if wind_enabled else 0.0)
	m.set_shader_parameter("wobble_speed", wobble_speed)


func _apply_particle_nodes() -> void:
	var mode := (GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	for p in _particle_nodes:
		p.cast_shadow = mode
		p.fixed_fps = process_fps
		p.preprocess = 1.0 / float(process_fps)


func _wind_vector() -> Vector2:
	var a := deg_to_rad(wind_direction)
	return Vector2(cos(a), sin(a))


func _create_grid() -> void:
	var height_range_data: Vector2 = terrain.data.get_height_range()
	var height: float = height_range_data.x - height_range_data.y
	var aabb := AABB()
	aabb.size = Vector3(_cell_width, height, _cell_width)
	aabb.position = aabb.size * -0.5
	aabb.position.y = height_range_data.y
	var half := grid_width / 2
	for x in range(-half, half + 1):
		for z in range(-half, half + 1):
			var node := GPUParticles3D.new()
			node.lifetime = 600.0
			node.amount = _amount
			node.explosiveness = 1.0
			node.amount_ratio = 1.0
			node.process_material = _process_material
			node.draw_pass_1 = _mesh
			node.material_override = _blade_material
			node.speed_scale = 1.0
			node.custom_aabb = aabb
			node.use_fixed_seed = true
			if not _particle_nodes.is_empty():
				node.seed = _particle_nodes[0].seed
			add_child(node)
			node.emitting = true
			_particle_nodes.append(node)
	_apply_particle_nodes()
	_last_pos = Vector3.ZERO


func _set_offsets() -> void:
	var half := grid_width / 2
	_offsets.clear()
	for x in range(-half, half + 1):
		for z in range(-half, half + 1):
			_offsets.append(Vector3(
				float(x * _rows) * _instance_spacing,
				0.0,
				float(z * _rows) * _instance_spacing))


func _destroy_grid() -> void:
	for node in _particle_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_particle_nodes.clear()


func _position_grid(pos: Vector3) -> void:
	for i in _particle_nodes.size():
		if i >= _offsets.size():
			return
		var node := _particle_nodes[i]
		var snap := Vector3(pos.x, 0.0, pos.z).snapped(Vector3.ONE) + _offsets[i]
		node.global_position = (snap / _instance_spacing).round() * _instance_spacing
		node.reset_physics_interpolation()
		node.restart(true)


## Los mapas de Terrain3D cambian al esculpir o pintar, asi que se reenvian cada
## fotograma en vez de cachearlos.
func _push_terrain_maps() -> void:
	var rid: RID = _process_material.get_rid()
	if not rid.is_valid() or terrain.data == null:
		return
	RenderingServer.material_set_param(rid, "_background_mode", terrain.material.world_background)
	RenderingServer.material_set_param(rid, "_vertex_spacing", terrain.vertex_spacing)
	RenderingServer.material_set_param(rid, "_vertex_density", 1.0 / terrain.vertex_spacing)
	RenderingServer.material_set_param(rid, "_region_size", terrain.region_size)
	RenderingServer.material_set_param(rid, "_region_texel_size", 1.0 / terrain.region_size)
	RenderingServer.material_set_param(rid, "_region_map_size", 32)
	RenderingServer.material_set_param(rid, "_region_map", terrain.data.get_region_map())
	RenderingServer.material_set_param(rid, "_region_locations", terrain.data.get_region_locations())
	RenderingServer.material_set_param(rid, "_height_maps", terrain.data.get_height_maps_rid())
	RenderingServer.material_set_param(rid, "_control_maps", terrain.data.get_control_maps_rid())
	RenderingServer.material_set_param(rid, "_color_maps", terrain.data.get_color_maps_rid())


## Oculta en el Inspector los controles que la altura uniforme deja sin efecto.
func _validate_property(property: Dictionary) -> void:
	var hidden_when_uniform := ["height_min", "height_max", "clump_boost",
		"clump_start", "clump_full", "patch_full"]
	if uniform_height and property.name in hidden_when_uniform:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	elif not uniform_height and property.name == "blade_height":
		property.usage = PROPERTY_USAGE_NO_EDITOR
