@tool
class_name CliffFoldsGenerator
extends Node3D
## Convierte las paredes empinadas esculpidas en Terrain3D en una malla plegada (estilo B del laboratorio).
## La malla sigue el perfil esculpido (hombros incluidos); los pliegues solo aparecen en la zona de cliff.
## Lee las alturas sin modificarlas, abre agujeros de Terrain3D solo bajo los pliegues y crea colision por chunk.
## Flujo: esculpir -> Regenerar cliffs. Para re-esculpir una pared: Restaurar terreno, esculpir, Regenerar.
## Hornear guarda malla/material/colision en un PackedScene. Runtime solo instancia ese recurso, sin generar
## (salvo que el terreno guardado ya no coincida con el bake: ver Rebuild Stale Bake).

@export_group("Generacion")
## Terrain3D del que se leen las alturas y donde se abren los agujeros. Debe estar en la misma escena.
## Coste: ninguno por si mismo; cambiarlo requiere Regenerar.
@export var terrain: Terrain3D
## Solo en editor y sin bake: genera una vista previa al abrir. Si hay bake, carga ese recurso. Nunca reconstruye al iniciar el juego.
## Coste: generacion CPU solo en editor cuando falta bake. Apagado requiere pulsar Regenerar u Hornear.
@export var rebuild_on_ready := true
## En el juego, si el terreno guardado ya no coincide con el bake (esculpiste o regeneraste sin volver a hornear),
## reconstruye los cliffs al iniciar en lugar de mostrar la malla vieja sobre agujeros que no cubre (huecos al vacio,
## malla levantada). Coste: una regeneracion completa al cargar (unos segundos de pausa). Apagado: solo avisa.
## La comprobacion compara alturas guardadas en el bake; los bakes anteriores a esta opcion no la tienen hasta rehornear.
@export var rebuild_stale_bake := true
## Regenera automaticamente al cambiar parametros de este nodo (no al esculpir). Agrupa cambios con Preview Delay.
## Coste alto en terrenos grandes: cada cambio reconstruye mallas, colisiones y agujeros de forma sincrona y puede pausar el editor. Apagado por defecto.
@export var live_preview := false
## Segundos sin cambios antes de regenerar con Live Preview. Se aplica en vivo.
## Coste: no cambia el coste de cada reconstruccion; solo cuantas veces ocurre mientras arrastras sliders.
@export_range(0.1, 3.0, 0.05, "suffix:s") var preview_delay := 0.6
## Lee el terreno actual, detecta paredes y reconstruye malla, colision y agujeros desde cero. Nunca acumula deformaciones.
## Coste: reconstruccion completa y sincrona. El resumen de vertices y tiempo aparece en la salida.
@export_tool_button("Regenerar cliffs") var rebuild_button: Callable = regenerate
## Genera B y guarda malla/material/colision en Bake Path y los datos de Terrain3D. Guarda la escena con Ctrl+S despues para conservar la referencia.
## Coste de generacion y escritura solo en editor. Runtime carga el recurso sin reconstruir. No ejecuta optimizacion de colision.
@export_tool_button("Hornear y guardar B") var bake_button: Callable = bake
## Copia pliegues, resolucion y angulos de mezcla desde cliff_playground.tscn. Sobrescribe esos controles solo al pulsar este boton.
## Coste bajo de lectura; requiere regenerar/hornear despues. Sirve para comparar con los ajustes exactos del B guardado.
@export_tool_button("Copiar ajustes del B de referencia") var reference_button: Callable = copy_reference_settings
## Recurso horneado que carga el juego. Lo asigna Hornear y guardar B; sin bake no se genera geometria al iniciar el juego.
## Coste runtime de cargar/dibujar mallas y colision, sin ruido ni reconstruccion. Tras editar hay que hornear otra vez y guardar la escena.
@export var baked_scene: PackedScene
## Archivo exclusivo para este generador. Usa una ruta distinta para cada instancia que tenga otra escultura.
## Coste de disco solo al hornear; guarda recursos binarios. No cambia al regenerar la vista previa.
@export_file("*.scn") var bake_path := "res://terrain_data/automatic_cliff/cliffs_baked.scn"
## Elimina la malla generada y cierra solo los agujeros que abrio este nodo (los que pintaste a mano se conservan). Usalo antes de re-esculpir una pared.
## Coste: bajo; actualiza el mapa de control y la colision de Terrain3D.
@export_tool_button("Restaurar terreno") var restore_button: Callable = restore_terrain
## Regenera registrando como propios los agujeros no registrados que quedan bajo la cubierta (restos de pruebas
## anteriores). Despues, Regenerar/Restaurar los cierran cuando ya no hacen falta. No uses este boton si pintaste
## a mano agujeros bajo el cliff que quieras conservar. Coste: el de una regeneracion.
@export_tool_button("Adoptar agujeros bajo la cubierta") var adopt_button: Callable = adopt_holes_under_cover

@export_group("Deteccion de paredes")
## Inclinacion en grados (0 = plano, 90 = vertical) a partir de la cual una zona se convierte en cliff plegado. Mayor: solo paredes casi verticales.
## Cada columna termina donde la escultura baja de este angulo: el hombro mas suave queda como superficie esculpida sin pliegues.
## Con Terrain Auto Slope = 1, 60 coincide con la roca completa del Auto Shader. Coste: bajarlo amplia el area con vertices, colision y agujeros.
@export_range(30.0, 89.0, 1.0, "suffix:degrees") var minimum_slope := 60.0
## Banda angular en la que el pliegue pasa de 0 a su intensidad completa. Mayor suaviza la entrada del efecto.
## Un collar se corta cuando la escultura vuelve a superar Minimum Slope + este valor (otra pared de una terraza). Sin coste extra.
@export_range(1.0, 25.0, 1.0, "suffix:degrees") var slope_transition := 10.0
## Radio en celdas usado para medir la pendiente. Mayor ignora irregularidades pequenas del esculpido y da direcciones de pliegue mas estables; demasiado alto ensancha la mascara.
## Coste: despreciable.
@export_range(1, 6, 1) var normal_radius := 2
## Valor antiguo conservado para migracion. No se utiliza; ahora la transicion se mide en metros desde cima/pie.
@export_storage var edge_fade_cells := 2

@export_group("Pliegues")
## Semilla reproducible del patron. Otra semilla redistribuye los pliegues con los mismos ajustes.
## Coste: igual entre semillas.
@export var pattern_seed: int = 27
## Tamano de las formas en metros. Mayor: grandes formaciones; menor: arrugas finas (puede requerir bajar Mesh Step).
## Coste: no cambia el numero de vertices.
@export_range(0.5, 10.0, 0.1, "suffix:m") var fold_size := 3.5
## Metros que se hunden las hendiduras, perpendicular a la pared.
## Coste: no agrega geometria; valores grandes pueden producir autointersecciones y contactos de escalada irregulares.
@export_range(0.0, 3.0, 0.05, "suffix:m") var indentation := 0.5
## Metros que sobresalen los salientes, perpendicular a la pared.
## Coste: no agrega geometria; salientes grandes pueden atravesar la cima o el suelo cercanos.
@export_range(0.0, 3.0, 0.05, "suffix:m") var protrusion := 0.5
## Exponente del patron: menor ensancha los pliegues, mayor concentra las crestas.
## Coste: no agrega geometria; crestas muy estrechas pueden requerir bajar Mesh Step.
@export_range(0.4, 4.0, 0.05) var fold_sharpness := 3.0
## Estira el patron verticalmente; mayor produce surcos verticales mas largos.
## Coste: ninguno.
@export_range(0.25, 5.0, 0.05) var vertical_stretch := 1.8

