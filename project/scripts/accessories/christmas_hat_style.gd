@tool
class_name ChristmasHatStyle
extends Resource
## Aspecto y física compartidos del gorro navideño. El gorro del suelo y el que lleva la ardilla
## usan el mismo recurso (resources/accessories/christmas_hat_style.tres), así que se ven igual.
## Estilo por defecto: low-poly suave tipo juguete, facetado y mate como la ardilla.
## Medidas en metros del gorro sin escalar; HatSlot y el pickup pueden escalarlo después.
## Forma, color, material y calidad regeneran la malla (Live Preview en el editor). Física: en vivo.

@export_group("Forma · cuerpo")
## Radio de la abertura (base) del gorro, en metros. Mayor lo ensancha entero; regenera.
@export_range(0.08, 0.8, 0.005, "suffix:m") var opening_radius := 0.44:
	set(value): opening_radius = value; emit_changed()
## Largo (altura sobre su curva) desde el ribete hasta el pompón. Mayor deja una cola más larga; regenera.
@export_range(0.2, 2.0, 0.01, "suffix:m") var body_length := 1.0:
	set(value): body_length = value; emit_changed()
## Inclinación de la copa desde el ribete hacia el lado de la caída. 0 sale recta hacia arriba; regenera.
@export_range(0.0, 60.0, 1.0, "suffix:°") var lean_degrees := 22.0:
	set(value): lean_degrees = value; emit_changed()
## Abombado de la copa sobre el ribete, como fracción del radio. 0 es un cono recto; 0,3 una cúpula blanda. Regenera.
@export_range(0.0, 0.6, 0.01) var crown_puff := 0.1:
	set(value): crown_puff = value; emit_changed()
## Radio de la punta como fracción del radio de la abertura. Menor deja la cola más fina antes del pompón. Regenera.
@export_range(0.03, 0.6, 0.01) var tip_ratio := 0.14:
	set(value): tip_ratio = value; emit_changed()
## Curva del estrechamiento. Menor de 1 adelgaza pronto; mayor conserva volumen hasta el final. Regenera.
@export_range(0.3, 2.5, 0.05) var taper_power := 0.8:
	set(value): taper_power = value; emit_changed()
## Caída de la punta: ángulo total de doblez en reposo, sumado a la inclinación. 0 deja el gorro erguido; 110 deja la cola colgando de lado. La gravedad añade caída extra en juego. Regenera.
@export_range(0.0, 170.0, 1.0, "suffix:°") var droop_degrees := 100.0:
	set(value): droop_degrees = value; emit_changed()
## Hacia dónde caen la inclinación y la cola, alrededor del eje vertical del gorro. 0 = +Z local; 90 = +X local. HatSlot gira el gorro entero. Regenera.
@export_range(-180.0, 180.0, 1.0, "suffix:°") var droop_direction_degrees := 66.0:
	set(value): droop_direction_degrees = value; emit_changed()
## Curvatura: punto del largo (0–1) donde se dobla la tela. Menor dobla junto al ribete; mayor deja una copa alta antes del pliegue. Regenera.
@export_range(0.05, 0.95, 0.01) var fold_position := 0.5:
	set(value): fold_position = value; emit_changed()
## Curvatura: anchura del pliegue (0–1 del largo). Menor produce un doblez marcado; mayor una curva amplia y redonda. Regenera.
@export_range(0.02, 0.6, 0.01) var fold_softness := 0.4:
	set(value): fold_softness = value; emit_changed()
## Radio de giro mínimo del pliegue, en múltiplos del grosor local de la tela. Menor permite dobleces más cerrados
## pero el interior se comprime y aparecen estrías; 2 mantiene la tela limpia y lleva la caída hacia la cola fina. Regenera.
@export_range(1.0, 4.0, 0.05) var fold_min_radius := 2.0:
	set(value): fold_min_radius = value; emit_changed()
## Ondulación suave de la tela como fracción del radio local. 0 la deja lisa (recomendado para low-poly). Regenera.
@export_range(0.0, 0.3, 0.005) var wrinkle_strength := 0.0:
	set(value): wrinkle_strength = value; emit_changed()
## Frecuencia de la ondulación. Mayor produce pliegues más pequeños. Regenera.
@export_range(0.5, 12.0, 0.1) var wrinkle_frequency := 1.4:
	set(value): wrinkle_frequency = value; emit_changed()
## Semilla del ruido de ondulación y bultos. Cambiarla produce otro gorro con la misma forma general. Regenera.
@export var noise_seed := 7:
	set(value): noise_seed = value; emit_changed()

