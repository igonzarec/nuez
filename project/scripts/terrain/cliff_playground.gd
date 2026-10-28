@tool
extends Node3D
## Laboratorio aislado: referencia, heightmap y cubierta con desplazamiento normal.
## Los datos generados son temporales. No es una herramienta para editar regiones existentes.

@export_group("Generacion")
## Actualiza automaticamente al cambiar parametros en el Inspector (editor o Remote durante juego). Reconstruye alturas, malla y colision; puede causar una pausa. Apagado conserva el boton manual.
## Coste: compara parametros cada frame y regenera todo al detectar cambios estables. La reconstruccion es sincrona (CPU y subida de recursos a GPU); puede pausar editor/juego. Apagarlo evita regeneraciones automaticas, no reduce la geometria ya creada.
@export var live_preview := true
## Segundos sin nuevos cambios antes de regenerar. Mayor agrupa mas ajustes de sliders y reduce reconstrucciones. Se aplica en vivo.
## Coste: subirlo reduce la frecuencia de reconstrucciones al editar, pero no el coste de cada reconstruccion ni los FPS de la escena estable. No cambia memoria o poligonos.
@export_range(0.1, 2.0, 0.05, "suffix:s") var preview_delay := 0.4
## Activa el relieve A/B; apagado restaura ambas formas base al regenerar.
## Coste: apagarlo omite los calculos de ruido/desplazamiento, pero conserva resolucion, poligonos y colisiones. Cambiarlo reconstruye todo; no es una optimizacion importante de renderizado estable.
@export var relief_enabled := true
## Regenera desde cero con los valores actuales; nunca acumula deformaciones.
## Coste: reconstruccion completa y sincrona de heightmap, mallas y colisiones activas; puede pausar la interfaz. La memoria temporal aumenta durante la construccion. No ejecutar repetidamente si no hubo cambios.
@export_tool_button("Regenerar comparacion") var rebuild_button: Callable = regenerate
## Restaura la geometria sin relieve, conservando los parametros para volver a activarla.
## Coste: realiza una reconstruccion completa, igual que Regenerar. Conserva numero de vertices y colisiones; restaurar la forma no simplifica las mallas.
@export_tool_button("Restaurar forma base") var reset_button: Callable = restore_base
## Semilla reproducible del patron compartido por A/B. Live Preview o regeneracion manual.
## Coste: cambiarla recalcula todo el laboratorio. No cambia la resolucion ni el presupuesto nominal de vertices; el coste estable es similar entre semillas.
@export var pattern_seed: int = 27
@export_group("Forma base")
## Altura en metros. Mayor aumenta la verticalidad con la misma carrera. Live Preview o regeneracion manual.
## Coste: mayor altura agrega filas sobre las paredes B para mantener Mesh Step, aumentando CPU de generacion, memoria, triangulos renderizados y colision B. La cuadricula y los triangulos de colision A mantienen su cantidad.
@export_range(4.0, 20.0, 0.5, "suffix:m") var cliff_height := 12.0
## Ancho de cada muestra en metros, con bordes laterales suavizados. Live Preview o regeneracion manual.
## Coste: cambia la forma dentro de una cuadricula fija; no agrega vertices ni triangulos por si mismo. Requiere reconstruccion completa y puede variar ligeramente el trabajo de calculo del relieve.
@export_range(12.0, 28.0, 1.0, "suffix:m") var cliff_width := 24.0
## Distancia horizontal que ocupa la pared. Menor se acerca a vertical; A pierde muestras. Live Preview o regeneracion manual.
## Coste: cambia la distribucion y cantidad de filas B segun la longitud de la pared; no equivale a un control directo de rendimiento. A mantiene muestras fijas: una carrera menor pierde detalle horizontal sin ahorrar memoria.
@export_range(0.5, 8.0, 0.25, "suffix:m") var wall_run := 2.0
@export_group("Referencia redondeada")
## Agrega una segunda fila con referencia, alturas A y malla B redondeadas de 360 grados. Live Preview; aumenta el coste de regeneracion y colision.
## Coste: activarlo agrega una malla B, dos colisiones de alturas y una colision B si estan habilitadas, mas calculos de heightmap. Aumenta CPU de generacion, memoria, renderizado y fisica. Apagarlo elimina esos recursos al regenerar.
@export var rounded_enabled := true
## Radio medio en metros de las tres muestras cerradas. Mayor ensancha la meseta; la carrera se limita al radio local. Live Preview.
## Coste: redistribuye filas entre cima y faldon de B; el numero total es aproximadamente constante, con variaciones por redondeo. No aumenta la resolucion de A. Cambiarlo regenera todo; no usarlo como ajuste principal de rendimiento.
@export_range(8.0, 14.0, 0.5, "suffix:m") var rounded_radius := 12.0
## Variacion relativa del radio: 0 es circular, mayor crea entrantes y lobulos amplios. Se limita el radio exterior a 15.5 m para conservar separacion entre muestras. Live Preview.
## Coste: cambia posiciones y normales con la misma topologia; no agrega triangulos. Reconstruccion completa. Mas irregularidad puede dificultar contactos de escalada, pero no implica un aumento proporcional de memoria o GPU.
@export_range(0.0, 0.25, 0.01) var outline_irregularity := 0.15
@export_group("Pliegues compartidos")
## Tamano de las formas en metros; mayor genera pliegues mas amplios. Live Preview o regeneracion manual.
## Coste: no cambia el numero de vertices ni las muestras de ruido. Pliegues mas pequenos pueden requerir reducir Mesh Step para verse bien, lo cual si aumenta mucho el coste B. Regenera todo.
@export_range(0.5, 10.0, 0.1, "suffix:m") var fold_size := 3.5
## Metros de desplazamiento negativo: hacia abajo en A, hacia dentro en B. Live Preview o regeneracion manual.
## Coste: no agrega vertices ni triangulos; cambia posiciones y reconstruye colision. Valores grandes pueden producir autointersecciones/contactos complejos, sin un aumento fijo predecible de FPS o memoria.
@export_range(0.0, 3.0, 0.05, "suffix:m") var indentation := 0.7
## Metros de desplazamiento positivo: hacia arriba en A, hacia fuera en B. Live Preview o regeneracion manual.
## Coste: no agrega vertices ni triangulos; cambia posiciones y reconstruye colision. Salientes grandes pueden aumentar solapamientos y complejidad de contactos; el presupuesto geometrico permanece igual.
@export_range(0.0, 3.0, 0.05, "suffix:m") var protrusion := 1.0
## Exponente del patron; menor ensancha los pliegues, mayor concentra las crestas. Live Preview o regeneracion manual.
## Coste: cambia un exponente por muestra, manteniendo topologia y presupuesto de memoria. Crestas muy estrechas pueden requerir menor Mesh Step; ese ajuste adicional si aumenta el coste. Regenera todo.
@export_range(0.4, 3.0, 0.05) var fold_sharpness := 0.8
## Estira el patron verticalmente; mayor produce surcos mas largos. Live Preview o regeneracion manual.
## Coste: cambia las coordenadas del ruido, no el numero de muestras, vertices o triangulos. Mantiene un coste estable similar; editarlo provoca reconstruccion completa.
@export_range(0.25, 5.0, 0.05) var vertical_stretch := 1.8
## Inclinacion minima en grados para comenzar el relieve, medida sobre la forma original. Live Preview o regeneracion manual.
## Coste: en esta implementacion es una mascara del desplazamiento, no un recorte de malla. Subirlo no elimina triangulos ni colisiones aunque menos superficie tenga relieve. Regenera todo.
@export_range(0.0, 85.0, 1.0, "suffix:degrees") var minimum_slope := 60.0
## Banda angular de entrada del efecto; mayor suaviza su aparicion. Live Preview o regeneracion manual.
## Coste: modifica la mascara angular; no agrega ni elimina geometria. Misma memoria y coste de renderizado aproximado; cambiarlo reconstruye todo.
@export_range(1.0, 20.0, 1.0, "suffix:degrees") var slope_transition := 8.0
## Metros de transicion sin desplazamiento en cima, pie y extremos. Evita juntas abiertas. Live Preview o regeneracion manual.
## Coste: modifica la mascara de bordes, sin reducir vertices, triangulos ni consultas de ruido. Un borde mas amplio no simplifica la malla. Cambiarlo reconstruye todo.
@export_range(0.5, 4.0, 0.1, "suffix:m") var edge_fade := 1.5
@export_group("Malla B")
## Distancia objetivo entre vertices sobre la pared, en metros. Menor da mas detalle y cuesta mas CPU/colision. Live Preview o regeneracion manual.
## Coste alto: reducirlo a la mitad produce aproximadamente cuatro veces mas vertices/triangulos en B. Aumentan generacion CPU, memoria, trabajo GPU y construccion/consultas de colision B. No mejora ni encarece la resolucion de A. Aplica a ambas mallas B.
@export_range(0.15, 1.0, 0.05, "suffix:m") var mesh_step := 0.3
@export_group("Aspecto y colision")
## Usa soft-grass (ID 0) y soft-cliff (ID 1) del Terrain3D por inclinacion final. Apagado recupera color uniforme. Live Preview o regeneracion manual.
## Coste: regenera todo; agrega calculo de pendientes/pintura en A y seis lecturas de textura por pixel en B (triplanar). No agrega geometria ni colision.
@export var slope_textures_enabled := true
## Angulo en grados desde horizontal donde comienza a aparecer roca. Mayor conserva hierba en pendientes mas fuertes. Live Preview o regeneracion manual.
## Coste: cambia la mezcla sin cambiar poligonos; en este laboratorio cualquier cambio reconstruye todo, incluidas colisiones activas.
@export_range(0.0, 85.0, 1.0, "suffix:degrees") var rock_start_angle := 45.0
## Grados de transicion hasta roca completa. Menor da borde mas nitido; mayor suaviza la mezcla. Live Preview o regeneracion manual.
## Coste: no cambia muestras de textura ni geometria; requiere reconstruccion completa. Transiciones muy estrechas pueden mostrar dientes a distancia.
@export_range(1.0, 30.0, 1.0, "suffix:degrees") var rock_blend_angle := 10.0
## Color uniforme compartido, sin texturas ni normal maps para comparar la forma. Live Preview o regeneracion manual.
## Coste: el color no agrega complejidad al material ni triangulos, pero actualmente su cambio activa la reconstruccion completa, incluidas colisiones. Usar Preview Delay para agrupar cambios del selector de color.
@export var rock_color := Color(0.48, 0.39, 0.29)
## Colision triangular de blockout desde la malla B y las mismas alturas de A. Live Preview o regeneracion manual. No es un proxy simplificado.
## Coste alto: activado construye y guarda colisiones triangulares y el suelo fisico, con coste CPU de generacion y consultas de fisica. Apagado ahorra esos recursos, pero el personaje deja de tener suelo/paredes fisicos en este laboratorio; las mallas visibles no se simplifican.
@export var collision_enabled := true