@export_group("Malla")
## Distancia horizontal maxima en metros desde cada semilla de columna hasta su cima o pie (donde la pendiente baja de Minimum Slope).
## Cada columna encuentra su propia cima y pie. Si la pendiente sigue alta al llegar al limite, la zona de cliff termina ahi y se avisa.
## Mayor admite paredes mas tendidas o altas; coste CPU solo al regenerar, sin coste runtime.
@export_range(1.0, 64.0, 0.5, "suffix:m") var profile_search_distance := 16.0
## Pasadas de busqueda de paredes. Cada pasada siembra columnas a la altura mediana de lo que sigue sin cubrir,
## asi cada escalon de una pared con terrazas recibe su propia franja. 1 = solo una altura por pared.
## Mayor cubre terrazas mas complejas; coste CPU proporcional solo al regenerar. Lo no cubierto queda como Terrain3D esculpido.
@export_range(1, 12, 1) var wall_search_passes := 6
## Diferencia maxima en metros entre la cima (o el pie) de columnas vecinas antes de partir la franja.
## Evita triangulos estirados donde una terraza termina contra otra pared. Menor parte antes (huecos sin pliegues);
## mayor une columnas distintas y puede deformar la malla. Regenerar.
@export_range(0.25, 10.0, 0.25, "suffix:m") var strip_break_distance := 2.0
## Valor antiguo conservado para cargar escenas. La construccion por contornos de B esta siempre activa.
@export_storage var reconstruct_surface := true
## Pasadas de suavizado del contorno semilla y de los limites cima/pie a lo largo de cada franja. 0 conserva dientes del muestreo.
## Los limites se mueven sobre la propia escultura (la malla nunca se separa de las alturas). CPU solo al regenerar/hornear.
@export_range(0, 40, 1) var surface_smoothing := 16
## Desplazamiento maximo en metros que el suavizado puede mover el contorno semilla o los limites cima/pie. 0 desactiva el suavizado.
## Mayor alinea mejor las filas en esculturas irregulares, pero desplaza mas el inicio de los pliegues. No modifica Terrain3D. Regenerar.
@export_range(0.0, 2.0, 0.05, "suffix:m") var smoothing_limit := 0.5
## Metros verticales desde el borde de la zona de cliff (cima/pie de cada columna) para desvanecer los pliegues, como B.
## Tambien suaviza los extremos de paredes abiertas. Mayor deja una franja mas lisa. Sin coste extra; regenerar/hornear.
@export_range(0.1, 10.0, 0.1, "suffix:m") var edge_fade_meters := 2.0
## Collar opaco en metros, medido sobre la superficie, que sigue exactamente la escultura fuera de la zona de cliff (hombro y suelo).
## Tapa los huecos que Terrain3D deja alrededor de sus agujeros en LOD lejanos. No abre agujeros. Mayor: mas geometria y colision.
## Recomendado >= 1 m; con 0 los agujeros quedan sin margen y pueden verse rendijas. Regenerar.
@export_range(0.0, 8.0, 0.25, "suffix:m") var seam_overlap := 2.0
## Banda en metros, despues del collar, donde la malla se funde con Terrain3D mediante un tramado (pase opaco, compatible con el
## desenfoque de camara). 0 deja un borde duro (usa entonces Skirt Depth). Coste: una superficie pequena por chunk con discard, sin colision. Regenerar.
@export_range(0.0, 4.0, 0.05, "suffix:m") var seam_fade_width := 1.0
## Distancia a la camara en metros desde la que la banda de fundido empieza a volverse opaca (opaca del todo al doble).
## De lejos Terrain3D usa triangulos gruesos junto a los agujeros, sombreados con la normal de la pared: a traves del tramado se ven
## como rayas oscuras al pie y la cima de los cliffs. Opaca, la banda los tapa; de lejos su borde no se distingue porque copia el
## sombreado del terreno. 0 = siempre tramada. En vivo; hornea para el juego. Coste nulo.
@export_range(0.0, 200.0, 1.0, "suffix:m") var seam_fade_far_distance := 24.0:
	set(value):
		seam_fade_far_distance = value
		_update_rock_angles()
## Elevacion de la cubierta en metros para evitar parpadeo donde coincide con Terrain3D. Mayor puede crear un escalon visible.
## Se suma a Seam Depth Offset. Coste nulo; regenerar.
@export_range(0.0, 0.1, 0.005, "suffix:m") var seam_lift := 0.02
## Separacion objetivo en metros alrededor del contorno Y a lo alto de la pared. Menor da pliegues mas detallados.
## Coste alto: reducir a la mitad multiplica aproximadamente por cuatro geometria, memoria y colision. Regenerar/hornear.
@export_range(0.1, 2.0, 0.05, "suffix:m") var mesh_step := 0.5
## Valor antiguo conservado para migracion; no limita la malla B.
@export_storage var max_subdivisions := 6
## Tamano en metros de cada chunk de malla y colision. Menor mejora el descarte por camara; mayor reduce el numero de nodos.
## Coste: no cambia el total de triangulos; chunks muy pequenos aumentan draw calls.
@export_range(4.0, 64.0, 1.0, "suffix:m") var chunk_size := 16.0
## Faldon que baja desde el borde de la malla para tapar rendijas con los LOD lejanos de Terrain3D. 0 lo desactiva.
## Solo se aplica con Seam Fade Width = 0 (con fundido el borde es transparente). Coste: bajo, sin colision.
@export_range(0.0, 2.0, 0.05, "suffix:m") var skirt_depth := 0.3
## Valor antiguo conservado para cargar escenas. No se aplica: ocultar una malla dejaria visibles sus agujeros permanentes.
@export_storage var visibility_range := 0.0

@export_group("Aspecto y colision")
## ID de textura de Terrain3D para zonas suaves de la malla (soft-grass).
## Coste: ninguno extra.
@export_range(0, 31, 1) var grass_texture_id := 0
## ID de textura de Terrain3D para paredes de la malla (soft-cliff).
## Coste: ninguno extra.
@export_range(0, 31, 1) var cliff_texture_id := 1
## Copia el Auto Shader de Terrain3D en la malla: mismas texturas, escala, proyeccion vertical, mezcla por altura y pendiente
## (Terrain Auto Slope), calculado con la pendiente esculpida. Asi la union y el hombro no se distinguen del terreno.
## Apagado: mezcla antigua por Rock Start/Blend Angle. Coste: dos texturas planas + seis triplanares por pixel. En vivo tras regenerar.
@export var match_terrain_shading := true
## 0-1: cuanto usa la roca de los pliegues proyeccion triplanar en lugar de la proyeccion de Terrain3D. Solo con Match Terrain Shading.
## 1 evita estiramientos en pliegues profundos; 0 copia exactamente la textura del terreno. Fuera de los pliegues siempre copia al terreno.
@export_range(0.0, 1.0, 0.05) var fold_triplanar := 1.0
## 0-1: borde limpio entre hierba y roca sobre la malla (solo Match Terrain Shading). En el pie y la cima la escultura cruza los
## angulos de roca a lo largo de casi un metro y la mezcla por altura dibuja dientes de hierba que suben por la roca. Con 1 la
## transicion se estrecha a pocos cm y los pliegues son siempre roca. La banda de fundido conserva la regla exacta del terreno, asi
## la union no cambia. 0 copia exactamente la regla del terreno en toda la malla. En vivo; hornea para el juego.
@export_range(0.0, 1.0, 0.05) var clean_rock_edge := 1.0:
	set(value):
		clean_rock_edge = value
		_update_rock_angles()
