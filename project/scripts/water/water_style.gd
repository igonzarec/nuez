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

## 0-1: rios mas claros junto a las orillas y mas azules en el centro del cauce (no depende de la profundidad, asi que
## las uniones con lagos no cambian). 0 = mismo tono en todo el ancho. En vivo.
@export_range(0.0, 1.0, 0.01) var river_edge_light := 0.35:
	set(value):
		river_edge_light = value
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

@export_group("Lineas de orilla")
## Segunda linea fina de espuma, discontinua, separada de la orilla hacia el agua (la primera es la espuma de orilla).
## 0 = sin segunda linea. En vivo.
@export_range(0.0, 1.0, 0.01) var shore_line_strength := 0.7:
	set(value):
		shore_line_strength = value
		emit_changed()
## Metros de profundidad del agua donde va la segunda linea (mayor = mas lejos de la orilla). En vivo.
@export_range(0.05, 2.0, 0.01, "suffix:m") var shore_line_depth := 0.35:
	set(value):
		shore_line_depth = value
		emit_changed()
## Grosor de la segunda linea, en metros de profundidad. En vivo.
@export_range(0.01, 0.5, 0.005, "suffix:m") var shore_line_width := 0.05:
	set(value):
		shore_line_width = value
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
## Color base de la cortina de la cascada (el azul del agua cayendo). En vivo.
@export var fall_color := Color(0.45, 0.67, 0.88):
	set(value):
		fall_color = value
		emit_changed()
## Color de la franja del borde y de las lineas claras de la cortina. En vivo.
@export var fall_streak_color := Color(0.86, 0.94, 1.0):
	set(value):
		fall_streak_color = value
		emit_changed()
## Color de las manchas oscuras y de los lados de la cortina (le da volumen redondeado). En vivo.
@export var fall_shadow_color := Color(0.3, 0.52, 0.78):
	set(value):
		fall_shadow_color = value
		emit_changed()
## Largo de las manchas oscuras que bajan con el agua (menor = mas largas). En vivo.
@export_range(0.01, 1.0, 0.005) var fall_streak_length := 0.07:
	set(value):
		fall_streak_length = value
		emit_changed()
## 0-1: cuanto del color propio de la cascada (Fall Color) se mezcla con el del rio. 0 = la cortina es el mismo agua
## del rio cayendo (sus colores y crestas), mas oscura abajo; 1 = solo Fall Color. En vivo.
@export_range(0.0, 1.0, 0.01) var fall_color_mix := 0.25:
	set(value):
		fall_color_mix = value
		emit_changed()
## 0-1: crestas del rio que siguen sobre la cortina, estiradas por la caida. En vivo.
@export_range(0.0, 1.0, 0.01) var fall_crests := 0.6:
	set(value):
		fall_crests = value
		emit_changed()
## 0-1: transparencia de la cortina: cuanto se ve el acantilado detras, tenido del azul de la cascada. 0 = opaca.
## En vivo.
@export_range(0.0, 1.0, 0.01) var fall_transparency := 0.3:
	set(value):
		fall_transparency = value
		emit_changed()
## 0-1: reflejo del cielo y brillo del sol sobre la cortina. Es el brillo que aparece justo debajo del borde, donde la
## cortina sale casi horizontal y se ve en angulo rasante. 1 = como el resto del agua (Fresnel Strength, Specular);
## 0 = la cortina sin reflejos. En vivo.
@export_range(0.0, 1.0, 0.01) var fall_reflection := 1.0:
	set(value):
		fall_reflection = value
		emit_changed()
## 0-1: cuanto ondulan de lado las lineas claras y las manchas oscuras. 0 = rectas. En vivo.
@export_range(0.0, 1.0, 0.01) var fall_streak_wave := 0.3:
	set(value):
		fall_streak_wave = value
		emit_changed()
## 0-1: suavidad del borde de las lineas claras y de las manchas. Menor = trazos duros de dibujo; mayor = degradados.
## En vivo.
@export_range(0.0, 1.0, 0.01) var fall_streak_softness := 0.35:
	set(value):
		fall_streak_softness = value
		emit_changed()
## Escala de las manchas oscuras de la cortina. Mayor = manchas mas finas. En vivo.
@export_range(0.1, 8.0, 0.05) var fall_streak_scale := 1.5:
	set(value):
		fall_streak_scale = value
		emit_changed()
## Velocidad de caida de las vetas en m/s.
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var fall_speed := 6.0:
	set(value):
		fall_speed = value
		emit_changed()
## 0-2: espuma en los rapidos.
@export_range(0.0, 2.0, 0.01) var rapids_foam := 0.2:
	set(value):
		rapids_foam = value
		emit_changed()
## 0-2: espuma en el borde de arriba y en la base de una cascada (donde cambia la pendiente).
@export_range(0.0, 2.0, 0.01) var break_foam := 1.0:
	set(value):
		break_foam = value
		emit_changed()