var _noise := FastNoiseLite.new()
var _generated: Node3D
var _player: ExplorerPlayer
var _rig: TrailCamera
var _overview: Camera3D
var _building := false
var _observed_parameters: Array = []
var _preview_wait := -1.0
const CENTERS := [24.0, 64.0, 104.0]
const GRID := 512
const SPACING := 0.25

func _preview_parameters() -> Array:
	return [relief_enabled, pattern_seed, cliff_height, cliff_width, wall_run,
		fold_size, indentation, protrusion, fold_sharpness, vertical_stretch,
		minimum_slope, slope_transition, edge_fade, mesh_step, rock_color, collision_enabled,
		rounded_enabled, rounded_radius, outline_irregularity,
		slope_textures_enabled, rock_start_angle, rock_blend_angle]

func _process(delta: float) -> void:
	if _building:
		return
	if not live_preview:
		_preview_wait = -1.0
		return
	var parameters := _preview_parameters()
	if parameters != _observed_parameters:
		_observed_parameters = parameters
		_preview_wait = preview_delay
		return
	if _preview_wait >= 0.0:
		_preview_wait -= delta
		if _preview_wait <= 0.0:
			_preview_wait = -1.0
			_regenerate_preview.call_deferred()

func _regenerate_preview() -> void:
	# Recheck after deferral: disabling the checkbox cancels queued work too.
	if live_preview and is_inside_tree():
		regenerate()