## Fraccion de la distancia a la camara que la malla se adelanta en profundidad (sin moverse en pantalla) para ganar a Terrain3D
## donde coinciden. 0.002 = 2 mm por metro. Mayor evita parpadeos con LOD lejanos; demasiado puede dibujar la malla por delante de
## objetos muy cercanos a la pared. Coste nulo; regenerar para aplicarlo al material.
@export_range(0.0, 0.01, 0.0005) var seam_depth_offset := 0.002
## Solo con Match Terrain Shading apagado. Angulo en grados donde empieza a verse roca sobre la malla. Mayor conserva hierba en pendientes mas fuertes.
## Coste: ninguno extra (triplanar con seis lecturas de textura por pixel).
@export_range(0.0, 85.0, 1.0, "suffix:degrees") var rock_start_angle := 45.0
## Solo con Match Terrain Shading apagado. Grados de transicion hasta roca completa. Menor: borde mas nitido; puede mostrar dientes a distancia.
## Coste: ninguno extra.
@export_range(1.0, 30.0, 1.0, "suffix:degrees") var rock_blend_angle := 10.0
## Activa el Auto Shader de Terrain3D (mismas texturas por pendiente) en el resto del terreno. Lo que pintes a mano en Terrain3D tiene prioridad.
## Coste: el del Auto Shader de Terrain3D; no afecta a la malla.
@export var terrain_auto_shader := true
## Solo con Rock By Angle apagado. Parametro auto_slope de Terrain3D: mayor hace que la roca aparezca antes en pendientes moderadas.
## No es un angulo: con 1 la roca es completa a 60 grados. Con Match Terrain Shading la malla usa el mismo valor. Se aplica al regenerar.
@export_range(0.0, 10.0, 0.1) var terrain_auto_slope := 1.0
## Sustituye la mezcla lineal del Auto Shader por una regla de angulos, en Terrain3D (shader override generado desde su propio
## shader, guardado en el material de esta escena) y en la malla. Asi las colinas suaves quedan con hierba y la roca marca lo trepable.
## Con esto activo Terrain Auto Slope no se usa. Afecta a todo el terreno de esta escena; lo pintado a mano conserva prioridad.
## Activar/desactivar se aplica al regenerar u hornear. Coste: el del Auto Shader (un acos por pixel mas).
@export var rock_by_angle := true
## Pendiente en grados donde empieza a mezclarse roca. Por debajo, hierba pura. Por defecto algo menos que la escalada del jugador
## (65 grados en superficies sin etiqueta) para anunciar la pared. Se actualiza en vivo en Terrain3D y la malla; hornea para el juego.
@export_range(0.0, 89.0, 0.5, "suffix:degrees") var rock_angle_start := 58.0:
	set(value):
		rock_angle_start = value
		_update_rock_angles()
## Pendiente en grados con roca completa. Mas cerca de Rock Angle Start: borde mas nitido (la mezcla por altura de las texturas lo
## vuelve irregular). Debe ser mayor que Rock Angle Start. En vivo en Terrain3D y la malla; hornea para el juego.
@export_range(0.5, 90.0, 0.5, "suffix:degrees") var rock_angle_full := 66.0:
	set(value):
		rock_angle_full = value
		_update_rock_angles()
## Solo con Rock By Angle. Hierba que se quita por cada metro de altura (como auto_height_reduction de Terrain3D, que aqui se ignora).
## 0 = la roca depende solo del angulo: ninguna mancha en colinas. Mayor anade roca en cumbres altas aunque sean suaves; incluso
## valores pequenos dejan manchas, porque la mezcla por altura de las texturas favorece a la roca. En vivo; hornea para el juego.
@export_range(0.0, 1.0, 0.01) var rock_height_reduction := 0.0:
	set(value):
		rock_height_reduction = value
		_update_rock_angles()
## Colision triangular por chunk que sigue los pliegues (grupo climbable, capas 1 y 3). Colision de blockout; no es un proxy simplificado.
## Coste alto: construir y consultar trimesh por chunk. Apagado: los agujeros dejan caer al personaje a traves de las paredes.
@export var collision_enabled := true

@export_group("Distancia (LOD)")
## Terrain3D simplifica el terreno lejano en anillos cada vez mas gruesos y solo oculta un vertice si cae justo sobre un agujero:
## de lejos sobreviven triangulos grandes que cruzan la pared y asoman como picos verdes delante del cliff. Esto empuja hacia atras
## en profundidad (mismo pixel en pantalla) los vertices lejanos que tienen un agujero cerca, para que la malla del cliff les gane.
## Va en el shader override de Terrain3D (junto a Rock By Angle). Activar/desactivar se aplica al regenerar u hornear.
## Coste: hasta 24 lecturas de textura por vertice, solo en los anillos lejanos (pocos vertices); nada en el LOD cercano.
@export var far_spike_fix := true
## Empuje en profundidad, en multiplos del paso del anillo lejano (3 = 6 m para un anillo de 2 m). Solo cambia quien tapa a quien:
## la iluminacion sigue en la superficie real. Mayor elimina picos mas grandes; demasiado deja ver a traves del terreno cercano a un
## cliff lo que este justo detras (la base del cliff tras la cima de una colina, objetos enterrados). En vivo; hornea para el juego.
@export_range(0.0, 8.0, 0.25) var far_spike_push := 3.0:
	set(value):
		far_spike_push = value
		_update_rock_angles()
## Radio de busqueda alrededor de cada vertice lejano, en multiplos del paso del anillo: busca agujeros o un desnivel de mas de 60 grados.
## Debe cubrir todos los vertices de los triangulos que cruzan la pared: por debajo de ~2 quedan munones verdes al pie de pilares
## estrechos. Mayor empuja tambien terreno algo mas alejado del cliff. En vivo; hornea para el juego.
@export_range(0.5, 4.0, 0.25) var far_spike_reach := 2.5:
	set(value):
		far_spike_reach = value
		_update_rock_angles()
## Genera versiones simplificadas de cada chunk de la malla al regenerar/hornear; Godot elige una segun el tamano en pantalla.
## Reduce vertices dibujados a distancia. No afecta a la colision. Coste: generacion algo mas lenta y bake mas grande.
@export var mesh_lod := true
## Angulo en grados por debajo del cual la simplificacion puede fusionar normales. Mayor simplifica mas (pliegues mas blandos
## a distancia); menor conserva aristas marcadas. Regenerar/hornear.
@export_range(0.0, 180.0, 1.0, "suffix:degrees") var mesh_lod_merge_angle := 25.0
## Sesgo de LOD de cada chunk (GeometryInstance3D.lod_bias). Mayor que 1 mantiene detalle hasta mas lejos; menor simplifica antes.
## El umbral global esta en Project Settings > Rendering > Mesh LOD > LOD Change > Threshold Pixels. En vivo; hornea para el juego.
@export_range(0.1, 8.0, 0.05) var mesh_lod_bias := 1.0:
	set(value):
		mesh_lod_bias = value
		_update_rock_angles()

## Celdas (x, z en pixeles globales de Terrain3D) cuyos agujeros abrio este nodo. Se guarda con la escena para poder restaurarlos.
@export_storage var owned_holes := PackedInt32Array()

