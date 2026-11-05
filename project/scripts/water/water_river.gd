@tool
class_name WaterRiver
extends WaterBody
## Rio que sigue la curva: la altura de cada punto es la superficie del agua y el agua fluye del primer punto al ultimo.
## Donde la curva baja empinada aparecen rapidos y, casi en vertical, una cascada (cortina con espuma arriba y abajo); esos
## tramos empinados no tallan el terreno. Edita los puntos con las herramientas de Path3D; la malla se rehace en vivo.

@export_group("Forma")
## Ancho del agua en metros. Width Curve lo multiplica a lo largo del rio. En vivo.
@export_range(0.5, 80.0, 0.05, "suffix:m") var width := 6.0:
	set(value):
		width = value
		_queue_rebuild()
## Multiplicador del ancho a lo largo del rio (x: 0 = primer punto, 1 = ultimo). Vacio = ancho constante. En vivo.
@export var width_curve: Curve:
	set(value):
		if width_curve != null and width_curve.changed.is_connected(_queue_rebuild):
			width_curve.changed.disconnect(_queue_rebuild)
		width_curve = value
		if width_curve != null:
			width_curve.changed.connect(_queue_rebuild)
		_queue_rebuild()
## Metros que la malla se extiende bajo cada orilla para que su borde quede oculto en el terreno. Solo se dibuja donde una
## orilla lo tapa: donde no la hay (repisa, borde de una cascada) el agua conserva el ancho de Width. En vivo.
@export_range(0.0, 4.0, 0.05, "suffix:m") var bank_overlap := 0.75:
	set(value):
		bank_overlap = value
		_queue_rebuild()
## Separacion en metros entre filas de la malla a lo largo del rio. Menor sigue mejor las curvas cerradas y las cascadas;
## coste: mas vertices (muy pocos en cualquier caso). En vivo.
@export_range(0.1, 4.0, 0.05, "suffix:m") var step := 0.5:
	set(value):
		step = value
		_queue_rebuild()
## Divisiones a lo ancho de la malla. Mas sigue mejor un fondo curvo en cascadas anchas. En vivo.
@export_range(1, 16, 1) var cross_segments := 4:
	set(value):
		cross_segments = value
		_queue_rebuild()
## Metros antes y despues de un cambio de pendiente (borde de cascada, base, inicio de rapidos) con espuma. En vivo.
@export_range(0.25, 10.0, 0.05, "suffix:m") var break_foam_length := 2.5:
	set(value):
		break_foam_length = value
		_queue_rebuild()

@export_group("Cascada · forma")
## La cortina sigue la trayectoria de un chorro: sale horizontal del borde y la gravedad la curva hasta la poza. Este
## valor son los metros extra que el agua cae mas lejos del acantilado que la curva del rio: mayor = sale con mas
## velocidad y el borde se redondea mas. 0 = aterriza justo en el punto de la curva. Solo la malla; el nado usa la curva.
## En vivo.
@export_range(0.0, 8.0, 0.05, "suffix:m") var fall_bulge := 0.5:
	set(value):
		fall_bulge = value
		_queue_rebuild()
## Hacia donde sale el agua del borde, en grados: 0 = horizontal; positivo = sube un poco antes de caer (joroba sobre el
## borde, como un chorro con fuerza); negativo = ya sale apuntando hacia abajo (cae mas pegada a la roca). Aterriza en
## el mismo sitio (Fall Bulge). En vivo.
@export_range(-60.0, 45.0, 0.5, "suffix:degrees") var fall_exit_angle := 0.0:
	set(value):
		fall_exit_angle = value
		_queue_rebuild()
## 0-1: forma de toda la caida. 1 = arco de chorro (sale abierta y se curva con la gravedad); menor = se acerca a una
## rampa recta entre el borde y la poza. En vivo.
@export_range(0.0, 1.0, 0.01) var fall_arc := 1.0:
	set(value):
		fall_arc = value
		_queue_rebuild()
## Tamano de la curva del borde sobre el rio, en metros antes del borde: cuanto antes empieza el rio a doblarse hacia la
## caida (baja un poco al acercarse). 0 = el rio llega recto hasta el borde. Mas suave con Step pequeno. En vivo.
@export_range(0.0, 6.0, 0.05, "suffix:m") var fall_lip_round_before := 1.5:
	set(value):
		fall_lip_round_before = value
		_queue_rebuild()
## Tamano de la curva del borde sobre la cortina, en metros despues del borde: cuanto tarda el agua en pasar de salir
## del borde a caer. Mayor = curva mas amplia y redonda. 0 = codo tal cual. En vivo.
@export_range(0.0, 6.0, 0.05, "suffix:m") var fall_lip_round := 1.5:
	set(value):
		fall_lip_round = value
		_queue_rebuild()
## 0-1: cuanto se redondea la curva dentro de ese tamano. 1 = curva suave y amplia; menor = codo mas marcado. En vivo.
@export_range(0.0, 1.0, 0.01) var fall_lip_round_strength := 1.0:
	set(value):
		fall_lip_round_strength = value
		_queue_rebuild()
## 0-1: cuanto se ensancha la cortina hacia abajo (0,3 = 30 % mas ancha en la base). 0 = mismo ancho que el agua visible
## del rio entre sus orillas (Width), igual que la espuma de la base. En vivo.
@export_range(0.0, 1.0, 0.01) var fall_widen := 0.0:
	set(value):
		fall_widen = value
		_queue_rebuild()
## Grosor de la cortina en metros: la seccion es redondeada (abombada hacia delante, bordes hacia atras), asi que de lado
## se ve con volumen y la luz recorre la curva. 0 = lamina plana. En vivo.
@export_range(0.0, 3.0, 0.01, "suffix:m") var fall_thickness := 0.45:
	set(value):
		fall_thickness = value
		_queue_rebuild()
## Mueve la espuma de la base (lobulos, lineas, burbujas, gotas) a lo largo de la corriente, en metros: positivo = mas
## hacia fuera, alejandose del acantilado; negativo = mas hacia la pared. Ya se coloca sola donde aterriza la cortina y
## delante de su grosor; esto es un ajuste fino. En vivo.
@export_range(-4.0, 4.0, 0.05, "suffix:m") var fall_fx_offset := 0.0:
	set(value):
		fall_fx_offset = value
		_queue_rebuild()
## Sube o baja la espuma de la base, en metros. En vivo.
@export_range(-1.0, 1.0, 0.01, "suffix:m") var fall_fx_lift := 0.0:
	set(value):
		fall_fx_lift = value
		_queue_rebuild()
## Donde va la franja del borde en esta cascada: la mueve entera a lo largo de la superficie, en metros, sin cambiar su
## forma. Positivo = mas abajo por la cortina; negativo = mas arriba por el rio (hasta unos 6 m antes del borde). 0 =
## centrada en el borde. En vivo (guarda la escena para que el juego lo use).
@export_range(-5.0, 10.0, 0.05, "suffix:m") var fall_lip_band_offset := 0.0:
	set(value):
		fall_lip_band_offset = value
		_apply_band_shifts()

@export_group("Desembocadura")
## Funde el rio con el lago donde entra o sale de uno (WaterLake a la misma altura): la malla del rio sigue dentro del lago y
## se desvanece poco a poco, en vez de cortarse en la orilla. Apagado = corte en la orilla. En vivo.
@export var mouth_blend_enabled := true:
	set(value):
		mouth_blend_enabled = value
		_queue_rebuild()
## Metros dentro del lago, medidos desde la orilla, en que el rio pasa de opaco a invisible. Mayor = transicion mas suave y
## larga (la corriente del rio se ve entrar mas en el lago); menor = cambio mas rapido. Si la curva acaba antes, el rio se
## prolonga en linea recta. Coste: unas filas mas de malla. En vivo.
@export_range(0.5, 40.0, 0.25, "suffix:m") var mouth_blend_length := 8.0:
	set(value):
		mouth_blend_length = value
		_queue_rebuild()

@export_group("Piedras del fondo")
## Cantos rodados ovalados repartidos por el fondo del cauce. Solo visuales: sin colision ni logica. Se regeneran solos al
## cambiar el rio o tallar el cauce; tus valores se conservan. En vivo.
@export var pebbles_enabled := true:
	set(value):
		pebbles_enabled = value
		_queue_pebbles()
## Piedras por metro cuadrado de fondo. Mayor = lecho pedregoso; menor = piedras sueltas. Coste: un solo dibujo para todo
## el rio (MultiMesh); miles de piedras siguen siendo baratas. En vivo.
@export_range(0.0, 20.0, 0.05) var pebble_density := 2.5:
	set(value):
		pebble_density = value
		_queue_pebbles()
## Largo minimo de una piedra, en metros. En vivo.
@export_range(0.01, 2.0, 0.005, "suffix:m") var pebble_size_min := 0.1:
	set(value):
		pebble_size_min = value
		_queue_pebbles()
## Largo maximo de una piedra, en metros. En vivo.
@export_range(0.01, 3.0, 0.005, "suffix:m") var pebble_size_max := 0.5:
	set(value):
		pebble_size_max = value
		_queue_pebbles()
