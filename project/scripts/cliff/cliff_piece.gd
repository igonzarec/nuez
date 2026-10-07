@tool
extends StaticBody3D
## Roca procedural con proxy independiente. Frente local +Z; base local Y=0.
## Sólo regenera su geometría interna: conserva plataformas y zonas manuales.

@export_group("Forma")
## Wall genera la pared; Ledge un bloque facetado con techo nevado ajustable.
@export_enum("Wall", "Ledge") var piece_type := 0
## Anchura X, altura Y y profundidad Z en metros. Usar valores positivos.
@export var dimensions := Vector3(60, 36, 18)
## Semilla reproducible de la forma y el color de facetas. No mueve hijos manuales.
@export var shape_seed := 21
## Columnas del frente. Más columnas añaden facetas y caras al proxy estático; reconstruye.
@export_range(2, 32, 1) var columns := 12
## Filas del relieve. Aumentan detalle visual y físico; coste proporcional a Columns por Rows.
@export_range(1, 24, 1) var rows := 8
## Relieve horizontal en metros. Crea nervaduras verticales escalables; reconstruye.
@export_range(0.0, 3.0, 0.05) var relief := 1.1
## Relieve visual adicional en metros. Mantener pequeño para coincidir con el proxy.
@export_range(0.0, 0.2, 0.01) var facet_depth := 0.08
## Variación del borde superior en metros. La nieve y la colisión siguen ese borde.
@export_range(0.0, 3.0, 0.05) var rim_variation := 0.6
## Pared: anchura superior respecto a la base. Menor valor estrecha los extremos hacia arriba.
@export_range(0.5, 1.0, 0.01) var top_width_ratio := 0.88
## Pared: descenso de los extremos de la coronación en metros; cero deja un borde casi recto.
@export_range(0.0, 15.0, 0.1) var crown_drop := 5.0
## Repisas: estrechamiento de la base, de 0 (recta) a 0.7. No cambia la pendiente elegida del techo.
@export_range(0.0, 0.7, 0.01) var bevel := 0.25
## Repisas: variación horizontal de esquinas como fracción del tamaño. 0.03–0.1 conserva apoyos legibles.
@export_range(0.0, 0.25, 0.01) var corner_variation := 0.08

@export_group("Silueta y relieve")
## Terreno SnowTerrain de referencia. Lee su superficie generada al reconstruir; no modifica el terreno.
@export_node_path("Node3D") var terrain_path := NodePath("")
## Mezcla con altura y profundidad del terreno de referencia. Requiere Rebuild tras editar ese terreno.
@export_range(0.0, 1.0, 0.01) var terrain_conform := 0.65
## Desfase en metros por delante de la superficie muestreada; evita esconder la roca dentro de la montaña.
@export_range(0.0, 5.0, 0.05) var terrain_offset := 0.6
## Variación lateral de la silueta en metros. Deforma ambos flancos, sin mover plataformas.
@export_range(0.0, 8.0, 0.1) var silhouette_irregularity := 2.0
## Desplazamiento de la cumbre hacia izquierda/derecha como fracción del ancho.
@export_range(-0.3, 0.3, 0.01) var crown_asymmetry := 0.12
## Relieve adicional a distintas alturas, en metros. También cambia el proxy físico.
@export_range(0.0, 6.0, 0.1) var vertical_relief := 1.6
## Proyección de la parte inferior hacia el jugador, en metros. Forma una base más ancha.
@export_range(0.0, 12.0, 0.1) var base_projection := 3.0

@export_group("Bloque o apoyo")
## Ajusta profundidad a la pared antecesora al mover X/Y o regenerarla. Desactivar para colocar libremente en Z.
@export var attach_to_wall := false
## Repisas: metros que sobresale el frente respecto a la pared con Attach To Wall; sin él desplaza la pieza en Z.
@export_range(-12.0, 20.0, 0.05) var protrusion := 0.0
## Inclinación del techo en grados: X izquierda/derecha; Y atrás/delante. Limitada internamente a ±25°.
@export var top_slope_degrees := Vector2.ZERO
## Irregularidad vertical de las esquinas del techo en metros. Mantener baja para apoyo semirregular.
@export_range(0.0, 1.0, 0.01) var top_irregularity := 0.06
## Desplaza el cinturón de facetas laterales en metros; altera también el volumen físico del bloque.
@export_range(0.0, 3.0, 0.05) var side_relief := 0.3

