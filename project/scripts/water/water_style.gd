@tool
class_name WaterStyle
extends Resource
## Aspecto del agua compartido por rios, lagos y cascadas (WaterRiver, WaterLake). Varios cuerpos de agua pueden usar el
## mismo estilo; duplica el recurso (Make Unique) para dar a uno un aspecto propio. Todo se aplica en vivo, sin regenerar.
## El agua lee lo que hay detras (pantalla y profundidad): el fondo se ve en lo poco profundo y la espuma aparece sola donde
## algo cruza la superficie (orillas, piedras, el jugador). Guia: docs/water.md.

@export_group("Color")
## Color del agua donde es poco profunda (orillas, vados). Mas claro y verdoso da agua tropical; mas gris, agua de montana.
@export var shallow_color := Color(0.40, 0.70, 0.88):
	set(value):
		shallow_color = value
		emit_changed()
## Color del agua profunda (centro del cauce, fondo del lago). Mas oscuro hace el agua mas densa y misteriosa.
@export var deep_color := Color(0.13, 0.38, 0.75):
	set(value):
		deep_color = value
		emit_changed()
## Metros de profundidad para pasar casi del todo al color profundo. Menor oscurece el agua enseguida; mayor la mantiene
## clara aunque sea honda.
@export_range(0.1, 10.0, 0.05, "suffix:m") var depth_scale := 1.2:
	set(value):
		depth_scale = value
		emit_changed()
## Transparencia: metros a los que el fondo deja de verse. Mayor = agua cristalina (se ven piedras y arena hondas); menor =
## agua turbia u opaca.
@export_range(0.05, 10.0, 0.05, "suffix:m") var clarity := 0.55:
	set(value):
		clarity = value
		emit_changed()
## 0-1: cuanto tine el agua el fondo que se ve a traves. 0 deja el fondo con su color; 1 lo tine del todo con el color del agua.
@export_range(0.0, 1.0, 0.01) var bed_tint := 0.6:
	set(value):
		bed_tint = value
		emit_changed()
## 0-1: cuanto cambia el tono con la profundidad. 1 = orillas claras y centro oscuro (Shallow -> Deep Color, el fondo se
## ve en lo poco profundo); 0 = todo el agua con el mismo tono, el de Uniform Depth, sin cambios en uniones ni zanjas del
## cauce. La espuma de orilla no cambia. En vivo.
@export_range(0.0, 1.0, 0.01) var depth_tone_amount := 1.0:
	set(value):
		depth_tone_amount = value
		emit_changed()
## Profundidad en metros cuyo tono usa todo el agua cuando Depth Tone Amount es 0 (mezcla con el real entre 0 y 1). Menor =
## tono claro y transparente (Shallow Color); mayor = tono profundo (Deep Color). En vivo.
@export_range(0.0, 10.0, 0.05, "suffix:m") var uniform_depth := 1.2:
	set(value):
		uniform_depth = value
		emit_changed()
## 0-1: luz propia del agua. Mayor la mantiene brillante a la sombra de cliffs y arboles; 0 se oscurece como el terreno.
@export_range(0.0, 1.0, 0.01) var self_light := 0.25:
	set(value):
		self_light = value
		emit_changed()

@export_group("Superficie")
## Tamano de las ondas en metros. Mayor = ondulacion amplia y tranquila; menor = superficie picada.
@export_range(0.2, 10.0, 0.05, "suffix:m") var wave_scale := 2.0:
	set(value):
		wave_scale = value
		emit_changed()
## Fuerza de las ondas en la luz, los reflejos y la refraccion. 0 = espejo liso.
@export_range(0.0, 2.0, 0.01) var wave_strength := 0.35:
	set(value):
		wave_strength = value
		emit_changed()
## Velocidad con que cambian las ondas (tambien en lagos, sin corriente).
@export_range(0.0, 3.0, 0.01) var wave_speed := 0.4:
	set(value):
		wave_speed = value
		emit_changed()