## 0-1: cuanto abundan las pequenas. 0 = todos los tamanos por igual; 1 = casi todas pequenas y alguna grande. En vivo.
@export_range(0.0, 1.0, 0.01) var pebble_small_bias := 0.6:
	set(value):
		pebble_small_bias = value
		_queue_pebbles()
## Ancho respecto al largo (min, max). 1 = redonda vista desde arriba; 0,5 = alargada como un huevo. En vivo.
@export var pebble_width_range := Vector2(0.55, 0.9):
	set(value):
		pebble_width_range = value
		_queue_pebbles()
## Alto respecto al largo (min, max). Menor = cantos planos de rio; mayor = piedras gorditas. En vivo.
@export var pebble_height_range := Vector2(0.3, 0.55):
	set(value):
		pebble_height_range = value
		_queue_pebbles()
## 0-1: parte de la piedra enterrada en el fondo. Mayor = asoman menos. En vivo.
@export_range(0.0, 0.9, 0.01) var pebble_sink := 0.35:
	set(value):
		pebble_sink = value
		_queue_pebbles()
## Inclinacion aleatoria maxima de cada piedra, en grados. 0 = todas tumbadas planas. En vivo.
@export_range(0.0, 45.0, 0.5, "suffix:degrees") var pebble_tilt := 12.0:
	set(value):
		pebble_tilt = value
		_queue_pebbles()
## 0-1: parte del ancho del rio que cubren, desde el centro. 1 = hasta la orilla. En vivo.
@export_range(0.0, 1.0, 0.01) var pebble_coverage := 0.9:
	set(value):
		pebble_coverage = value
		_queue_pebbles()
## Reparto a lo ancho: -1 = concentradas en el centro del cauce; 0 = uniforme; 1 = junto a las orillas. En vivo.
@export_range(-1.0, 1.0, 0.01) var pebble_edge_bias := 0.0:
	set(value):
		pebble_edge_bias = value
		_queue_pebbles()
## 0-1: agrupacion en manchas. 0 = repartidas por igual; 1 = en grupos con huecos de arena entre ellos. En vivo.
@export_range(0.0, 1.0, 0.01) var pebble_clumping := 0.45:
	set(value):
		pebble_clumping = value
		_queue_pebbles()
## Tamano de las manchas de piedras, en metros. En vivo.
@export_range(0.5, 30.0, 0.1, "suffix:m") var pebble_clump_size := 3.0:
	set(value):
		pebble_clump_size = value
		_queue_pebbles()
## Metros minimos de agua sobre una piedra. Evita que asomen por la superficie en lo poco profundo. En vivo.
@export_range(0.0, 2.0, 0.01, "suffix:m") var pebble_min_depth := 0.12:
	set(value):
		pebble_min_depth = value
		_queue_pebbles()
## Colores de las piedras: cada piedra toma un punto al azar del degradado. Varios tramos = varios rangos de color (gris,
## ocre, pardo...). En modo Constant cada tramo es un color fijo. Vacio = grises. En vivo.
@export var pebble_colors: Gradient = _default_pebble_colors():
	set(value):
		if pebble_colors != null and pebble_colors.changed.is_connected(_queue_pebbles):
			pebble_colors.changed.disconnect(_queue_pebbles)
		pebble_colors = value
		if pebble_colors != null:
			pebble_colors.changed.connect(_queue_pebbles)
		_queue_pebbles()
## 0-1: variacion extra de brillo por piedra sobre su color. En vivo.
@export_range(0.0, 0.5, 0.01) var pebble_brightness_variation := 0.12:
	set(value):
		pebble_brightness_variation = value
		_queue_pebbles()
## Aspereza de la superficie (0 brillante, 1 mate). En vivo.
@export_range(0.0, 1.0, 0.01) var pebble_roughness := 0.8:
	set(value):
		pebble_roughness = value
		_queue_pebbles()
## Semilla del reparto. Cambiala para otra colocacion con los mismos ajustes. En vivo.
@export var pebble_seed := 1:
	set(value):
		pebble_seed = value
		_queue_pebbles()
## Distancia en metros a partir de la que no se dibujan (0 = siempre), medida a cada tramo de Pebble Chunk Length.
## Ahorra en rios largos. En vivo.
@export_range(0.0, 500.0, 1.0, "suffix:m") var pebble_draw_distance := 120.0:
	set(value):
		pebble_draw_distance = value
		_queue_pebbles()
## Largo en metros de cada tramo de piedras. Cada tramo se dibuja y se oculta por distancia por separado. Menor = corte
## por distancia mas fino (algun dibujo mas); mayor = menos dibujos. En vivo.
@export_range(5.0, 200.0, 1.0, "suffix:m") var pebble_chunk_length := 25.0:
	set(value):
		pebble_chunk_length = value
		_queue_pebbles()
## Tope de piedras por rio. Si la densidad pide mas, se reduce por igual en todo el rio (nunca se queda sin piedras un
## tramo). En vivo.
@export_range(10, 100000, 10) var pebble_max_count := 20000:
	set(value):
		pebble_max_count = value
		_queue_pebbles()

@export_group("Cauce (Terrain3D)")
## 0-1: parte del ancho con fondo plano a Carve Depth; el resto sube en curva hasta la orilla. Al tallar.
@export_range(0.0, 1.0, 0.01) var bed_flat := 0.45
## Inclinacion en grados de la orilla interior de las curvas, donde un rio deposita arena: playas suaves frente a la margen
## exterior cortada (Bank Angle). Igual a Bank Angle = sin diferencia entre margenes. Al tallar.
@export_range(5.0, 80.0, 0.5, "suffix:degrees") var bank_angle_inner := 20.0
## Radio en metros de una curva cuya orilla interior ya es playa completa. Curvas mas abiertas mezclan hacia Bank Angle;
## mayor = playas tambien en curvas suaves. Al tallar.
@export_range(2.0, 200.0, 0.5, "suffix:m") var beach_bend_radius := 25.0

var _pebbles: Node3D
var _fall_fx: Node3D
# 0 at the lip to 1 at the base for rows on a fall, -1 elsewhere (from the last mesh build).
var _fall_progress := PackedFloat32Array()
# Bases of the falls found by the last mesh build: [position (local), width, flow direction (local, flat)].
# Fall effects (foam, lumps, bubbles, drops, mist) are set in the water style (Cascada · efectos), shared by every river.
var fall_fx_enabled: bool:
	get:
		return style.fall_fx_enabled if style != null else true
var fall_foam_enabled: bool:
	get:
		return style.fall_foam_enabled if style != null else true
var fall_foam_size: float:
	get:
		return style.fall_foam_size if style != null else 1.8
var fall_foam_opacity: float:
	get:
		return style.fall_foam_opacity if style != null else 0.65
var fall_foam_patch: float:
	get:
		return style.fall_foam_patch if style != null else 0.19
var fall_foam_rings: float:
	get:
		return style.fall_foam_rings if style != null else 5.0
var fall_foam_ring_speed: float:
	get:
		return style.fall_foam_ring_speed if style != null else 1.2
var fall_foam_line_width: float:
	get:
		return style.fall_foam_line_width if style != null else 0.16
var fall_foam_dashes: float:
	get:
		return style.fall_foam_dashes if style != null else 0.5
var fall_foam_reach: float:
	get:
		return style.fall_foam_reach if style != null else 0.62
var fall_foam_wobble: float:
	get:
		return style.fall_foam_wobble if style != null else 0.06
var fall_foam_drift: float:
	get:
		return style.fall_foam_drift if style != null else 0.6
var fall_puff_size: float:
	get:
		return style.fall_puff_size if style != null else 0.7
var fall_puff_density: float:
	get:
		return style.fall_puff_density if style != null else 4.0
var fall_puff_pulse: float:
	get:
		return style.fall_puff_pulse if style != null else 0.35
var fall_puff_opacity: float:
	get:
		return style.fall_puff_opacity if style != null else 0.85
var fall_puff_size_variation: float:
	get:
		return style.fall_puff_size_variation if style != null else 0.6
var fall_puff_shape_variation: float:
	get:
		return style.fall_puff_shape_variation if style != null else 0.5
var fall_puff_scatter: float:
	get:
		return style.fall_puff_scatter if style != null else 0.5
var fall_puff_seed: int:
	get:
		return style.fall_puff_seed if style != null else 7
var fall_puff_life_enabled: bool:
	get:
		return style.fall_puff_life_enabled if style != null else true
var fall_puff_life_speed: float:
	get:
		return style.fall_puff_life_speed if style != null else 0.45
var fall_puff_life_speed_variation: float:
	get:
		return style.fall_puff_life_speed_variation if style != null else 0.6
var fall_puff_life_size_variation: float:
	get:
		return style.fall_puff_life_size_variation if style != null else 0.5
var fall_puff_min_size: float:
	get:
		return style.fall_puff_min_size if style != null else 0.0
var fall_puff_hold: float:
	get:
		return style.fall_puff_hold if style != null else 0.3
var fall_fx_shadow_color: Color:
	get:
		return style.fall_fx_shadow_color if style != null else Color(0.56, 0.8, 0.95)
var fall_mist_enabled: bool:
	get:
		return style.fall_mist_enabled if style != null else false
var fall_mist_amount: int:
	get:
		return style.fall_mist_amount if style != null else 40
var fall_mist_size: float:
	get:
		return style.fall_mist_size if style != null else 2.0