const EPSILON := 0.001
## Height samples stored per bake and the difference (m) that counts as a re-sculpted terrain.
const STALE_SAMPLES := 4096
const STALE_TOLERANCE := 0.02
var _bake_stale := false
var _uncovered_holes := 0
var _texture_signature: Array = []
var _texture_check_wait := 0.0
var _noise := FastNoiseLite.new()
var _generated: Node3D
var _building := false
var _observed_parameters: Array = []
var _preview_wait := -1.0
# Grid snapshot of the terrain covering all regions.
var _spacing := 1.0
var _origin := Vector2i.ZERO
var _w := 0
var _d := 0
var _heights := PackedFloat32Array()
var _normals := PackedVector3Array()
var _mask := PackedFloat32Array()
var _amplitude := PackedFloat32Array()
var _subdivisions := 1
var _positions := {}
var _surface_candidate
var _last_build_ok := false
var _wanted_holes := PackedInt32Array()
var _adopting := false

func _preview_parameters() -> Array:
	return [minimum_slope, slope_transition, normal_radius, pattern_seed,
		fold_size, indentation, protrusion, fold_sharpness, vertical_stretch, mesh_step,
		profile_search_distance, wall_search_passes, strip_break_distance, surface_smoothing, smoothing_limit,
		edge_fade_meters, seam_overlap, seam_fade_width, seam_lift,
		chunk_size, skirt_depth, visibility_range, grass_texture_id,
		cliff_texture_id, match_terrain_shading, fold_triplanar, seam_depth_offset,
		rock_start_angle, rock_blend_angle, terrain_auto_shader, terrain_auto_slope,
		rock_by_angle, rock_angle_start, rock_angle_full, rock_height_reduction, collision_enabled,
		far_spike_fix, far_spike_push, far_spike_reach, mesh_lod, mesh_lod_merge_angle, mesh_lod_bias,
		seam_fade_far_distance, clean_rock_edge]

func _ready() -> void:
	_observed_parameters = _preview_parameters()
	if baked_scene == null and not Engine.is_editor_hint():
		_recover_bake()
	if baked_scene != null:
		_load_baked()
		_check_stale_bake.call_deferred()
	elif Engine.is_editor_hint() and rebuild_on_ready:
		_rebuild_when_ready.call_deferred()
	elif not Engine.is_editor_hint():
		push_error("CliffFolds: falta el bake. Abre la escena y pulsa Hornear y guardar B.")
	if not Engine.is_editor_hint():
		set_process(false)
		# A scene saved before its last bake with the override (or an older one) still gets it in game.
		if (rock_by_angle or far_spike_fix) and is_instance_valid(terrain) and terrain.material != null \
				and not _override_up_to_date(terrain.material):
			_apply_terrain_override(terrain.material)
		# Terrain3D texture settings and the live controls changed after the bake still reach the mesh.
		_update_texture_params()
		_update_rock_angles()

## The scene was saved without its bake reference (bake after the last Ctrl+S): use the file at Bake Path
## if the terrain was saved with that bake's holes, so the walls do not vanish in game.
func _recover_bake() -> void:
	if not ResourceLoader.exists(bake_path) or not is_instance_valid(terrain) or terrain.data == null:
		return
	var candidate := load(bake_path) as PackedScene
	if candidate == null:
		return
	var probe := candidate.instantiate()
	var holes: PackedInt32Array = probe.get_meta("owned_holes", PackedInt32Array())
	probe.free()
	var checked := 0
	var matching := 0
	for i in range(0, holes.size(), maxi(2, holes.size() / 64 * 2)):
		checked += 1
		if terrain.data.get_control_hole(Vector3(holes[i], 0.0, holes[i + 1]) * terrain.vertex_spacing):
			matching += 1
	if checked == 0 or matching * 10 < checked * 9:
		return
	baked_scene = candidate
	push_warning("CliffFolds: la escena no referencia el bake; se usa %s. Abre la escena y guardala con Ctrl+S." % bake_path)

## The bake stores terrain heights under its footprint. If the saved sculpture no longer matches, the mesh and
## holes describe another terrain: rebuild in game (Rebuild Stale Bake) or warn.
func _check_stale_bake() -> void:
	for i in 10:
		if is_instance_valid(terrain) and terrain.data != null:
			break
		await get_tree().process_frame
	_bake_stale = _uncovered_holes > 0 or _stale_bake_samples() > 0
	if not _bake_stale:
		return
	update_configuration_warnings()
	if Engine.is_editor_hint():
		push_warning("CliffFolds: el terreno cambio desde el ultimo bake. Pulsa Hornear y guardar B y guarda la escena.")
	elif rebuild_stale_bake:
		push_warning("CliffFolds: el terreno cambio desde el ultimo bake; se reconstruyen los cliffs al iniciar. Hornea y guarda la escena para evitarlo.")
		regenerate()
	else:
		push_error("CliffFolds: el terreno cambio desde el ultimo bake; puede haber huecos sin cubrir. Hornea y guarda la escena.")

## Number of baked height samples that differ from the current terrain (0 for bakes without samples).
func _stale_bake_samples() -> int:
	if not is_instance_valid(_generated) or not is_instance_valid(terrain) or terrain.data == null:
		return 0
	var samples: PackedVector3Array = _generated.get_meta("height_samples", PackedVector3Array())
	var changed := 0
	for p in samples:
		if absf(terrain.data.get_pixel(Terrain3DRegion.TYPE_HEIGHT, Vector3(p.x, 0.0, p.z)).r - p.y) > STALE_TOLERANCE:
			changed += 1
	return changed

## Raw heights (valid under holes) on a subsample of the mesh footprint, stored in the bake.
func _height_samples() -> PackedVector3Array:
	var cells: PackedInt32Array = _surface_candidate.footprint_cells()
	var count := cells.size() / 2
	var stride := maxi(1, ceili(float(count) / STALE_SAMPLES))
	var samples := PackedVector3Array()
	for k in range(0, count, stride):
		var position := _world(Vector2i(cells[k * 2], cells[k * 2 + 1]))
		samples.append(Vector3(position.x, terrain.data.get_pixel(Terrain3DRegion.TYPE_HEIGHT, position).r, position.z))
	return samples

func _rebuild_when_ready() -> void:
	# Terrain3D creates its data after entering the tree; wait for it instead of failing.
	for i in 10:
		if is_instance_valid(terrain) and terrain.data != null:
			regenerate()
			return
		await get_tree().process_frame
	push_warning("CliffFoldsGenerator: asigna un Terrain3D con datos para generar cliffs.")

func _process(delta: float) -> void:
	# Terrain3D texture settings (color, scale, files) follow live in the editor, checked a few times per second.
	_texture_check_wait -= delta
	if not _building and _texture_check_wait <= 0.0:
		_texture_check_wait = 0.25
		if _texture_settings().values() != _texture_signature:
			_update_texture_params()
	if _building or not live_preview:
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
			regenerate.call_deferred()

func regenerate() -> void:
	if _building or not is_inside_tree():
		return
	if not is_instance_valid(terrain) or terrain.data == null:
		push_warning("CliffFoldsGenerator: falta el Terrain3D o sus datos.")
		return
	_building = true
	_last_build_ok = false
	var start := Time.get_ticks_msec()
	_observed_parameters = _preview_parameters()
	_noise.seed = pattern_seed
	_noise.frequency = 1.0 / fold_size
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.fractal_octaves = 2
	_read_terrain()
	_build_mask()
	var cells := _cliff_cells()
	if not _prepare_contours():
		_building = false
		return
	_apply_terrain_material()
	_clear_generated()
	var stats := _build_reconstructed_meshes()
	var holes_changed := _set_owned_holes(_wanted_holes)
	if holes_changed:
		_refresh_terrain()
	_heights = PackedFloat32Array()
	_normals = PackedVector3Array()
	_mask = PackedFloat32Array()
	_amplitude = PackedFloat32Array()
	_positions.clear()
	_building = false
	_last_build_ok = true
	if holes_changed:
		_mark_scene_unsaved()
	update_configuration_warnings()
	var mode := "B: %d franjas, paso %.2f m, %d agujeros" % [_surface_candidate.wall_count, mesh_step, _wanted_holes.size() / 2]
	print("Cliff folds: %d celdas, %d chunks, %d vertices, %s, %d ms." % [
		cells.size(), stats.x, stats.y, mode, Time.get_ticks_msec() - start])
	_wanted_holes = PackedInt32Array()