## Cuanto deforman las ondas el fondo visto a traves del agua. 0 = sin distorsion. Valores altos pueden mostrar bordes raros
## junto a objetos que cruzan la superficie.
@export_range(0.0, 0.15, 0.001) var refraction := 0.03:
	set(value):
		refraction = value
		emit_changed()

@export_group("Corriente")
## Velocidad de la corriente en m/s (solo rios; los lagos no fluyen). Mueve ondas, destellos y espuma rio abajo. En los
## rapidos se acelera sola. Tambien la usara el nado para empujar al jugador.
@export_range(0.0, 8.0, 0.05, "suffix:m/s") var flow_speed := 1.2:
	set(value):
		flow_speed = value
		emit_changed()
## Estiramiento de las ondas en la direccion del rio. 1 = redondas; mayor = vetas alargadas que leen la corriente.
@export_range(1.0, 6.0, 0.05) var flow_stretch := 1.8:
	set(value):
		flow_stretch = value
		emit_changed()

@export_group("Destellos")
## Color de los destellos (reflejos de sol estilizados).
@export var sparkle_color := Color(1.0, 1.0, 1.0):
	set(value):
		sparkle_color = value
		emit_changed()
## Tamano de las manchas de destello en metros. Mayor = manchas grandes; menor = chispas finas.
@export_range(0.1, 5.0, 0.01, "suffix:m") var sparkle_scale := 0.7:
	set(value):
		sparkle_scale = value
		emit_changed()
## 0-1: cuanta superficie cubren los destellos. 0 = ninguno; 0,2 = salpicado; 0,5 = muy brillante.
@export_range(0.0, 1.0, 0.01) var sparkle_amount := 0.12:
	set(value):
		sparkle_amount = value
		emit_changed()
## Suavidad del borde de cada destello. Menor = borde nitido de dibujo; mayor = brillo difuso.
@export_range(0.001, 0.5, 0.001) var sparkle_softness := 0.06:
	set(value):
		sparkle_softness = value
		emit_changed()
## Intensidad de los destellos. Mayor de 1 los hace brillar por encima del blanco (util con mucha sombra).
@export_range(0.0, 3.0, 0.01) var sparkle_strength := 1.0:
	set(value):
		sparkle_strength = value
		emit_changed()
## Velocidad del parpadeo de los destellos. 0 = fijos (solo se mueven con la corriente).
@export_range(0.0, 10.0, 0.05) var sparkle_twinkle := 1.5:
	set(value):
		sparkle_twinkle = value
		emit_changed()

@export_group("Crestas")
## Color de las crestas: la red de lineas claras y onduladas que cubre el agua y avanza con la corriente (el rasgo principal
## del estilo). Blanco azulado por defecto.
@export var crest_color := Color(0.82, 0.93, 1.0):
	set(value):
		crest_color = value
		emit_changed()
## Tamano en metros del dibujo de las crestas. Menor = agua picada y densa; mayor = ondas amplias. Se suma una
## segunda capa a la mitad de tamano.
@export_range(0.1, 6.0, 0.01, "suffix:m") var crest_scale := 0.9:
	set(value):
		crest_scale = value
		emit_changed()
## Grosor de las lineas de cresta. Mayor = trazos gruesos de dibujo.
@export_range(0.0, 0.5, 0.005) var crest_width := 0.035:
	set(value):
		crest_width = value
		emit_changed()
## Suavidad del borde de las lineas. 0 = trazo nitido; mayor = brillo difuso.
@export_range(0.001, 0.5, 0.001) var crest_softness := 0.04:
	set(value):
		crest_softness = value
		emit_changed()
## 0-1: cuanta superficie tiene crestas (el resto queda liso). 1 = red completa; 0,4 = parches sueltos.
@export_range(0.0, 1.0, 0.01) var crest_amount := 0.75:
	set(value):
		crest_amount = value
		emit_changed()
## Intensidad de las crestas. 0 las desactiva.
@export_range(0.0, 2.0, 0.01) var crest_strength := 0.9:
	set(value):
		crest_strength = value
		emit_changed()