@export_group("Roca")
## Color principal. Se actualiza sin reconstruir la geometría.
@export var rock_color := Color(0.18, 0.21, 0.25)
## Color de las vetas oscuras. Se actualiza en vivo.
@export var vein_color := Color(0.07, 0.09, 0.12)
## Frecuencia de las vetas por metro; mayor valor produce vetas más juntas.
@export_range(0.05, 12.0, 0.05) var strata_scale := 2.0
## Intensidad de las vetas; cero las elimina. No modifica colisiones.
@export_range(0.0, 1.0, 0.01) var strata_strength := 0.22
## Ondulación de las vetas en metros. No deforma la roca física.
@export_range(0.0, 4.0, 0.05) var strata_warp := 0.8
## Contraste de color entre triángulos. Cero deja sólo la iluminación geométrica.
@export_range(0.0, 1.0, 0.01) var facet_variation := 0.35
## Rugosidad: uno mate, cero brillante. La roca suele necesitar valores altos.
@export_range(0.0, 1.0, 0.01) var roughness := 0.93

@export_group("Nieve superior")
## Capa sólida sobre la coronación. Incluye colisión a su altura visible.
@export var snow_enabled := true
## Grosor en metros. Reconstruye la capa y el proxy; no altera plataformas hijas.
@export_range(0.02, 1.5, 0.01) var snow_depth := 0.18
## Color de esta capa, independiente del material del terreno existente.
@export var snow_color := Color(0.86, 0.95, 1.0)
## Rugosidad de nieve: mayor valor reduce brillos; actualización en vivo.
@export_range(0.0, 1.0, 0.01) var snow_roughness := 0.9
## Activa el grano del mismo shader que usa SnowTerrain. Apagado conserva volumen y detalle amplio.
@export var snow_grain_enabled := false
## Frecuencia por metro. Más alto = grano más pequeño; actualización en vivo.
@export_range(0.1, 40.0, 0.1) var snow_grain_scale := 12.0
## Intensidad del grano fino; sólo actúa con Snow Grain Enabled.
@export_range(0.0, 0.3, 0.01) var snow_grain_strength := 0.07
## Microrelieve de iluminación del shader; no cambia colisión ni geometría.
@export_range(0.0, 0.3, 0.005) var snow_micro_relief := 0.045
## Suavidad de sombreado: cero facetas, uno normales suavizadas.
@export_range(0.0, 1.0, 0.01) var snow_shading_softness := 1.0
## Contraste de detalle mediano en nieve plana; independiente del grano.
@export_range(0.0, 1.0, 0.01) var snow_flat_detail_strength := 0.1
## Frecuencia del detalle mediano, independiente de Grain Scale.
@export_range(0.1, 20.0, 0.1) var snow_flat_detail_scale := 2.0
## Brillo del material nevado, sin alterar la luz global ni el color guardado.
@export_range(0.1, 1.5, 0.01) var snow_brightness := 1.0
## Brillo adicional de superficies horizontales; bajar si se pierde detalle por luz.
@export_range(0.1, 1.5, 0.01) var snow_flat_brightness := 0.95
## Ondulación geométrica en metros; la colisión sigue la nieve visible. Reconstruye.
@export_range(0.0, 0.8, 0.01) var snow_undulation := 0.06
## Longitud de la ondulación en metros; mayor produce variaciones más amplias.
@export_range(0.2, 20.0, 0.1) var snow_undulation_size := 3.0
## Repisas: abombado suave del centro en metros. Cero conserva sólo espesor y ondulación.
@export_range(0.0, 1.0, 0.01) var snow_rounding := 0.12
## Divisiones por parche de nieve. Coste cuadrático de malla y colisión; 3–6 suele bastar.
@export_range(1, 12, 1) var snow_segments := 4

@export_group("Escalada y física")
## Whole Wall: toda la roca. Selected Zones: sólo ClimbZones. Disabled: no agarrarse.
@export_enum("Whole Wall", "Selected Zones", "Disabled") var climb_mode := 0
## Desviación máxima respecto a una pared vertical, en grados. Mayor admite facetas más inclinadas.
@export_range(5.0, 70.0, 1.0) var climb_surface_tilt := 35.0
## Repisas: usar el modo de la pared antecesora, evitando escalada cuando ésta se apaga.
@export var inherit_climb_mode := true
## Colisión sólida independiente del detalle visual. Desactivar sólo para decoración.
@export var solid_enabled := true
## Añade capa 3 (Camera Blocker). El jugador usa capa 1. Cambio inmediato.
@export var camera_blocker := true