func _ready() -> void:
	if not Engine.is_editor_hint():
		# Give Terrain3D a valid camera before its first physics notification.
		_overview = Camera3D.new()
		add_child(_overview)
		_overview.position = Vector3(64,85,150)
		_overview.look_at(Vector3(64,3,61))
		_overview.far = 300.0
		if get_parent() == get_tree().root:
			_overview.make_current()
		$Terrain3D.set_camera(_overview)
	regenerate()
	if not Engine.is_editor_hint():
		_setup_preview.call_deferred()

func restore_base() -> void:
	relief_enabled = false
	regenerate()

func regenerate() -> void:
	if not is_inside_tree() or _building:
		return
	_building = true
	_preview_wait = -1.0
	_observed_parameters = _preview_parameters()
	_noise.seed = pattern_seed
	_noise.frequency = 1.0 / fold_size
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.fractal_octaves = 2
	if not is_instance_valid(_generated):
		_generated = get_node_or_null("GeneratedComparison")
	if is_instance_valid(_generated):
		_generated.free()
	_generated = Node3D.new()
	_generated.name = "GeneratedComparison"
	add_child(_generated)
	_build_heightmap()
	_build_shell()
	if rounded_enabled:
		_build_curved_shell()
	if collision_enabled:
		_build_height_collisions()
	for i in 3:
		var label := Label3D.new()
		label.text = ["REFERENCIA", "A · ALTURAS Terrain3D", "B · PLIEGUES DE MALLA"][i]
		label.position = Vector3(CENTERS[i], cliff_height + 3.0, 39.0)
		label.font_size = 64
		label.pixel_size = 0.012
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_generated.add_child(label)
		if rounded_enabled:
			var curved_label := label.duplicate() as Label3D
			curved_label.text = "CONTORNO CERRADO · " + label.text
			curved_label.position.z = 84.0
			_generated.add_child(curved_label)
	_building = false
	print("Cliff playground: regenerado. A: desplazamiento Y; B: desplazamiento normal. Semilla ", pattern_seed)