## Estiramiento a lo ancho del rio: mayor = crestas mas transversales a la corriente, como olas pequenas.
@export_range(0.25, 5.0, 0.05) var crest_stretch := 1.8:
	set(value):
		crest_stretch = value
		emit_changed()
## Ondulacion de las lineas. 0 = curvas suaves; mayor = trazos serpenteantes y retorcidos.
@export_range(0.0, 1.5, 0.01) var crest_wobble := 0.6:
	set(value):
		crest_wobble = value
		emit_changed()
## Velocidad con que las crestas cambian de forma (ademas de avanzar con la corriente).
@export_range(0.0, 4.0, 0.01) var crest_speed := 0.6:
	set(value):
		crest_speed = value
		emit_changed()
## 0-1: oscurece los valles entre crestas para dar variacion de azules.
@export_range(0.0, 1.0, 0.01) var trough_shade := 0.35:
	set(value):
		trough_shade = value
		emit_changed()

@export_group("Espuma de orilla")
## Color de la espuma (orillas, piedras, rapidos, base de cascadas).
@export var foam_color := Color(0.95, 0.98, 1.0):
	set(value):
		foam_color = value
		emit_changed()
## Ancho de la espuma en metros de profundidad: aparece donde el agua tiene menos que esto. Mayor = franja ancha en orillas
## y alrededor de piedras.
@export_range(0.0, 2.0, 0.01, "suffix:m") var foam_width := 0.25:
	set(value):
		foam_width = value
		emit_changed()
## 0-1: suavidad del borde de la espuma. 0 = borde de dibujo; 1 = muy difusa.
@export_range(0.0, 1.0, 0.01) var foam_softness := 0.5:
	set(value):
		foam_softness = value
		emit_changed()
## Tamano en metros de las manchas que rompen la espuma.
@export_range(0.05, 5.0, 0.01, "suffix:m") var foam_noise_scale := 0.6:
	set(value):
		foam_noise_scale = value
		emit_changed()
## 0-1: cuanto se rompe la espuma en manchas. 0 = franja continua; 1 = muy irregular.
@export_range(0.0, 1.0, 0.01) var foam_breakup := 0.65:
	set(value):
		foam_breakup = value
		emit_changed()
## 0-1: opacidad de la espuma.
@export_range(0.0, 1.0, 0.01) var foam_strength := 0.7:
	set(value):
		foam_strength = value
		emit_changed()

@export_group("Rapidos y cascadas")
## Pendiente del rio en grados donde empiezan los rapidos (mas ondas, corriente mas rapida, espuma).
@export_range(0.0, 45.0, 0.5, "suffix:degrees") var rapids_start_angle := 4.0:
	set(value):
		rapids_start_angle = value
		emit_changed()
## Pendiente en grados con rapidos completos. Debe ser mayor que Rapids Start Angle.
@export_range(0.5, 60.0, 0.5, "suffix:degrees") var rapids_full_angle := 15.0:
	set(value):
		rapids_full_angle = value
		emit_changed()
## Pendiente en grados donde el agua empieza a verse como cascada (cortina blanca con vetas).
@export_range(10.0, 85.0, 0.5, "suffix:degrees") var fall_start_angle := 35.0:
	set(value):
		fall_start_angle = value
		emit_changed()
## Pendiente en grados con cascada completa. Debe ser mayor que Fall Start Angle.
@export_range(15.0, 90.0, 0.5, "suffix:degrees") var fall_full_angle := 60.0:
	set(value):
		fall_full_angle = value
		emit_changed()
## Color de la cortina de la cascada.
@export var fall_color := Color(0.78, 0.90, 0.98):
	set(value):
		fall_color = value
		emit_changed()
## Densidad de las vetas verticales de la cascada. Mayor = vetas finas.
@export_range(0.1, 8.0, 0.05) var fall_streak_scale := 3.0:
	set(value):
		fall_streak_scale = value
		emit_changed()
## Velocidad de caida de las vetas en m/s.
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var fall_speed := 6.0:
	set(value):
		fall_speed = value
		emit_changed()
## 0-2: espuma en los rapidos.
@export_range(0.0, 2.0, 0.01) var rapids_foam := 0.6:
	set(value):
		rapids_foam = value
		emit_changed()
