@tool
class_name GreenHatStyle
extends Resource
## Forma y física de green hat. Unidades en metros; cambios agrupados por el Live Preview.
## El gorro en reposo es un cono recto: la curva de la cola no se dibuja, la produce la gravedad
## sobre la mitad trasera con una simulación de cadena. La misma física lo mueve al jugar.

@export_group("Borde")
## Radios exteriores X/Z en metros. Aumentar envuelve una cabeza mayor. Live Preview.
@export var brim_radii := Vector2(0.57, 0.54)
## Alto total del borde acolchado en metros. Mayor baja el borde hacia los ojos. Live Preview.
@export_range(0.08, 0.5, 0.01) var brim_height := 0.26
## Grosor radial del borde en metros. Mayor crea un rollo más grueso. Live Preview.
@export_range(0.03, 0.2, 0.005) var brim_thickness := 0.1

@export_group("Cono")
## Largo del cono recto antes de que la gravedad lo doble, en metros desde el borde. Mayor alarga la cola. Live Preview.
@export_range(0.3, 2.5, 0.01) var cone_length := 1.5
## Inclinación del cono hacia atrás en reposo, en grados. Decide hacia dónde se dobla la cola con la gravedad. Live Preview.
@export_range(-20, 60, 1) var backward_angle_degrees := 24.0
## Dirección de la inclinación alrededor de Y, en grados: 0 es atrás; ±90 es lateral. Live Preview.
@export_range(-180, 180, 1) var tip_direction_degrees := 0.0
## Posición de todo lo verde (copa, cola y pompón) respecto al borde blanco, en metros locales del gorro.
## X lateral, Y sube o hunde la copa dentro del borde, Z la lleva hacia atrás (+) o hacia la cara (-).
## Útil para recentrar la copa al inclinarla mucho con Backward Angle Degrees. Live Preview.
@export var crown_offset := Vector3.ZERO
## Abombado de la copa sobre el borde, como fracción del radio. 0 afina en línea recta; 0,2 da una cúpula llena. Live Preview.
@export_range(0.0, 0.5, 0.01) var crown_fullness := 0.2
## Radio de la punta como fracción del radio de la base. Menor deja la cola más fina antes del pompón. Live Preview.
@export_range(0.03, 0.5, 0.01) var tip_ratio := 0.08
## Curva del estrechamiento. Menor de 1 adelgaza pronto (cola larga y fina); mayor conserva volumen. Live Preview.
@export_range(0.3, 2.5, 0.05) var taper_power := 0.75
## Amplitud de pliegues anchos en metros. 0 produce tela lisa. Live Preview.
@export_range(0, 0.08, 0.002) var folds := 0.004