func adopt_holes_under_cover() -> void:
	_adopting = true
	regenerate()
	_adopting = false

func restore_terrain() -> void:
	if not is_instance_valid(terrain) or terrain.data == null:
		return
	_clear_generated()
	baked_scene = null
	_last_build_ok = false
	if _set_owned_holes(PackedInt32Array()):
		_refresh_terrain()
	_mark_scene_unsaved()
	print("Cliff folds: terreno restaurado; agujeros propios cerrados. El bake queda desconectado hasta volver a hornear.")

func _prepare_contours() -> bool:
	var builder = preload("res://scripts/terrain/cliff_contour_builder.gd").new()
	builder.step = mesh_step
	builder.fade = edge_fade_meters
	builder.overlap = seam_overlap
	builder.seam_fade = seam_fade_width
	builder.smoothing = surface_smoothing
	builder.limit = smoothing_limit
	builder.reach = profile_search_distance
	builder.break_distance = strip_break_distance
	builder.passes = wall_search_passes
	builder.minimum_slope = minimum_slope
	builder.reentry_slope = minimum_slope + slope_transition
	if not builder.build(_heights, _normals, _mask, _w, _d, _spacing, _origin):
		push_error("Cliff B: " + builder.error + " Se conserva la cubierta anterior.")
		return false
	var owned := {}
	for i in range(0, owned_holes.size(), 2):
		owned[Vector2i(owned_holes[i], owned_holes[i + 1])] = true
	# Unregistered holes under the mesh or its fade would show the void: refuse unless adopting test leftovers.
	var foreign := PackedInt32Array()
	var footprint: PackedInt32Array = builder.footprint_cells()
	for i in range(0, footprint.size(), 2):
		var cell := Vector2i(footprint[i], footprint[i + 1])
		if not owned.has(cell) and terrain.data.get_control_hole(_world(cell)):
			foreign.append_array(PackedInt32Array([cell.x, cell.y]))
	if not foreign.is_empty():
		if not _adopting:
			push_error(("Cliff B: la cubierta cruza %d agujeros no registrados (pintados a mano o restos de pruebas). " +
				"Si son restos, pulsa Adoptar agujeros bajo la cubierta; si son tuyos, separa esa zona. Se conserva la cubierta anterior.") % [foreign.size() / 2])
			return false
		owned_holes.append_array(foreign)
		print("Cliff B: %d agujeros no registrados bajo la cubierta pasan a ser propios." % [foreign.size() / 2])
	_wanted_holes = builder.hole_cells()
	if builder.bare_cells * 100 > builder.wall_cells * 3:
		push_warning("Cliff B: %d%% de la pared detectada queda como Terrain3D esculpido sin pliegues (uniones de terrazas o columnas partidas). Prueba mas Wall Search Passes o Strip Break Distance." % [builder.bare_cells * 100 / builder.wall_cells])
	if builder.reach_hits > 0:
		push_warning("Cliff B: %d columnas llegaron a Profile Search Distance antes de salir de la pendiente; su zona de cliff termina ahi." % builder.reach_hits)
	_surface_candidate = builder
	return true

func copy_reference_settings() -> void:
	var reference := load("res://scenes/cliff_playground.tscn") as PackedScene
	if reference == null:
		return
	var node := reference.instantiate()
	for property in ["pattern_seed", "fold_size", "indentation", "protrusion", "fold_sharpness",
			"vertical_stretch", "minimum_slope", "slope_transition", "mesh_step", "rock_start_angle", "rock_blend_angle"]:
		set(property, node.get(property))
	edge_fade_meters = node.get("edge_fade")
	node.free()
	notify_property_list_changed()
	update_configuration_warnings()