var fall_mist_height: float:
	get:
		return style.fall_mist_height if style != null else 3.0
var fall_mist_opacity: float:
	get:
		return style.fall_mist_opacity if style != null else 0.5
var fall_splash_enabled: bool:
	get:
		return style.fall_splash_enabled if style != null else true
var fall_splash_amount: int:
	get:
		return style.fall_splash_amount if style != null else 140
var fall_splash_height: float:
	get:
		return style.fall_splash_height if style != null else 1.8
var fall_bubbles_enabled: bool:
	get:
		return style.fall_bubbles_enabled if style != null else true
var fall_bubbles_amount: int:
	get:
		return style.fall_bubbles_amount if style != null else 70
var fall_bubbles_size: float:
	get:
		return style.fall_bubbles_size if style != null else 0.12
var fall_bubbles_spread: float:
	get:
		return style.fall_bubbles_spread if style != null else 1.2
var fall_splash_size: float:
	get:
		return style.fall_splash_size if style != null else 1.0
var fall_bubbles_opacity: float:
	get:
		return style.fall_bubbles_opacity if style != null else 0.85
var fall_splash_opacity: float:
	get:
		return style.fall_splash_opacity if style != null else 1.0
var fall_splash_shading: float:
	get:
		return style.fall_splash_shading if style != null else 0.6
var fall_fx_color: Color:
	get:
		return style.fall_fx_color if style != null else Color(0.84, 0.95, 1.0)

var _fall_bases: Array = []
# Falls of the last build, in world space: [lip (x, z), outward (x, z), reach in metres, half width in metres, lip height].
var _fall_zones: Array = []
# Share of Bank Overlap drawn on each row of the last build: 0 on a fall and on the stretch leading into its lip, so the
# river reaching the lip is exactly as wide as the curtain (no corners sticking out over the cliff).
var _overlap_scale := PackedFloat32Array()
# Metres from each river row to the lip of the fall it leads into (-1 when farther than 6 m or not leading into one).
var _lip_gap := PackedFloat32Array()
# Metres along the curtain surface from its lip, on the rows of a fall (-1 elsewhere).
var _lip_down := PackedFloat32Array()
# Signed metres from the foot of a fall: > 0 up the curtain, < 0 out over the water below (up to 6 m); NAN elsewhere.
var _foot_s := PackedFloat32Array()
var _pebbles_queued := false

# Samples in world space for water queries (swimming, camera), refreshed with the mesh.
var _world_points := PackedVector3Array()
var _world_halves := PackedFloat32Array()
var _world_bounds := Rect2()

func _ready() -> void:
	set_notify_transform(true)
	# The default gradient is set by the initializer, which skips the setter: listen to it here.
	if pebble_colors != null and not pebble_colors.changed.is_connected(_queue_pebbles):
		pebble_colors.changed.connect(_queue_pebbles)
	super()

## Grey, ochre, brown, slate and pale river stones.
static func _default_pebble_colors() -> Gradient:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.3, 0.55, 0.8, 1.0])
	gradient.colors = PackedColorArray([Color(0.56, 0.55, 0.52), Color(0.62, 0.52, 0.38), Color(0.42, 0.34, 0.27),
		Color(0.45, 0.5, 0.54), Color(0.72, 0.7, 0.66)])
	return gradient

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_queue_rebuild()

func _default_curve() -> Curve3D:
	var shape := Curve3D.new()
	shape.add_point(Vector3(0, 0, 0))
	shape.add_point(Vector3(0, 0, 20))
	return shape

func _cache_world_samples(points: PackedVector3Array, halves: PackedFloat32Array) -> void:
	_world_points = PackedVector3Array()
	_world_halves = halves
	for point in points:
		_world_points.append(to_global(point))
	if _world_points.is_empty():
		return
	_world_bounds = Rect2(Vector2(_world_points[0].x, _world_points[0].z), Vector2.ZERO)
	var widest := 0.0
	for i in _world_points.size():
		_world_bounds = _world_bounds.expand(Vector2(_world_points[i].x, _world_points[i].z))
		widest = maxf(widest, halves[i])
	_world_bounds = _world_bounds.grow(widest + 1.0)

func _surface_at(point: Vector3) -> Dictionary:
	var q := Vector2(point.x, point.z)
	if _world_points.size() < 2 or not _world_bounds.has_point(q):
		return {}
	# In front of the cliff, from the lip down to the foot of a fall, there is only air and the falling sheet.
	for zone in _fall_zones:
		var p: Vector2 = q - zone[0]
		if p.dot(zone[1]) > 0.0 and p.dot(zone[1]) < zone[2] and absf(p.cross(zone[1])) < zone[3]:
			return {}
	var steep := tan(deg_to_rad(35.0))
	var rapids_start := deg_to_rad(style.rapids_start_angle if style != null else 4.0)
	var rapids_full := maxf(deg_to_rad(style.rapids_full_angle if style != null else 15.0), rapids_start + 0.01)
	var best := INF
	var result := {}
	for i in _world_points.size() - 1:
		var a := _world_points[i]
		var b := _world_points[i + 1]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var run := ab.length()
		# Falls hang in the air: nothing to swim in, the swimmer drops down the sheet.
		if absf(b.y - a.y) > maxf(run, 0.001) * steep:
			continue
		var raw := (q - Vector2(a.x, a.z)).dot(ab) / maxf(run * run, 0.000001)
		# Past the lip (or behind the foot) of a fall there is only air: no water in front of the cliff.
		if (raw > 1.0 and _world_steep(i + 1, steep)) or (raw < 0.0 and _world_steep(i - 1, steep)):
			continue
		var u := clampf(raw, 0.0, 1.0)
		var d := q.distance_to(Vector2(a.x, a.z) + ab * u)
		var half := lerpf(_world_halves[i], _world_halves[i + 1], u)
		if d > half + 0.25 or d >= best:
			continue
		best = d
		var flat := ab / maxf(run, 0.001)
		# Same speed-up as the shader in rapids, weaker towards the banks.
		var rapids := smoothstep(rapids_start, rapids_full, atan2(maxf(a.y - b.y, 0.0), maxf(run, 0.001)))
		var edge := clampf((half - d) / maxf(half * 0.4, 0.01), 0.0, 1.0)
		var speed := _style_flow_speed() * (1.0 + rapids * 1.5) * lerpf(0.25, 1.0, edge)
		result = {"surface": lerpf(a.y, b.y, u), "flow": Vector3(flat.x, 0.0, flat.y) * speed, "edge": edge}
	return result

## True when world sample segment i (to i + 1) is a fall (steeper than 35 degrees).
func _world_steep(i: int, steep: float) -> bool:
	if i < 0 or i + 1 >= _world_points.size():
		return false
	var a := _world_points[i]
	var b := _world_points[i + 1]
	return absf(b.y - a.y) > maxf(Vector2(b.x - a.x, b.z - a.z).length(), 0.001) * steep

## Per row, how much of Bank Overlap each side (x = left, y = right) may draw: 1 where the terrain rises above the water
## just past the visible edge (a bank hides the overlap), 0 where it does not (a cliff ledge, the lip of a fall, low
## ground), so the water there keeps the width of its channel instead of spilling out. Eased over a few rows.
func _bank_cover(points: PackedVector3Array, tangents: PackedVector3Array, halves: PackedFloat32Array,
		widen: PackedFloat32Array, in_lake: PackedByteArray) -> PackedVector2Array:
	var count := points.size()
	var cover := PackedVector2Array()
	cover.resize(count)
	cover.fill(Vector2.ONE)
	if bank_overlap <= 0.0 or not is_instance_valid(terrain) or terrain.data == null or not is_inside_tree():
		return cover
	var across := Vector3.RIGHT
	for i in count:
		var flat := Vector3(tangents[i].x, 0.0, tangents[i].z)
		if flat.length() > 0.001:
			across = Vector3(-flat.z, 0.0, flat.x).normalized()
		if in_lake[i]:
			continue
		var row := cover[i]
		for side in 2:
			var probe := to_global(points[i] + across * (-1.0 if side == 0 else 1.0) * (halves[i] * widen[i] + bank_overlap * 0.6))
			var ground := terrain.data.get_height(probe)
			if is_nan(ground) or ground < probe.y - 0.02:
				row[side] = 0.0
		cover[i] = row
	# Narrow before an open stretch, not on it: spread the gaps a row each way, then soften.
	for _pass in 2:
		var spread := cover.duplicate()
		for i in count:
			spread[i] = cover[i].min(cover[maxi(i - 1, 0)]).min(cover[mini(i + 1, count - 1)])
		cover = spread
	for _pass in 3:
		var soft := cover.duplicate()
		for i in range(1, count - 1):
			soft[i] = (cover[i - 1] + cover[i] * 2.0 + cover[i + 1]) * 0.25
		cover = soft
	return cover

