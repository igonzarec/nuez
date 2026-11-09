@tool
class_name CliffFoldsGenerator
extends Node3D
## Convierte las paredes empinadas esculpidas en Terrain3D en una malla plegada (estilo B del laboratorio).
## La malla sigue el perfil esculpido (hombros incluidos); los pliegues solo aparecen en la zona de cliff.
## Lee las alturas sin modificarlas, abre agujeros de Terrain3D solo bajo los pliegues y crea colision por chunk.
## Flujo: esculpir -> Regenerar cambios (solo los cliffs cuyo terreno cambio). Para re-esculpir una pared: seleccionala
## (clic con el plugin "Cliffs" o un CliffZone), Restaurar seleccion/zonas, esculpir, Regenerar cambios.
## Un "cliff" es un grupo de paredes conectadas (o a menos de Cliff Link Distance); cada uno se regenera por separado.
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
## Lee el terreno actual, detecta paredes y reconstruye TODOS los cliffs (malla, colision y agujeros) desde cero.
## Usalo al cambiar ajustes de pliegues o malla. Coste: reconstruccion completa y sincrona (segundos en mapas grandes).
@export_tool_button("Regenerar cliffs") var rebuild_button: Callable = regenerate
## Reconstruye solo los cliffs de las regiones de Terrain3D cuyo relieve cambio desde la ultima regeneracion
## (esculpir, tallar un rio) y crea los cliffs nuevos que aparezcan ahi. Coste: proporcional a lo cambiado.
@export_tool_button("Regenerar cambios") var changes_button: Callable = regenerate_changes
## Genera B y guarda malla/material/colision en Bake Path y los datos de Terrain3D. Guarda la escena con Ctrl+S despues para conservar la referencia.
## Coste de generacion y escritura solo en editor. Runtime carga el recurso sin reconstruir. No ejecuta optimizacion de colision.
@export_tool_button("Hornear y guardar B") var bake_button: Callable = bake
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

@export_group("Regeneracion por cliff")
## Reconstruye los cliffs seleccionados (clic con el plugin "Cliffs": boton Seleccionar cliff en la barra 3D).
@export_tool_button("Regenerar seleccion") var selection_rebuild_button: Callable = regenerate_selection
## Quita la malla y cierra los agujeros solo de los cliffs seleccionados: el terreno esculpido queda a la vista para
## re-esculpirlo. Despues, Regenerar cambios (o Regenerar seleccion) los vuelve a crear.
@export_tool_button("Restaurar seleccion") var selection_restore_button: Callable = restore_selection
## Vacia la seleccion.
@export_tool_button("Limpiar seleccion") var selection_clear_button: Callable = clear_selection
## Quita los cliffs seleccionados y los EXCLUYE: ninguna regeneracion (Regenerar cliffs, cambios, hornear, ni la
## reconstruccion al iniciar el juego) vuelve a poner pliegues ahi; la pared queda como Terrain3D esculpido. Las zonas
## excluidas se ven en rojo en el editor.
@export_tool_button("Excluir seleccion") var selection_exclude_button: Callable = exclude_selection
## Quita la exclusion de la zona roja donde hiciste clic (o de los cliffs seleccionados) y regenera ahi.
@export_tool_button("Incluir seleccion") var selection_include_button: Callable = include_selection
## Quita todas las exclusiones y regenera esas zonas.
@export_tool_button("Quitar todas las exclusiones") var exclusions_clear_button: Callable = clear_exclusions
## Reconstruye los cliffs que tocan algun CliffZone activo (nodos hijo de este; se mueven y escalan con el gizmo).
## Una zona elige cliffs enteros: nunca regenera medio cliff.
@export_tool_button("Regenerar zonas") var zones_rebuild_button: Callable = regenerate_zones
## Quita la malla y cierra los agujeros de los cliffs que tocan algun CliffZone activo.
@export_tool_button("Restaurar zonas") var zones_restore_button: Callable = restore_zones
## Metros entre dos paredes por debajo de los cuales forman un mismo cliff (se regeneran juntas). Debe superar lo que
## una franja se extiende fuera de su pared (collar + fundido + Edge Fade, unos 5 m por lado) o podrian pisarse.
## Mayor = cliffs mas grandes y menos independientes; menor = mas pequenos (riesgo de solapes). Regenerar cliffs.
@export_range(4.0, 80.0, 0.5, "suffix:m") var cliff_link_distance := 12.0
## Distancia en metros alrededor del clic dentro de la cual se busca un cliff si el clic no cae justo sobre uno.
## Mayor = mas facil acertar desde lejos; menor = mas preciso entre cliffs cercanos. En vivo.
@export_range(0.0, 30.0, 0.5, "suffix:m") var pick_radius := 6.0
## Resalta en el editor los cliffs seleccionados y los que tocan las zonas. No se hornea. En vivo.
@export var highlight_enabled := true:
	set(value):
		highlight_enabled = value
		_update_highlight()
		_draw_exclusions()
## Color del resaltado de los cliffs seleccionados con clic. La transparencia (alfa) regula la intensidad. En vivo.
@export var selection_color := Color(1.0, 0.75, 0.1, 0.55):
	set(value):
		selection_color = value
		_update_highlight()
## Color del resaltado de los cliffs que tocan un CliffZone activo. En vivo.
@export var zone_color := Color(0.2, 0.75, 1.0, 0.45):
	set(value):
		zone_color = value
		_update_highlight()
## Color de las zonas excluidas (cuadros sobre el terreno, solo en el editor). En vivo.
@export var excluded_color := Color(1.0, 0.25, 0.2, 0.9):
	set(value):
		excluded_color = value
		_draw_exclusions()

@export_group("Deteccion de paredes")
## Inclinacion en grados (0 = plano, 90 = vertical) a partir de la cual una zona se convierte en cliff plegado. Mayor: solo paredes casi verticales.
## Cada columna termina donde la escultura baja de este angulo: el hombro mas suave queda como superficie esculpida sin pliegues.
## Con Terrain Auto Slope = 1, 60 coincide con la roca completa del Auto Shader. Coste: bajarlo amplia el area con vertices, colision y agujeros.
## Con Rock Follows Cliffs, la roca de Terrain3D y la malla siguen este angulo en vivo.
@export_range(30.0, 89.0, 1.0, "suffix:degrees") var minimum_slope := 60.0:
	set(value):
		minimum_slope = value
		_update_rock_angles()
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
## Donde la malla descansa sobre la escultura (collar, banda de fundido, hombros) usa las texturas que pintes a mano en Terrain3D
## (nieve, tierra, caminos...) en lugar de la regla automatica, asi la union no deja un anillo de pasto. Se lee en vivo del propio
## Terrain3D: pintar se ve al momento, sin regenerar ni hornear. Las celdas en automatico siguen la regla de siempre.
## No copia la rotacion ni el antirrepeticion (detile) de cada celda pintada. Coste: hasta cuatro lecturas del mapa de control y
## ocho de textura por pixel, solo en la malla y solo fuera de los pliegues.
@export var painted_textures := true:
	set(value):
		painted_textures = value
		_update_texture_params()