func bake() -> void:
	regenerate()
	if not _last_build_ok:
		return
	if not bake_path.begins_with("res://") or bake_path.get_extension() != "scn":
		push_error("Cliff B: Bake Path debe ser un archivo res:// terminado en .scn.")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(bake_path.get_base_dir()))
	_set_bake_owners(_generated, _generated)
	_generated.remove_meta("preview_only")
	_generated.set_meta("owned_holes", owned_holes)
	_generated.set_meta("author_parameters", _preview_parameters())
	_generated.set_meta("height_samples", _height_samples())
	_bake_stale = false
	_uncovered_holes = 0
	var packed := PackedScene.new()
	var result := packed.pack(_generated)
	if result == OK:
		result = ResourceSaver.save(packed, bake_path, ResourceSaver.FLAG_COMPRESS)
	if result != OK:
		push_error("Cliff B: no se pudo guardar el bake: " + error_string(result))
		return
	baked_scene = ResourceLoader.load(bake_path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	# The terrain and baked mesh must describe the same holes when exported.
	terrain.data.save_directory(terrain.data_directory)
	_mark_scene_unsaved()
	update_configuration_warnings()
	print("Cliff B guardado: ", bake_path, ". Guarda la escena con Ctrl+S.")

## Shows the unsaved asterisk: the bake reference and owned holes only persist with Ctrl+S.
func _mark_scene_unsaved() -> void:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return
	var editor := Engine.get_singleton("EditorInterface")
	if editor != null:
		editor.mark_scene_as_unsaved()

func _set_bake_owners(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		_set_bake_owners(child, root)

func _load_baked() -> void:
	var old := get_node_or_null("GeneratedCliffs")
	if old != null:
		old.free()
	_generated = baked_scene.instantiate()
	_generated.name = "GeneratedCliffs"
	add_child(_generated)
	_generated.top_level = true
	_generated.global_transform = Transform3D.IDENTITY
	# Union: holes opened by a regeneration after the last bake must stay registered as owned.
	var known := {}
	for i in range(0, owned_holes.size(), 2):
		known[Vector2i(owned_holes[i], owned_holes[i + 1])] = true
	var baked: PackedInt32Array = _generated.get_meta("owned_holes", PackedInt32Array())
	var in_bake := {}
	for i in range(0, baked.size(), 2):
		in_bake[Vector2i(baked[i], baked[i + 1])] = true
		if not known.has(Vector2i(baked[i], baked[i + 1])):
			owned_holes.append_array(PackedInt32Array([baked[i], baked[i + 1]]))
	# Holes opened by a regeneration after the bake have no baked mesh over them: the game would show the void.
	_uncovered_holes = 0
	if is_instance_valid(terrain) and terrain.data != null:
		for cell: Vector2i in known:
			if not in_bake.has(cell) and terrain.data.get_control_hole(Vector3(cell.x, 0.0, cell.y) * terrain.vertex_spacing):
				_uncovered_holes += 1

func _get_configuration_warnings() -> PackedStringArray:
	if baked_scene == null:
		return PackedStringArray(["Falta el bake. Pulsa Hornear y guardar B antes de ejecutar/exportar y guarda la escena."])
	if is_instance_valid(_generated) and _generated.get_meta("preview_only", false):
		return PackedStringArray(["La vista previa no esta horneada. Pulsa Hornear y guardar B y guarda la escena."])
	if _bake_stale:
		return PackedStringArray(["El terreno cambio desde el bake: el juego veria huecos o la malla vieja. Pulsa Hornear y guardar B y guarda la escena."])
	if is_instance_valid(_generated) and _generated.has_meta("author_parameters"):
		if _generated.get_meta("author_parameters") != _preview_parameters():
			return PackedStringArray(["Los ajustes cambiaron desde el bake. Vuelve a hornear y guarda la escena."])
	return PackedStringArray()

func _clear_generated() -> void:
	if not is_instance_valid(_generated):
		_generated = get_node_or_null("GeneratedCliffs")
	if is_instance_valid(_generated):
		_generated.free()
	_generated = Node3D.new()
	_generated.name = "GeneratedCliffs"
	_generated.set_meta("preview_only", true)
	_generated.top_level = true
	add_child(_generated)
	_generated.global_transform = Transform3D.IDENTITY

func _apply_terrain_material() -> void:
	var material := terrain.material
	if material == null:
		return
	material.auto_shader = terrain_auto_shader
	# Terrain3D convention: overlay covers flat ground and base covers slopes.
	material.set_shader_param("auto_base_texture", cliff_texture_id)
	material.set_shader_param("auto_overlay_texture", grass_texture_id)
	material.set_shader_param("auto_slope", terrain_auto_slope)
	_apply_terrain_override(material)

const OVERRIDE_MARK := "// CliffFolds: terrain override"
const ROCK_MARK := "// CliffFolds: rock by angle"
const VERTEX_ANCHOR := "VERTEX = (VIEW_MATRIX * vec4(v_vertex, 1.0)).xyz;"
# Far LODs: a coarse vertex near a hole is pushed back along the view ray (same pixel, farther depth), so the
# coarse triangles Terrain3D stretches across a wall lose against the cliff mesh instead of showing as spikes.
# The step includes the morph toward the next ring: the finest ring also morphs (about 25-32 m with mesh_size 64).
const FAR_SPIKE_CODE := """
	// CliffFolds: far spike fix
	float cliff_far_offset = 0.0;
	float cliff_far_step = scale * (1.0 + vertex_lerp);
	if (cliff_far_step > _vertex_spacing + 1e-6 && !(CAMERA_VISIBLE_LAYERS == _mouse_layer) && PROJECTION_MATRIX[3][3] == 0.0) {
		// A hole, or a rise steeper than 60 degrees (a vertical wall's hole band can fall between two samples).
		for (int k = 0; k < 24; k++) {
			float angle = float(k) * 0.785398;
			float radius = cliff_far_step * cliff_far_reach * float(k / 8 + 1) / 3.0;
			ivec3 probe = get_index_coord(start_pos + vec2(cos(angle), sin(angle)) * radius * _vertex_density, 1);
			if (probe.z >= 0 && (bool(floatBitsToUint(texelFetch(_control_maps, probe, 0)).r >> 2u & 0x1u)
					|| abs(texelFetch(_height_maps, probe, 0).r - v_vertex.y) > radius * 1.732)) {
				cliff_far_offset = cliff_far_push * cliff_far_step;
				break;
			}
		}
	}
	// Only the rasterized depth moves: VERTEX (lighting, shadows) stays on the real surface.
	POSITION = PROJECTION_MATRIX * vec4(VERTEX * (1.0 + cliff_far_offset / max(length(VERTEX), 1.0)), 1.0);
"""

func _is_our_override(material: Terrain3DMaterial) -> bool:
	return material != null and material.shader_override_enabled and material.shader_override != null \
		and (material.shader_override.code.contains(OVERRIDE_MARK) or material.shader_override.code.contains(ROCK_MARK))

func _override_up_to_date(material: Terrain3DMaterial) -> bool:
	if not _is_our_override(material):
		return false
	var code: String = material.shader_override.code
	return (not rock_by_angle or code.contains(ROCK_MARK)) and (not far_spike_fix or code.contains(FAR_SPIKE_CODE))

## Installs (or removes) CliffFolds' Terrain3D shader override, built from Terrain3D's own generated shader:
## the angle rule replaces the auto blend line (Rock By Angle) and the far spike fix is added to vertex()
## (Far Spike Fix). A user override without our mark is patched as a copy.
func _apply_terrain_override(material: Terrain3DMaterial) -> void:
	var ours := _is_our_override(material)
	if not rock_by_angle and not far_spike_fix:
		if ours:
			material.shader_override_enabled = false
			material.shader_override = null
		return
	var code := ""
	if material.shader_override_enabled and material.shader_override != null and not ours:
		code = material.shader_override.code
	else:
		# Enabling the override with no shader makes Terrain3D fill it with its clean generated code. The
		# compiled code (shader RID) is not usable: in the editor it already carries the brush decal and debug
		# views, which Terrain3D injects again into any override ("Redefinition of _editor_brush_texture").
		material.shader_override_enabled = false
		material.shader_override = null
		material.shader_override_enabled = true
		code = material.shader_override.code if material.shader_override != null else ""
		material.shader_override_enabled = false
		material.shader_override = null
	if code.contains("_editor_") or not code.contains("uniform float _mesh_size"):
		push_warning("CliffFolds: no reconozco el shader de Terrain3D; Rock By Angle y Far Spike Fix solo se aplican a la malla.")
		return
	var uniforms := OVERRIDE_MARK + "\n"
	var patched := false
	if rock_by_angle:
		var blend := RegEx.create_from_string("float\\s+auto_blend\\s*=\\s*clamp\\([\\s\\S]*?,\\s*0\\.0\\s*,\\s*1\\.0\\s*\\)\\s*;")
		var found := blend.search(code)
		if found == null or not code.contains("w_normal") or not code.contains("v_vertex"):
			push_warning("CliffFolds: el shader de Terrain3D no tiene Auto Shader; Rock By Angle solo se aplica a la malla.")
		else:
			code = code.substr(0, found.get_start()) + ROCK_MARK + "\n\tfloat auto_blend = clamp(1.0 - smoothstep(rock_angle_start, rock_angle_full, " \
				+ "degrees(acos(clamp(w_normal.y, -1.0, 1.0)))) - rock_height_reduction * 0.01 * v_vertex.y, 0.0, 1.0);" \
				+ code.substr(found.get_end())
			uniforms += "uniform float rock_angle_start = 58.0;\nuniform float rock_angle_full = 66.0;\nuniform float rock_height_reduction = 0.0;\n"
			patched = true
	if far_spike_fix:
		if not code.contains(VERTEX_ANCHOR) or not code.contains("start_pos") or not code.contains("float scale"):
			push_warning("CliffFolds: no reconozco el vertex() de Terrain3D; Far Spike Fix no se aplica.")
		else:
			code = code.replace(VERTEX_ANCHOR, VERTEX_ANCHOR + FAR_SPIKE_CODE)
			uniforms += "uniform float cliff_far_push = 3.0;\nuniform float cliff_far_reach = 2.5;\n"
			patched = true
	if not patched:
		if ours:
			material.shader_override_enabled = false
			material.shader_override = null
		return
	code = code.replace("uniform float _mesh_size", uniforms + "uniform float _mesh_size")
	var shader := Shader.new()
	shader.code = code
	material.shader_override = shader
	material.shader_override_enabled = true
	_update_rock_angles()

## Pushes the rock angles, far spike fix and LOD bias to Terrain3D and the generated chunks without rebuilding.
func _update_rock_angles() -> void:
	if not is_inside_tree():
		return
	var full := maxf(rock_angle_full, rock_angle_start + 0.5)
	if is_instance_valid(terrain) and _is_our_override(terrain.material):
		var code: String = terrain.material.shader_override.code
		if code.contains(ROCK_MARK):
			terrain.material.set_shader_param("rock_angle_start", rock_angle_start)
			terrain.material.set_shader_param("rock_angle_full", full)
			terrain.material.set_shader_param("rock_height_reduction", rock_height_reduction)
		if code.contains("cliff_far_push"):
			terrain.material.set_shader_param("cliff_far_push", far_spike_push)
			terrain.material.set_shader_param("cliff_far_reach", far_spike_reach)
	if not is_instance_valid(_generated):
		return
	for chunk in _generated.get_children():
		if chunk is GeometryInstance3D:
			chunk.lod_bias = mesh_lod_bias
		if chunk is MeshInstance3D and chunk.mesh != null:
			for surface in chunk.mesh.get_surface_count():
				var material := chunk.mesh.surface_get_material(surface) as ShaderMaterial
				if material != null:
					material.set_shader_parameter("rock_by_angle", rock_by_angle)
					material.set_shader_parameter("clean_rock_edge", clean_rock_edge)
					material.set_shader_parameter("fade_far_distance", seam_fade_far_distance)
					material.set_shader_parameter("rock_angle_start", rock_angle_start)
					material.set_shader_parameter("rock_angle_full", full)
					material.set_shader_parameter("rock_height_reduction", rock_height_reduction)

func _read_terrain() -> void:
	_spacing = terrain.vertex_spacing
	var size: int = terrain.region_size
	var locations: Array = terrain.data.get_region_locations()
	_w = 0
	_d = 0
	if locations.is_empty():
		return
	var low: Vector2i = locations[0]
	var high: Vector2i = locations[0]
	for location: Vector2i in locations:
		low = low.min(location)
		high = high.max(location)
	_origin = low * size
	_w = (high.x - low.x + 1) * size
	_d = (high.y - low.y + 1) * size
	_heights.resize(_w * _d)
	_heights.fill(NAN)
	for location: Vector2i in locations:
		var region: Terrain3DRegion = terrain.data.get_region(location)
		if region == null or region.is_deleted():
			continue
		var image: Image = region.get_height_map()
		if image.get_format() != Image.FORMAT_RF:
			image = image.duplicate()
			image.convert(Image.FORMAT_RF)
		# Raw heights stay valid under holes, so regeneration never reads its own holes as gaps.
		var values := image.get_data().to_float32_array()
		var base := (location - low) * size
		for z in size:
			var row := (base.y + z) * _w + base.x
			for x in size:
				_heights[row + x] = values[z * size + x]

func _build_mask() -> void:
	_normals.resize(_w * _d)
	_normals.fill(Vector3.UP)
	_mask.resize(_w * _d)
	_mask.fill(0.0)
	var r := normal_radius
	for z in range(r, _d - r):
		for x in range(r, _w - r):
			var i := z * _w + x
			var gx := (_heights[i + r] - _heights[i - r]) / (2.0 * r * _spacing)
			var gz := (_heights[i + r * _w] - _heights[i - r * _w]) / (2.0 * r * _spacing)
			if is_nan(gx) or is_nan(gz) or is_nan(_heights[i]):
				continue
			_normals[i] = Vector3(-gx, 1.0, -gz).normalized()
			var angle := rad_to_deg(atan(sqrt(gx * gx + gz * gz)))
			if angle >= minimum_slope:
				_mask[i] = maxf(EPSILON * 2.0, smoothstep(minimum_slope, minimum_slope + slope_transition, angle))
func _cliff_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for z in _d:
		for x in _w:
			if _mask[z * _w + x] > EPSILON:
				cells.append(Vector2i(x, z))
	return cells
func _set_owned_holes(wanted: PackedInt32Array) -> bool:
	var keep := {}
	for j in range(0, wanted.size(), 2):
		keep[Vector2i(wanted[j], wanted[j + 1])] = true
	var changed := false
	for j in range(0, owned_holes.size(), 2):
		var cell := Vector2i(owned_holes[j], owned_holes[j + 1])
		if not keep.has(cell) and terrain.data.get_control_hole(_world(cell)):
			terrain.data.set_control_hole(_world(cell), false)
			changed = true
	for cell: Vector2i in keep:
		if not terrain.data.get_control_hole(_world(cell)):
			terrain.data.set_control_hole(_world(cell), true)
			changed = true
	owned_holes = wanted
	return changed

func _refresh_terrain() -> void:
	terrain.data.update_maps(Terrain3DRegion.TYPE_CONTROL, true, false)
	if terrain.get_collision() != null:
		terrain.get_collision().build()

func _world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * _spacing, 0.0, cell.y * _spacing)

func _build_reconstructed_meshes() -> Vector2i:
	var surface = _surface_candidate
	for i in surface.vertices.size():
		var p: Vector3 = surface.vertices[i]
		var normal: Vector3 = surface.fold_normals[i]
		var angle := rad_to_deg(acos(clampf(normal.y, -1.0, 1.0)))
		var amount := smoothstep(minimum_slope, minimum_slope + slope_transition, angle)
		amount *= surface.relief[i]
		var n := clampf(_noise.get_noise_3d(p.x, p.y / vertical_stretch, p.z) * 1.8, -1.0, 1.0)
		n = signf(n) * pow(absf(n), fold_sharpness)
		surface.vertices[i] = p + normal * n * (protrusion if n >= 0.0 else indentation) * amount + Vector3.UP * seam_lift
	surface.compute_normals()
	# Where the mesh rests on the sculpture, shade with the terrain's own normal so the join disappears.
	for i in surface.normals.size():
		var weight: float = surface.relief[i]
		if weight < 1.0:
			surface.normals[i] = surface.terrain_normals[i].lerp(surface.normals[i], weight).normalized()
	# Calculate shared normals before splitting chunks: no lighting seams at chunk borders.
	var chunks := {}
	var edges := {}
	var skirts := skirt_depth > 0.0 and seam_fade_width <= 0.0
	for t in range(0, surface.indices.size(), 3):
		var a: int = surface.indices[t]
		var b: int = surface.indices[t + 1]
		var c: int = surface.indices[t + 2]
		var center: Vector3 = (surface.vertices[a] + surface.vertices[b] + surface.vertices[c]) / 3.0
		var key := Vector2i(floori(center.x / chunk_size), floori(center.z / chunk_size))
		if not chunks.has(key):
			chunks[key] = [PackedInt32Array(), PackedInt32Array()]
		var faded: bool = minf(surface.alpha[a], minf(surface.alpha[b], surface.alpha[c])) < 0.999
		chunks[key][1 if faded else 0].append_array(PackedInt32Array([a, b, c]))
		if skirts:
			for pair in [Vector2i(a, b), Vector2i(b, c), Vector2i(c, a)]:
				var edge := Vector2i(mini(pair.x, pair.y), maxi(pair.x, pair.y))
				edges[edge] = edges.get(edge, 0) + 1
	var materials := [_surface_material(false), _surface_material(true)]
	var count := 0
	for key: Vector2i in chunks:
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var slope_uv := PackedVector2Array()
		var mask_uv := PackedVector2Array()
		var parts := [PackedInt32Array(), PackedInt32Array()]
		var skirt := PackedInt32Array()
		var local_ids := {}
		for part in 2:
			var triangles: PackedInt32Array = chunks[key][part]
			var local := PackedInt32Array()
			for id in triangles:
				if not local_ids.has(id):
					local_ids[id] = vertices.size()
					vertices.append(surface.vertices[id])
					normals.append(surface.normals[id])
					var slope: Vector3 = surface.terrain_normals[id]
					slope_uv.append(Vector2(slope.x, slope.z))
					mask_uv.append(Vector2(surface.relief[id], surface.alpha[id]))
				local.append(local_ids[id])
			parts[part] = local
		if skirts:
			var triangles: PackedInt32Array = chunks[key][0]
			for t in range(0, triangles.size(), 3):
				for side in 3:
					var a: int = triangles[t + side]
					var b: int = triangles[t + (side + 1) % 3]
					if edges[Vector2i(mini(a, b), maxi(a, b))] != 1:
						continue
					var ia: int = local_ids[a]
					var ib: int = local_ids[b]
					var bottom := vertices.size()
					for id in [ia, ib]:
						vertices.append(vertices[id] + Vector3.DOWN * skirt_depth)
						normals.append(normals[id])
						slope_uv.append(slope_uv[id])
						mask_uv.append(mask_uv[id])
					skirt.append_array(PackedInt32Array([ia, ib, bottom, ib, bottom + 1, bottom,
						ia, bottom, ib, ib, bottom, bottom + 1]))
		count += vertices.size()
		_add_chunk(key, [vertices, normals, slope_uv, mask_uv], parts[0], parts[1], skirt, materials)
	return Vector2i(chunks.size(), count)

func _add_chunk(chunk_key: Vector2i, data: Array, opaque: PackedInt32Array, faded: PackedInt32Array,
		skirt: PackedInt32Array, materials: Array) -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data[0]
	arrays[Mesh.ARRAY_NORMAL] = data[1]
	# UV: sculpted normal (x, z) for texturing. UV2: fold weight and seam opacity.
	arrays[Mesh.ARRAY_TEX_UV] = data[2]
	arrays[Mesh.ARRAY_TEX_UV2] = data[3]
	var mesh := ArrayMesh.new()
	var importer := ImporterMesh.new()
	var solid := opaque.duplicate()
	solid.append_array(skirt)
	for part in [[solid, materials[0]], [faded, materials[1]]]:
		var part_indices: PackedInt32Array = part[0]
		if part_indices.is_empty():
			continue
		var surface := arrays.duplicate()
		surface[Mesh.ARRAY_INDEX] = part_indices
		if mesh_lod:
			importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, surface, [], {}, part[1])
		else:
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface)
			mesh.surface_set_material(mesh.get_surface_count() - 1, part[1])
	if mesh_lod and importer.get_surface_count() > 0:
		importer.generate_lods(mesh_lod_merge_angle, 60.0, [])
		mesh = importer.get_mesh()
	var visual := MeshInstance3D.new()
	visual.name = "CliffChunk_%d_%d" % [chunk_key.x, chunk_key.y]
	visual.mesh = mesh
	visual.lod_bias = mesh_lod_bias
	# Terrain holes persist: culling their replacement by distance would expose the void.
	visual.visibility_range_end = 0.0
	_generated.add_child(visual)
	if not collision_enabled or opaque.is_empty():
		return
	var vertices: PackedVector3Array = data[0]
	var faces := PackedVector3Array()
	faces.resize(opaque.size())
	for i in opaque.size():
		faces[i] = vertices[opaque[i]]
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var body := StaticBody3D.new()
	body.name = visual.name + "Collision"
	body.collision_layer = 1 | 4
	body.add_to_group("climbable", true)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	_generated.add_child(body)