@export_subgroup("Cascada · franja del borde")
## 0-1: opacidad de la franja blanca del borde (donde el agua se asoma y empieza a caer). Menor = mas transparente: deja
## ver Fall Color (el mismo a ambos lados del borde, sin linea en el pliegue). 0 = sin franja. En vivo.
@export_range(0.0, 1.0, 0.01) var fall_lip_band := 0.85:
	set(value):
		fall_lip_band = value
		emit_changed()
## Metros antes del borde en que el agua del rio se vuelve opaca y deja de reflejar el cielo (rapida y con aire): el
## borde del acantilado bajo el agua no se ve como una linea oscura, y los picos de la franja sobre el rio contrastan
## igual que sus muescas sobre la cortina, se mire desde donde se mire. 0 = agua normal hasta el borde. En vivo.
@export_range(0.0, 6.0, 0.05, "suffix:m") var fall_lip_opaque := 1.5:
	set(value):
		fall_lip_opaque = value
		emit_changed()
## 0-1: transparencia real de la franja: deja ver el agua de debajo (sus crestas y su movimiento). Distinto de Fall Lip
## Band, que la mezcla con un color uniforme. Con valores altos puede notarse el pliegue del borde, porque el agua es
## distinta a cada lado. 0 = opaca. En vivo.
@export_range(0.0, 1.0, 0.01) var fall_lip_band_transparency := 0.0:
	set(value):
		fall_lip_band_transparency = value
		emit_changed()
## Color de la franja y de sus picos (las lineas de la cortina usan Fall Streak Color). En vivo.
@export var fall_lip_band_color := Color(0.86, 0.94, 1.0):
	set(value):
		fall_lip_band_color = value
		emit_changed()
## Brillo de la franja y de las lineas claras: color plano, sin luz ni reflejos, igual a ambos lados del borde.
## 1 = el color tal cual; menor = mas apagadas. En vivo.
@export_range(0.0, 1.5, 0.01) var fall_marks_light := 1.15:
	set(value):
		fall_marks_light = value
		emit_changed()
## 0-1: suavidad de los bordes de la franja y de sus muescas. 0 = recortados; 1 = difuminados. En vivo.
@export_range(0.0, 1.0, 0.01) var fall_lip_band_softness := 0.3:
	set(value):
		fall_lip_band_softness = value
		emit_changed()
## Tamano de las irregularidades de los bordes: mayor = ondulaciones mas pequenas y seguidas; menor = mas amplias. En vivo.
@export_range(0.2, 4.0, 0.05) var fall_lip_band_ragged_scale := 1.0:
	set(value):
		fall_lip_band_ragged_scale = value
		emit_changed()
## 0-1: cuanto respira el grosor de la franja con el tiempo, distinto a lo ancho. 0 = grosor fijo. En vivo.
@export_range(0.0, 1.0, 0.01) var fall_lip_band_pulse := 0.25:
	set(value):
		fall_lip_band_pulse = value
		emit_changed()
## Velocidad con que la franja, sus muescas y sus picos cambian de forma. 0 = quietos. En vivo.
@export_range(0.0, 5.0, 0.05) var fall_lip_band_speed := 0.8:
	set(value):
		fall_lip_band_speed = value
		emit_changed()

@export_subgroup("Cascada · franja · borde de abajo")
## Grosor de la franja por debajo del borde, en metros sobre la cortina. Junto con Band Up decide el grosor del
## centro blanco. En vivo.
@export_range(0.0, 6.0, 0.01, "suffix:m") var fall_lip_band_height := 1.2:
	set(value):
		fall_lip_band_height = value
		emit_changed()
## 0-1: irregularidad de este borde (sube y baja a lo ancho). 0 = recto. En vivo.
@export_range(0.0, 1.0, 0.01) var fall_lip_band_ragged := 0.6:
	set(value):
		fall_lip_band_ragged = value
		emit_changed()
## Forma de este borde: muescas de agua azul que entran en la franja, o picos blancos que salen de ella (misma
## forma, mismo pulso y velocidad). En vivo.
@export_enum("Muescas hacia dentro", "Picos hacia fuera") var fall_lip_bottom_shape := 0:
	set(value):
		fall_lip_bottom_shape = value
		emit_changed()
## 0-1: cuantas muescas o picos tiene este borde. 0 = ninguno. En vivo.
@export_range(0.0, 1.0, 0.01) var fall_lip_bottom_amount := 0.5:
	set(value):
		fall_lip_bottom_amount = value
		emit_changed()
## Largo medio de las muescas o picos de este borde, en metros (varian entre ellos y con el tiempo). Las muescas no
## pasan del grosor de la franja. En vivo.
@export_range(0.0, 6.0, 0.01, "suffix:m") var fall_lip_bottom_size := 0.9:
	set(value):
		fall_lip_bottom_size = value
		emit_changed()