func _base_height(x: float, z: float) -> float:
	var side := 1.0 - smoothstep(cliff_width * 0.5 - 3.0, cliff_width * 0.5, absf(x))
	var front := clampf((42.0 - z) / wall_run, 0.0, 1.0)
	var back := smoothstep(20.0, 29.0, z)
	return cliff_height * side * front * back

func _base_normal(x: float, z: float) -> Vector3:
	var e := 0.05
	return Vector3(_base_height(x-e,z)-_base_height(x+e,z), 2.0*e,
		_base_height(x,z-e)-_base_height(x,z+e)).normalized()

func _offset(x: float, z: float, h: float) -> float:
	if not relief_enabled or z < 42.0-wall_run or z > 42.0:
		return 0.0
	var slope := rad_to_deg(acos(clampf(_base_normal(x,z).y, -1.0, 1.0)))
	var mask := smoothstep(minimum_slope, minimum_slope+slope_transition, slope)
	mask *= smoothstep(0.0, edge_fade, h) * smoothstep(0.0, edge_fade, cliff_height-h)
	mask *= smoothstep(0.0, edge_fade, cliff_width*0.5-3.0-absf(x))
	var n := clampf(_noise.get_noise_2d(x, h/vertical_stretch)*1.8, -1.0, 1.0)
	n = signf(n)*pow(absf(n), fold_sharpness)
	return n * (protrusion if n >= 0.0 else indentation) * mask

func _outline_radius(angle: float) -> float:
	# Periodic low frequencies give a closed outline without a seam at +/- PI.
	var phase := float(pattern_seed % 1000) * 0.37
	var variation := 0.65*sin(3.0*angle+phase)+0.35*sin(5.0*angle-phase)
	return minf(15.5, rounded_radius*(1.0+outline_irregularity*variation))

func _curved_height(x: float, z: float) -> float:
	var p := Vector2(x,z-84.0)
	var radius := _outline_radius(atan2(p.y,p.x))
	return cliff_height*clampf((radius-p.length())/minf(wall_run,radius*0.8),0.0,1.0)

func _curved_normal(x: float, z: float) -> Vector3:
	var e := 0.05
	return Vector3(_curved_height(x-e,z)-_curved_height(x+e,z),2.0*e,
		_curved_height(x,z-e)-_curved_height(x,z+e)).normalized()

func _curved_offset(x: float, z: float, h: float) -> float:
	if not relief_enabled or h <= 0.0 or h >= cliff_height:
		return 0.0
	var slope := rad_to_deg(acos(clampf(_curved_normal(x,z).y,-1.0,1.0)))
	var mask := smoothstep(minimum_slope,minimum_slope+slope_transition,slope)
	mask *= smoothstep(0.0,edge_fade,h)*smoothstep(0.0,edge_fade,cliff_height-h)
	# World-space 3D pattern remains continuous around the complete circumference.
	var n := clampf(_noise.get_noise_3d(x,h/vertical_stretch,z-84.0)*1.8,-1.0,1.0)
	n = signf(n)*pow(absf(n),fold_sharpness)
	return n*(protrusion if n >= 0.0 else indentation)*mask