func _terrain_parameter(parameter: String, fallback: Variant) -> Variant:
	var value = terrain.material.get_shader_param(parameter) if terrain.material != null else null
	return fallback if value == null else value

func _surface_material(faded: bool) -> Material:
	var assets := terrain.assets
	var grass: Terrain3DTextureAsset = assets.get_texture(grass_texture_id) if assets != null else null
	var cliff: Terrain3DTextureAsset = assets.get_texture(cliff_texture_id) if assets != null else null
	if grass == null or cliff == null:
		push_warning("CliffFoldsGenerator: no encuentro las texturas ID %d/%d; uso color plano." % [grass_texture_id, cliff_texture_id])
		var flat := StandardMaterial3D.new()
		flat.albedo_color = Color(0.48, 0.39, 0.29)
		flat.roughness = 1.0
		return flat
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/cliff_slope_fade.gdshader") if faded else preload("res://shaders/cliff_slope_surface.gdshader")
	_apply_texture_params(material, _texture_settings())
	material.set_shader_parameter("slope_start", rock_start_angle)
	material.set_shader_parameter("slope_width", rock_blend_angle)
	material.set_shader_parameter("match_terrain", match_terrain_shading)
	material.set_shader_parameter("auto_slope", terrain_auto_slope)
	material.set_shader_parameter("rock_by_angle", rock_by_angle)
	material.set_shader_parameter("rock_angle_start", rock_angle_start)
	material.set_shader_parameter("rock_angle_full", maxf(rock_angle_full, rock_angle_start + 0.5))
	material.set_shader_parameter("rock_height_reduction", rock_height_reduction)
	material.set_shader_parameter("vertex_spacing", _spacing)
	material.set_shader_parameter("fold_triplanar", fold_triplanar)
	material.set_shader_parameter("clean_rock_edge", clean_rock_edge)
	material.set_shader_parameter("fade_far_distance", seam_fade_far_distance)
	material.set_shader_parameter("depth_offset", seam_depth_offset)
	return material

