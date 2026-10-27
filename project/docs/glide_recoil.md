# Recoil al chocar planeando

Al chocar con una pared durante Glide, la ardilla cierra las membranas, recoge
brazos y piernas, contrae torso y cabeza y retrocede. El estado visible es
`glide_recoil`. Al terminar pasa a caída con gravedad y control aéreo normales.
Por defecto permanece a la misma altura durante la reacción; Gravity Scale
permite añadir descenso durante ese intervalo. No causa daño ni cambia el collider.

Al entrar emite `wall_recoil`, reproducido con `hurt.wav` mediante **Audio de
reacciones → Hurt Sound** del jugador. Comparte definición con el pansazo de
caídas fuertes. Véanse [audio del personaje](character_audio.md) y
[splat por caída](fall_splat.md).

Mantener **F** en teclado o **Cruz/A** en mando pide escalada y tiene prioridad
si la superficie permite agarrarse, está dentro del alcance y cumple el ángulo
de agarre existente. F también es el botón de escalada desde tierra o caída;
Espacio queda para salto/planeo. R1/RB sigue siendo planeo en mando. Si el agarre
no es válido, el impacto puede producir recoil aunque se mantenga escalada.
Durante recoil no se puede agarrar ni volver a planear. Para volver a desplegar
después hay que soltar y pulsar de nuevo planeo: mantenerlo no cancela la caída.
Tocar suelo interrumpe recoil y devuelve el aterrizaje normal.

## Controles físicos

En **res://scenes/player.tscn → SquirrelExplorer → Choque de planeo**:

| Control | Inicial | Efecto |
| --- | --- | --- |
| Glide Recoil Enabled | Sí | Activa la reacción. |
| Max Angle Degrees | 65° | Desviación máxima del choque frontal; aumentar incluye más roces. Se mide con la trayectoria horizontal previa al choque, no con el giro visual. |
| Min Wall Slope Degrees | 65° | Inclinación mínima desde la horizontal. Siempre excluye suelo caminable y techos. |
| Min Speed | 1,5 m/s | Rapidez horizontal mínima de llegada. |
| Probe Distance | 0,18 m | Anticipación de cápsula; 0 exige contacto físico real. |
| Duration | 0,38 s | Duración del estado antes de caer. |
| Push Speed | 2,5 m/s | Retroceso horizontal desde la pared. |
| Tangent Retention | 0,2 | Fracción de velocidad lateral conservada. |
| Gravity Scale | 0 | Gravedad durante la reacción; 1 usa la normal. |
| Braking | 4 m/s² | Frenado del retroceso. |

Los controles llevan el prefijo **Glide Recoil** en el Inspector. Duración,
retroceso e inercia se capturan al impactar; los demás se consultan en vivo.
La elegibilidad y velocidad de escalada siguen en sus grupos existentes.

## Pose y transiciones

En **player.tscn → Animation → Recoil de planeo**:

| Control | Inicial | Efecto |
| --- | --- | --- |
| Recoil Pose Enabled | Sí | Activa contracción visual, conservando la reacción física al desactivarlo. |
| Compress Duration | 0,08 s | Tiempo hasta máxima contracción. |
| Recover Duration | 0,16 s | Tramo final para recuperar una postura abierta antes de caer. |
| Squash | 0,2 | Compresión vertical del modelo; no cambia colisión. |
| Body Pitch Degrees | 22° | Inclinación hacia atrás. |
| Body Drop | 0,12 m | Descenso del torso. |
| Head Retract | 0,05 m | Retracción de cabeza. |
| Head Pitch Degrees | 20° | Cabeza hacia el pecho. |
| Arm Lift Degrees | 25° | Apertura lateral de brazos. |
| Arm Tuck Degrees | 55° | Brazos hacia delante, junto al pecho. |
| Leg Tuck Degrees | 45° | Piernas hacia la panza. |
| Pose Response | 28 s⁻¹ | Rapidez de mezcla hacia la pose. |

Todos llevan el prefijo **Recoil** y responden en vivo. Compresión y recuperación
se limitan a la duración física del estado. Aumentar Duration permite sostener
la postura más tiempo sin ralentizar la entrada. Para un golpe seco prueba
Compress Duration 0,04 y Pose Response 40; para más recogimiento aumenta
Arm/Leg Tuck y Head Retract moderadamente, vigilando cruces entre piezas.

Para experimentar, edita los nodos en **Remote** durante el juego. Para guardar
los ajustes, aplícalos a los nodos locales de player.tscn y guarda la escena.
No se han sobrescrito los valores existentes de las demás animaciones.

## Alcance de la detección

Usa contactos reales de la cápsula y una consulta adicional en la dirección de
avance. Funciona con paredes físicas aunque no sean escalables; no necesita
etiqueta de cliff. No detecta por separado alas, cola o cada vértice de la malla.
Si el cuerpo visual cruza antes del contacto, aumenta Probe Distance; demasiado
alcance produce una reacción antes de tocar visiblemente. Los choques fuera
del ángulo o por debajo de la velocidad mínima conservan la colisión normal.

Comprobación manual sugerida: choque frontal sin escalada, llegada con F/A
mantenido, roce lateral fuera del ángulo, aterrizaje sobre pendiente caminable,
mantener planeo tras recoil y soltar/pulsar de nuevo después de la reacción.