@export_group("Editor")
## Reconstruye geometría después de editar controles. No modifica nodos manuales.
@export var live_preview := true
## Segundos de espera tras el último cambio; agrupa operaciones al arrastrar sliders.
@export_range(0.1, 2.0, 0.05) var preview_delay := 0.35
## Fuerza regeneración aunque Live Preview esté apagado. Coste proporcional a filas/columnas.
@export_tool_button("Rebuild Geometry") var rebuild_action = rebuild

var _generated: Node3D
var _rock: ShaderMaterial
var _snow: ShaderMaterial
var _terrain_faces := PackedVector3Array()
var _wall_faces := PackedVector3Array()
var _geometry_revision := 0
var _placement_z := 0.0
var _built := []
var _pending := []
var _wait := 0.0
var _material_values := []

func _ready() -> void:
	add_to_group("climbable")
	call_deferred("rebuild")

func _shape_values() -> Array:
	var wall := _parent_wall() if attach_to_wall else null
	return [piece_type, dimensions, shape_seed, columns, rows, relief, facet_depth, rim_variation, top_width_ratio, crown_drop, bevel, corner_variation, snow_enabled, snow_depth, terrain_path, terrain_conform, terrain_offset, silhouette_irregularity, crown_asymmetry, vertical_relief, base_projection, protrusion, top_slope_degrees, top_irregularity, side_relief, snow_undulation, snow_undulation_size, snow_rounding, snow_segments, attach_to_wall, global_transform if attach_to_wall else Transform3D.IDENTITY, wall._geometry_revision if wall else 0]

func _parent_wall() -> Node3D:
	var node := get_parent()
	while node:
		if node.has_method("front_depth_at") and node.get("piece_type") == 0: return node
		node = node.get_parent()
	return null

func front_depth_at(x: float, y: float) -> float:
	return _project_faces(_wall_faces, x, y, 0.0, INF)

func _process(delta: float) -> void:
	collision_layer = (1 | (4 if camera_blocker else 0)) if solid_enabled else 0
	collision_mask = 0
	_apply_materials()
	if not live_preview: return
	var values := _shape_values()
	if values == _built: return
	if values != _pending:
		_pending = values.duplicate()
		_wait = preview_delay
	_wait -= delta
	if _wait <= 0.0: rebuild()

func allows_climb(point: Vector3) -> bool:
	if inherit_climb_mode:
		var ancestor := get_parent()
		while ancestor:
			if ancestor.has_method("allows_climb"):
				return ancestor.allows_climb(point)
			ancestor = ancestor.get_parent()
	if climb_mode == 2: return false
	if climb_mode == 0: return true
	var zones := get_node_or_null("ClimbZones")
	if zones:
		for zone in zones.get_children():
			if zone.has_method("contains_point") and zone.contains_point(point): return true
	return false

func climb_normal_limit() -> float:
	return sin(deg_to_rad(climb_surface_tilt))

func snow_sample(hit: Dictionary) -> Vector2:
	return Vector2(1.0, snow_depth) if snow_enabled and Vector3(hit.normal).dot(global_basis.y.normalized()) > 0.75 else Vector2.ZERO

func _apply_materials() -> void:
	if not _rock: return
	var values := [rock_color, vein_color, strata_scale, strata_strength, strata_warp, facet_variation, roughness, snow_color, snow_roughness, snow_grain_enabled, snow_grain_scale, snow_grain_strength, snow_micro_relief, snow_shading_softness, snow_flat_detail_strength, snow_flat_detail_scale, snow_brightness, snow_flat_brightness]
	if values == _material_values: return
	_material_values = values.duplicate()
	for key in ["rock_color", "vein_color", "strata_scale", "strata_strength", "strata_warp", "facet_variation"]:
		_rock.set_shader_parameter(key, get(key))
	_rock.set_shader_parameter("roughness_value", roughness)
	_snow.set_shader_parameter("snow_color", snow_color)
	_snow.set_shader_parameter("roughness", snow_roughness)
	for key in ["grain_enabled", "grain_scale", "grain_strength", "micro_relief", "shading_softness", "flat_detail_strength", "flat_detail_scale", "flat_brightness"]:
		_snow.set_shader_parameter(key, get("snow_" + key))
	_snow.set_shader_parameter("snow_brightness", snow_brightness)