## Solo con Painted Textures. Intensidad de pliegue (0-1) a partir de la cual la textura pintada cede a la regla de roca. 0 = solo
## collar y banda planos; mayor deja que lo pintado suba por los pliegues (una zona nevada pintaria tambien la pared). En vivo.
@export_range(0.0, 1.0, 0.01) var painted_fold_limit := 0.15:
	set(value):
		painted_fold_limit = value
		_update_texture_params()
## Solo con Painted Textures. Las caras de los pliegues que miran hacia arriba (repisas, salientes, fondos de hendidura) toman
## tambien la textura pintada en esa zona: pinta nieve sobre el cliff (pared incluida) y se acumula en las repisas mientras las
## caras empinadas siguen de roca. Sin pintura encima, no cambia nada. En vivo. Coste: el de Painted Textures, solo en esas caras.
@export var painted_ledges := true:
	set(value):
		painted_ledges = value
		_update_texture_params()
## Solo con Painted Ledges. Inclinacion maxima en grados (0 = horizontal) de una cara totalmente cubierta. Mayor cubre tambien
## caras mas empinadas (mas nieve); menor la deja solo en repisas casi planas. En vivo.
@export_range(0.0, 80.0, 1.0, "suffix:degrees") var ledge_angle := 55.0:
	set(value):
		ledge_angle = value
		_update_texture_params()
## Solo con Painted Ledges. Grados por encima de Ledge Angle en los que la cobertura se desvanece. Menor: borde mas nitido. En vivo.
@export_range(1.0, 30.0, 1.0, "suffix:degrees") var ledge_softness := 10.0:
	set(value):
		ledge_softness = value
		_update_texture_params()
## Solo con Painted Ledges. Cuanto rompe el borde de la repisa el relieve de la propia textura (su altura): 0 = borde liso que
## sigue solo la inclinacion; mayor = borde irregular, como nieve acumulada. En vivo.
@export_range(0.0, 0.5, 0.01) var ledge_breakup := 0.15:
	set(value):
		ledge_breakup = value
		_update_texture_params()
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
## Solo con Rock By Angle. Deriva los angulos de roca de la deteccion de cliffs: empieza en Minimum Slope - Rock Follow Lead y es
## completa Rock Follow Width grados despues. Asi detras de todo cliff hay roca y las colinas sin cliff quedan con hierba, aunque
## cambies Minimum Slope. Rock Angle Start/Full se conservan y vuelven a usarse al apagarlo. En vivo; hornea para el juego.
@export var rock_follows_cliffs := false:
	set(value):
		rock_follows_cliffs = value
		_update_rock_angles()
## Solo con Rock Follows Cliffs. Grados antes de Minimum Slope en que empieza la roca. Mayor anuncia la pared antes; 0 empieza
## justo donde nacen los pliegues. En vivo.
@export_range(0.0, 30.0, 0.5, "suffix:degrees") var rock_follow_lead := 2.0:
	set(value):
		rock_follow_lead = value
		_update_rock_angles()
## Solo con Rock Follows Cliffs. Grados desde el inicio de la roca hasta roca completa. Menor: borde mas nitido. En vivo.
@export_range(0.5, 30.0, 0.5, "suffix:degrees") var rock_follow_width := 8.0:
	set(value):
		rock_follow_width = value
		_update_rock_angles()
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
## De donde sale el angulo minimo de agarre de la malla de cliffs. Heredar: Grab Min Slope Degrees del ClimbRules del Player (una
## sola fuente de verdad, recomendado). Angulo Propio: Climb Min Slope Degrees de abajo. Cualquier Pendiente: toda cara que alcance
## el rayo del pecho (prueba). Orientacion y sostener siempre vienen de ClimbRules. En vivo, sin regenerar ni rehornear. Coste nulo.
@export_enum("Heredar", "Angulo Propio", "Cualquier Pendiente") var climb_rule_mode := 1
## Solo con Angulo Propio. Pendiente minima, en grados desde horizontal, para AGARRARSE a la malla. 75.5 = limite fijo anterior.
## Menor permite pliegues y paredes mas tendidos. La malla solo existe donde la escultura supera Minimum Slope: bajarlo por debajo
## no crea pared nueva. En vivo.
@export_range(10.0, 89.0, 0.5, "suffix:degrees") var climb_min_slope_degrees := 75.5
## Valor antiguo: al cargar una escena con Climb Any Slope activo pasa a Climb Rule Mode = Cualquier Pendiente.
@export_storage var climb_any_slope := false:
	set(value):
		if value:
			climb_rule_mode = 2

@export_group("Distancia (LOD)")
## Terrain3D simplifica el terreno lejano en anillos cada vez mas gruesos y solo oculta un vertice si cae justo sobre un agujero:
## de lejos sobreviven triangulos grandes que cruzan la pared y asoman como picos verdes delante del cliff. Esto empuja hacia atras
## en profundidad (mismo pixel en pantalla) los vertices lejanos que tienen un agujero o un desnivel fuerte cerca, para que la malla
## del cliff les gane. Haria falta incluso sin agujeros: en el pie concavo los triangulos gruesos cortan la esquina por fuera.
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
## Los agujeros del terreno solo se abren en su malla mas fina. De lejos, un vertice grueso sobre un agujero borra su triangulo entero,
## que puede ser mayor que Seam Overlap: se veian puntos de cielo en la franja del cliff. Apagado = agujeros en todos los anillos.
## Requiere Far Spike Fix, que empuja ese terreno detras de la malla. Limite: un agujero pintado a mano fuera de un cliff (una cueva)
## se ve cerrado desde mas lejos de unos 16 m con mesh_size 64 y vertex_spacing 0,25; la colision no cambia.
## Se aplica al iniciar el juego, y en el editor al regenerar u hornear. Coste nulo.
@export var far_hole_fill := true
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
## Con registro de cliffs, son los agujeros de cada cliff seguidos (ver cliff_hole_counts).
@export_storage var owned_holes := PackedInt32Array()
## Registro por cliff: id, cuantos agujeros de owned_holes le pertenecen (en orden) y bloques (x, z globales de
## BLOCK celdas) bajo su malla. Vacio = escena anterior al registro (la primera regeneracion parcial regenera todo).
@export_storage var cliff_ids := PackedInt32Array()
@export_storage var cliff_hole_counts := PackedInt32Array()
@export_storage var cliff_blocks: Array[PackedInt32Array] = []
@export_storage var next_cliff_id := 0
## Huella (md5) del relieve de cada region de Terrain3D en la ultima regeneracion de sus cliffs: "x,z" -> md5.
@export_storage var region_hashes := {}
## Ajustes con los que se regeneraron todos los cliffs por ultima vez (aviso si una regeneracion parcial los mezcla).
@export_storage var registry_parameters: Array = []
## Bloques (x, z globales de BLOCK celdas) donde no se generan cliffs (Excluir seleccion). Se guarda con la escena.
@export_storage var excluded_blocks := PackedInt32Array()