## Points (local), half widths, distances, tangents and slopes along the curve.
func _samples() -> Dictionary:
	var length := curve.get_baked_length()
	var count := maxi(2, ceili(length / step) + 1)
	var points := PackedVector3Array()
	var halves := PackedFloat32Array()
	var distances := PackedFloat32Array()
	for i in count:
		var d := length * i / (count - 1)
		points.append(curve.sample_baked(d, true))
		distances.append(d)
		var factor := width_curve.sample_baked(d / maxf(length, 0.001)) if width_curve != null else 1.0
		halves.append(maxf(width * factor, 0.1) * 0.5)
	var tangents := PackedVector3Array()
	var slopes := PackedFloat32Array()
	for i in count:
		var t := (points[mini(i + 1, count - 1)] - points[maxi(i - 1, 0)]).normalized()
		tangents.append(t)
		slopes.append(asin(clampf(absf(t.y), 0.0, 1.0)) / (PI * 0.5))
	return {"points": points, "halves": halves, "distances": distances, "tangents": tangents, "slopes": slopes}

func _build_mesh() -> ArrayMesh:
	if curve.point_count < 2 or curve.get_baked_length() < 0.01:
		_world_points = PackedVector3Array()
		return null
	var s := _samples()
	var points: PackedVector3Array = s.points
	var halves: PackedFloat32Array = s.halves
	var distances: PackedFloat32Array = s.distances
	var tangents: PackedVector3Array = s.tangents
	var slopes: PackedFloat32Array = s.slopes
	_cache_world_samples(points, halves)
	var lakes := []
	var outlines := []
	if is_inside_tree():
		for body in get_tree().get_nodes_in_group("water_bodies"):
			if body is WaterLake and body != self:
				lakes.append(body)
				outlines.append(body.shore_outline())
	if mouth_blend_enabled:
		_extend_into_lakes(s, lakes, outlines)
		points = s.points
		halves = s.halves
		distances = s.distances
		tangents = s.tangents
		slopes = s.slopes
	var count := points.size()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangent_data := PackedFloat32Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	# CUSTOM0: x = signed metres from the foot of a fall, z = 1 where that is known (0 elsewhere).
	var custom0 := PackedFloat32Array()
	var indices := PackedInt32Array()
	var across := Vector3.RIGHT
	# Moving surface: enough divisions across for the waves to bend the water.
	var segments := cross_segments
	var spacing := _motion_spacing()
	if spacing > 0.0:
		var widest := 0.0
		for half in halves:
			widest = maxf(widest, half)
		segments = maxi(cross_segments, ceili((widest + bank_overlap) * 2.0 / spacing))
	if fall_thickness > 0.0:
		for slope in slopes:
			if slope >= (style.fall_start_angle if style != null else 35.0) / 90.0:
				segments = maxi(segments, 12)
				break
	var columns := segments + 1
	# Along-the-flow texture coordinate: metres, squeezed where the water runs faster (rapids, falls). The shader scrolls it
	# at one speed, so faster water moves and stretches its pattern without the shear stripes a per-pixel speed gives.
	var rapids_low := (style.rapids_start_angle if style != null else 4.0) / 90.0
	var rapids_high := maxf((style.rapids_full_angle if style != null else 15.0) / 90.0, rapids_low + 0.001)
	var along := 0.0
	var previous_rapids := 0.0
	var window := ceili(break_foam_length / maxf(distances[1] - distances[0], 0.001))
	# Rows inside a lake at the same height: with the mouth blend they fade out along the river over Mouth Blend Length
	# from the shore and sit just above the lake (drawn after it, see _render_priority); without it they are skipped (one
	# row is kept past the shore).
	var in_lake := PackedByteArray()
	in_lake.resize(count)
	var mouth := PackedFloat32Array()
	mouth.resize(count)
	var sides := PackedFloat32Array()
	sides.resize(count)
	for i in count:
		var world := to_global(points[i])
		for l in lakes.size():
			var lake: WaterLake = lakes[l]
			var depth: float = lake.shore_depth(world, outlines[l])
			# The lake mesh reaches Bank Overlap past its outline: the river must stay above it there too, or the lake
			# edge shows on top of the river as a strip across it.
			if depth <= -(lake.bank_overlap + 0.5):
				continue
			if mouth_blend_enabled:
				var lifted := to_local(Vector3(world.x, lake.global_position.y + 0.01, world.z))
				var point := points[i]
				# Inside the lake the river lies on it (a fall's run-out would otherwise be a shelf above the pool);
				# on the ring just outside it only rises, so the lake edge never shows on top of it.
				point.y = lifted.y if depth > 0.0 else maxf(point.y, lifted.y)
				points[i] = point
			if depth <= 0.0:
				continue
			in_lake[i] = 1
			break
	if mouth_blend_enabled:
		_mouth_fades(in_lake, distances, mouth, sides)
	var widen := _shape_falls(points, slopes, tangents, distances, halves)
	var cover := _bank_cover(points, tangents, halves, widen, in_lake)
	for i in count:
		var t := tangents[i]
		var flat := Vector3(t.x, 0.0, t.z)
		# Across stays horizontal; in a vertical drop it keeps the direction from above the fall.
		if flat.length() > 0.001:
			across = Vector3(-flat.z, 0.0, flat.x).normalized()
		var normal := across.cross(t).normalized()
		# Foam below a steeper stretch (base of a fall, end of rapids); a highlight just above one (the lip, where the
		# water curls over before dropping).
		var upstream := slopes[i]
		var downstream := slopes[i]
		for j in range(maxi(i - window, 0), i):
			upstream = maxf(upstream, slopes[j])
		for j in range(i + 1, mini(i + window / 2 + 1, count)):
			downstream = maxf(downstream, slopes[j])
		var break_foam := clampf((upstream - slopes[i]) * 2.0, 0.0, 1.0)
		var lip_amount := clampf((downstream - slopes[i]) * 2.0, 0.0, 1.0) if mouth[i] <= 0.0 else 0.0
		# On the curtain itself: white flames near the top, churning foam at the foot.
		var progress := _fall_progress[i] if i < _fall_progress.size() else -1.0
		if progress >= 0.0:
			lip_amount = maxf(lip_amount, pow(1.0 - progress, 2.0))
			break_foam = maxf(break_foam, smoothstep(0.8, 1.0, progress) * 0.9)
		# The curtain is as wide as the water you see between the banks above (its Width), not the drawn width: the bank
		# overlap hidden under the banks narrows away before the lip.
		var overlap := bank_overlap * (_overlap_scale[i] if i < _overlap_scale.size() else 1.0)
		# Each side keeps its overlap only where a bank covers it (see _bank_cover).
		var extent_left := halves[i] * widen[i] + overlap * cover[i].x
		var extent_right := halves[i] * widen[i] + overlap * cover[i].y
		var extent := maxf(extent_left, extent_right)
		# The whole curtain reads as a fall from just below the lip, even where the jet still leaves almost flat: its lines
		# and tone start at the curve of the edge.
		var shade_slope := slopes[i]
		if progress >= 0.0:
			var full := (style.fall_full_angle if style != null else 60.0) / 90.0
			shade_slope = maxf(slopes[i], lerpf(slopes[i], full, smoothstep(0.0, 0.12, progress)))
		elif i < _overlap_scale.size() and _overlap_scale[i] < 1.0:
			# The river bending down into the lip still reads as calm river, not as a strip of rapids.
			shade_slope = minf(shade_slope, rapids_low)
		var rapids := smoothstep(rapids_low, rapids_high, shade_slope)
		if i > 0:
			along += (distances[i] - distances[i - 1]) / (1.0 + 1.5 * (rapids + previous_rapids) * 0.5)
		else:
			along = distances[0]
		previous_rapids = rapids
		# Curtain volume: bulges forward in the middle, sides curl back. Fades in over the first part of the drop so the
		# rounded lip stays a smooth continuation of the river.
		var volume := fall_thickness * smoothstep(0.0, 0.25, progress) if progress >= 0.0 else 0.0
		var front := normal
		if volume > 0.0 and front.dot(Vector3(t.x, 0.0, t.z)) < 0.0:
			front = -front
		var visible_half := maxf(extent if progress >= 0.0 else halves[i] * widen[i], 0.01)
		for k in columns:
			var side := -1.0 + 2.0 * k / segments
			var reach := extent_left if side < 0.0 else extent_right
			var offset := 0.0
			var vertex_normal := normal
			if volume > 0.0:
				# Slab with rounded sides: nearly flat front, edges rolling back (root^0.35), so it reads as one thick body
				# of water instead of a hollow shell.
				var section := clampf(side * extent / visible_half, -0.97, 0.97)
				var root := sqrt(1.0 - section * section)
				offset = volume * pow(root, 0.35)
				# Slope of the section across the curtain, for the shading normal.
				var tilt := volume * 0.35 * pow(root, -0.65) * (-section / root) / visible_half
				vertex_normal = (front - across * tilt).normalized()
				if front != normal:
					vertex_normal = -vertex_normal
			vertices.append(points[i] + across * side * reach + front * offset)
			normals.append(vertex_normal)
			tangent_data.append_array(PackedFloat32Array([t.x, t.y, t.z, 1.0]))
			uvs.append(Vector2(side * reach, along))
			var edge := clampf((halves[i] - absf(side) * reach) / maxf(halves[i], 0.01), 0.0, 1.0)
			if progress >= 0.0:
				edge = clampf((1.0 - absf(side)) * reach / maxf(halves[i], 0.01), 0.0, 1.0)
			colors.append(Color(shade_slope, break_foam, edge, 1.0))
			# UV2.y: mouth sides inside lakes (> 0), the highlight above a lip (0 to -1) or a curtain row (-2 - lip).
			# Curtain rows are shifted by 2 so the shader can tell them apart from the highlight above a lip.
			var lip_code := -(2.0 + lip_amount) if progress >= 0.0 else -lip_amount
			# The curtain wins over the mouth sides: its foot often reaches into the pool.
			# UV2.x: mouth fade (0-1); or one signed distance across the lip for the lip band: -(1 + metres above the lip) on
			# the river just before it, -(101 + metres down the curtain surface) on the curtain.
			var mouth_code := mouth[i]
			if mouth[i] <= 0.0:
				if progress >= 0.0 and i < _lip_down.size() and _lip_down[i] >= 0.0:
					mouth_code = -(101.0 + _lip_down[i])
				elif i < _lip_gap.size() and _lip_gap[i] >= 0.0:
					mouth_code = -(1.0 + _lip_gap[i])
			uv2s.append(Vector2(mouth_code, lip_code if progress >= 0.0 or sides[i] <= 0.0 else sides[i]))
			var foot := _foot_s[i] if i < _foot_s.size() else NAN
			if is_nan(foot):
				custom0.append_array(PackedFloat32Array([0.0, 0.0, 0.0, 0.0]))
			else:
				custom0.append_array(PackedFloat32Array([foot, 0.0, 1.0, 0.0]))
		var buried := false
		if i > 0 and mouth_blend_enabled:
			buried = mouth[i] >= 1.0 and mouth[i - 1] >= 1.0
		elif i > 0:
			buried = in_lake[i] and in_lake[i - 1]
		if i > 0 and not buried:
			var row := i * columns
			var previous := row - columns
			for k in segments:
				indices.append_array(PackedInt32Array([previous + k, row + k, previous + k + 1,
					previous + k + 1, row + k, row + k + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangent_data
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_CUSTOM0] = custom0
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
		Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	return mesh

func _after_rebuild() -> void:
	_queue_pebbles()
	_build_fall_fx()

## Bends each fall away from the cliff (Fall Bulge) and returns the width multiplier of every row (Fall Widen). Also
## records where each fall meets the water below, for the base effects. Mesh only: swimming uses the curve.
func _shape_falls(points: PackedVector3Array, slopes: PackedFloat32Array, tangents: PackedVector3Array,
		distances: PackedFloat32Array, halves: PackedFloat32Array) -> PackedFloat32Array:
	var count := points.size()
	_fall_progress = PackedFloat32Array()
	_fall_progress.resize(count)
	_fall_progress.fill(-1.0)
	var widen := PackedFloat32Array()
	widen.resize(count)
	widen.fill(1.0)
	_overlap_scale = PackedFloat32Array()
	_overlap_scale.resize(count)
	_overlap_scale.fill(1.0)
	_lip_gap = PackedFloat32Array()
	_lip_gap.resize(count)
	_lip_gap.fill(-1.0)
	_lip_down = PackedFloat32Array()
	_lip_down.resize(count)
	_lip_down.fill(-1.0)
	_foot_s = PackedFloat32Array()
	_foot_s.resize(count)
	_foot_s.fill(NAN)
	_fall_bases.clear()
	_fall_zones.clear()
	var threshold := (style.fall_start_angle if style != null else 35.0) / 90.0
	var i := 0
	while i < count:
		if slopes[i] < threshold:
			i += 1
			continue
		var a := maxi(i - 1, 0)
		var b := i
		while b + 1 < count and slopes[b + 1] >= threshold:
			b += 1
		b = mini(b + 1, count - 1)
		var outward := Vector3(tangents[a].x, 0.0, tangents[a].z)
		outward = outward.normalized() if outward.length() > 0.001 else Vector3.FORWARD
		var span := maxf(distances[b] - distances[a], 0.001)
		# Projectile from the lip: horizontal exit, gravity bends it down, lands Fall Bulge beyond the curve's base.
		var lip := points[a]
		var drop := maxf(lip.y - points[b].y, 0.01)
		var reach := Vector2(points[b].x - lip.x, points[b].z - lip.z).dot(Vector2(outward.x, outward.z)) + fall_bulge
		# Exit Angle tilts the jet as it leaves; solve the flight so it still lands Reach away and Drop below.
		var tan_exit := tan(deg_to_rad(fall_exit_angle))
		var flight := sqrt(2.0 * drop / 9.8)
		var speed := maxf(reach, 0.05) / flight
		var rise := 0.0
		for _step in 8:
			rise = speed * tan_exit
			flight = (rise + sqrt(maxf(rise * rise + 19.6 * drop, 0.0))) / 9.8
			speed = maxf(reach, 0.05) / maxf(flight, 0.01)
		rise = speed * tan_exit
		var land_point := lip + outward * maxf(reach, 0.05) + Vector3.DOWN * drop
		for j in range(a, b + 1):
			var u := (distances[j] - distances[a]) / span
			var time := u * flight
			var jet := lip + outward * speed * time + Vector3.UP * (rise * time - 4.9 * time * time)
			var jet_velocity := (outward * speed + Vector3.UP * (rise - 9.8 * time)) * flight
			# Fall Arc blends the jet towards a straight ramp from the lip to the landing point.
			points[j] = lip.lerp(land_point, u).lerp(jet, fall_arc)
			var velocity := (land_point - lip).lerp(jet_velocity, fall_arc)
			tangents[j] = velocity.normalized()
			slopes[j] = asin(clampf(absf(tangents[j].y), 0.0, 1.0)) / (PI * 0.5)
			widen[j] = 1.0 + fall_widen * u
			_fall_progress[j] = u
			_overlap_scale[j] = 0.0
		# Upstream of the lip the hidden overlap narrows away over Bank Overlap x 3 metres.
		var taper := maxf(bank_overlap * 3.0, 0.5)
		for j in range(a - 1, -1, -1):
			var gap := distances[a] - distances[j]
			if gap > taper:
				break
			_overlap_scale[j] = minf(_overlap_scale[j], smoothstep(0.0, taper, gap))
		for j in range(a - 1, -1, -1):
			var gap := distances[a] - distances[j]
			if gap > 6.0:
				break
			_lip_gap[j] = gap if _lip_gap[j] < 0.0 else minf(_lip_gap[j], gap)
		# Round the bend from the river into the drop: relax the rows around the lip towards their neighbours.
		var row_step := maxf(distances[mini(a + 1, count - 1)] - distances[a], 0.05)
		var rows_before := ceili(fall_lip_round_before / row_step)
		var rows_after := ceili(fall_lip_round / row_step)
		var passes := roundi(maxi(rows_before, rows_after) * 3 * fall_lip_round_strength)
		if passes > 0 and (rows_before > 0 or rows_after > 0):
			var first := maxi(a - rows_before, 1)
			var last := mini(a + rows_after, b - 1)
			for _pass in passes:
				var relaxed := points.duplicate()
				for j in range(first, last + 1):
					relaxed[j] = (points[j - 1] + points[j] * 2.0 + points[j + 1]) * 0.25
				for j in range(first, last + 1):
					points[j] = relaxed[j]
			for j in range(maxi(first - 1, 0), mini(last + 2, count)):
				var tangent := (points[mini(j + 1, count - 1)] - points[maxi(j - 1, 0)]).normalized()
				tangents[j] = tangent
				slopes[j] = asin(clampf(absf(tangent.y), 0.0, 1.0)) / (PI * 0.5)
		# Distance along the curtain surface from the lip (after the rounding), for the lip band.
		var along_curtain := 0.0
		for j in range(a, b + 1):
			if j > a:
				along_curtain += points[j].distance_to(points[j - 1])
			_lip_down[j] = along_curtain
		for j in range(a, b + 1):
			_foot_s[j] = along_curtain - _lip_down[j]
		for j in range(b + 1, count):
			var out := distances[j] - distances[b]
			if out > 6.0:
				break
			_foot_s[j] = -out
		if is_inside_tree():
			var world_lip := to_global(lip)
			var world_out := global_transform.basis * outward
			var flat_out := Vector2(world_out.x, world_out.z).normalized()
			var world_base := to_global(points[b])
			var landing := (Vector2(world_base.x, world_base.z) - Vector2(world_lip.x, world_lip.z)).dot(flat_out)
			_fall_zones.append([Vector2(world_lip.x, world_lip.z), flat_out, maxf(landing, 0.5),
				halves[b] * (1.0 + fall_widen) + bank_overlap, world_lip.y])
		# A short run-out after the fall keeps the extra width, easing back to normal.
		for j in range(b + 1, mini(b + 6, count)):
			widen[j] = 1.0 + fall_widen * (1.0 - float(j - b) / 6.0)
		# The water below: the lowest of the first rows after the fall (the pool or the river carrying on).
		var base := points[b]
		for j in range(b, mini(b + 4, count)):
			base.y = minf(base.y, points[j].y)
		# Foam as wide as the curtain at its foot.
		# The curtain's visible face sits ahead of its centre line by its thickness: bring the foam out to meet it, plus the
		# hand offsets.
		base += outward * (fall_thickness * 0.6 + fall_fx_offset) + Vector3.UP * fall_fx_lift
		_fall_bases.append([base, halves[b] * (1.0 + fall_widen) * 2.0, outward])
		i = b + 1
	return widen

## Foam, mist and splashes at the base of every fall of this river.
var _built_fx_key: Array = []

## Where this river's lip band sits, on its own material (not part of the shared style).
func _apply_band_shifts() -> void:
	if _material != null:
		_material.set_shader_parameter("fall_lip_band_offset", fall_lip_band_offset)

func _after_style() -> void:
	_apply_band_shifts()
	var key: Array = style.fall_fx_key() if style != null else []
	if key != _built_fx_key and is_inside_tree():
		_built_fx_key = key
		_build_fall_fx()

func _build_fall_fx() -> void:
	if is_instance_valid(_fall_fx):
		for child in _fall_fx.get_children():
			_fall_fx.remove_child(child)
			child.queue_free()
	if not fall_fx_enabled or _fall_bases.is_empty() or not is_inside_tree():
		return
	if not is_instance_valid(_fall_fx):
		_fall_fx = Node3D.new()
		_fall_fx.name = "FallEffects"
		add_child(_fall_fx, false, Node.INTERNAL_MODE_FRONT)
	for base in _fall_bases:
		var origin: Vector3 = base[0]
		var outward: Vector3 = base[2]
		var width: float = base[1]
		var holder := Node3D.new()
		holder.name = "FallBase"
		_fall_fx.add_child(holder)
		holder.position = origin
		# Face downstream: local -Z along the flow, X across the sheet.
		holder.basis = Basis.looking_at(outward, Vector3.UP)
		if fall_foam_enabled:
			holder.add_child(_make_fall_foam(width))
			holder.add_child(_make_fall_puffs(width))
			if fall_bubbles_enabled and fall_bubbles_amount > 0:
				holder.add_child(_make_fall_bubbles(width))
		if fall_mist_enabled and fall_mist_amount > 0:
			holder.add_child(_make_fall_mist(width))
		if fall_splash_enabled and fall_splash_amount > 0:
			holder.add_child(_make_fall_splash(width))

func _make_fall_foam(width: float) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(width * fall_foam_size, width * fall_foam_size * 0.8)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/water/fall_foam.gdshader")
	# After lakes (0) and rivers (1).
	material.render_priority = 2
	material.set_shader_parameter("foam_color", fall_fx_color)
	material.set_shader_parameter("opacity", fall_foam_opacity)
	material.set_shader_parameter("noise_scale", maxf(width * 0.18, 0.2))
	material.set_shader_parameter("drift_speed", fall_foam_drift)
	material.set_shader_parameter("patch_size", fall_foam_patch)
	material.set_shader_parameter("rings", fall_foam_rings)
	material.set_shader_parameter("ring_speed", fall_foam_ring_speed)
	material.set_shader_parameter("line_width", fall_foam_line_width)
	material.set_shader_parameter("dashes", fall_foam_dashes)
	material.set_shader_parameter("reach", fall_foam_reach)
	material.set_shader_parameter("wobble", fall_foam_wobble)
	var foam := MeshInstance3D.new()
	foam.name = "Foam"
	foam.mesh = plane
	foam.material_override = material
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Centred a little downstream of the impact, just above the water.
	# The impact (UV.y 0.88 on the plane) sits right under the fall; the rest fans out downstream (-Z).
	foam.position = Vector3(0.0, 0.03, -plane.size.y * 0.38)
	return foam

## Cartoon foam band: squashed spheres in two staggered rows across the base, each pulsing on its own phase.
func _make_fall_puffs(width: float) -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = fall_puff_seed
	var count := maxi(3, ceili(width * fall_puff_density))
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = sphere
	multimesh.instance_count = count
	for k in count:
		var across := (float(k) + rng.randf_range(-0.3, 0.3) * (1.0 + fall_puff_scatter)) / float(maxi(count - 1, 1)) - 0.5
		var row := k % 3
		var row_scale: float = [1.0, 0.85, 0.65][row]
		var variation := rng.randf_range(-1.0, 1.0) * fall_puff_size_variation
		var size := fall_puff_size * row_scale * (1.0 + variation * (0.6 if variation > 0.0 else 0.5))
		var shape := fall_puff_shape_variation
		var stretch := Vector3(1.15 * (1.0 + rng.randf_range(-0.3, 0.5) * shape), 0.8 * (1.0 + rng.randf_range(-0.4, 0.5) * shape),
			1.0 + rng.randf_range(-0.3, 0.3) * shape) * size
		var basis := Basis(Vector3.UP, rng.randf() * TAU * shape) * Basis.from_scale(stretch)
		var depth := -0.1 - row * fall_puff_size * 0.9
		var origin := Vector3(across * width * 1.08, size * 0.25 - 0.05 - row * 0.08 + rng.randf_range(-0.12, 0.12) * fall_puff_scatter,
			depth + rng.randf_range(-0.12, 0.12) * (1.0 + 3.0 * fall_puff_scatter))
		multimesh.set_instance_transform(k, Transform3D(basis, origin))
		multimesh.set_instance_custom_data(k, Color(rng.randf() * TAU, rng.randf_range(0.7, 1.4), 0.0, 0.0))
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/water/fall_puff.gdshader")
	material.set_shader_parameter("light_color", fall_fx_color)
	material.set_shader_parameter("pulse", fall_puff_pulse)
	material.set_shader_parameter("opacity", fall_puff_opacity)
	material.set_shader_parameter("life_enabled", fall_puff_life_enabled)
	material.set_shader_parameter("life_speed", fall_puff_life_speed)
	material.set_shader_parameter("life_speed_variation", fall_puff_life_speed_variation)
	material.set_shader_parameter("life_size_variation", fall_puff_life_size_variation)
	material.set_shader_parameter("min_size", fall_puff_min_size)
	material.set_shader_parameter("hold", fall_puff_hold)
	# Translucent: after lakes (0), rivers (1) and the foam lines (2), so the water never paints over them.
	material.render_priority = 3
	var puffs := MultiMeshInstance3D.new()
	puffs.name = "Puffs"
	puffs.multimesh = multimesh
	puffs.material_override = material
	puffs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return puffs

func _make_fall_mist(width: float) -> CPUParticles3D:
	var mist := CPUParticles3D.new()
	mist.name = "Mist"
	mist.amount = fall_mist_amount
	mist.lifetime = 2.6
	mist.preprocess = 2.6
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	mist.emission_box_extents = Vector3(width * 0.5, 0.2, 0.4)
	mist.direction = Vector3(0.0, 1.0, -0.6)
	mist.spread = 35.0
	var rise := fall_mist_height / mist.lifetime
	mist.initial_velocity_min = rise * 0.6
	mist.initial_velocity_max = rise * 1.3
	mist.damping_min = 0.4
	mist.damping_max = 0.8
	mist.gravity = Vector3(0.0, 0.15, 0.0)
	mist.angle_min = 0.0
	mist.angle_max = 360.0
	mist.scale_amount_min = 0.6
	mist.scale_amount_max = 1.2
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.4))
	grow.add_point(Vector2(1.0, 1.6))
	mist.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	fade.colors = PackedColorArray([Color(fall_fx_color, 0.0), Color(fall_fx_color, fall_mist_opacity), Color(fall_fx_color, 0.0)])
	mist.color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * fall_mist_size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _soft_dot()
	material.render_priority = 3
	quad.material = material
	mist.mesh = quad
	mist.position = Vector3(0.0, 0.2, -0.3)
	return mist