func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, shade: float = 1.0) -> void:
	if (b-a).cross(c-a).length_squared() < 0.00000001: return
	if (c - a).cross(b - a).dot(normal) < 0.0:
		var swap := b
		b = c
		c = swap
	st.set_color(Color(shade, shade, shade))
	st.set_normal((c - a).cross(b - a).normalized())
	for p in [a, b, c]: st.add_vertex(p)

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	_triangle(st, a, b, c, normal)
	_triangle(st, a, c, d, normal)

func _visual(st: SurfaceTool, material: Material, label: String) -> void:
	var visual := MeshInstance3D.new()
	visual.name = label
	if label == "SnowCap":
		st.generate_normals()
	visual.mesh = st.commit()
	visual.material_override = material
	# Capa visual 20: la luz de relleno exclusiva no afecta al resto de la escena.
	visual.layers = 1 | (1 << 19)
	_generated.add_child(visual)

func _proxy(points: PackedVector3Array) -> void:
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var collider := CollisionShape3D.new()
	collider.shape = shape
	# CollisionShape must be a direct child of the physics body.
	add_child(collider)
	collider.set_meta("cliff_generated", true)

func rebuild() -> void:
	if not is_inside_tree(): return
	if is_instance_valid(_generated):
		remove_child(_generated)
		_generated.queue_free()
	for child in get_children():
		if child is CollisionShape3D and child.get_meta("cliff_generated", false):
			remove_child(child)
			child.queue_free()
	_generated = Node3D.new()
	_generated.name = "GeneratedGeometry"
	add_child(_generated)
	_rock = ShaderMaterial.new()
	_rock.shader = preload("res://shaders/cliff_rock.gdshader")
	_snow = ShaderMaterial.new()
	_snow.shader = preload("res://shaders/terrain_snow.gdshader")
	_material_values.clear()
	_apply_materials()
	var rock := SurfaceTool.new()
	var snow := SurfaceTool.new()
	rock.begin(Mesh.PRIMITIVE_TRIANGLES)
	snow.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = shape_seed
	var size := dimensions.abs().max(Vector3.ONE * 0.1)
	_placement_z = protrusion
	var wall := _parent_wall() if attach_to_wall else null
	if wall:
		var contact: Vector3 = wall.to_local(to_global(Vector3(0,size.y,0)))
		contact.z = wall.front_depth_at(contact.x,contact.y)
		_placement_z += to_local(wall.to_global(contact)).z - size.z*0.5
	if piece_type == 1:
		_build_ledge(rock, snow, size, rng)
	else:
		_load_terrain()
		_build_wall(rock, snow, size, rng)
	_visual(rock, _rock, "Rock")
	if snow_enabled:
		_collision_surface(snow)
		_visual(snow, _snow, "SnowCap")
	_built = _shape_values().duplicate()
	_geometry_revision += 1
	collision_layer = (1 | (4 if camera_blocker else 0)) if solid_enabled else 0
	collision_mask = 0

func _collision_surface(st: SurfaceTool) -> void:
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(st.commit().get_faces())
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.set_meta("cliff_generated", true)
	add_child(collider)

func _load_terrain() -> void:
	_terrain_faces.clear()
	if terrain_path.is_empty(): return
	var terrain := get_node_or_null(terrain_path)
	if terrain == null: return
	var mesh_node = terrain.get("_mesh")
	if not mesh_node is MeshInstance3D or mesh_node.mesh == null: return
	var transform_to_local: Transform3D = global_transform.affine_inverse() * mesh_node.global_transform
	for point in mesh_node.mesh.get_faces():
		_terrain_faces.append(transform_to_local * point)

func _terrain_front(x: float, y: float, fallback: float, depth: float) -> float:
	var sampled := _project_faces(_terrain_faces,x,y,-INF,depth)
	return lerpf(fallback,sampled+terrain_offset,terrain_conform) if sampled != -INF else fallback