const EPSILON := 0.001
## Celdas por lado de un bloque del registro de cliffs (2 m con vertex_spacing 0.25).
const BLOCK := 8
const MODE_ALL := 0
const MODE_CHANGES := 1
const MODE_SEEDS := 2
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
# Editor cache between partial regenerations: grid, mask and cliff labels, valid while the region hashes match.
var _grid_hashes := {}
var _grid_key: Array = []
var _bw := 0
var _bd := 0
var _occupied := PackedByteArray()
var _labels := PackedInt32Array()
var _label_blocks := {}
var _selected := PackedInt32Array()
var _selected_seeds := PackedInt32Array()
var _zone_cliffs := PackedInt32Array()
var _selection_material: ShaderMaterial
var _zone_material: ShaderMaterial
var _zone_wait := -1.0
var _exclusion_lines: MeshInstance3D

func _preview_parameters() -> Array:
	return [minimum_slope, slope_transition, normal_radius, pattern_seed,
		fold_size, indentation, protrusion, fold_sharpness, vertical_stretch, mesh_step,
		profile_search_distance, wall_search_passes, strip_break_distance, surface_smoothing, smoothing_limit,
		edge_fade_meters, seam_overlap, seam_fade_width, seam_lift,
		chunk_size, skirt_depth, visibility_range, grass_texture_id,
		cliff_texture_id, match_terrain_shading, fold_triplanar, seam_depth_offset,
		rock_start_angle, rock_blend_angle, terrain_auto_shader, terrain_auto_slope,
		rock_by_angle, rock_angle_start, rock_angle_full, rock_height_reduction, collision_enabled,
		far_spike_fix, far_spike_push, far_spike_reach, far_hole_fill, mesh_lod, mesh_lod_merge_angle, mesh_lod_bias,
		seam_fade_far_distance, clean_rock_edge, rock_follows_cliffs, rock_follow_lead, rock_follow_width]

## Rock blend angles (start, full) used by the Terrain3D override and the mesh.
func _rock_angles() -> Vector2:
	var start := minimum_slope - rock_follow_lead if rock_follows_cliffs else rock_angle_start
	var width := rock_follow_width if rock_follows_cliffs else rock_angle_full - rock_angle_start
	return Vector2(start, start + maxf(width, 0.5))

## Limite de |normal.y| para agarrarse a la colision generada; -1 = heredar de ClimbRules. climbing.gd lo busca en el ancestro del cuerpo.
func climb_normal_limit() -> float:
	match climb_rule_mode:
		0:
			return -1.0
		2:
			return 1.0
	return cos(deg_to_rad(climb_min_slope_degrees))

func _ready() -> void:
	_observed_parameters = _preview_parameters()
	_draw_exclusions.call_deferred()
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
	# Terrain3D's control maps and texture array exist only once its data is loaded: bind them for painted textures.
	_update_texture_params()
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

## Raw heights (valid under holes) on a subsample of the cells under the mesh (its holes), stored in the bake.
func _height_samples() -> PackedVector3Array:
	var cells: PackedInt32Array = owned_holes
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
	if _zone_wait >= 0.0:
		_zone_wait -= delta
		if _zone_wait < 0.0 and not _building:
			_refresh_zone_cliffs()
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
	_run(MODE_ALL)

## Rebuilds only the cliffs of Terrain3D regions whose heights changed since their last regeneration.
func regenerate_changes() -> void:
	_run(MODE_CHANGES)

func regenerate_selection() -> void:
	if _selected.is_empty() and _selected_seeds.is_empty():
		push_warning("CliffFolds: no hay cliffs seleccionados. Activa Seleccionar cliff en la barra 3D y haz clic en uno.")
		return
	_run(MODE_SEEDS, _selection_seeds())

func restore_selection() -> void:
	if _selected.is_empty():
		push_warning("CliffFolds: no hay cliffs generados seleccionados.")
		return
	_run(MODE_SEEDS, _selection_seeds(), true)

func clear_selection() -> void:
	_selected = PackedInt32Array()
	_selected_seeds = PackedInt32Array()
	_update_highlight()

## Restores the selected cliffs and keeps them out of every later regeneration.
func exclude_selection() -> void:
	if _selected.is_empty() and _selected_seeds.is_empty():
		push_warning("CliffFolds: selecciona con clic los cliffs (o las paredes restauradas) que quieres excluir.")
		return
	var seeds := PackedInt32Array()
	for id in _selected:
		var k := cliff_ids.find(id)
		if k >= 0:
			seeds.append_array(cliff_blocks[k])
	# Clicks on a wall without cover (already restored): exclude the whole wall found there.
	if not _selected_seeds.is_empty() and is_instance_valid(terrain) and terrain.data != null:
		_ensure_grid()
		var base := _origin / BLOCK
		var reach := ceili(pick_radius / (BLOCK * terrain.vertex_spacing))
		var taken := {}
		for i in range(0, _selected_seeds.size(), 2):
			var best := -1
			var best_distance := INF
			for dz in range(-reach, reach + 1):
				for dx in range(-reach, reach + 1):
					var local := Vector2i(_selected_seeds[i] + dx, _selected_seeds[i + 1] + dz) - base
					if local.x < 0 or local.y < 0 or local.x >= _bw or local.y >= _bd:
						continue
					var b := local.y * _bw + local.x
					if _occupied[b] and _labels[b] >= 0 and Vector2(dx, dz).length() < best_distance:
						best_distance = Vector2(dx, dz).length()
						best = _labels[b]
			if best >= 0 and not taken.has(best):
				taken[best] = true
				for j in _label_blocks[best]:
					seeds.append(j % _bw + base.x)
					seeds.append(j / _bw + base.y)
		_release_grid()
	if seeds.is_empty():
		push_warning("CliffFolds: no hay pared empinada cerca de donde hiciste clic.")
		return
	var known := {}
	for i in range(0, excluded_blocks.size(), 2):
		known[Vector2i(excluded_blocks[i], excluded_blocks[i + 1])] = true
	for i in range(0, seeds.size(), 2):
		var block := Vector2i(seeds[i], seeds[i + 1])
		if not known.has(block):
			known[block] = true
			excluded_blocks.append(block.x)
			excluded_blocks.append(block.y)
	_run(MODE_SEEDS, seeds, true, false)
	_draw_exclusions()
	print("Cliff folds: %d bloques excluidos en total." % (excluded_blocks.size() / 2))

## Removes the exclusion touched by the selection (the red area clicked, or the selected cliffs) and rebuilds there.
func include_selection() -> void:
	var seeds := _selection_seeds()
	if seeds.is_empty() or excluded_blocks.is_empty():
		push_warning("CliffFolds: haz clic sobre una zona excluida (roja) y pulsa Incluir seleccion.")
		return
	var excluded := {}
	for i in range(0, excluded_blocks.size(), 2):
		excluded[Vector2i(excluded_blocks[i], excluded_blocks[i + 1])] = true
	# Whole connected red areas within Pick Radius of the clicked spots.
	var reach := ceili(pick_radius / (BLOCK * terrain.vertex_spacing))
	var frontier := []
	for i in range(0, seeds.size(), 2):
		for dz in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var block := Vector2i(seeds[i] + dx, seeds[i + 1] + dz)
				if excluded.has(block):
					frontier.append(block)
	var freed := {}
	while not frontier.is_empty():
		var block: Vector2i = frontier.pop_back()
		if freed.has(block) or not excluded.has(block):
			continue
		freed[block] = true
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				frontier.append(block + Vector2i(dx, dz))
	if freed.is_empty():
		push_warning("CliffFolds: la seleccion no toca ninguna zona excluida (roja).")
		return
	var kept := PackedInt32Array()
	var rebuilt := PackedInt32Array()
	for block: Vector2i in excluded:
		if freed.has(block):
			rebuilt.append_array(PackedInt32Array([block.x, block.y]))
		else:
			kept.append_array(PackedInt32Array([block.x, block.y]))
	excluded_blocks = kept
	_run(MODE_SEEDS, rebuilt)
	_draw_exclusions()