func _make_fall_splash(width: float) -> CPUParticles3D:
	var splash := CPUParticles3D.new()
	splash.name = "Splash"
	splash.amount = fall_splash_amount
	splash.lifetime = 0.9
	splash.preprocess = 0.9
	splash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	splash.emission_box_extents = Vector3(width * 0.55, 0.3, 0.5)
	splash.direction = Vector3(0.0, 1.0, -0.4)
	splash.spread = 45.0
	var speed := sqrt(2.0 * 9.8 * fall_splash_height)
	splash.initial_velocity_min = speed * 0.55
	splash.initial_velocity_max = speed
	# Same droplets as the player's splash: round, flat white leaving the water, light blue as they fall, shrinking away.
	splash.gravity = Vector3(0.0, -16.0, 0.0)
	splash.lifetime = maxf(0.5, 2.0 * speed / 16.0)
	splash.preprocess = splash.lifetime
	splash.scale_amount_min = 0.7 * fall_splash_size
	splash.scale_amount_max = 1.8 * fall_splash_size
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(0.6, 0.8))
	shrink.add_point(Vector2(1.0, 0.0))
	splash.scale_amount_curve = shrink
	var tint := Gradient.new()
	tint.set_color(0, Color.WHITE)
	tint.set_color(0, Color(Color.WHITE, fall_splash_opacity))
	tint.set_color(1, Color(fall_fx_color.lerp(fall_fx_shadow_color, fall_splash_shading), fall_splash_opacity))
	splash.color_ramp = tint
	var drop := SphereMesh.new()
	drop.radius = 0.06
	drop.height = 0.12
	drop.radial_segments = 10
	drop.rings = 5
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = fall_fx_color
	if fall_splash_opacity < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.render_priority = 3
	drop.material = material
	splash.mesh = drop
	splash.position = Vector3(0.0, 0.05, -0.2)
	return splash