## Terrain3D settings the mesh copies: both texture assets (files, color, UV scale) and the auto shader blend
## parameters of the Terrain3D material. Empty if the textures are missing.
func _texture_settings() -> Dictionary:
	if not is_instance_valid(terrain) or terrain.assets == null:
		return {}
	var grass: Terrain3DTextureAsset = terrain.assets.get_texture(grass_texture_id)
	var cliff: Terrain3DTextureAsset = terrain.assets.get_texture(cliff_texture_id)
	if grass == null or cliff == null:
		return {}
	return {
		"grass_texture": grass.albedo_texture, "cliff_texture": cliff.albedo_texture,
		"grass_tint": grass.albedo_color, "cliff_tint": cliff.albedo_color,
		"grass_scale": grass.uv_scale, "cliff_scale": cliff.uv_scale,
		"auto_height_reduction": _terrain_parameter("auto_height_reduction", 0.1),
		"blend_sharpness": _terrain_parameter("blend_sharpness", 0.5),
		"enable_projection": _terrain_parameter("enable_projection", true),
		"projection_threshold": _terrain_parameter("projection_threshold", 0.8),
	}

func _apply_texture_params(material: ShaderMaterial, settings: Dictionary) -> void:
	for parameter in settings:
		material.set_shader_parameter(parameter, settings[parameter])

## Copies the current Terrain3D texture settings to every chunk material (editor: when they change; game: on load,
## so a color or scale changed after the bake still matches the terrain).
func _update_texture_params() -> void:
	var settings := _texture_settings()
	_texture_signature = settings.values()
	if settings.is_empty() or not is_instance_valid(_generated):
		return
	for chunk in _generated.get_children():
		if chunk is MeshInstance3D and chunk.mesh != null:
			for surface in chunk.mesh.get_surface_count():
				var material := chunk.mesh.surface_get_material(surface) as ShaderMaterial
				if material != null:
					_apply_texture_params(material, settings)
