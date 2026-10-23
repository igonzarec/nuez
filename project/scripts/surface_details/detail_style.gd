@tool
extends Resource
## Apariencia de una capa de detalle pintada. Los cambios se agrupan en vivo.

@export_group("Capa")
## Activa esta capa sin borrar su pintura. En vivo.
@export var enabled := true
## Tipo de geometría. Nieve, hojas, terrones o hierba. Requiere reconstrucción automática.
@export_enum("Nieve", "Hojas", "Tierra", "Pasto") var kind := 0:
	set(value):
		kind = value
		notify_property_list_changed()
## ID histórico guardado para cargar perfiles anteriores. El pincel actual sólo pinta detalle y no lo utiliza ni modifica.
@export_storage var texture_id := -1
@export_group("Distribución")
## Elementos por m² de cobertura completa. Mayor aumenta el coste de generación y GPU; el presupuesto global limita la cantidad. En vivo.
@export_range(0.1, 64.0, 0.1) var density := 10.0
## Tamaño mínimo en metros. Para pasto es la altura; para el resto es el diámetro/longitud. En vivo, reconstrucción agrupada.
@export_range(0.01, 2.0, 0.01, "suffix:m") var size_min := 0.08
## Tamaño máximo en metros. Se ordena con Size Min. En vivo, reconstrucción agrupada.
@export_range(0.01, 3.0, 0.01, "suffix:m") var size_max := 0.22
## Proporción vertical del grumo, curvatura de hoja o ancho relativo del pasto. Mayor da más volumen/ancho. En vivo.
@export_range(0.02, 1.5, 0.01) var thickness := 0.25
## Pendiente máxima desde horizontal, grados. Menor evita laderas. En vivo; no borra la cobertura guardada.
@export_range(0.0, 89.0, 1.0, "suffix:°") var maximum_slope := 55.0
## Separación sobre el relieve en metros. Aumentar evita intersecciones, pero puede hacer flotar el detalle. En vivo.
@export_range(-0.1, 0.2, 0.001, "suffix:m") var ground_offset := 0.008
## Orienta el detalle según la normal del terreno. Apagar mantiene el eje vertical mundial. En vivo.
@export var align_to_ground := true
## Semilla determinista. Cambiarla redistribuye los elementos dentro de la cobertura, sin modificar la pintura. En vivo.
@export var random_seed := 37
@export_group("Apariencia")
## Primer extremo de la paleta. En vivo, conservando las posiciones.
@export var color_a := Color(0.85, 0.91, 0.96)
## Segundo extremo de la paleta; cada elemento interpola entre ambos. En vivo.
@export var color_b := Color(0.98, 0.99, 1.0)
## Variación de claridad por elemento, de 0 a 1. Mayor rompe la uniformidad. En vivo.
@export_range(0.0, 0.5, 0.01) var color_variation := 0.08
## Parámetro legado conservado para recursos anteriores. La nieve usa ahora los controles de Nieve: superficie.
@export_range(0.0, 1.0, 0.01) var realism := 0.85
## Rugosidad del acabado normal: 1 mate, 0 pulido. En vivo; independiente de la suavidad toon.
@export_range(0.0, 1.0, 0.01) var roughness := 0.95
## Brillo especular del acabado normal. 0 elimina reflejos del sol. Toon lo desactiva. En vivo.
@export_range(0.0, 1.0, 0.01) var specular := 0.12
## 0 sigue la preferencia toon del juego, 1 iluminación normal, 2 toon local. En el editor, Seguir ajustes usa iluminación normal. En vivo.
@export_enum("Seguir ajustes", "Normal", "Toon") var shading := 0
## Anchura del corte de luz toon. 0 duro, 1 suave. Independiente de Roughness. En vivo; requiere Toon o modo global activo.
@export_range(0.0, 1.0, 0.01) var toon_softness := 0.08
## Intensidad del microrelieve de nieve en el material. Mayor enfatiza el grano; no cambia colisión. En vivo.
@export_range(0.0, 1.0, 0.01) var grain_strength := 0.25
@export_group("Movimiento")
## Movimiento opcional de hojas y pasto. Nieve y tierra permanecen quietas. En vivo.
@export var wind_enabled := false
## Desplazamiento máximo del viento en metros. Mayor agita más; 0 inmóvil. En vivo.
@export_range(0.0, 0.5, 0.005, "suffix:m") var wind_strength := 0.025
## Ritmo del balanceo en ciclos aproximados por segundo. Mayor acelera. En vivo.
@export_range(0.0, 5.0, 0.05) var wind_speed := 1.0
## Dirección horizontal del viento, en grados. 0 hacia +X, 90 hacia +Z. En vivo.
@export_range(-180.0, 180.0, 1.0, "suffix:°") var wind_direction := 25.0