func clear_exclusions() -> void:
	if excluded_blocks.is_empty():
		return
	var rebuilt := excluded_blocks.duplicate()
	excluded_blocks = PackedInt32Array()
	_run(MODE_SEEDS, rebuilt)
	_draw_exclusions()

## Editor-only red squares over the excluded blocks, at terrain height.
func _draw_exclusions() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if excluded_blocks.is_empty() or not highlight_enabled or not is_instance_valid(terrain) or terrain.data == null:
		if is_instance_valid(_exclusion_lines):
			_exclusion_lines.queue_free()
		_exclusion_lines = null
		return
	if not is_instance_valid(_exclusion_lines):
		_exclusion_lines = MeshInstance3D.new()
		_exclusion_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_exclusion_lines.top_level = true
		add_child(_exclusion_lines, false, Node.INTERNAL_MODE_BACK)
		_exclusion_lines.global_transform = Transform3D.IDENTITY
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = excluded_color
	material.render_priority = 20
	var size := BLOCK * terrain.vertex_spacing
	var inset := size * 0.15
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for i in range(0, excluded_blocks.size(), 2):
		var x0 := excluded_blocks[i] * size + inset
		var z0 := excluded_blocks[i + 1] * size + inset
		var x1 := (excluded_blocks[i] + 1) * size - inset
		var z1 := (excluded_blocks[i + 1] + 1) * size - inset
		var corners := []
		for c: Vector2 in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)]:
			var h := terrain.data.get_height(Vector3(c.x, 0.0, c.y))
			corners.append(Vector3(c.x, (0.0 if is_nan(h) else h) + 0.15, c.y))
		for k in 4:
			mesh.surface_add_vertex(corners[k])
			mesh.surface_add_vertex(corners[(k + 1) % 4])
	mesh.surface_end()
	_exclusion_lines.mesh = mesh

func regenerate_zones() -> void:
	var seeds := _zone_seeds()
	if seeds.is_empty():
		push_warning("CliffFolds: no hay CliffZone activos. Anade un nodo CliffZone como hijo de este nodo.")
		return
	_run(MODE_SEEDS, seeds)

func restore_zones() -> void:
	var seeds := _zone_seeds()
	if seeds.is_empty():
		push_warning("CliffFolds: no hay CliffZone activos. Anade un nodo CliffZone como hijo de este nodo.")
		return
	_run(MODE_SEEDS, seeds, true)

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
	_clear_registry()
	_mark_scene_unsaved()
	print("Cliff folds: terreno restaurado; agujeros propios cerrados. El bake queda desconectado hasta volver a hornear.")

func _clear_registry() -> void:
	cliff_ids = PackedInt32Array()
	cliff_hole_counts = PackedInt32Array()
	cliff_blocks = []
	region_hashes = {}
	_selected = PackedInt32Array()
	_selected_seeds = PackedInt32Array()
	_zone_cliffs = PackedInt32Array()

## Mode All rebuilds every cliff. Changes and Seeds rebuild (or, with Restore, remove) whole cliffs: those whose
## blocks touch the seeds (global block coordinates, x/z pairs) or the changed regions, plus every cliff they touch.
func _run(mode: int, seeds := PackedInt32Array(), restore := false, reopen := true) -> void:
	if _building or not is_inside_tree():
		return
	if not is_instance_valid(terrain) or terrain.data == null:
		push_warning("CliffFoldsGenerator: falta el Terrain3D o sus datos.")
		return
	var legacy := cliff_ids.is_empty() and not owned_holes.is_empty()
	# Chunks without a cliff id come from an older bake: they could not be replaced one cliff at a time.
	_ensure_generated()
	for child in _generated.get_children():
		if not child.has_meta("cliff_id"):
			legacy = true
			break
	if mode != MODE_ALL and legacy:
		print("Cliff folds: esta escena aun no tiene registro de cliffs; se regenera todo una vez.")
		mode = MODE_ALL
		restore = false
	_building = true
	_last_build_ok = false
	var start := Time.get_ticks_msec()
	_observed_parameters = _preview_parameters()
	_noise.seed = pattern_seed
	_noise.frequency = 1.0 / fold_size
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.fractal_octaves = 2
	var hashes := _ensure_grid()
	# Which old cliffs go (drop, by id) and which current cliffs (labels) are rebuilt.
	var drop := {}
	var labels := {}
	if mode == MODE_ALL:
		for id in cliff_ids:
			drop[id] = true
		for label: int in _label_blocks:
			labels[label] = true
	else:
		var seed_blocks := {}
		if mode == MODE_CHANGES:
			var size := terrain.region_size / BLOCK
			for key: String in hashes:
				if region_hashes.get(key, "") == hashes[key]:
					continue
				var location := _region_location(key)
				for bz in size:
					for bx in size:
						seed_blocks[location * size + Vector2i(bx, bz)] = true
		else:
			for i in range(0, seeds.size(), 2):
				seed_blocks[Vector2i(seeds[i], seeds[i + 1])] = true
		_close_over(seed_blocks, drop, labels, restore)
		if restore:
			labels.clear()
	if mode == MODE_CHANGES and drop.is_empty() and labels.is_empty():
		_mark_clean_regions(hashes, labels, next_cliff_id)
		_building = false
		_last_build_ok = true
		_release_grid()
		print("Cliff folds: no hay cliffs que regenerar por cambios (%d ms)." % (Time.get_ticks_msec() - start))
		return
	if not registry_parameters.is_empty() and mode != MODE_ALL and not restore and registry_parameters != _preview_parameters():
		push_warning("CliffFolds: cambiaste ajustes desde la ultima regeneracion completa; los cliffs regenerados ahora usan los nuevos y el resto los antiguos. Pulsa Regenerar cliffs para igualarlos.")
	var first_new := next_cliff_id
	# Build every new cliff before touching the scene: a failure keeps the previous cover.
	var built := []
	var wall_total := 0
	for label: int in labels:
		var builder = _build_cliff(_label_blocks[label], drop, mode == MODE_ALL)
		if builder == null:
			_building = false
			_release_grid()
			return
		if builder.wall_count > 0:
			built.append(builder)
			wall_total += builder.wall_count
	_apply_terrain_material()
	if mode == MODE_ALL:
		_clear_generated()
	else:
		_ensure_generated()
		_remove_cliff_nodes(drop)
	# A restored cliff must come back with the next Regenerar cambios or bake: forget its regions' hashes.
	var size_in_blocks := terrain.region_size / BLOCK
	var reopened := {}
	if restore and reopen:
		for k in cliff_ids.size():
			if drop.has(cliff_ids[k]):
				var dropped: PackedInt32Array = cliff_blocks[k]
				for i in range(0, dropped.size(), 2):
					reopened["%d,%d" % [floori(float(dropped[i]) / size_in_blocks), floori(float(dropped[i + 1]) / size_in_blocks)]] = true
	# Registry: keep the untouched cliffs, add the new ones with their holes.
	var kept_ids := PackedInt32Array()
	var kept_counts := PackedInt32Array()
	var kept_blocks: Array[PackedInt32Array] = []
	var kept_holes := PackedInt32Array()
	var offset := 0
	for k in cliff_ids.size():
		var count := cliff_hole_counts[k] if k < cliff_hole_counts.size() else 0
		if mode != MODE_ALL and not drop.has(cliff_ids[k]):
			kept_ids.append(cliff_ids[k])
			kept_counts.append(count)
			kept_blocks.append(cliff_blocks[k] if k < cliff_blocks.size() else PackedInt32Array())
			kept_holes.append_array(owned_holes.slice(offset * 2, (offset + count) * 2))
		offset += count
	var chunks := 0
	var vertex_count := 0
	for builder in built:
		var id := next_cliff_id
		next_cliff_id += 1
		var stats := _build_reconstructed_meshes(builder, id)
		chunks += stats.x
		vertex_count += stats.y
		var holes: PackedInt32Array = builder.hole_cells()
		kept_ids.append(id)
		kept_counts.append(holes.size() / 2)
		kept_blocks.append(_footprint_blocks(builder))
		kept_holes.append_array(holes)
	cliff_ids = kept_ids
	cliff_hole_counts = kept_counts
	cliff_blocks = kept_blocks
	var holes_changed := _set_owned_holes(kept_holes)
	if holes_changed:
		_refresh_terrain()
	if mode == MODE_ALL:
		region_hashes = hashes.duplicate()
		registry_parameters = _preview_parameters()
	else:
		_mark_clean_regions(hashes, labels, first_new)
		for key: String in reopened:
			region_hashes.erase(key)
	_surface_candidate = built[0] if not built.is_empty() else null
	_selected = PackedInt32Array()
	_selected_seeds = PackedInt32Array()
	_generated.set_meta("preview_only", true)
	_building = false
	_last_build_ok = true
	if mode != MODE_ALL or holes_changed:
		_mark_scene_unsaved()
	update_configuration_warnings()
	_refresh_zone_cliffs()
	_release_grid()
	var what := "todos"
	if mode != MODE_ALL:
		what = ("%d restaurados" % drop.size()) if restore else ("%d regenerados, %d quitados" % [built.size(), drop.size()])
	print("Cliff folds: %d cliffs (%s), %d franjas, %d chunks, %d vertices, %d agujeros en total, %d ms." % [
		cliff_ids.size(), what, wall_total, chunks, vertex_count, owned_holes.size() / 2, Time.get_ticks_msec() - start])
	_wanted_holes = PackedInt32Array()

