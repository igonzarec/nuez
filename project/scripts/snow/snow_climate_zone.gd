@tool
extends Node3D
## Volumen de clima para Snowfall; independiente de las zonas de nieve pintada.

@export_group("Zona de nevada")
## Activa esta zona sin moverla ni cambiar la nieve del suelo. En vivo.
@export var enabled := true
## Semiextensión horizontal en metros desde el origen del nodo. Aumentar amplía la zona; en vivo.
@export var half_size := Vector2(24.0,24.0)
## Distancia exterior de transición de la nevada, en metros. Mayor hace más gradual la entrada y salida; en vivo.
@export_range(0.1,100.0,0.5,"suffix:m") var fade_distance := 12.0
## Fuerza de los copos dentro de la zona, de 0 a 1. En vivo; multiplica la intensidad de Snowfall.
@export_range(0.0,1.0,0.01) var intensity := 1.0

func weight_at(point: Vector3) -> float:
	if not enabled: return 0.0
	var local := to_local(point)
	var outside := Vector2(maxf(0.0,absf(local.x)-half_size.x),maxf(0.0,absf(local.z)-half_size.y)).length()
	return intensity*(1.0-smoothstep(0.0,maxf(0.1,fade_distance),outside))
