@tool
class_name TrailToonLook
extends Resource
## Perfil reutilizable de iluminación. Los cambios se aplican en ejecución, incluso en pausa.

## Activa este perfil local. Apagado conserva el material original; el general activo tiene prioridad. En vivo.
@export var enabled := false
## Niveles de luz directa, sin unidades. Menos bandas produce masas de color mayores. En vivo; coste pequeño por luz y píxel.
@export_range(2, 6, 1) var bands := 3
## Anchura relativa de transición, de 0 a 1. 0 duro, 1 mezcla bandas vecinas. En vivo.
@export_range(0.0, 1.0, 0.01) var softness := 0.08
## Desplaza los cortes de luz, de -1 a 1. Positivo amplía las zonas iluminadas; negativo amplía las oscuras. En vivo.
@export_range(-1.0, 1.0, 0.01) var light_offset := 0.0
## Contraste de luz directa alrededor del punto medio. 1 neutro; mayor separa las bandas. No modifica ambiente ni niebla. En vivo.
@export_range(0.1, 3.0, 0.05) var contrast := 1.0
## Fuerza relativa del mapa de normales, 0 plano y 1 original. Conserva normales geométricas y colisión. En vivo.
@export_range(0.0, 1.0, 0.01) var normal_strength := 1.0

func signature() -> Array:
	return [enabled, bands, softness, light_offset, contrast, normal_strength]
