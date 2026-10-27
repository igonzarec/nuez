@tool
class_name NPCPatrolPoint
extends Marker3D
## Órdenes para el tramo que lleva hasta este punto; el controlador del player las ejecuta.

## Mantiene Sprint durante este tramo. Apagado camina. Usa Sprint Speed de Body; en vivo al seguir este punto.
@export var sprint := false
## Pulsa salto una vez al empezar a dirigirse a este punto, después de la pausa anterior. Requiere apoyo válido; no teletransporta ni fuerza un doble salto. Se consulta al iniciar el tramo.
@export var jump_before_leg := false
## Mantiene planeo cuando Body ya está en el aire durante este tramo. Requiere Glide Enabled del actor. La pulsación se genera al abandonar el suelo; en vivo.
@export var glide_in_air := false
## Mantiene agarre durante este tramo. Requiere pared escalable y Climb Enabled del actor. En vivo; al apagarlo suelta el agarre.
@export var climb_held := false