## Small white bubbles that pop up on the foam, drift downstream and fade.
func _make_fall_bubbles(width: float) -> CPUParticles3D:
	var bubbles := CPUParticles3D.new()
	bubbles.name = "FoamBubbles"
	bubbles.amount = fall_bubbles_amount
	bubbles.lifetime = 1.6
	bubbles.preprocess = 1.6
	bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	bubbles.emission_box_extents = Vector3(width * 0.55, 0.05, fall_puff_size * 1.2)
	# Downstream (-Z) and outward, along the water.
	bubbles.direction = Vector3(0.0, 0.25, -1.0)
	bubbles.spread = 70.0
	var drift := width * fall_bubbles_spread * 0.5 / bubbles.lifetime
	bubbles.initial_velocity_min = drift * 0.3
	bubbles.initial_velocity_max = drift
	bubbles.damping_min = drift * 0.3
	bubbles.damping_max = drift * 0.6
	bubbles.gravity = Vector3.ZERO
	bubbles.scale_amount_min = 0.5
	bubbles.scale_amount_max = 1.4
	var life := Curve.new()
	life.add_point(Vector2(0.0, 0.0))
	life.add_point(Vector2(0.15, 1.0))
	life.add_point(Vector2(0.75, 0.8))
	life.add_point(Vector2(1.0, 0.0))
	bubbles.scale_amount_curve = life
	var ball := SphereMesh.new()
	ball.radius = fall_bubbles_size * 0.5
	ball.height = fall_bubbles_size * 0.6
	ball.radial_segments = 8
	ball.rings = 4
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/water/fall_puff.gdshader")
	material.set_shader_parameter("light_color", fall_fx_color)
	material.set_shader_parameter("pulse", 0.0)
	# Particles have their own life; no lump cycle on top.
	material.set_shader_parameter("life_enabled", false)
	material.set_shader_parameter("opacity", fall_bubbles_opacity)
	material.render_priority = 3
	ball.material = material
	bubbles.mesh = ball
	bubbles.position = Vector3(0.0, 0.04, -fall_puff_size * 1.2)
	return bubbles