## Grows the seeds to whole cliffs: current cliffs (labels) on seeded blocks and old cliffs whose blocks touch them,
## repeated until nothing new joins (an old cliff may span two new ones after re-sculpting). Restore uses old cliffs only.
func _close_over(seed_blocks: Dictionary, drop: Dictionary, labels: Dictionary, restore: bool) -> void:
	var old_index := {}
	for k in cliff_ids.size():
		var blocks: PackedInt32Array = cliff_blocks[k] if k < cliff_blocks.size() else PackedInt32Array()
		for i in range(0, blocks.size(), 2):
			var key := Vector2i(blocks[i], blocks[i + 1])
			if not old_index.has(key):
				old_index[key] = []
			old_index[key].append(cliff_ids[k])
	var base := _origin / BLOCK
	var frontier: Array = seed_blocks.keys()
	var seen := {}
	while not frontier.is_empty():
		var next := []
		for block: Vector2i in frontier:
			if seen.has(block):
				continue
			seen[block] = true
			for id in old_index.get(block, []):
				if drop.has(id):
					continue
				drop[id] = true
				var blocks: PackedInt32Array = cliff_blocks[cliff_ids.find(id)]
				for i in range(0, blocks.size(), 2):
					next.append(Vector2i(blocks[i], blocks[i + 1]))
			if restore:
				continue
			var local := block - base
			if local.x < 0 or local.y < 0 or local.x >= _bw or local.y >= _bd:
				continue
			var b := local.y * _bw + local.x
			if not _occupied[b] or _labels[b] < 0 or labels.has(_labels[b]):
				continue
			labels[_labels[b]] = true
			for j in _label_blocks[_labels[b]]:
				next.append(Vector2i(j % _bw, j / _bw) + base)
		frontier = next

## After a partial run (registry already updated): a changed region is up to date when every current cliff on it was
## rebuilt and no other registry cliff lies there.
func _mark_clean_regions(hashes: Dictionary, labels: Dictionary, first_new: int) -> void:
	var size := terrain.region_size / BLOCK
	var rebuilt_regions := {}
	var other_regions := {}
	for k in cliff_ids.size():
		var blocks: PackedInt32Array = cliff_blocks[k]
		for i in range(0, blocks.size(), 2):
			var region := Vector2i(floori(float(blocks[i]) / size), floori(float(blocks[i + 1]) / size))
			if cliff_ids[k] >= first_new:
				rebuilt_regions[region] = true
			else:
				other_regions[region] = true
	for key: String in hashes:
		if region_hashes.get(key, "") == hashes[key]:
			continue
		var location := _region_location(key)
		if other_regions.has(location):
			continue
		var clean := true
		var base := location * size - _origin / BLOCK
		for bz in size:
			for bx in size:
				var b := (base.y + bz) * _bw + base.x + bx
				if b >= 0 and b < _labels.size() and _occupied[b] and not labels.has(_labels[b]):
					clean = false
					break
			if not clean:
				break
		if clean:
			region_hashes[key] = hashes[key]

func _region_location(key: String) -> Vector2i:
	var parts := key.split(",")
	return Vector2i(parts[0].to_int(), parts[1].to_int())