func _build_curved_shell() -> void:
	var columns := ceili(TAU*18.0/mesh_step)
	var top_rings := maxi(1,ceili(rounded_radius/mesh_step))
	var wall_rings := maxi(2,ceili(sqrt(cliff_height*cliff_height+wall_run*wall_run)/mesh_step))
	var apron_rings := maxi(1,ceili((18.0-rounded_radius+2.0)/mesh_step))
	var rings := top_rings+wall_rings+apron_rings
	var vertices := PackedVector3Array([Vector3(CENTERS[2],cliff_height,84.0)])
	var indices := PackedInt32Array()
	for row in range(1,rings+1):
		for col in columns:
			var angle := TAU*float(col)/columns
			var outer := _outline_radius(angle)
			var inner := outer-minf(wall_run,outer*0.8)
			var radius: float
			if row <= top_rings:
				radius = inner*float(row)/top_rings
			elif row <= top_rings+wall_rings:
				radius = lerpf(inner,outer,float(row-top_rings)/wall_rings)
			else:
				radius = lerpf(outer,18.0,float(row-top_rings-wall_rings)/apron_rings)
			var x := cos(angle)*radius
			var z := 84.0+sin(angle)*radius
			var h := _curved_height(x,z)
			vertices.append(Vector3(x+CENTERS[2],maxf(h,0.015),z)+_curved_normal(x,z)*_curved_offset(x,z,h))
	for col in columns:
		indices.append_array(PackedInt32Array([0,1+col,1+(col+1)%columns]))
	for row in rings-1:
		for col in columns:
			var a := 1+row*columns+col
			var b := 1+row*columns+(col+1)%columns
			var c := a+columns
			var d := b+columns
			indices.append_array(PackedInt32Array([a,c,b,b,c,d]))
	_add_shell_mesh(vertices,indices,"RoundedCliffMeshB")

func _build_heightmap() -> void:
	var terrain: Terrain3D = $Terrain3D
	# This scene has no source regions. Replacing only its transient data leaves other scenes untouched.
	terrain.region_size = GRID
	terrain.vertex_spacing = SPACING
	terrain.mesh_size = 64
	terrain.material = terrain.material.duplicate(true)
	terrain.material.world_background = 0
	terrain.material.set_shader_param("flat_terrain_normals", false)
	terrain.material.set_shader_param("enable_macro_variation", false)
	terrain.material.show_colormap = not slope_textures_enabled
	terrain.material.auto_shader = false
	terrain.material.set_shader_param("enable_projection", true)
	terrain.assets = terrain.assets.duplicate(true)
	for asset in terrain.assets.texture_list:
		asset.normal_depth = 0.0
		asset.ao_strength = 0.0
		asset.roughness = 1.0
	# Explicit blockout triangles avoid missing plateau contacts in the mixed hole/heightmap region.
	terrain.collision_mode = Terrain3DCollision.DISABLED
	terrain.collision_layer = 1 | 4
	var heights := Image.create(GRID, GRID, false, Image.FORMAT_RF)
	var control := Image.create(GRID, GRID, false, Image.FORMAT_RF)
	var colors := Image.create(GRID, GRID, false, Image.FORMAT_RGBA8)
	colors.fill(Color.WHITE if slope_textures_enabled else rock_color)
	var hole_bytes := PackedByteArray()
	hole_bytes.resize(4)
	hole_bytes.encode_u32(0, 4)
	var hole := hole_bytes.decode_float(0)
	for iz in GRID:
		var z := iz*SPACING
		for ix in GRID:
			var x := ix*SPACING
			var h := _base_height(x-CENTERS[0],z)
			var ax := x-CENTERS[1]
			var ah := _base_height(ax,z)
			h = maxf(h, clampf(ah+_offset(ax,z,ah), 0.0, cliff_height))
			if rounded_enabled and z >= 64.0:
				var curved_a := _curved_height(ax,z)
				h = maxf(h, _curved_height(x-CENTERS[0],z))
				h = maxf(h, clampf(curved_a+_curved_offset(ax,z,curved_a),0.0,cliff_height))
			heights.set_pixel(ix,iz,Color(h,0,0))
			# Complete rectangular replacement B: mesh includes its own base, top and rear ramp.
			if x >= 90.0 and x <= 118.0 and z >= 18.0 and z <= 46.0:
				control.set_pixel(ix,iz,Color(hole,0,0))
			if rounded_enabled and Vector2(x-CENTERS[2],z-84.0).length() <= 16.0:
				control.set_pixel(ix,iz,Color(hole,0,0))
	if slope_textures_enabled:
		_paint_slope_controls(heights,control)
	terrain.data.import_images([heights,control,colors], Vector3.ZERO, 0.0, 1.0)

