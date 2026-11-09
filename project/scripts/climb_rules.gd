@tool
class_name ClimbRules
extends Resource
## Reglas de escalada compartidas: qué pendientes permiten agarrarse, sostener el
## agarre y desde qué ángulo hay que mirar a la pared. Una sola fuente de verdad
## que leen el Player (climbing.gd), las superficies en modo "Heredar"
## (CliffFoldsGenerator, CliffPiece) y ClimbDebugView. Todo se consulta en vivo.
## La pendiente caminable y el alcance del agarre siguen en el Player (son del
## cuerpo, no de la superficie). Ver project/docs/climb_rules.md.

@export_group("Agarre inicial")
## Permite agarrarse a superficies sin etiqueta climbable (Terrain3D esculpido) según su pendiente. Desactívalo cuando haya
## edificios, árboles u otros objetos verticales que no deban treparse. En vivo.
@export var untagged_enabled := true
## Pendiente mínima, en grados desde horizontal, para EMPEZAR a trepar. La usan Terrain3D y las superficies en modo Heredar.
## Menor permite agarrarse a laderas más tendidas; mayor exige paredes más verticales. Por debajo de Walkable Slope Degrees del
## Player la ardilla camina: un valor menor que ese solo sirve para entrar y salir enseguida por la cima. En vivo.
@export_range(10.0, 89.0, 0.5, "suffix:°") var grab_min_slope_degrees := 65.0
## Pendiente máxima, en grados desde horizontal, de una superficie SIN etiqueta que puede agarrarse. 89 admite paredes casi
## verticales; Terrain3D no genera caras por encima de 90. No limita mallas en modo Heredar (admiten salientes). En vivo.
@export_range(10.0, 89.0, 0.5, "suffix:°") var grab_max_slope_degrees := 89.0

@export_group("Continuidad")
## Permite pendientes más suaves una vez agarrado, sin facilitar el agarre inicial. Conserva zonas Disabled. En vivo.
@export var sustain_enabled := true
## Pendiente mínima, en grados desde horizontal, para CONSERVAR un agarre ya iniciado. Menor deja seguir por la transición
## hacia la cima. Sólo relaja el agarre inicial, nunca lo endurece. En vivo.
@export_range(5.0, 85.0, 0.5, "suffix:°") var sustain_min_slope_degrees := 40.0

@export_group("Orientación")
## Desviación máxima, en grados, entre hacia dónde mira la ardilla y la pared. 25 exige entrar de frente; 45 admite diagonales.
## También se aplica al seguir agarrado: un pliegue que gira más que esto entre dos fotogramas suelta el agarre. En vivo.
@export_range(5.0, 89.0, 1.0, "suffix:°") var facing_angle_degrees := 30.0
## Mide la desviación solo en horizontal (¿miras hacia la pared?), ignorando lo tendida que esté. Activado permite agarrarse a
## pendientes suaves; apagado (comportamiento anterior) mide en 3D y cualquier cara de menos de ~(90 - Facing Angle) grados
## falla siempre. Las caras casi planas siguen rechazadas. En vivo.
@export var facing_horizontal := false