## Ancho medio de cada muesca o pico en su base, en metros. En vivo.
@export_range(0.05, 2.0, 0.01, "suffix:m") var fall_lip_bottom_width := 0.4:
	set(value):
		fall_lip_bottom_width = value
		emit_changed()

@export_subgroup("Cascada · franja · borde de arriba")
## Grosor de la franja por encima del borde, en metros sobre el rio. 0 = empieza en el borde. En vivo.
@export_range(0.0, 6.0, 0.01, "suffix:m") var fall_lip_band_up := 0.25:
	set(value):
		fall_lip_band_up = value
		emit_changed()
## 0-1: irregularidad de este borde. 0 = recto. En vivo.
@export_range(0.0, 1.0, 0.01) var fall_lip_top_ragged := 0.6:
	set(value):
		fall_lip_top_ragged = value
		emit_changed()
## Forma de este borde: muescas de agua azul que entran en la franja, o picos blancos que salen hacia el rio. En vivo.
@export_enum("Muescas hacia dentro", "Picos hacia fuera") var fall_lip_top_shape := 1:
	set(value):
		fall_lip_top_shape = value
		emit_changed()
## 0-1: cuantas muescas o picos tiene este borde. 0 = ninguno. En vivo.
@export_range(0.0, 1.0, 0.01) var fall_lip_top_amount := 0.6:
	set(value):
		fall_lip_top_amount = value
		emit_changed()
## Largo medio de las muescas o picos de este borde, en metros. En vivo.
@export_range(0.0, 6.0, 0.01, "suffix:m") var fall_lip_top_size := 0.8:
	set(value):
		fall_lip_top_size = value
		emit_changed()
## Ancho medio de cada muesca o pico en su base, en metros. En vivo.
@export_range(0.05, 2.0, 0.01, "suffix:m") var fall_lip_top_width := 0.45:
	set(value):
		fall_lip_top_width = value
		emit_changed()

@export_subgroup("Cascada · franja del pie")
## 0-1: opacidad de la franja blanca al pie de la cascada (la misma franja que la del borde, anclada abajo). Menor =
## mezcla con Fall Color. 0 = sin franja. En vivo.
@export_range(0.0, 1.0, 0.01) var fall_foot_band := 0.85:
	set(value):
		fall_foot_band = value
		emit_changed()
## 0-1: transparencia real: deja ver el agua de debajo. 0 = opaca. En vivo.
@export_range(0.0, 1.0, 0.01) var fall_foot_band_transparency := 0.0:
	set(value):
		fall_foot_band_transparency = value
		emit_changed()
## Mueve la franja entera, en metros: positivo = mas arriba por la cortina; negativo = hacia el agua de abajo. En vivo.
@export_range(-5.0, 10.0, 0.05, "suffix:m") var fall_foot_band_offset := 0.0:
	set(value):
		fall_foot_band_offset = value
		emit_changed()
## Color de la franja del pie. En vivo.
@export var fall_foot_band_color := Color(0.86, 0.94, 1.0):
	set(value):
		fall_foot_band_color = value
		emit_changed()
## 0-1: suavidad de sus bordes y de sus muescas o picos. En vivo.
@export_range(0.0, 1.0, 0.01) var fall_foot_band_softness := 0.3:
	set(value):
		fall_foot_band_softness = value
		emit_changed()
## Tamano de las irregularidades de los bordes: mayor = ondulaciones mas pequenas y seguidas. En vivo.
@export_range(0.2, 4.0, 0.05) var fall_foot_band_ragged_scale := 1.0:
	set(value):
		fall_foot_band_ragged_scale = value
		emit_changed()
## 0-1: cuanto respira el grosor con el tiempo. 0 = fijo. En vivo.
@export_range(0.0, 1.0, 0.01) var fall_foot_band_pulse := 0.25:
	set(value):
		fall_foot_band_pulse = value
		emit_changed()
## Velocidad con que cambia de forma. 0 = quieta. En vivo.
@export_range(0.0, 5.0, 0.05) var fall_foot_band_speed := 0.8:
	set(value):
		fall_foot_band_speed = value
		emit_changed()

@export_subgroup("Cascada · franja del pie · borde de arriba")
## Grosor de la franja por encima del pie, en metros sobre la cortina. En vivo.
@export_range(0.0, 8.0, 0.01, "suffix:m") var fall_foot_band_up := 1.8:
	set(value):
		fall_foot_band_up = value
		emit_changed()
## 0-1: irregularidad de este borde. 0 = recto. En vivo.
@export_range(0.0, 1.0, 0.01) var fall_foot_top_ragged := 0.6:
	set(value):
		fall_foot_top_ragged = value
		emit_changed()
## Forma de este borde: muescas de agua azul que entran en la franja, o picos blancos que suben por la cortina.
## En vivo.
@export_enum("Muescas hacia dentro", "Picos hacia fuera") var fall_foot_top_shape := 1:
	set(value):
		fall_foot_top_shape = value
		emit_changed()