## Builds one cliff on a crop of the grid around its blocks, with the mask of every other cliff cleared.
## Returns null (and reports) when its cover would cross holes nobody owns.
func _build_cliff(blocks: PackedInt32Array, drop: Dictionary, everything: bool):
	var lo := Vector2i(_bw, _bd)
	var hi := Vector2i(-1, -1)
	for j in blocks:
		lo = lo.min(Vector2i(j % _bw, j / _bw))
		hi = hi.max(Vector2i(j % _bw, j / _bw))
	var margin := ceili((profile_search_distance + seam_overlap + seam_fade_width + edge_fade_meters + 2.0) / _spacing)
	var x0 := maxi(0, lo.x * BLOCK - margin)
	var z0 := maxi(0, lo.y * BLOCK - margin)
	var x1 := mini(_w, (hi.x + 1) * BLOCK + margin)
	var z1 := mini(_d, (hi.y + 1) * BLOCK + margin)
	var cw := x1 - x0
	var cd := z1 - z0
	var heights := PackedFloat32Array()
	var normals := PackedVector3Array()
	for z in range(z0, z1):
		heights.append_array(_heights.slice(z * _w + x0, z * _w + x1))
		normals.append_array(_normals.slice(z * _w + x0, z * _w + x1))
	var mask := PackedFloat32Array()
	mask.resize(cw * cd)
	for j in blocks:
		var bx := (j % _bw) * BLOCK
		var bz := (j / _bw) * BLOCK
		for z in range(bz, mini(bz + BLOCK, _d)):
			var source := z * _w
			var target := (z - z0) * cw - x0
			for x in range(bx, mini(bx + BLOCK, _w)):
				mask[target + x] = _mask[source + x]
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
	if not builder.build(heights, normals, mask, cw, cd, _spacing, _origin + Vector2i(x0, z0)):
		# Only slivers of wall (no strip fits): this cliff simply gets no cover.
		builder.wall_count = 0
		return builder
	# Holes under the cover that no cliff owns (painted by hand or test leftovers) would show the void.
	var owned := {}
	if everything or cliff_ids.is_empty():
		for i in range(0, owned_holes.size(), 2):
			owned[Vector2i(owned_holes[i], owned_holes[i + 1])] = true
	else:
		var offset := 0
		for k in cliff_ids.size():
			var count := cliff_hole_counts[k] if k < cliff_hole_counts.size() else 0
			for i in range(offset, offset + count):
				owned[Vector2i(owned_holes[i * 2], owned_holes[i * 2 + 1])] = true
			offset += count
	var foreign := 0
	var footprint: PackedInt32Array = builder.footprint_cells()
	for i in range(0, footprint.size(), 2):
		var cell := Vector2i(footprint[i], footprint[i + 1])
		if not owned.has(cell) and terrain.data.get_control_hole(_world(cell)):
			foreign += 1
	if foreign > 0:
		if not _adopting:
			push_error(("Cliff B: la cubierta cruza %d agujeros no registrados (pintados a mano o restos de pruebas). " +
				"Si son restos, pulsa Adoptar agujeros bajo la cubierta; si son tuyos, separa esa zona. Se conserva la cubierta anterior.") % foreign)
			return null
		print("Cliff B: %d agujeros no registrados bajo la cubierta pasan a ser propios." % foreign)
	if builder.bare_cells * 100 > builder.wall_cells * 3:
		push_warning("Cliff B: %d%% de una pared queda como Terrain3D esculpido sin pliegues (uniones de terrazas o columnas partidas). Prueba mas Wall Search Passes o Strip Break Distance." % [builder.bare_cells * 100 / maxi(builder.wall_cells, 1)])
	if builder.reach_hits > 0:
		push_warning("Cliff B: %d columnas llegaron a Profile Search Distance antes de salir de la pendiente; su zona de cliff termina ahi." % builder.reach_hits)
	return builder

## Global blocks (x, z pairs) under the builder's mesh.
func _footprint_blocks(builder) -> PackedInt32Array:
	var seen := {}
	var cells: PackedInt32Array = builder.footprint_cells()
	for i in range(0, cells.size(), 2):
		seen[Vector2i(floori(float(cells[i]) / BLOCK), floori(float(cells[i + 1]) / BLOCK))] = true
	var result := PackedInt32Array()
	for block: Vector2i in seen:
		result.append(block.x)
		result.append(block.y)
	return result

func _ensure_generated() -> void:
	if not is_instance_valid(_generated):
		_generated = get_node_or_null("GeneratedCliffs")
	if not is_instance_valid(_generated):
		_clear_generated()

func _remove_cliff_nodes(drop: Dictionary) -> void:
	for child in _generated.get_children():
		if drop.has(int(child.get_meta("cliff_id", -1))):
			_generated.remove_child(child)
			child.free()

## Grid, mask and cliff labels. Kept in the editor between partial runs; regions whose heights changed (md5) are
## read again. Returns the current hash of every region ("x,z" -> md5).
func _ensure_grid() -> Dictionary:
	var hashes := {}
	var locations: Array = terrain.data.get_region_locations()
	for location: Vector2i in locations:
		var region: Terrain3DRegion = terrain.data.get_region(location)
		if region == null or region.is_deleted():
			continue
		var context := HashingContext.new()
		context.start(HashingContext.HASH_MD5)
		context.update(region.get_height_map().get_data())
		hashes["%d,%d" % [location.x, location.y]] = context.finish().hex_encode()
	var key := [terrain.vertex_spacing, terrain.region_size, minimum_slope, slope_transition, normal_radius,
		cliff_link_distance, hashes.keys(), hash(excluded_blocks)]
	var full := _heights.is_empty() or key != _grid_key
	var changed := []
	if not full:
		for region_key: String in hashes:
			if _grid_hashes.get(region_key, "") != hashes[region_key]:
				changed.append(_region_location(region_key))
	if full:
		_read_terrain()
		_build_mask()
	elif not changed.is_empty():
		var size: int = terrain.region_size
		var low := _origin / size
		for location: Vector2i in changed:
			var image: Image = terrain.data.get_region(location).get_height_map()
			if image.get_format() != Image.FORMAT_RF:
				image = image.duplicate()
				image.convert(Image.FORMAT_RF)
			var values := image.get_data().to_float32_array()
			var base := (location - low) * size
			for z in size:
				var row := (base.y + z) * _w + base.x
				for x in size:
					_heights[row + x] = values[z * size + x]
		for location: Vector2i in changed:
			var base := (location - low) * size
			_build_mask_rect(base.x - normal_radius - 1, base.y - normal_radius - 1,
				base.x + size + normal_radius + 1, base.y + size + normal_radius + 1)
	if full or not changed.is_empty():
		_build_labels()
	_grid_hashes = hashes
	_grid_key = key
	return hashes

## Outside the editor the grid is dropped after use (a stale rebuild in game runs once).
func _release_grid() -> void:
	if Engine.is_editor_hint():
		return
	_heights = PackedFloat32Array()
	_normals = PackedVector3Array()
	_mask = PackedFloat32Array()
	_occupied = PackedByteArray()
	_labels = PackedInt32Array()
	_label_blocks = {}
	_grid_key = []