@export_group("Ribete")
## Grosor radial del ribete blanco alrededor de la abertura. Mayor lo hace más mullido; regenera.
@export_range(0.01, 0.25, 0.005, "suffix:m") var brim_thickness := 0.1:
	set(value): brim_thickness = value; emit_changed()
## Alto del ribete. Regenera.
@export_range(0.02, 0.4, 0.005, "suffix:m") var brim_height := 0.18:
	set(value): brim_height = value; emit_changed()
## Almohadillas regulares alrededor del ribete (aspecto esponjoso pero geométrico). 0 lo deja liso. Regenera.
@export_range(0, 32, 1) var brim_puffs := 12:
	set(value): brim_puffs = value; emit_changed()
## Profundidad de las almohadillas como fracción del grosor del ribete. Regenera.
@export_range(0.0, 0.6, 0.01) var brim_puff_depth := 0.16:
	set(value): brim_puff_depth = value; emit_changed()

@export_group("Pompón")
## Radio del pompón en el extremo de la cola. Mayor lo hace más llamativo; regenera.
@export_range(0.02, 0.3, 0.005, "suffix:m") var pompom_radius := 0.11:
	set(value): pompom_radius = value; emit_changed()
## Desplazamiento del pompón respecto al final de la cola, en metros locales del gorro. Se mueve con la física de la punta. Regenera.
@export var pompom_offset := Vector3.ZERO:
	set(value): pompom_offset = value; emit_changed()

@export_group("Color")
## Rojo de la tela. Por defecto, cálido y apagado.
@export var velvet_color := Color("b8392f"):
	set(value): velvet_color = value; emit_changed()
## Color de la tela en el interior del doblez (sombra pintada suave).
@export var fold_color := Color("8f2a25"):
	set(value): fold_color = value; emit_changed()
## Cuánto oscurece el doblez. 0 desactiva la sombra pintada; 1 llega a Fold Color. Regenera.
@export_range(0.0, 1.0, 0.01) var fold_shading := 0.35:
	set(value): fold_shading = value; emit_changed()
## Blanco del ribete y del pompón.
@export var fur_color := Color("f2ede5"):
	set(value): fur_color = value; emit_changed()
## Blanco en los surcos entre almohadillas y bultos.
@export var fur_shadow_color := Color("ddd5cc"):
	set(value): fur_shadow_color = value; emit_changed()

@export_group("Material")
## Rugosidad del material, como la ardilla (0,5). Mayor es más mate. Si Apariencia → mate del personaje está activa, esa opción manda. Regenera.
@export_range(0.0, 1.0, 0.01) var roughness := 0.5:
	set(value): roughness = value; emit_changed()
## Especular del material, como la ardilla (0,5). 0 elimina los brillos. Regenera.
@export_range(0.0, 1.0, 0.01) var specular := 0.5:
	set(value): specular = value; emit_changed()
## Brillo de borde. 0 (por defecto) igual que la ardilla; mayor da un borde afelpado a contraluz. Regenera.
@export_range(0.0, 1.0, 0.01) var plush_rim := 0.0:
	set(value): plush_rim = value; emit_changed()

@export_group("Detalle opcional · peluche")
## Bultos irregulares de peluche sobre ribete y pompón, como fracción de su grosor. 0 (por defecto) mantiene el estilo low-poly limpio. Regenera.
@export_range(0.0, 0.8, 0.01) var lump_strength := 0.0:
	set(value): lump_strength = value; emit_changed()
## Bultos por metro. Mayor produce mechones más pequeños. Regenera.
@export_range(4.0, 80.0, 0.5) var lump_density := 14.0:
	set(value): lump_density = value; emit_changed()
## Capas de pelo translúcidas sobre ribete y pompón. 0 (por defecto) las desactiva. Cada capa duplica la geometría blanca (coste de vértices y sobre-dibujo). Regenera.
@export_range(0, 8, 1) var fur_shells := 0:
	set(value): fur_shells = value; emit_changed()
## Largo del pelo: distancia de la capa exterior. Regenera.
@export_range(0.0, 0.05, 0.001, "suffix:m") var fur_length := 0.014:
	set(value): fur_length = value; emit_changed()
## Densidad de fibras en las capas. Mayor produce pelo más fino. Regenera.
@export_range(4.0, 64.0, 1.0) var fur_fiber_scale := 22.0:
	set(value): fur_fiber_scale = value; emit_changed()