## 0-1: cuantas muescas o picos. 0 = ninguno. En vivo.
@export_range(0.0, 1.0, 0.01) var fall_foot_top_amount := 0.8:
	set(value):
		fall_foot_top_amount = value
		emit_changed()
## Largo medio de las muescas o picos, en metros. Las muescas no pasan del grosor. En vivo.
@export_range(0.0, 8.0, 0.01, "suffix:m") var fall_foot_top_size := 1.8:
	set(value):
		fall_foot_top_size = value
		emit_changed()
## Ancho medio de cada muesca o pico en su base, en metros. En vivo.
@export_range(0.05, 2.0, 0.01, "suffix:m") var fall_foot_top_width := 0.45:
	set(value):
		fall_foot_top_width = value
		emit_changed()

@export_subgroup("Cascada · franja del pie · borde de abajo")
## Grosor de la franja por debajo del pie, en metros sobre el agua de abajo. 0 = acaba en el pie. En vivo.
@export_range(0.0, 6.0, 0.01, "suffix:m") var fall_foot_band_down := 0.3:
	set(value):
		fall_foot_band_down = value
		emit_changed()
## 0-1: irregularidad de este borde. En vivo.
@export_range(0.0, 1.0, 0.01) var fall_foot_bottom_ragged := 0.6:
	set(value):
		fall_foot_bottom_ragged = value
		emit_changed()
## Forma de este borde: muescas que entran en la franja, o picos que salen hacia el agua. En vivo.
@export_enum("Muescas hacia dentro", "Picos hacia fuera") var fall_foot_bottom_shape := 0:
	set(value):
		fall_foot_bottom_shape = value
		emit_changed()
## 0-1: cuantas muescas o picos. 0 = ninguno. En vivo.
@export_range(0.0, 1.0, 0.01) var fall_foot_bottom_amount := 0.0:
	set(value):
		fall_foot_bottom_amount = value
		emit_changed()
## Largo medio, en metros. En vivo.
@export_range(0.0, 6.0, 0.01, "suffix:m") var fall_foot_bottom_size := 0.5:
	set(value):
		fall_foot_bottom_size = value
		emit_changed()
## Ancho medio en la base, en metros. En vivo.
@export_range(0.05, 2.0, 0.01, "suffix:m") var fall_foot_bottom_width := 0.4:
	set(value):
		fall_foot_bottom_width = value
		emit_changed()

@export_subgroup("Cascada · franjas (comun)")
## 0-1: el agua corre por dentro de las franjas (brillo que baja con Fall Speed). En vivo.
@export_range(0.0, 1.0, 0.01) var fall_streak_shimmer := 0.25:
	set(value):
		fall_streak_shimmer = value
		emit_changed()
## Cambia el reparto aleatorio de las franjas y de sus muescas y picos. En vivo.
@export_range(0, 999, 1) var fall_streak_seed := 0:
	set(value):
		fall_streak_seed = value
		emit_changed()

@export_group("Cascada · efectos")
## Espuma, lobulos, burbujas, gotas y neblina al pie de las cascadas de todos los rios que usan este estilo.
## Espuma, neblina y salpicaduras en la base de cada cascada de cada rio. Solo visuales. Se colocan solas donde acaba cada
## tramo empinado. En vivo.
@export var fall_fx_enabled := true:
	set(value):
		fall_fx_enabled = value
		emit_changed()
## Espuma al pie de la cascada: franja de lobulos esponjosos que laten y lineas blancas curvas en el agua. En vivo.
@export var fall_foam_enabled := true:
	set(value):
		fall_foam_enabled = value
		emit_changed()
## Tamano de la espuma respecto al ancho de la cortina. Mayor = la espuma se extiende mas por la poza. En vivo.
@export_range(0.5, 5.0, 0.05) var fall_foam_size := 1.8:
	set(value):
		fall_foam_size = value
		emit_changed()
## Opacidad de las lineas de espuma del agua (0-1). En vivo.
@export_range(0.0, 1.0, 0.01) var fall_foam_opacity := 0.65:
	set(value):
		fall_foam_opacity = value
		emit_changed()
## Radio de la mancha blanca solida bajo los lobulos (fraccion del tamano de la espuma). 0 = sin mancha. En vivo.
@export_range(0.0, 0.5, 0.005) var fall_foam_patch := 0.19:
	set(value):
		fall_foam_patch = value
		emit_changed()
## Lineas de espuma que salen del impacto (mayor = mas lineas y mas juntas). En vivo.
@export_range(0.5, 20.0, 0.1) var fall_foam_rings := 5.0:
	set(value):
		fall_foam_rings = value
		emit_changed()
## Velocidad con que las lineas se alejan del impacto. 0 = quietas. En vivo.
@export_range(0.0, 5.0, 0.05) var fall_foam_ring_speed := 1.2:
	set(value):
		fall_foam_ring_speed = value
		emit_changed()