@export_group("Gravedad y física de la cola")
## Simula la cola: gravedad en reposo e inercia, aire y giros al moverse. Apagado deja el cono recto. En vivo.
@export var tail_physics := true
## Largo de la copa (0–1 del largo) desde el borde: el cuerpo verde que abraza la cabeza. La cola empieza aquí. Live Preview.
@export_range(0.0, 0.9, 0.01) var rigid_ratio := 0.36
## Cuánto del movimiento de la cola se transmite a la copa (0–1). 0 deja la copa totalmente rígida; 1 la deja
## ceder como una tela el doble de rígida que la cola junto a ella. El borde nunca se mueve. En vivo.
@export_range(0.0, 1.0, 0.01) var crown_transmission := 0.5
## Transición de esa transmisión a lo largo de la copa. 1 la reparte linealmente desde la cola hasta el borde;
## mayor la concentra cerca de la cola y deja rígida la parte baja; menor la extiende hacia el borde. En vivo.
@export_range(0.2, 6.0, 0.05) var crown_transition := 2.0
## Huesos de la cola. Más da una curva más suave; coste pequeño de CPU. Live Preview.
@export_range(4, 20, 1) var tail_bones := 14
## Un solo doblez: la cola es rígida salvo en una zona blanda, así nunca aparecen dos pliegues.
## Rigideces relativas al peso que sostiene cada articulación (con 1 la tela horizontal se dobla ~57°).
## Rigidez de la cola fuera del doblez. Mayor la mantiene recta antes y después del pliegue y la hace
## balancearse menos; menor la deja más suelta. También es la base de la rigidez transmitida a la copa. En vivo.
@export_range(1.0, 40.0, 0.5) var tail_stiffness := 12.0
## Dónde está el doblez, de 0 (justo tras la copa) a 1 (junto al pompón). En vivo.
@export_range(0.0, 1.0, 0.01) var fold_position := 0.3
## Qué tan pronunciado es el doblez (0–1). 0 no dobla (cola casi recta); 1 lo deja caer casi en vertical. En vivo.
@export_range(0.0, 1.0, 0.01) var fold_strength := 0.9
## Anchura del doblez (0–1 de la cola blanda). Menor da un pliegue corto y marcado; mayor, una curva amplia. En vivo.
@export_range(0.05, 1.0, 0.01) var fold_spread := 0.8
## Ablandamiento extra de la punta (0–1). 0 evita un segundo pliegue; mayor deja la punta colgar sola. En vivo.
@export_range(0.0, 1.0, 0.01) var tip_softness := 0.0
## Peso del pompón respecto a un tramo de la cola. Mayor tira más de la punta hacia abajo. En vivo.
@export_range(0.0, 10.0, 0.1) var pom_weight := 1.0
## Multiplicador de la gravedad del proyecto. Mayor dobla y cuelga más la cola. En vivo.
@export_range(0.0, 3.0, 0.05) var gravity_scale := 1.0
## Amortiguación relativa a la crítica. 1 detiene el balanceo sin rebotar; menor deja oscilar (0,3 rebota
## varias veces); mayor de 1 lo frena más lento, como tela pesada. En vivo.
@export_range(0.0, 3.0, 0.01) var damping_ratio := 1.0
## Arrastre del aire: cuánto se queda atrás la cola al correr o planear. En vivo.
@export_range(0.0, 10.0, 0.1) var air_drag := 1.2
## Inercia: cuánto empujan a la cola las aceleraciones y giros de la cabeza. 0 la lleva rígida; 1 es físico. En vivo.
@export_range(0.0, 2.0, 0.05) var inertia := 1.0
## Límite de la aceleración de inercia en m/s². Evita que aterrizajes o teletransportes lancen la cola; mayor permite sacudidas más fuertes. En vivo.
@export_range(1.0, 200.0, 1.0, "suffix:m/s²") var max_inertia := 30.0
## Ángulo máximo de cada articulación de la cola, en grados. Evita pliegues imposibles. En vivo.
@export_range(10.0, 90.0, 1.0, "suffix:°") var max_bend_degrees := 55.0
## Centro de la esfera de colisión de la cabeza y el borde, en metros locales del gorro. La cola descansa sobre ella. En vivo.
@export var collision_center := Vector3(0, -0.32, 0)
## Radio de la esfera de colisión, en metros. Debe cubrir la cabeza y el borde para que la cola no los atraviese. En vivo.
@export_range(0.0, 1.5, 0.01) var collision_radius := 0.66

## Grosor de la tela (fracción de su radio) que se mantiene fuera de la esfera de la cabeza. 1 evita que la
## superficie verde atraviese la cabeza; menor permite que la tela apoye más pegada. En vivo.
@export_range(0.0, 1.5, 0.05) var collision_margin := 1.0
@export_group("Pompón")
## Radio del pompón en metros. Mayor destaca en la silueta posterior. Live Preview.
@export_range(0.06, 0.3, 0.005) var pom_radius := 0.15
## Separación del pompón respecto a la punta, a lo largo de la cola, en metros. Live Preview.
@export_range(-0.1, 0.4, 0.01) var pom_backward_offset := 0.06
## Escala por eje del pompón. Live Preview.
@export var pom_scale := Vector3(1.0, 1.05, 1.0)

@export_group("Acabado")
## Color del cuerpo. Live Preview; sin texturas de tela.
@export var body_color := Color("456447")
## Blanco cálido del borde y pompón. Live Preview; sin pelo fotográfico.
@export var trim_color := Color("eee5cf")
## Rugosidad: mayor reduce brillo. Live Preview.
@export_range(0.6, 1.0, 0.01) var roughness := 0.94
## Segmentos alrededor de la forma. Mayor suaviza y aumenta geometría. Live Preview.
@export_range(16, 64, 4) var segments := 32
## Anillos a lo largo del cono. Más suaviza la curva de la cola; coste de vértices. Live Preview.
@export_range(12, 96, 1) var length_rings := 48

## Valores que obligan a regenerar la malla (la física se lee en vivo).
func signature() -> Array:
	return [brim_radii, brim_height, brim_thickness, crown_offset, cone_length, backward_angle_degrees, tip_direction_degrees, crown_fullness, tip_ratio, taper_power, folds, rigid_ratio, tail_bones, pom_radius, pom_backward_offset, pom_scale, body_color, trim_color, roughness, segments, length_rings]