## Capas de felpa corta sobre el terciopelo. 0 (por defecto) lo deja liso. Coste como Fur Shells. Regenera.
@export_range(0, 4, 1) var velvet_shells := 0:
	set(value): velvet_shells = value; emit_changed()
## Largo de la felpa del terciopelo. Regenera.
@export_range(0.0, 0.02, 0.0005, "suffix:m") var velvet_fuzz_length := 0.004:
	set(value): velvet_fuzz_length = value; emit_changed()

@export_group("Física de la cola")
## Activa la simulación de la cola y el pompón. Apagado conserva la forma de reposo. En vivo.
@export var physics_enabled := true
## Parte rígida del gorro (0–1 del largo) desde el ribete: la copa que abraza la cabeza nunca se deforma.
## Sólo se mueve la cola a partir de aquí. Mayor deja menos cola suelta; 0 simula todo el cuerpo. Regenera.
@export_range(0.0, 0.9, 0.01) var rigid_length := 0.45:
	set(value): rigid_length = value; emit_changed()
## Tramo (0–1 del largo) en el que la tela pasa de rígida a suelta. Mayor reparte el movimiento y evita pliegues bruscos. Regenera.
@export_range(0.02, 0.5, 0.01) var rigid_blend := 0.18:
	set(value): rigid_blend = value; emit_changed()
## Segmentos simulados a lo largo de la cola (huesos). Más da curvas más suaves; coste pequeño de CPU por gorro. Regenera.
@export_range(3, 12, 1) var physics_segments := 7:
	set(value): physics_segments = value; emit_changed()
## Fuerza con que la tela vuelve a su forma de reposo cerca del ribete, en 1/s². Mayor la hace más rígida. En vivo.
@export_range(0.0, 600.0, 1.0) var base_stiffness := 300.0
## Rigidez en la punta como fracción de Base Stiffness. Menor deja el pompón más suelto y colgante. En vivo.
@export_range(0.0, 1.0, 0.01) var tip_stiffness_ratio := 0.22
## Multiplicador de la gravedad del proyecto sobre la cola. Mayor la hace colgar más. En vivo.
@export_range(0.0, 3.0, 0.05) var gravity_scale := 0.8
## Pérdida de velocidad por segundo (0–1). Mayor calma el balanceo antes; menor deja que oscile. En vivo.
@export_range(0.0, 1.0, 0.01) var damping := 0.2
## Arrastre del aire: cuánto se queda atrás la cola al correr o planear. Mayor la hace ondear más hacia atrás. En vivo.
@export_range(0.0, 20.0, 0.1) var air_drag := 0.7
## Fracción del movimiento de la cabeza que la cola sigue al instante. 1 la lleva rígida; menor deja más inercia. En vivo.
@export_range(0.0, 1.0, 0.01) var motion_follow := 0.55
## Límite de velocidad de la cola en m/s para evitar latigazos tras teletransportes o caídas. En vivo.
@export_range(1.0, 60.0, 0.5, "suffix:m/s") var max_speed := 18.0
## Radio de la esfera de colisión de la cabeza como fracción de Opening Radius. La cola no la atraviesa. En vivo.
@export_range(0.0, 3.0, 0.05) var head_collision_scale := 1.15
## Iteraciones de restricciones por paso. Mayor mantiene mejor el largo de la tela; coste pequeño. En vivo.
@export_range(1, 8, 1) var solver_iterations := 3

@export_group("Suavizado y subdivisiones")
## Facetas planas low-poly como la ardilla. Apagado suaviza las normales (aspecto liso). Regenera.
@export var faceted := true:
	set(value): faceted = value; emit_changed()
## Anillos de la tela a lo largo de la cola. Pocos mantienen el estilo low-poly; más suavizan la curva. Regenera.
@export_range(4, 96, 1) var body_rings := 21:
	set(value): body_rings = value; emit_changed()
## Lados de cada anillo de la tela. Regenera.
@export_range(5, 48, 1) var radial_segments := 14:
	set(value): radial_segments = value; emit_changed()
## Divisiones alrededor del ribete. Usa un múltiplo de Brim Puffs para almohadillas regulares. Regenera.
@export_range(8, 160, 1) var brim_segments := 48:
	set(value): brim_segments = value; emit_changed()
## Divisiones de la sección del ribete. Regenera.
@export_range(4, 32, 1) var brim_tube_segments := 7:
	set(value): brim_tube_segments = value; emit_changed()
## Divisiones de latitud del pompón (la longitud usa el doble). Regenera.
@export_range(3, 32, 1) var pompom_rings := 5:
	set(value): pompom_rings = value; emit_changed()