## 0-1: grosor de cada linea (fraccion del hueco entre lineas). En vivo.
@export_range(0.02, 0.9, 0.01) var fall_foam_line_width := 0.16:
	set(value):
		fall_foam_line_width = value
		emit_changed()
## 0-1: cuanto se cortan las lineas en trazos. 0 = anillos enteros; 1 = trazos sueltos. En vivo.
@export_range(0.0, 1.0, 0.01) var fall_foam_dashes := 0.5:
	set(value):
		fall_foam_dashes = value
		emit_changed()
## Hasta donde llegan las lineas antes de desvanecerse (fraccion del tamano de la espuma). En vivo.
@export_range(0.1, 1.0, 0.01) var fall_foam_reach := 0.62:
	set(value):
		fall_foam_reach = value
		emit_changed()
## Ondulacion de la mancha y de las lineas. 0 = circulos perfectos. En vivo.
@export_range(0.0, 0.3, 0.005) var fall_foam_wobble := 0.06:
	set(value):
		fall_foam_wobble = value
		emit_changed()
## Velocidad general de la animacion de la espuma (cortes, ondulacion y lineas). En vivo.
@export_range(0.0, 3.0, 0.05) var fall_foam_drift := 0.6:
	set(value):
		fall_foam_drift = value
		emit_changed()
## Tamano de los lobulos de espuma, en metros (radio medio). En vivo.
@export_range(0.1, 3.0, 0.01, "suffix:m") var fall_puff_size := 0.7:
	set(value):
		fall_puff_size = value
		emit_changed()
## Lobulos por metro de ancho de la cortina. En vivo.
@export_range(0.5, 20.0, 0.05) var fall_puff_density := 4.0:
	set(value):
		fall_puff_density = value
		emit_changed()
## Cuanto laten los lobulos (0 = quietos). En vivo.
@export_range(0.0, 1.0, 0.01) var fall_puff_pulse := 0.35:
	set(value):
		fall_puff_pulse = value
		emit_changed()
## Opacidad de los lobulos de espuma (0-1). Algo translucidos dejan ver el agua y la cortina detras. En vivo.
@export_range(0.0, 1.0, 0.01) var fall_puff_opacity := 0.85:
	set(value):
		fall_puff_opacity = value
		emit_changed()
## 0-1: cuanto varia el tamano entre lobulos. 0 = todos iguales; 1 = de pequenos a el doble. En vivo.
@export_range(0.0, 1.0, 0.01) var fall_puff_size_variation := 0.6:
	set(value):
		fall_puff_size_variation = value
		emit_changed()
## 0-1: cuanto varia la forma: unos mas aplastados, otros mas altos o alargados, girados al azar. En vivo.
@export_range(0.0, 1.0, 0.01) var fall_puff_shape_variation := 0.5:
	set(value):
		fall_puff_shape_variation = value
		emit_changed()
## 0-1: desorden de la colocacion: lobulos que se adelantan, se atrasan y suben o bajan. 0 = filas ordenadas.
@export_range(0.0, 1.0, 0.01) var fall_puff_scatter := 0.5:
	set(value):
		fall_puff_scatter = value
		emit_changed()
## Cambia el reparto aleatorio de los lobulos. En vivo.
@export_range(0, 999, 1) var fall_puff_seed := 7:
	set(value):
		fall_puff_seed = value
		emit_changed()
## Ciclo de vida de los lobulos: cada uno surge, crece, encoge hasta desaparecer y vuelve a surgir en otro sitio y
## con otro tamano. Apagado = lobulos fijos (solo laten). En vivo.
@export var fall_puff_life_enabled := true:
	set(value):
		fall_puff_life_enabled = value
		emit_changed()
## Ciclos por segundo de media (0,45 = cada lobulo vive unos 2 s). Mayor = espuma mas agitada. En vivo.
@export_range(0.0, 3.0, 0.01) var fall_puff_life_speed := 0.45:
	set(value):
		fall_puff_life_speed = value
		emit_changed()
## 0-1: cuanto difiere el ritmo entre lobulos (0 = todos a la vez; 1 = muy desacompasados). En vivo.
@export_range(0.0, 1.0, 0.01) var fall_puff_life_speed_variation := 0.6:
	set(value):
		fall_puff_life_speed_variation = value
		emit_changed()
## 0-1: cuanto cambia el tamano de una aparicion a la siguiente. En vivo.
@export_range(0.0, 1.0, 0.01) var fall_puff_life_size_variation := 0.5:
	set(value):
		fall_puff_life_size_variation = value
		emit_changed()
## 0-1: tamano minimo del ciclo. 0 = desaparece del todo; mayor = solo encoge. En vivo.
@export_range(0.0, 1.0, 0.01) var fall_puff_min_size := 0.0:
	set(value):
		fall_puff_min_size = value
		emit_changed()
## 0-1: parte del ciclo que pasa a tamano completo. 0 = siempre creciendo o encogiendo; mayor = aparece, se
## queda y se va rapido. En vivo.
@export_range(0.0, 0.95, 0.01) var fall_puff_hold := 0.3:
	set(value):
		fall_puff_hold = value
		emit_changed()