## 0-2: espuma en el borde de arriba y en la base de una cascada (donde cambia la pendiente).
@export_range(0.0, 2.0, 0.01) var break_foam := 1.0:
	set(value):
		break_foam = value
		emit_changed()

@export_group("Reflejo")
## Color del cielo reflejado al mirar el agua de lado.
@export var sky_color := Color(0.75, 0.88, 1.0):
	set(value):
		sky_color = value
		emit_changed()
## 0-1: fuerza del reflejo de cielo en angulos rasantes. 0 = sin reflejo.
@export_range(0.0, 1.0, 0.01) var fresnel_strength := 0.2:
	set(value):
		fresnel_strength = value
		emit_changed()
## Lo rasante que debe ser la mirada para reflejar. Mayor = solo muy de lado.
@export_range(0.5, 10.0, 0.1) var fresnel_power := 4.0:
	set(value):
		fresnel_power = value
		emit_changed()
## 0-1: brillo especular del sol sobre las ondas.
@export_range(0.0, 1.0, 0.01) var specular := 0.5:
	set(value):
		specular = value
		emit_changed()
## 0-1: rugosidad. Menor = reflejo del sol pequeno y nitido; mayor = brillo amplio y suave.
@export_range(0.0, 1.0, 0.01) var roughness := 0.08:
	set(value):
		roughness = value
		emit_changed()

@export_group("Causticas")
## Color de las causticas (luz ondulante sobre el fondo).
@export var caustic_color := Color(0.85, 1.0, 1.0):
	set(value):
		caustic_color = value
		emit_changed()
## Tamano en metros de las celdas de luz del fondo.
@export_range(0.1, 6.0, 0.01, "suffix:m") var caustic_scale := 1.2:
	set(value):
		caustic_scale = value
		emit_changed()
## Velocidad de las causticas.
@export_range(0.0, 4.0, 0.01) var caustic_speed := 0.6:
	set(value):
		caustic_speed = value
		emit_changed()
## Intensidad de las causticas. 0 = desactivadas. Se apagan solas con la profundidad.
@export_range(0.0, 2.0, 0.01) var caustic_strength := 0.35:
	set(value):
		caustic_strength = value
		emit_changed()

@export_group("Distancia")
## Metros a la camara desde los que el agua se simplifica (menos refraccion y transparencia, ondas mas suaves; del todo a
## 1,5 veces). Ayuda a que el agua lejana combine con el desenfoque de la camara. Mayor conserva detalle mas lejos.
@export_range(5.0, 400.0, 1.0, "suffix:m") var far_distance := 40.0:
	set(value):
		far_distance = value
		emit_changed()

@export_group("Bajo el agua")
## Color de la niebla al bucear, en lo lejano y hacia el fondo. Mas oscuro = agua mas honda y misteriosa. Lo usa la camara
## cuando queda bajo esta agua. En vivo.
@export var underwater_color := Color(0.10, 0.33, 0.55):
	set(value):
		underwater_color = value
		emit_changed()
## Color de la niebla mirando hacia la superficie, por donde entra la luz. En vivo.
@export var underwater_light_color := Color(0.42, 0.74, 0.90):
	set(value):
		underwater_light_color = value
		emit_changed()
## Metros bajo el agua a los que la niebla tapa casi todo; lo cercano (el jugador) queda casi limpio. Mayor = se ve mas lejos al bucear (agua cristalina); menor =
## agua turbia. Independiente de Clarity, que es la transparencia vista desde fuera. En vivo.
@export_range(0.5, 60.0, 0.1, "suffix:m") var underwater_fog_distance := 14.0:
	set(value):
		underwater_fog_distance = value
		emit_changed()
## Tinte minimo junto a la camara (0-1): cuanto se colorea lo que esta pegado a ella. 0 = sin tinte cerca. En vivo.
@export_range(0.0, 1.0, 0.01) var underwater_tint := 0.12:
	set(value):
		underwater_tint = value
		emit_changed()