## Blocks with any cliff cell, grown by half the link distance and split into connected groups: one label per cliff.
func _build_labels() -> void:
	_bw = ceili(float(_w) / BLOCK)
	_bd = ceili(float(_d) / BLOCK)
	_occupied.resize(_bw * _bd)
	_occupied.fill(0)
	for z in _d:
		var row := z * _w
		var brow := (z / BLOCK) * _bw
		for x in _w:
			if _mask[row + x] > EPSILON:
				_occupied[brow + x / BLOCK] = 1
	# Excluded blocks never hold a cliff.
	var base := _origin / BLOCK
	for i in range(0, excluded_blocks.size(), 2):
		var local := Vector2i(excluded_blocks[i], excluded_blocks[i + 1]) - base
		if local.x >= 0 and local.y >= 0 and local.x < _bw and local.y < _bd:
			_occupied[local.y * _bw + local.x] = 0
	var radius := maxi(0, ceili(cliff_link_distance * 0.5 / (BLOCK * _spacing)))
	# Chebyshev growth by rings around the occupied blocks.
	var grown := _occupied.duplicate()
	var front := PackedInt32Array()
	for b in _occupied.size():
		if _occupied[b]:
			front.append(b)
	for ring in radius:
		var next := PackedInt32Array()
		for b in front:
			var bx := b % _bw
			var bz := b / _bw
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var x := bx + dx
					var z := bz + dz
					if x < 0 or z < 0 or x >= _bw or z >= _bd:
						continue
					var j := z * _bw + x
					if not grown[j]:
						grown[j] = 1
						next.append(j)
		front = next
	_labels.resize(_bw * _bd)
	_labels.fill(-1)
	_label_blocks = {}
	var label := 0
	for b in grown.size():
		if not grown[b] or _labels[b] >= 0:
			continue
		var members := PackedInt32Array()
		var queue := PackedInt32Array([b])
		_labels[b] = label
		var head := 0
		while head < queue.size():
			var i := queue[head]
			head += 1
			if _occupied[i]:
				members.append(i)
			var bx := i % _bw
			var bz := i / _bw
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var x := bx + dx
					var z := bz + dz
					if x < 0 or z < 0 or x >= _bw or z >= _bd:
						continue
					var j := z * _bw + x
					if grown[j] and _labels[j] < 0:
						_labels[j] = label
						queue.append(j)
		if not members.is_empty():
			_label_blocks[label] = members
		label += 1

func _selection_seeds() -> PackedInt32Array:
	var seeds := _selected_seeds.duplicate()
	for id in _selected:
		var k := cliff_ids.find(id)
		if k >= 0:
			seeds.append_array(cliff_blocks[k])
	return seeds

## Global blocks inside any enabled CliffZone child.
func _zone_seeds() -> PackedInt32Array:
	var seeds := PackedInt32Array()
	if not is_instance_valid(terrain):
		return seeds
	var size := BLOCK * terrain.vertex_spacing
	for zone in _zones():
		var box: AABB = zone.world_aabb()
		var lo := Vector2i(floori(box.position.x / size), floori(box.position.z / size))
		var hi := Vector2i(floori(box.end.x / size), floori(box.end.z / size))
		for bz in range(lo.y, hi.y + 1):
			for bx in range(lo.x, hi.x + 1):
				if zone.contains_xz(Vector2((bx + 0.5) * size, (bz + 0.5) * size)):
					seeds.append(bx)
					seeds.append(bz)
	return seeds

func _zones() -> Array:
	var result := []
	for child in get_children():
		if child.has_method("contains_xz") and child.get("enabled"):
			result.append(child)
	return result

## Registry cliffs that touch an enabled zone, for the highlight.
func _refresh_zone_cliffs() -> void:
	var seeds := _zone_seeds()
	var wanted := {}
	for i in range(0, seeds.size(), 2):
		wanted[Vector2i(seeds[i], seeds[i + 1])] = true
	_zone_cliffs = PackedInt32Array()
	if not wanted.is_empty():
		for k in cliff_ids.size():
			var blocks: PackedInt32Array = cliff_blocks[k]
			for i in range(0, blocks.size(), 2):
				if wanted.has(Vector2i(blocks[i], blocks[i + 1])):
					_zone_cliffs.append(cliff_ids[k])
					break
	_update_highlight()

## Called by CliffZone children when they move, resize or toggle: refreshes the highlight shortly after.
func zones_changed() -> void:
	_zone_wait = 0.3

## Editor click: the cliff under the ray (its collision, else the terrain point and the nearest cliff within Pick Radius).
## Additive toggles it; otherwise it replaces the selection. Returns a status line for the plugin.
func pick(origin: Vector3, direction: Vector3, additive: bool) -> String:
	if not is_instance_valid(terrain) or terrain.data == null:
		return "Falta el Terrain3D."
	var id := -1
	var point := Vector3(NAN, NAN, NAN)
	var space := get_world_3d().direct_space_state
	if space != null:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + direction * 5000.0))
		if not hit.is_empty():
			point = hit.position
			if hit.collider != null and hit.collider.has_meta("cliff_id"):
				id = int(hit.collider.get_meta("cliff_id"))
	if id < 0:
		var ground := terrain.get_intersection(origin, direction, false)
		if ground.is_finite() and absf(ground.z) < 1e30 and \
				(not point.is_finite() or origin.distance_to(ground) < origin.distance_to(point)):
			point = ground
	if id < 0 and not point.is_finite():
		return "El clic no toca el terreno."
	# A bare steep wall (restored or excluded) is picked as a spot, not snapped to a neighbouring cliff.
	if id < 0 and not _on_bare_wall(point):
		id = _nearest_cliff(point)
	if not additive:
		_selected = PackedInt32Array()
		_selected_seeds = PackedInt32Array()
	var message := ""
	if id >= 0:
		var at := _selected.find(id)
		if at >= 0 and additive:
			_selected.remove_at(at)
			message = "Cliff %d quitado." % id
		elif at < 0:
			_selected.append(id)
			message = "Cliff %d seleccionado." % id
	else:
		# No generated cliff here: remember the spot; Regenerar seleccion builds whatever wall is there.
		var size := BLOCK * terrain.vertex_spacing
		_selected_seeds.append(floori(point.x / size))
		_selected_seeds.append(floori(point.z / size))
		var excluded := false
		for i in range(0, excluded_blocks.size(), 2):
			if absi(excluded_blocks[i] - _selected_seeds[-2]) <= 1 and absi(excluded_blocks[i + 1] - _selected_seeds[-1]) <= 1:
				excluded = true
				break
		if excluded:
			message = "Zona excluida (roja): Incluir seleccion la devuelve."
		else:
			message = "Pared sin cliff: Regenerar seleccion la crea; Excluir seleccion la deja sin pliegues siempre."
	var tinted := _update_highlight()
	return message + " Seleccionados: %d (%d trozos resaltados%s)." % [_selected.size(), tinted,
		"" if highlight_enabled else ", resaltado apagado"]

func _on_bare_wall(point: Vector3) -> bool:
	var size := BLOCK * terrain.vertex_spacing
	var block := Vector2i(floori(point.x / size), floori(point.z / size))
	for k in cliff_ids.size():
		var blocks: PackedInt32Array = cliff_blocks[k]
		for i in range(0, blocks.size(), 2):
			if blocks[i] == block.x and blocks[i + 1] == block.y:
				return false
	var normal := terrain.data.get_normal(point)
	return normal.is_finite() and rad_to_deg(acos(clampf(normal.y, -1.0, 1.0))) >= minimum_slope - 5.0

func _nearest_cliff(point: Vector3) -> int:
	var size := BLOCK * terrain.vertex_spacing
	var here := Vector2(point.x, point.z) / size
	var best := -1
	var best_distance := pick_radius / size + 0.75
	for k in cliff_ids.size():
		var blocks: PackedInt32Array = cliff_blocks[k]
		for i in range(0, blocks.size(), 2):
			var distance := here.distance_to(Vector2(blocks[i] + 0.5, blocks[i + 1] + 0.5))
			if distance < best_distance:
				best_distance = distance
				best = cliff_ids[k]
	return best