## Color en sombra de los lobulos y las gotas (el claro es FX Color). En vivo.
@export var fall_fx_shadow_color := Color(0.56, 0.8, 0.95):
	set(value):
		fall_fx_shadow_color = value
		emit_changed()
## Neblina: nubecillas blancas que suben y se dispersan desde la base. En vivo.
@export var fall_mist_enabled := false:
	set(value):
		fall_mist_enabled = value
		emit_changed()
## Nubecillas de neblina vivas a la vez. Coste: particulas de CPU (pocas). En vivo.
@export_range(0, 200, 1) var fall_mist_amount := 40:
	set(value):
		fall_mist_amount = value
		emit_changed()
## Tamano de cada nubecilla, en metros. En vivo.
@export_range(0.1, 6.0, 0.05, "suffix:m") var fall_mist_size := 2.0:
	set(value):
		fall_mist_size = value
		emit_changed()
## Altura en metros a la que sube la neblina antes de desvanecerse. En vivo.
@export_range(0.2, 15.0, 0.1, "suffix:m") var fall_mist_height := 3.0:
	set(value):
		fall_mist_height = value
		emit_changed()
## Opacidad de la neblina (0-1). En vivo.
@export_range(0.0, 1.0, 0.01) var fall_mist_opacity := 0.5:
	set(value):
		fall_mist_opacity = value
		emit_changed()
## Gotas que saltan al chocar el agua con la poza. En vivo.
@export var fall_splash_enabled := true:
	set(value):
		fall_splash_enabled = value
		emit_changed()
## Gotas vivas a la vez. En vivo.
@export_range(0, 300, 1) var fall_splash_amount := 140:
	set(value):
		fall_splash_amount = value
		emit_changed()
## Altura en metros que alcanzan las gotas. En vivo.
@export_range(0.2, 8.0, 0.05, "suffix:m") var fall_splash_height := 1.8:
	set(value):
		fall_splash_height = value
		emit_changed()
## Particulas de espuma: burbujitas blancas que aparecen sobre la espuma de la base, se alejan con el agua y se
## deshacen. En vivo.
@export var fall_bubbles_enabled := true:
	set(value):
		fall_bubbles_enabled = value
		emit_changed()
## Burbujitas vivas a la vez. Coste: particulas de CPU (pocas). En vivo.
@export_range(0, 300, 1) var fall_bubbles_amount := 70:
	set(value):
		fall_bubbles_amount = value
		emit_changed()
## Tamano medio de cada burbujita, en metros. En vivo.
@export_range(0.02, 0.6, 0.01, "suffix:m") var fall_bubbles_size := 0.12:
	set(value):
		fall_bubbles_size = value
		emit_changed()
## Hasta donde se alejan de la cortina, respecto al ancho de la cascada. En vivo.
@export_range(0.2, 4.0, 0.05) var fall_bubbles_spread := 1.2:
	set(value):
		fall_bubbles_spread = value
		emit_changed()
## Tamano de las gotas (1 = como las del chapuzon del jugador). En vivo.
@export_range(0.2, 3.0, 0.05) var fall_splash_size := 1.0:
	set(value):
		fall_splash_size = value
		emit_changed()
## 0-1: opacidad de las burbujitas de espuma. Menor = mas transparentes. En vivo.
@export_range(0.0, 1.0, 0.01) var fall_bubbles_opacity := 0.85:
	set(value):
		fall_bubbles_opacity = value
		emit_changed()
## 0-1: opacidad de las gotas. Menor = mas transparentes. En vivo.
@export_range(0.0, 1.0, 0.01) var fall_splash_opacity := 1.0:
	set(value):
		fall_splash_opacity = value
		emit_changed()
## 0-1: cuanto se oscurecen las gotas al caer (hacia FX Shadow Color). 0 = siempre del color claro. En vivo.
@export_range(0.0, 1.0, 0.01) var fall_splash_shading := 0.6:
	set(value):
		fall_splash_shading = value
		emit_changed()
## Color de espuma, neblina y gotas. En vivo.
@export var fall_fx_color := Color(0.84, 0.95, 1.0):
	set(value):
		fall_fx_color = value
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
## Optimizacion: entre Far Distance y 1,5 veces esa distancia se desvanecen causticas, destellos y la segunda capa de
## crestas, y mas alla la GPU deja de calcularlos (tambien la refraccion y las ondas del jugador). Ahorra mucho en agua
## lejana o que llena la pantalla. Apagado = todo el detalle a cualquier distancia (mas caro). En vivo.
@export var far_simplify := true:
	set(value):
		far_simplify = value
		emit_changed()