## Opacidad maxima de la niebla (0-1). 1 tapa del todo lo lejano; menor deja ver siluetas a cualquier distancia. En vivo.
@export_range(0.0, 1.0, 0.01) var underwater_max_fog := 0.92:
	set(value):
		underwater_max_fog = value
		emit_changed()
## Color de la superficie vista desde abajo, fuera de la ventana de luz. En vivo.
@export var underwater_surface_color := Color(0.30, 0.62, 0.80):
	set(value):
		underwater_surface_color = value
		emit_changed()
## Inclinacion (0-1) a partir de la cual, mirando hacia arriba, la superficie deja ver el cielo (ventana de Snell). Menor =
## ventana mas ancha. En vivo.
@export_range(0.0, 1.0, 0.01) var underwater_window := 0.6:
	set(value):
		underwater_window = value
		emit_changed()

@export_group("Buceador visible")
## Solo afecta al jugador mientras bucea (el resto del agua no cambia): metros de agua a traves de los que aun se le ve
## claro desde fuera. Mayor = se ve nitido aunque bucee hondo; menor = se pierde enseguida. La camara lo activa con Reveal
## Swimmer. En vivo.
@export_range(0.05, 20.0, 0.05, "suffix:m") var swimmer_clarity := 8.0:
	set(value):
		swimmer_clarity = value
		emit_changed()
## Cuanto tine el agua al jugador sumergido (0-1). 0 = colores originales; 1 = muy azul. Aumenta un poco con la
## profundidad. En vivo.
@export_range(0.0, 1.0, 0.01) var swimmer_tint := 0.4:
	set(value):
		swimmer_tint = value
		emit_changed()

## Writes every value into a water ShaderMaterial (degrees become slope fractions: 90 degrees = 1).
func apply(material: ShaderMaterial) -> void:
	var values := {
		"shallow_color": shallow_color, "deep_color": deep_color, "depth_tone_amount": depth_tone_amount,
		"uniform_depth": uniform_depth, "depth_scale": depth_scale, "clarity": clarity,
		"bed_tint": bed_tint, "self_light": self_light, "wave_scale": wave_scale, "wave_strength": wave_strength,
		"wave_speed": wave_speed, "refraction": refraction, "flow_speed": flow_speed, "flow_stretch": flow_stretch,
		"sparkle_color": sparkle_color, "sparkle_scale": sparkle_scale, "sparkle_amount": sparkle_amount,
		"sparkle_softness": sparkle_softness, "sparkle_strength": sparkle_strength, "sparkle_twinkle": sparkle_twinkle,
		"crest_color": crest_color, "crest_scale": crest_scale, "crest_width": crest_width, "crest_softness": crest_softness,
		"crest_amount": crest_amount, "crest_strength": crest_strength, "crest_stretch": crest_stretch,
		"crest_wobble": crest_wobble, "crest_speed": crest_speed, "trough_shade": trough_shade,
		"foam_color": foam_color, "foam_width": foam_width, "foam_softness": foam_softness,
		"foam_noise_scale": foam_noise_scale, "foam_breakup": foam_breakup, "foam_strength": foam_strength,
		"rapids_start": rapids_start_angle / 90.0, "rapids_full": maxf(rapids_full_angle, rapids_start_angle + 0.5) / 90.0,
		"fall_start": fall_start_angle / 90.0, "fall_full": maxf(fall_full_angle, fall_start_angle + 0.5) / 90.0,
		"fall_color": fall_color, "fall_streak_scale": fall_streak_scale, "fall_speed": fall_speed,
		"rapids_foam": rapids_foam, "break_foam": break_foam, "sky_color": sky_color,
		"fresnel_strength": fresnel_strength, "fresnel_power": fresnel_power, "specular_amount": specular,
		"roughness_amount": roughness, "caustic_color": caustic_color, "caustic_scale": caustic_scale,
		"caustic_speed": caustic_speed, "caustic_strength": caustic_strength, "far_distance": far_distance,
		"under_surface_color": underwater_surface_color, "under_window": underwater_window,
	}
	for parameter: String in values:
		material.set_shader_parameter(parameter, values[parameter])