@export_group("Nieve: superficie")
## Multiplicador de reflectancia de la nieve. Menor conserva detalle bajo un sol intenso; mayor aclara. No altera los colores guardados ni la exposición global. En vivo.
@export_range(0.2, 1.0, 0.01) var snow_albedo_gain := 0.75
## Espesor visual en metros sobre el terreno, además de Ground Offset. Mayor separa la capa del suelo; no cambia colisión. En vivo, reconstrucción agrupada.
@export_range(0.005, 0.25, 0.005, "suffix:m") var snow_depth := 0.08
## Altura de ondulaciones suaves en metros. 0 da una capa lisa; subirla crea acumulaciones bajas. En vivo, reconstrucción agrupada; no cambia colisión.
@export_range(0.0, 0.2, 0.005, "suffix:m") var snow_relief := 0.06
## Tamaño horizontal de las ondulaciones en metros. Mayor produce acumulaciones amplias. En vivo, reconstrucción agrupada.
@export_range(0.5, 12.0, 0.1, "suffix:m") var snow_relief_scale := 1.2
## Separación objetivo entre vértices de nieve, metros. Menor mejora el borde pintado y cuesta más CPU/GPU. Se ajusta a la rejilla del terreno; reconstrucción en vivo.
@export_range(0.25, 2.0, 0.25, "suffix:m") var snow_mesh_spacing := 0.5
## Escala del micrograno, metros. Menor da cristales finos; se filtra al alejarse para evitar parpadeo. En vivo, sólo material.
@export_range(0.005, 0.1, 0.005, "suffix:m") var snow_grain_size := 0.025
## Suaviza la respuesta de la nieve a la luz, aproximando dispersión interna. Mayor aclara zonas rasantes. No es simulación física; en vivo, sólo material.
@export_range(0.0, 0.6, 0.01) var snow_scatter := 0.25
## Intensidad de destellos finos cerca de cámara. 0 desactiva; se filtran por tamaño de píxel y se omiten en toon. En vivo.
@export_range(0.0, 0.5, 0.01) var snow_sparkle := 0.06

@export_group("Nieve: estilo")
## Apariencia suave y mate, con relieve legible desde la cámara de juego. Desactivar conserva micrograno/destellos naturales. En vivo.
@export var snow_stylized := true
## Tamaño de las pequeñas ondulaciones del material, metros. Mayor da formas más amplias; no altera colisión. En vivo.
@export_range(0.1, 2.0, 0.01, "suffix:m") var snow_surface_scale := 0.32
## Fuerza de normales de las ondulaciones. Mayor marca el volumen con la luz; no desplaza la malla. En vivo.
@export_range(0.0, 1.0, 0.01) var snow_surface_strength := 0.13
## Contraste suave de huecos y crestas. Mantiene legible el relieve incluso con toon o sol cenital. 0 elimina esta variación; en vivo.
@export_range(0.0, 0.4, 0.01) var snow_surface_contrast := 0.10

@export_group("Nieve: hundimiento")
## Permite que el modelo se hunda parcialmente en la nieve. Desactivar lo sostiene sobre la capa. Usa la colisión original; no modifica velocidad ni salto. En vivo.
@export var snow_sink_enabled := true
## Compactación: 0 nieve polvo, 1 nieve dura. Mayor reduce hundimiento y profundidad de huellas. En vivo, nuevos pasos.
@export_range(0.0, 1.0, 0.01) var snow_compaction := 0.35
## Fracción máxima del espesor en que se hunde en nieve polvo. Se multiplica por 1-compactación. En vivo.
@export_range(0.0, 0.95, 0.01) var snow_sink_ratio := 0.65
## Hundimiento máximo, metros, aunque aumente el espesor. Evita ocultar demasiado al personaje. En vivo.
@export_range(0.0, 0.4, 0.01, "suffix:m") var snow_sink_max := 0.18
## Rapidez de adaptación visual al entrar/salir. Mayor responde antes; menor suaviza. En vivo.
@export_range(1.0, 30.0, 0.5) var snow_sink_response := 10.0