## Editor overlay on the chunks of selected cliffs and of cliffs inside zones. Removed before baking.
func _update_highlight() -> int:
	if not Engine.is_editor_hint() or not is_instance_valid(_generated):
		return 0
	var tinted := 0
	if _selection_material == null:
		_selection_material = _overlay_material()
		_zone_material = _overlay_material()
	for pair in [[_selection_material, selection_color], [_zone_material, zone_color]]:
		pair[0].set_shader_parameter("color", pair[1])
		# A bit nearer than the cliff mesh itself, which is already pulled forward by Seam Depth Offset.
		pair[0].set_shader_parameter("depth_offset", seam_depth_offset + 0.002)
	for child in _generated.get_children():
		if not child is MeshInstance3D:
			continue
		var id := int(child.get_meta("cliff_id", -1))
		var overlay: Material = null
		if highlight_enabled and id >= 0:
			if _selected.has(id):
				overlay = _selection_material
				tinted += 1
			elif _zone_cliffs.has(id):
				overlay = _zone_material
		child.material_overlay = overlay
	return tinted

## Flat translucent tint drawn over the chunks. It repeats the cliff shader's slide toward the camera (plus a little),
## otherwise the mesh, drawn nearer than its real surface, would hide its own overlay.
func _overlay_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.75, 0.1, 0.35);
uniform float depth_offset = 0.004;
void vertex() {
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (PROJECTION_MATRIX[3][3] == 0.0) {
		view.xyz *= 1.0 - depth_offset;
	}
	POSITION = PROJECTION_MATRIX * view;
}
void fragment() {
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.render_priority = 10
	return material

func _clear_highlight() -> void:
	if not is_instance_valid(_generated):
		return
	for child in _generated.get_children():
		if child is MeshInstance3D:
			child.material_overlay = null

func bake() -> void:
	# With a registry only what changed is rebuilt; settings changed since the last full run rebuild everything.
	if cliff_ids.is_empty() or registry_parameters != _preview_parameters():
		regenerate()
	else:
		regenerate_changes()
	if not _last_build_ok:
		return
	if not bake_path.begins_with("res://") or bake_path.get_extension() != "scn":
		push_error("Cliff B: Bake Path debe ser un archivo res:// terminado en .scn.")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(bake_path.get_base_dir()))
	_clear_highlight()
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
	_update_highlight()
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

# Far LODs keep their vertices over holes: dropping one removes a whole coarse triangle, wider than the collar that hides it.
const HOLE_ANCHOR := "(hole || (_background_mode"
const HOLE_FINE_ONLY := "((hole && scale < _vertex_spacing + 1e-6) || (_background_mode"

func _is_our_override(material: Terrain3DMaterial) -> bool:
	return material != null and material.shader_override_enabled and material.shader_override != null \
		and (material.shader_override.code.contains(OVERRIDE_MARK) or material.shader_override.code.contains(ROCK_MARK))

func _override_up_to_date(material: Terrain3DMaterial) -> bool:
	if not _is_our_override(material):
		return false
	var code: String = material.shader_override.code
	return rock_by_angle == code.contains(ROCK_MARK) and far_spike_fix == code.contains(FAR_SPIKE_CODE) \
		and (far_spike_fix and far_hole_fill) == code.contains(HOLE_FINE_ONLY)

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
			if far_hole_fill:
				if code.contains(HOLE_ANCHOR):
					code = code.replace(HOLE_ANCHOR, HOLE_FINE_ONLY)
				else:
					push_warning("CliffFolds: no reconozco los agujeros del vertex() de Terrain3D; Far Hole Fill no se aplica.")
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
	var angles := _rock_angles()
	if is_instance_valid(terrain) and _is_our_override(terrain.material):
		var code: String = terrain.material.shader_override.code
		if code.contains(ROCK_MARK):
			terrain.material.set_shader_param("rock_angle_start", angles.x)
			terrain.material.set_shader_param("rock_angle_full", angles.y)
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
					material.set_shader_parameter("rock_angle_start", angles.x)
					material.set_shader_parameter("rock_angle_full", angles.y)
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
	_build_mask_rect(0, 0, _w, _d)

## Normals and mask of the cells in [x0, x1) x [z0, z1) (clamped to the grid), from the current heights.
func _build_mask_rect(x0: int, z0: int, x1: int, z1: int) -> void:
	var r := normal_radius
	for z in range(maxi(r, z0), mini(_d - r, z1)):
		for x in range(maxi(r, x0), mini(_w - r, x1)):
			var i := z * _w + x
			var gx := (_heights[i + r] - _heights[i - r]) / (2.0 * r * _spacing)
			var gz := (_heights[i + r * _w] - _heights[i - r * _w]) / (2.0 * r * _spacing)
			_normals[i] = Vector3.UP
			_mask[i] = 0.0
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

## World position of a terrain vertex. Reads the terrain's spacing: the grid cache (_spacing) is empty until the first
## regeneration, and Restaurar right after opening the scene must still close the right holes.
func _world(cell: Vector2i) -> Vector3:
	var spacing := terrain.vertex_spacing if is_instance_valid(terrain) else _spacing
	return Vector3(cell.x * spacing, 0.0, cell.y * spacing)

func _build_reconstructed_meshes(surface, cliff_id: int) -> Vector2i:
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
		_add_chunk(key, [vertices, normals, slope_uv, mask_uv], parts[0], parts[1], skirt, materials, cliff_id)
	return Vector2i(chunks.size(), count)

func _add_chunk(chunk_key: Vector2i, data: Array, opaque: PackedInt32Array, faded: PackedInt32Array,
		skirt: PackedInt32Array, materials: Array, cliff_id: int) -> void:
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
	visual.name = "Cliff%d_Chunk_%d_%d" % [cliff_id, chunk_key.x, chunk_key.y]
	visual.set_meta("cliff_id", cliff_id)
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
	body.set_meta("cliff_id", cliff_id)
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
	var angles := _rock_angles()
	material.set_shader_parameter("rock_angle_start", angles.x)
	material.set_shader_parameter("rock_angle_full", angles.y)
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
		"use_painted": painted_textures and terrain.data != null,
		"painted_fold_limit": painted_fold_limit,
		"painted_ledges": painted_ledges,
		"ledge_min_y": cos(deg_to_rad(minf(ledge_angle + ledge_softness, 89.0))),
		"ledge_full_y": cos(deg_to_rad(ledge_angle)),
		"ledge_breakup": ledge_breakup,
		"painted_region_map": terrain.data.get_region_map() if terrain.data != null else PackedInt32Array(),
		"painted_region_size": float(terrain.region_size),
		"painted_colors": terrain.assets.get_texture_colors(),
		"painted_uv_scales": terrain.assets.get_texture_uv_scales(),
		# Terrain3D's live GPU arrays: bound by RID, never stored in the bake.
		RID_PREFIX + "painted_albedo": terrain.assets.get_albedo_array_rid(),
		RID_PREFIX + "painted_control": terrain.data.get_control_maps_rid() if terrain.data != null else RID(),
	}

const RID_PREFIX := "rid:"

func _apply_texture_params(material: ShaderMaterial, settings: Dictionary) -> void:
	for parameter: String in settings:
		if parameter.begins_with(RID_PREFIX):
			RenderingServer.material_set_param(material.get_rid(), parameter.trim_prefix(RID_PREFIX), settings[parameter])
		else:
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
