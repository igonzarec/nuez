@tool
extends Resource
## Apariencia de una capa de detalle pintada. Los cambios se agrupan en vivo.

@export_group("Capa")
## Activa esta capa sin borrar su pintura. En vivo.
@export var enabled := true
## Tipo de geometría. Nieve, hojas, terrones o hierba. Requiere reconstrucción automática.
@export_enum("Nieve", "Hojas", "Tierra", "Pasto") var kind := 0
## ID de Terrain3D que pinta el pincel cuando Pintar textura debajo está activo. -1 exige elegir una textura; no se pinta el suelo. No cambia zonas ya pintadas.
@export_range(-1, 31, 1) var texture_id := -1
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
## Realismo de nieve: 0 facetas sencillas; 1 grumos suaves irregulares con micrograno. En los otros tipos modifica la irregularidad geométrica. En vivo; cambios de geometría se agrupan.
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

func signature() -> int:
	var values: Array = []
	for property in get_property_list():
		if property.usage & PROPERTY_USAGE_STORAGE and property.name != "script":
			values.append(get(property.name))
	return hash(values)