func _project_faces(faces: PackedVector3Array, x: float, y: float, fallback: float, depth: float) -> float:
	var found := false
	var best := -INF
	for i in range(0, faces.size(), 3):
		var a := faces[i]
		var b := faces[i+1]
		var c := faces[i+2]
		var denominator := (b.y-c.y)*(a.x-c.x)+(c.x-b.x)*(a.y-c.y)
		if absf(denominator) < 0.0001: continue
		var u := ((b.y-c.y)*(x-c.x)+(c.x-b.x)*(y-c.y))/denominator
		var v := ((c.y-a.y)*(x-c.x)+(a.x-c.x)*(y-c.y))/denominator
		if u < 0 or v < 0 or u+v > 1: continue
		var z := u*a.z+v*b.z+(1-u-v)*c.z
		if z < -depth or z > depth: continue
		best = maxf(best, z)
		found = true
	return best if found else fallback

func _build_wall(rock: SurfaceTool, snow: SurfaceTool, size: Vector3, rng: RandomNumberGenerator) -> void:
	var grid: Array[PackedVector3Array] = []
	var heights := PackedFloat32Array()
	var phase := float(shape_seed) * 0.731
	for i in columns+1:
		var t := float(i)/columns
		var arch := pow(maxf(0.0, sin(clampf(t-crown_asymmetry, 0, 1)*PI)), 0.65)
		var height := maxf(1.0, size.y-minf(crown_drop,size.y*0.8)*(1-arch)+rng.randf_range(-rim_variation,rim_variation))
		var terrain_height := -INF
		var x := (t-0.5)*size.x*top_width_ratio
		for p in _terrain_faces:
			if absf(p.x-x) < size.x/columns and p.z >= -size.z and p.z < 3.0:
				terrain_height = maxf(terrain_height,p.y)
		if terrain_height != -INF:
			height = lerpf(height, clampf(terrain_height+0.2, size.y*0.35,size.y*1.2),terrain_conform)
		heights.append(height)
	for j in rows+1:
		var line := PackedVector3Array()
		var v := float(j)/rows
		for i in columns+1:
			var u := float(i)/columns
			var x := (u-0.5)*size.x*lerpf(1.0,top_width_ratio,pow(v,0.8))
			x += silhouette_irregularity * sin(v*5.0+phase+u*2.0)*sin(v*PI)
			var y := heights[i]*v
			var z := relief*sin(u*19.0+phase) + vertical_relief*sin(v*5.2+u*8+phase)
			z += base_projection*pow(1-v,1.4)
			z = _terrain_front(x,y,z,size.z) + relief*0.35*sin(u*23+v*7+phase)
			line.append(Vector3(x,y,z))
		grid.append(line)
	var physics := SurfaceTool.new()
	physics.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in rows:
		for i in columns:
			var p := grid[j][i]
			var q := grid[j][i+1]
			var r := grid[j+1][i+1]
			var t := grid[j+1][i]
			var center := (p+q+r+t)/4+Vector3.BACK*rng.randf_range(-facet_depth,facet_depth)
			for edge in [[p,q],[q,r],[r,t],[t,p]]:
				_triangle(rock,edge[0],edge[1],center,Vector3.BACK,rng.randf_range(0.65,1.2))
			_quad(physics,p,q,r,t,Vector3.BACK)
		# Cierra flancos por filas, siguiendo su silueta irregular.
		for i in [0,columns]:
			var a := grid[j][i]
			var b := grid[j+1][i]
			var normal := Vector3.LEFT if i == 0 else Vector3.RIGHT
			for surface in [rock,physics]:
				_quad(surface,a,b,Vector3(b.x,b.y,-size.z),Vector3(a.x,a.y,-size.z),normal)
	for i in columns:
		var a := grid[rows][i]
		var b := grid[rows][i+1]
		var top := [a,b,Vector3(b.x,b.y,-size.z),Vector3(a.x,a.y,-size.z)]
		for surface in [rock,physics]:
			_quad(surface,top[0],top[1],top[2],top[3],Vector3.UP)
			_quad(surface,Vector3(grid[0][i].x,0,-size.z),Vector3(grid[0][i+1].x,0,-size.z),top[2],top[3],Vector3.FORWARD)
		if snow_enabled: _cap(snow,top,snow_depth)
	_wall_faces = physics.commit().get_faces()
	_collision_surface(physics)