@export_group("Nieve: huellas")
## Deja huellas con los eventos de pasos del player. Sólo sobre cobertura pintada, apoyado en el terreno y con espesor suficiente. En vivo.
@export var snow_footprints_enabled := true
## Espesor mínimo local para dejar huella, metros. No cuenta Ground Offset. Mayor exige nieve más profunda; nuevos pasos.
@export_range(0.0, 0.25, 0.005, "suffix:m") var snow_footprint_min_depth := 0.04
## Anchura de la huella, metros. Mayor hace la pisada más visible. Nuevos pasos.
@export_range(0.06, 0.5, 0.01, "suffix:m") var snow_footprint_width := 0.22
## Longitud de la huella, metros. Nuevos pasos.
@export_range(0.1, 0.7, 0.01, "suffix:m") var snow_footprint_length := 0.34
## Separación lateral de cada pie respecto al centro del player, metros. Alterna izquierda/derecha. Nuevos pasos.
@export_range(0.0, 0.3, 0.01, "suffix:m") var snow_footprint_separation := 0.12
## Profundidad máxima visual de la huella, metros. Limitada por el hundimiento del perfil y espesor. No modifica colisión; nuevos pasos.
@export_range(0.005, 0.15, 0.005, "suffix:m") var snow_footprint_depth := 0.06
## Duración de las huellas, segundos. Se desvanecen en el último tercio. Sólo viven durante la partida; en vivo.
@export_range(5.0, 600.0, 5.0, "suffix:s") var snow_footprint_lifetime := 120.0
## Máximo de bloques de 16 m que conservan huellas. 512² RGBAF usa unos 4 MB de CPU y 4 MB de GPU por bloque. Al superar el límite desaparece el más antiguo. En vivo.
@export_range(1, 32, 1) var snow_footprint_tiles := 8
## Diferencia vertical máxima entre base del player y terreno para permitir nieve. Evita huellas bajo puentes y objetos elevados; metros, en vivo.
@export_range(0.03, 0.5, 0.01, "suffix:m") var snow_contact_tolerance := 0.15

@export_group("Hojas: apoyo")
## Margen mínimo sobre el relieve bajo toda la hoja, metros. Evita que sus extremos se entierren; mayor puede hacerla flotar. Incluye margen para viento. Reconstrucción en vivo.
@export_range(0.001, 0.1, 0.001, "suffix:m") var leaf_clearance := 0.012

func _validate_property(property: Dictionary) -> void:
	var hidden := false
	if property.name.begins_with("snow_"): hidden = kind != 0
	if property.name == "leaf_clearance": hidden = kind != 1
	if property.name == "realism": hidden = true
	if kind == 0 and property.name in ["density", "size_min", "size_max", "thickness", "align_to_ground", "wind_enabled", "wind_strength", "wind_speed", "wind_direction"]:
		hidden = true
	if hidden: property.usage &= ~PROPERTY_USAGE_EDITOR

func geometry_signature() -> int:
	repair_missing_values()
	# Color, toon y brillo sólo actualizan uniforms: no reemplazan instancias.
	var fields := ["enabled", "kind", "maximum_slope", "ground_offset", "random_seed"]
	if kind == 0:
		fields.append_array(["snow_depth", "snow_relief", "snow_relief_scale", "snow_mesh_spacing"])
	else:
		fields.append_array(["density", "size_min", "size_max", "thickness", "align_to_ground"])
		if kind == 1: fields.append_array(["leaf_clearance", "wind_enabled", "wind_strength"])
	var values: Array = []
	for field in fields: values.append(get(field))
	return hash(values)

func signature() -> int:
	var values: Array = []
	for property in get_property_list():
		if property.usage & PROPERTY_USAGE_STORAGE and property.name != "script":
			values.append(get(property.name))
	return hash(values)

func repair_missing_values() -> void:
	# Una recarga en caliente puede dejar campos nuevos en null al guardar.
	# Recuperar sólo ausencias; conservar siempre los ajustes numéricos del usuario.
	var defaults: Resource
	for property in get_property_list():
		if not (property.usage & PROPERTY_USAGE_STORAGE): continue
		if not (property.name.begins_with("snow_") or property.name == "leaf_clearance"): continue
		if get(property.name) != null: continue
		if defaults == null: defaults = get_script().new()
		set(property.name,defaults.get(property.name))