## Metros a la camara desde los que los efectos de la base de cada cascada (espuma, lobulos, burbujas, neblina, gotas) se
## ocultan y dejan de simularse; al volver a acercarse reaparecen ya en marcha. Se mide a cada cascada por separado.
## 0 = siempre activos. Menor = mas ahorro de CPU (particulas) y GPU, pero se nota si aparecen dentro de la vista.
## Solo en juego: en el editor siempre se ven. En vivo.
@export_range(0.0, 500.0, 1.0, "suffix:m") var fall_fx_distance := 80.0:
	set(value):
		fall_fx_distance = value
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

@export_group("Movimiento de la superficie")
## La superficie sube y baja de verdad: oleaje suave de fondo y las ondas del jugador levantan el agua (se ve a ras de
## agua y en la orilla). Apagado = superficie plana (solo cambian reflejos). Al cambiarlo las mallas se rehacen mas
## densas o vuelven a ser ligeras. Coste: mas vertices en lagos y rios. Apagado por defecto (experimental). En vivo.
@export var surface_motion_enabled := false:
	set(value):
		surface_motion_enabled = value
		emit_changed()
## Separacion en metros entre vertices de la malla con movimiento. Menor = ondas mas suaves y redondas; coste: muchos mas
## vertices (a 0,3 m un lago de 35 m tiene unos 15.000). Rehace las mallas. En vivo.
@export_range(0.1, 2.0, 0.05, "suffix:m") var surface_resolution := 0.3:
	set(value):
		surface_resolution = value
		emit_changed()
## Altura del oleaje de fondo, en metros (de valle a cresta aprox. el doble). 0 = sin oleaje, solo ondas del jugador.
## En vivo.
@export_range(0.0, 0.5, 0.005, "suffix:m") var swell_height := 0.1:
	set(value):
		swell_height = value
		emit_changed()
## Tamano de las olas de fondo, en metros. Mayor = ondulacion larga y lenta. En vivo.
@export_range(0.5, 30.0, 0.1, "suffix:m") var swell_scale := 4.0:
	set(value):
		swell_scale = value
		emit_changed()
## Velocidad del oleaje de fondo, en ciclos por segundo de la ola mayor. En vivo.
@export_range(0.0, 3.0, 0.01) var swell_speed := 0.25:
	set(value):
		swell_speed = value
		emit_changed()
## Altura que levanta una onda del jugador de fuerza 1, en metros. En vivo.
@export_range(0.0, 0.5, 0.005, "suffix:m") var player_wave_height := 0.14:
	set(value):
		player_wave_height = value
		emit_changed()

@export_group("Ondas del jugador")
## Ondas reales que el jugador crea al caer, nadar o caminar por el agua: anillos que se expanden por la superficie, se
## cruzan y se apagan, doblando reflejos, crestas y refraccion. Se activan en el nodo Swimming (Real Waves Enabled). En vivo.
@export_range(0.05, 3.0, 0.01, "suffix:m") var player_wave_length := 0.45:
	set(value):
		player_wave_length = value
		emit_changed()
## Velocidad a la que se expanden los anillos, en m/s. En vivo.
@export_range(0.1, 10.0, 0.05, "suffix:m/s") var player_wave_speed := 1.4:
	set(value):
		player_wave_speed = value
		emit_changed()
## Cuanto doblan la superficie (inclinacion de las ondas). Mayor = ondas mas marcadas. En vivo.
@export_range(0.0, 3.0, 0.01) var player_wave_strength := 1.8:
	set(value):
		player_wave_strength = value
		emit_changed()
## Ondas por anillo: ancho del tren de ondas en longitudes de onda. Mayor = mas ondulaciones concentricas. En vivo.
@export_range(0.3, 6.0, 0.05) var player_wave_rings := 1.6:
	set(value):
		player_wave_rings = value
		emit_changed()
## Rapidez con que se apagan, por segundo. Mayor = desaparecen antes. En vivo.
@export_range(0.05, 5.0, 0.01) var player_wave_damping := 0.9:
	set(value):
		player_wave_damping = value
		emit_changed()
## Cuanto se apagan al alejarse del origen. Mayor = solo cerca del jugador. En vivo.
@export_range(0.0, 3.0, 0.01) var player_wave_falloff := 0.25:
	set(value):
		player_wave_falloff = value
		emit_changed()