func _build_ledge(rock: SurfaceTool, snow: SurfaceTool, size: Vector3, rng: RandomNumberGenerator) -> void:
	# Octágono con esquinas cortadas: rompe la silueta rectangular del bloque.
	var outline := [Vector2(-0.36,-0.5),Vector2(0.34,-0.5),Vector2(0.5,-0.3),Vector2(0.5,0.32),Vector2(0.32,0.5),Vector2(-0.34,0.5),Vector2(-0.5,0.28),Vector2(-0.5,-0.3)]
	var top: Array[Vector3] = []
	var middle: Array[Vector3] = []
	var bottom: Array[Vector3] = []
	for p in outline:
		var x: float = p.x*size.x+rng.randf_range(-1,1)*size.x*corner_variation
		var z: float = p.y*size.z+rng.randf_range(-1,1)*size.z*corner_variation
		var y := maxf(0.1,size.y + x*tan(deg_to_rad(clampf(top_slope_degrees.x,-25,25))) + z*tan(deg_to_rad(clampf(top_slope_degrees.y,-25,25))) + rng.randf_range(-top_irregularity,top_irregularity))
		top.append(Vector3(x,y,z+_placement_z))
		middle.append(Vector3(x+rng.randf_range(-side_relief,side_relief),y*0.42,z+_placement_z+rng.randf_range(-side_relief,side_relief)))
		bottom.append(Vector3(x*(1-bevel),0,z*(1-bevel)+_placement_z))
	var center := Vector3(0,size.y,_placement_z)
	var points := PackedVector3Array()
	for i in top.size():
		points.append(top[i])
		points.append(middle[i])
		points.append(bottom[i])
		var k := (i+1)%top.size()
		var normal := ((top[i]+top[k])*0.5-center).normalized()
		_quad(rock,bottom[i],bottom[k],middle[k],middle[i],normal)
		_quad(rock,middle[i],middle[k],top[k],top[i],normal)
		_triangle(rock,top[i],top[k],center,Vector3.UP)
		_triangle(rock,bottom[k],bottom[i],Vector3(0,0,_placement_z),Vector3.DOWN)
		if snow_enabled:
			# Cuatro esquinas de un parche triangular (dos coinciden en el centro).
			_cap(snow,[top[i],top[k],center,center],snow_depth)
	_proxy(points)

func _snow_point(top: Array, u: float, v: float, depth: float) -> Vector3:
	var p: Vector3 = Vector3(top[0]).lerp(top[1],u).lerp(Vector3(top[3]).lerp(top[2],u),v)
	var wave := snow_undulation*(0.5+0.5*sin(p.x/snow_undulation_size)*cos(p.z/snow_undulation_size))
	# Para repisas el centro de cada abanico coincide, sin costuras entre parches.
	var dome := snow_rounding * sin(v*PI*0.5) if piece_type == 1 else 0.0
	return p+Vector3.UP*(depth+wave+dome)

func _cap(st: SurfaceTool, top: Array, depth: float) -> void:
	for j in snow_segments:
		for i in snow_segments:
			var u := float(i)/snow_segments
			var v := float(j)/snow_segments
			var u1 := float(i+1)/snow_segments
			var v1 := float(j+1)/snow_segments
			var a := _snow_point(top,u,v,depth)
			var b := _snow_point(top,u1,v,depth)
			var c := _snow_point(top,u1,v1,depth)
			var d := _snow_point(top,u,v1,depth)
			_quad(st,a,b,c,d,Vector3.UP)
	# Sólo el borde exterior del abanico; pared usa los cuatro bordes del parche.
	var edges := [[0,1]] if piece_type == 1 else [[0,1],[1,2],[2,3],[3,0]]
	var uv := [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]
	var center: Vector3 = (top[0]+top[1]+top[2]+top[3])/4
	for edge in edges:
		for i in snow_segments:
			var t := float(i)/snow_segments
			var t1 := float(i+1)/snow_segments
			var a: Vector3 = Vector3(top[edge[0]]).lerp(top[edge[1]],t)
			var b: Vector3 = Vector3(top[edge[0]]).lerp(top[edge[1]],t1)
			var va: Vector2 = Vector2(uv[edge[0]]).lerp(uv[edge[1]],t)
			var vb: Vector2 = Vector2(uv[edge[0]]).lerp(uv[edge[1]],t1)
			_quad(st,a,b,_snow_point(top,vb.x,vb.y,depth),_snow_point(top,va.x,va.y,depth),(a+b)*0.5-center)