## Soft round dot for the mist sprites (white centre fading to transparent).
static func _soft_dot() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 64
	texture.height = 64
	return texture

func _terrain_changed() -> void:
	_queue_pebbles()

func _queue_pebbles() -> void:
	if _pebbles_queued or not is_inside_tree():
		return
	_pebbles_queued = true
	_build_pebbles.call_deferred()

## Bed height at a world point: the terrain when it has data there (follows hand sculpting), else the carve profile.
func _bed_height(world: Vector3, surface: float, half: float, across_distance: float) -> float:
	var carved := lerpf(surface - carve_depth, surface - 0.05, _smooth(half * bed_flat, half, across_distance))
	if is_instance_valid(terrain) and terrain.data != null:
		var height: float = terrain.data.get_height(world)
		if not is_nan(height):
			# Far below the water: the river hangs over a drop (lip of a fall). No bed there.
			if height < surface - carve_depth - 1.5:
				return NAN
			if height < surface:
				return height
	return carved

## Scatters the bed pebbles along the calm stretches of the river (not falls, not inside lakes) in one MultiMesh.
func _build_pebbles() -> void:
	_pebbles_queued = false
	if not is_inside_tree():
		return
	if not pebbles_enabled or pebble_density <= 0.0 or curve == null or curve.point_count < 2:
		_clear_pebbles()
		return
	if not is_instance_valid(_pebbles):
		_pebbles = Node3D.new()
		_pebbles.name = "Pebbles"
		add_child(_pebbles, false, Node.INTERNAL_MODE_FRONT)
	_clear_pebbles()
	var s := _samples()
	var points: PackedVector3Array = s.points
	var halves: PackedFloat32Array = s.halves
	var tangents: PackedVector3Array = s.tangents
	var distances: PackedFloat32Array = s.distances
	var chunk_ids := PackedInt32Array()
	var lakes := []
	var outlines := []
	for body in get_tree().get_nodes_in_group("water_bodies"):
		if body is WaterLake:
			lakes.append(body)
			outlines.append(body.shore_outline())
	var rng := RandomNumberGenerator.new()
	rng.seed = pebble_seed
	var clumps := FastNoiseLite.new()
	clumps.seed = pebble_seed
	clumps.frequency = 1.0 / maxf(pebble_clump_size, 0.1)
	var steep := tan(deg_to_rad(20.0))
	var size_low := minf(pebble_size_min, pebble_size_max)
	var size_high := maxf(pebble_size_min, pebble_size_max)
	# Expected total first: over Max Count the density drops evenly along the river instead of the end running out.
	var expected_total := 0.0
	for i in points.size() - 1:
		var run_i := Vector2(points[i + 1].x - points[i].x, points[i + 1].z - points[i].z).length()
		if run_i >= 0.001 and absf(points[i + 1].y - points[i].y) <= run_i * steep:
			expected_total += run_i * (halves[i] + halves[i + 1]) * pebble_coverage * pebble_density
	var density_scale := minf(1.0, float(pebble_max_count) / maxf(expected_total, 1.0))
	var transforms: Array[Transform3D] = []
	var colors := PackedColorArray()
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var run := Vector2(b.x - a.x, b.z - a.z).length()
		# Rapids and falls: water too fast and steep for a resting bed.
		if run < 0.001 or absf(b.y - a.y) > run * steep:
			continue
		var half := (halves[i] + halves[i + 1]) * 0.5
		var area := run * half * 2.0 * pebble_coverage
		var expected := area * pebble_density * density_scale
		var count := int(expected) + (1 if rng.randf() < expected - floorf(expected) else 0)
		var flat := Vector3(tangents[i].x, 0.0, tangents[i].z).normalized()
		var across := Vector3(-flat.z, 0.0, flat.x)
		for n in count:
			if transforms.size() >= pebble_max_count:
				break
			var t := rng.randf()
			var r := rng.randf()
			var lateral := r
			if pebble_edge_bias > 0.0:
				lateral = pow(r, 1.0 / (1.0 + pebble_edge_bias * 3.0))
			elif pebble_edge_bias < 0.0:
				lateral = pow(r, 1.0 - pebble_edge_bias * 3.0)
			lateral *= pebble_coverage * (1.0 if rng.randf() < 0.5 else -1.0)
			var center := a.lerp(b, t)
			var local := center + across * lateral * half
			var world := to_global(local)
			# Not on the rounded lip of a fall: the water bends down there and would leave them sticking out.
			var near_lip := false
			for zone in _fall_zones:
				var offset: Vector2 = Vector2(world.x, world.z) - zone[0]
				if offset.dot(zone[1]) > -(fall_lip_round + 1.0) and absf(offset.cross(zone[1])) < zone[3] + 1.0 \
						and offset.dot(zone[1]) < zone[2]:
					near_lip = true
					break
			if near_lip:
				continue
			if pebble_clumping > 0.0:
				var patch := clumps.get_noise_2d(world.x, world.z) * 0.5 + 0.5
				if patch < pebble_clumping * 0.85 and rng.randf() < pebble_clumping:
					continue
			var inside_lake := false
			for l in lakes.size():
				if lakes[l].shore_depth(world, outlines[l], 1.0) > 0.0:
					inside_lake = true
					break
			if inside_lake:
				continue
			var surface := world.y
			var bed := _bed_height(world, surface, half, absf(lateral) * half)
			if is_nan(bed):
				continue
			var size := lerpf(size_low, size_high, pow(rng.randf(), 1.0 + pebble_small_bias * 3.0))
			var width := size * rng.randf_range(minf(pebble_width_range.x, pebble_width_range.y), maxf(pebble_width_range.x, pebble_width_range.y))
			var height := size * rng.randf_range(minf(pebble_height_range.x, pebble_height_range.y), maxf(pebble_height_range.x, pebble_height_range.y))
			var top := bed + height * (1.0 - pebble_sink)
			if top > surface - pebble_min_depth:
				continue
			var basis := Basis(Vector3.UP, rng.randf() * TAU)
			basis = basis * Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(-pebble_tilt, pebble_tilt)))
			basis = basis * Basis(Vector3.FORWARD, deg_to_rad(rng.randf_range(-pebble_tilt, pebble_tilt)))
			basis = basis.scaled_local(Vector3(width, height, size))
			var origin := to_local(Vector3(world.x, bed + height * (0.5 - pebble_sink), world.z))
			transforms.append(Transform3D(basis, origin))
			chunk_ids.append(int(lerpf(distances[i], distances[i + 1], t) / maxf(pebble_chunk_length, 1.0)))
			var color := pebble_colors.sample(rng.randf()) if pebble_colors != null else Color(0.5, 0.5, 0.48).lerp(Color(0.32, 0.31, 0.3), rng.randf())
			var shade := 1.0 + rng.randf_range(-pebble_brightness_variation, pebble_brightness_variation)
			colors.append(Color(color.r * shade, color.g * shade, color.b * shade, 1.0))
	# One MultiMesh per stretch, placed at its own centre: visibility range is measured to the node, so a single node at
	# the river origin would hide every pebble far from it.
	var chunks := {}
	for k in transforms.size():
		if not chunks.has(chunk_ids[k]):
			chunks[chunk_ids[k]] = []
		chunks[chunk_ids[k]].append(k)
	var mesh := _pebble_mesh()
	for id in chunks:
		var members: Array = chunks[id]
		var centre := Vector3.ZERO
		for k in members:
			centre += transforms[k].origin
		centre /= float(members.size())
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = mesh
		multimesh.instance_count = members.size()
		for n in members.size():
			var k: int = members[n]
			multimesh.set_instance_transform(n, Transform3D(transforms[k].basis, transforms[k].origin - centre))
			multimesh.set_instance_color(n, colors[k])
		var chunk := MultiMeshInstance3D.new()
		chunk.name = "Chunk%d" % id
		chunk.position = centre
		chunk.multimesh = multimesh
		chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chunk.visibility_range_end = pebble_draw_distance
		_pebbles.add_child(chunk)