## Brillo en las crestas de las ondas (0 = solo cambian los reflejos). En vivo.
@export_range(0.0, 2.0, 0.01) var player_wave_highlight := 0.5:
	set(value):
		player_wave_highlight = value
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
		"fall_streak_color": fall_streak_color, "fall_shadow_color": fall_shadow_color, 
		"fall_streak_length": fall_streak_length,
		"fall_transparency": fall_transparency, "fall_reflection": fall_reflection,
		"fall_color_mix": fall_color_mix, "fall_crests": fall_crests, "river_edge_light": river_edge_light,
		"shore_line_strength": shore_line_strength, "shore_line_depth": shore_line_depth, "shore_line_width": shore_line_width, "fall_streak_wave": fall_streak_wave,
		"fall_streak_softness": fall_streak_softness,
		"fall_foot_band": fall_foot_band, "fall_foot_band_transparency": fall_foot_band_transparency,
		"fall_foot_band_offset": fall_foot_band_offset, "fall_foot_band_color": fall_foot_band_color,
		"fall_foot_band_softness": fall_foot_band_softness,
		"fall_foot_band_ragged_scale": fall_foot_band_ragged_scale, "fall_foot_band_pulse": fall_foot_band_pulse,
		"fall_foot_band_speed": fall_foot_band_speed, "fall_foot_band_up": fall_foot_band_up,
		"fall_foot_top_ragged": fall_foot_top_ragged, "fall_foot_top_shape": fall_foot_top_shape,
		"fall_foot_top_amount": fall_foot_top_amount, "fall_foot_top_size": fall_foot_top_size,
		"fall_foot_top_width": fall_foot_top_width, "fall_foot_band_down": fall_foot_band_down,
		"fall_foot_bottom_ragged": fall_foot_bottom_ragged, "fall_foot_bottom_shape": fall_foot_bottom_shape,
		"fall_foot_bottom_amount": fall_foot_bottom_amount, "fall_foot_bottom_size": fall_foot_bottom_size,
		"fall_foot_bottom_width": fall_foot_bottom_width,
		"fall_lip_band": fall_lip_band, "fall_lip_band_transparency": fall_lip_band_transparency, "fall_lip_opaque": fall_lip_opaque, "fall_lip_band_color": fall_lip_band_color,
		"fall_marks_light": fall_marks_light, "fall_lip_band_softness": fall_lip_band_softness,
		"fall_lip_band_ragged_scale": fall_lip_band_ragged_scale, "fall_lip_band_pulse": fall_lip_band_pulse,
		"fall_lip_band_speed": fall_lip_band_speed, "fall_lip_band_height": fall_lip_band_height, "fall_lip_band_ragged": fall_lip_band_ragged,
		"fall_lip_bottom_shape": fall_lip_bottom_shape, "fall_lip_bottom_amount": fall_lip_bottom_amount,
		"fall_lip_bottom_size": fall_lip_bottom_size, "fall_lip_bottom_width": fall_lip_bottom_width,
		"fall_lip_band_up": fall_lip_band_up, "fall_lip_top_ragged": fall_lip_top_ragged,
		"fall_lip_top_shape": fall_lip_top_shape, "fall_lip_top_amount": fall_lip_top_amount,
		"fall_lip_top_size": fall_lip_top_size, "fall_lip_top_width": fall_lip_top_width, "fall_streak_shimmer": fall_streak_shimmer,
		"fall_streak_seed": float(fall_streak_seed),
		"rapids_foam": rapids_foam, "break_foam": break_foam, "sky_color": sky_color,
		"fresnel_strength": fresnel_strength, "fresnel_power": fresnel_power, "specular_amount": specular,
		"roughness_amount": roughness, "caustic_color": caustic_color, "caustic_scale": caustic_scale,
		"caustic_speed": caustic_speed, "caustic_strength": caustic_strength, "far_distance": far_distance, "far_simplify": far_simplify,
		"under_surface_color": underwater_surface_color, "under_window": underwater_window,
		"pw_length": player_wave_length, "pw_speed": player_wave_speed, "pw_strength": player_wave_strength,
		"pw_rings": player_wave_rings, "pw_damping": player_wave_damping, "pw_falloff": player_wave_falloff,
		"pw_highlight": player_wave_highlight,
		"motion_enabled": surface_motion_enabled, "swell_height": swell_height, "swell_scale": swell_scale,
		"swell_speed": swell_speed, "pw_height": player_wave_height,
	}
	for parameter: String in values:
		material.set_shader_parameter(parameter, values[parameter])

## Values of the fall effects (Cascada · efectos); a river rebuilds its foam, lumps, bubbles and drops when they change.
func fall_fx_key() -> Array:
	return [fall_fx_enabled, fall_foam_enabled, fall_foam_size, fall_foam_opacity, fall_foam_patch, fall_foam_rings, fall_foam_ring_speed, fall_foam_line_width, fall_foam_dashes, fall_foam_reach, fall_foam_wobble, fall_foam_drift, fall_puff_size, fall_puff_density, fall_puff_pulse, fall_puff_opacity, fall_puff_size_variation, fall_puff_shape_variation, fall_puff_scatter, fall_puff_seed, fall_puff_life_enabled, fall_puff_life_speed, fall_puff_life_speed_variation, fall_puff_life_size_variation, fall_puff_min_size, fall_puff_hold, fall_fx_shadow_color, fall_mist_enabled, fall_mist_amount, fall_mist_size, fall_mist_height, fall_mist_opacity, fall_splash_enabled, fall_splash_amount, fall_splash_height, fall_bubbles_enabled, fall_bubbles_amount, fall_bubbles_size, fall_bubbles_spread, fall_splash_size, fall_bubbles_opacity, fall_splash_opacity, fall_splash_shading, fall_fx_color]