func _paint_slope_controls(heights: Image, control: Image) -> void:
	var packed := PackedByteArray()
	packed.resize(4)
	for z in GRID:
		for x in GRID:
			# Retain holes; otherwise write grass base ID=0, cliff overlay ID=1 and blend.
			if control.get_pixel(x,z).r != 0.0:
				continue
			var dx := heights.get_pixel(maxi(x-1,0),z).r-heights.get_pixel(mini(x+1,GRID-1),z).r
			var dz := heights.get_pixel(x,maxi(z-1,0)).r-heights.get_pixel(x,mini(z+1,GRID-1)).r
			var normal := Vector3(dx,2.0*SPACING,dz).normalized()
			var angle := rad_to_deg(acos(clampf(normal.y,-1.0,1.0)))
			var blend := roundi(255.0*smoothstep(rock_start_angle,rock_start_angle+rock_blend_angle,angle))
			packed.encode_u32(0,(1 << 22) | (blend << 14))
			control.set_pixel(x,z,Color(packed.decode_float(0),0,0))

func _build_height_collisions() -> void:
	for sample in (4 if rounded_enabled else 2):
		var curved := sample >= 2
		var faces := PackedVector3Array()
		for iz in (152 if curved else 128):
			for ix in 128:
				var points: Array[Vector3] = []
				for delta: Vector2 in [Vector2.ZERO,Vector2(1,0),Vector2(0,1),Vector2.ONE]:
					var x := -16.0+(ix+delta.x)*SPACING
					var z := (64.0 if curved else 16.0)+(iz+delta.y)*SPACING
					var h := _curved_height(x,z) if curved else _base_height(x,z)
					if sample % 2 == 1:
						h = clampf(h+(_curved_offset(x,z,h) if curved else _offset(x,z,h)),0.0,cliff_height)
					points.append(Vector3(x+CENTERS[sample % 2],h,z))
				for index in [0,1,2,1,3,2]:
					faces.append(points[index])
		var body := StaticBody3D.new()
		body.name = "HeightmapCollision"+str(sample)
		body.collision_layer = 1 | 4
		body.add_to_group("climbable")
		var collider := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		collider.shape = shape
		body.add_child(collider)
		_generated.add_child(body)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1 | 4
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(128,0.2,128)
	floor_shape.shape = box
	floor_body.position = Vector3(64,-0.1,64)
	floor_body.add_child(floor_shape)
	_generated.add_child(floor_body)

func _build_shell() -> void:
	var rows: Array[float] = []
	# Extra rows follow surface distance along the steep front, rather than its XZ footprint.
	for segment: Vector3 in [Vector3(16.0,42.0-wall_run,1.0), Vector3(42.0-wall_run,42.0,0.0), Vector3(42.0,48.0,1.0)]:
		var length: float = segment.y-segment.x
		var count := ceili((length if segment.z > 0.0 else sqrt(length*length+cliff_height*cliff_height))/mesh_step)
		for j in count:
			rows.append(lerpf(segment.x,segment.y,float(j)/count))
	rows.append(48.0)
	var columns := ceili(32.0/mesh_step)
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for z in rows:
		for ix in columns+1:
			var x := lerpf(-16.0,16.0,float(ix)/columns)
			var h := _base_height(x,z)
			# Slightly raised flat apron overlaps the hole boundary without coplanar flickering.
			vertices.append(Vector3(x+CENTERS[2],maxf(h,0.015),z)+_base_normal(x,z)*_offset(x,z,h))
	for iz in rows.size()-1:
		for ix in columns:
			var a := iz*(columns+1)+ix
			var b := a+1
			var c := a+columns+1
			var d := c+1
			indices.append_array(PackedInt32Array([a,b,c,b,d,c]))
	_add_shell_mesh(vertices,indices,"CliffMeshB")