func _clear_pebbles() -> void:
	if not is_instance_valid(_pebbles):
		return
	for child in _pebbles.get_children():
		_pebbles.remove_child(child)
		child.queue_free()

## Low-poly unit pebble (1 m long), faceted like the rest of the art; each instance scales it to its own size.
func _pebble_mesh() -> Mesh:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 9
	sphere.rings = 5
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = pebble_roughness
	sphere.material = material
	return sphere

## Drawn after lakes (priority 0) so a mouth fading out blends over the lake surface.
func _render_priority() -> int:
	return 1

## Fade (0 opaque - 1 gone) of each row inside a lake, measured along the river from the shore it crossed. A run touching
## an end of the river fades toward that end; a run through the middle (the river crosses a lake) fades from both shores.
## Short runs fade over their own length so they always end invisible.
## Sides: 0-1 over the first metres past the shore, so the edges of the river soften right where it meets the lake
## instead of showing as straight lines over the lake surface.
func _mouth_fades(in_lake: PackedByteArray, distances: PackedFloat32Array, mouth: PackedFloat32Array,
		sides: PackedFloat32Array) -> void:
	var count := in_lake.size()
	var a := 0
	while a < count:
		if not in_lake[a]:
			a += 1
			continue
		var b := a
		while b + 1 < count and in_lake[b + 1]:
			b += 1
		var touches_start := a == 0
		var touches_end := b == count - 1
		var run := distances[b] - distances[a]
		if not (touches_start and touches_end):
			var both := not touches_start and not touches_end
			var length := maxf(minf(mouth_blend_length, run * (0.5 if both else 1.0)), 0.01)
			for i in range(a, b + 1):
				var from_entry := distances[i] - distances[a]
				var to_exit := distances[b] - distances[i]
				var inside := minf(from_entry, to_exit) if both else (from_entry if touches_end else to_exit)
				mouth[i] = clampf(inside / length, 0.0, 1.0)
				sides[i] = clampf(inside / minf(1.5, length), 0.0, 1.0)
		a = b + 1

## If an end of the curve stops at or inside a lake, prolongs it straight (flat, at the lake height) so the fade has Mouth
## Blend Length of river inside the lake. It never leaves the lake: in a small pond the fade is shorter. Mesh only: carving
## and water queries use the curve as drawn.
func _extend_into_lakes(s: Dictionary, lakes: Array, outlines: Array) -> void:
	# Packed arrays are values: edit local copies and store them back.
	var points: PackedVector3Array = s.points
	var halves: PackedFloat32Array = s.halves
	var distances: PackedFloat32Array = s.distances
	var tangents: PackedVector3Array = s.tangents
	var slopes: PackedFloat32Array = s.slopes
	var spacing := maxf(step, 0.1)
	for at_start in [false, true]:
		var count := points.size()
		var index := 0 if at_start else count - 1
		var end := points[index]
		var half := halves[index]
		var tangent := tangents[index]
		var outward := Vector3(tangent.x, 0.0, tangent.z) * (-1.0 if at_start else 1.0)
		if outward.length() < 0.001:
			continue
		outward = outward.normalized()
		var world := to_global(end)
		for l in lakes.size():
			var lake: WaterLake = lakes[l]
			var depth := lake.shore_depth(world, outlines[l])
			if depth < -(half + bank_overlap + 1.0):
				continue
			# River already inside the lake at this end.
			var inside := 0.0
			var j := index
			while j >= 0 and j < count and lake.shore_depth(to_global(points[j]), outlines[l]) > 0.0:
				inside = absf(distances[index] - distances[j])
				j += 1 if at_start else -1
			var level := to_local(Vector3(world.x, lake.global_position.y, world.z)).y
			var travelled := 0.0
			var entered := depth > 0.0
			var limit := mouth_blend_length + half * 2.0 + bank_overlap + 1.0
			while inside < mouth_blend_length and travelled < limit:
				var point := Vector3(end.x, level, end.z) + outward * (travelled + spacing)
				var point_depth := lake.shore_depth(to_global(point), outlines[l])
				if entered and point_depth <= 0.25:
					break
				travelled += spacing
				if point_depth > 0.0:
					entered = true
					inside += spacing
				if at_start:
					points.insert(0, point)
					halves.insert(0, half)
					distances.insert(0, distances[0] - spacing)
					tangents.insert(0, -outward)
					slopes.insert(0, 0.0)
				else:
					points.append(point)
					halves.append(half)
					distances.append(distances[distances.size() - 1] + spacing)
					tangents.append(outward)
					slopes.append(0.0)
			break
	s.points = points
	s.halves = halves
	s.distances = distances
	s.tangents = tangents
	s.slopes = slopes

func _collect_targets(targets: Dictionary) -> void:
	if curve == null or curve.point_count < 2:
		return
	var s := _samples()
	var points: PackedVector3Array = s.points
	var halves: PackedFloat32Array = s.halves
	var spacing := terrain.vertex_spacing
	var steep := tan(deg_to_rad(35.0))
	# Signed horizontal turn rate (rad/m) at each sample: positive turns toward +cross(tangent, side).
	var turns := PackedFloat32Array()
	turns.resize(points.size())
	for i in points.size():
		var before := points[maxi(i - 1, 0)]
		var after := points[mini(i + 1, points.size() - 1)]
		var t0 := Vector2(points[i].x - before.x, points[i].z - before.z)
		var t1 := Vector2(after.x - points[i].x, after.z - points[i].z)
		if t0.length() > 0.001 and t1.length() > 0.001:
			turns[i] = t0.angle_to(t1) / maxf((t0.length() + t1.length()) * 0.5, 0.001)
	for i in points.size() - 1:
		var a := to_global(points[i])
		var b := to_global(points[i + 1])
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var run := ab.length()
		# Falls and steep drops hang in front of the slope: carving them would cut a slot through the cliff.
		if absf(b.y - a.y) > maxf(run, 0.001) * steep:
			continue
		var into_fall_after := i + 2 < points.size() and absf(points[i + 2].y - points[i + 1].y) > \
			maxf(Vector2(points[i + 2].x - points[i + 1].x, points[i + 2].z - points[i + 1].z).length(), 0.001) * steep
		var into_fall_before := i > 0 and absf(points[i].y - points[i - 1].y) > \
			maxf(Vector2(points[i].x - points[i - 1].x, points[i].z - points[i - 1].z).length(), 0.001) * steep
		var reach := maxf(halves[i], halves[i + 1]) + bank_reach
		var near_falls := not _fall_zones.is_empty() and is_inside_tree()
		var low := Vector2i(floori((minf(a.x, b.x) - reach) / spacing), floori((minf(a.z, b.z) - reach) / spacing))
		var high := Vector2i(ceili((maxf(a.x, b.x) + reach) / spacing), ceili((maxf(a.z, b.z) + reach) / spacing))
		for z in range(low.y, high.y + 1):
			for x in range(low.x, high.x + 1):
				var q := Vector2(x * spacing, z * spacing)
				var raw := (q - Vector2(a.x, a.z)).dot(ab) / maxf(run * run, 0.000001)
				# Past the end of a stretch (round caps that fill the outer side of bends), but not into a fall and not
				# around one: there a cap would spread its own water level over the neighbours, e.g. the pool level behind
				# the foot of a fall up into the cliff.
				if (raw > 1.0 and into_fall_after) or (raw < 0.0 and into_fall_before):
					continue
				if (raw > 1.0 or raw < 0.0) and near_falls and WaterBody.under_fall(get_tree(), q, 1.0, reach, minf(a.y, b.y)):
					continue
				var u := clampf(raw, 0.0, 1.0)
				var d := q.distance_to(Vector2(a.x, a.z) + ab * u)
				var half := lerpf(halves[i], halves[i + 1], u)
				if d > half + bank_reach:
					continue
				var surface := lerpf(a.y, b.y, u)
				var waterline := surface - 0.05
				# Inner side of a bend (the side the river turns toward): gentler bank, the closer the bend the more.
				var turn := lerpf(turns[i], turns[i + 1], u)
				var side := ab.cross(q - Vector2(a.x, a.z) - ab * u)
				var inner := clampf(absf(turn) * beach_bend_radius, 0.0, 1.0) if side * turn > 0.0 else 0.0
				var angle := lerpf(bank_angle, bank_angle_inner, inner)
				var target: float
				if d <= half:
					target = lerpf(surface - carve_depth, waterline, _smooth(half * bed_flat, half, d))
				else:
					target = _bank_height(waterline, d - half, angle)
				var cell := Vector2i(x, z)
				if not targets.has(cell) or target < targets[cell].x:
					targets[cell] = Vector3(target, surface, angle)