func _add_shell_mesh(vertices: PackedVector3Array, indices: PackedInt32Array, mesh_name: String) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	for v in vertices:
		st.add_vertex(v)
	for i in indices:
		st.add_index(i)
	st.generate_normals()
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = rock_color
	mat.roughness = 1.0
	if slope_textures_enabled:
		var grass: Terrain3DTextureAsset = $Terrain3D.assets.get_texture(0)
		var cliff: Terrain3DTextureAsset = $Terrain3D.assets.get_texture(1)
		if grass != null and cliff != null:
			var slope_material := ShaderMaterial.new()
			slope_material.shader = preload("res://shaders/cliff_slope_surface.gdshader")
			slope_material.set_shader_parameter("grass_texture",grass.albedo_texture)
			slope_material.set_shader_parameter("cliff_texture",cliff.albedo_texture)
			slope_material.set_shader_parameter("grass_tint",grass.albedo_color)
			slope_material.set_shader_parameter("cliff_tint",cliff.albedo_color)
			slope_material.set_shader_parameter("grass_scale",grass.uv_scale)
			slope_material.set_shader_parameter("cliff_scale",cliff.uv_scale)
			slope_material.set_shader_parameter("slope_start",rock_start_angle)
			slope_material.set_shader_parameter("slope_width",rock_blend_angle)
			mesh.surface_set_material(0,slope_material)
		else:
			push_warning("Cliff playground necesita texturas Terrain3D ID 0 y 1; B conserva color uniforme.")
			mesh.surface_set_material(0,mat)
	else:
		mesh.surface_set_material(0, mat)
	var visual := MeshInstance3D.new()
	visual.name = mesh_name
	visual.mesh = mesh
	_generated.add_child(visual)
	if collision_enabled:
		var body := StaticBody3D.new()
		body.name = mesh_name+"Collision"
		body.collision_layer = 1 | 4
		body.add_to_group("climbable")
		var shape := CollisionShape3D.new()
		shape.shape = mesh.create_trimesh_shape()
		body.add_child(shape)
		_generated.add_child(body)

func _setup_preview() -> void:
	# When embedded in 3D_playground, its existing player/camera remain in charge.
	if get_tree().current_scene != self:
		_player = get_parent().get_node_or_null("SquirrelExplorer") as ExplorerPlayer
		_rig = get_parent().get_node_or_null("CameraRig") as TrailCamera
		if is_instance_valid(_player) and is_instance_valid(_rig):
			_add_preview_ui()
		return
	TrailInput.install()
	_player = preload("res://scenes/player.tscn").instantiate()
	add_child(_player)
	_player.set_controls(false)
	_rig = preload("res://scenes/camera_rig.tscn").instantiate()
	add_child(_rig)
	_rig.target = _player
	_rig.enabled = true
	_player.camera_rig = _rig
	var audio := TrailAudio.new()
	add_child(audio)
	audio.bind_player(_player)
	audio.bind_camera(_rig)
	_overview.make_current()
	$Terrain3D.set_camera(_overview)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35,-35,0)
	sun.shadow_enabled = true
	add_child(sun)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.23,0.3,0.38)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = 0.35
	add_child(world)
	_add_preview_ui()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_visit(1)
	_overview.make_current()
	$Terrain3D.set_camera(_overview)
	_player.set_controls(false)

func _add_preview_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var text := Label.new()
	text.text = "CLIFF LAB · 1/2/3 pared recta · 4/5/6 contorno cerrado (referencia/A/B)\nV vista general · R reiniciar · Ajustes: CliffPlayground / TerrainInstance > Inspector"
	text.position = Vector2(18,18)
	ui.add_child(text)

func _visit(index: int) -> void:
	if index >= 3 and not rounded_enabled:
		return
	_player.spawn_position = Vector3(CENTERS[index % 3],0.3,103.0 if index >= 3 else 47.0)
	_player.respawn()
	_rig.snap()
	_rig.camera.make_current()
	$Terrain3D.set_camera(_rig.camera)
	_player.set_controls(true)

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_instance_valid(_player) or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_1: _visit(0)
		KEY_2: _visit(1)
		KEY_3: _visit(2)
		KEY_4: _visit(3)
		KEY_5: _visit(4)
		KEY_6: _visit(5)
		KEY_R: _player.respawn()
		KEY_V:
			if _overview.current:
				_rig.camera.make_current()
				$Terrain3D.set_camera(_rig.camera)
				_player.set_controls(true)
			else:
				_overview.make_current()
				$Terrain3D.set_camera(_overview)
				_player.set_controls(false)
