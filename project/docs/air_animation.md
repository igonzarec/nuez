# Salto, caída y aterrizaje de Nuez

El temblor de Glide se aplica después de la mezcla de salida de la pose aérea.
Así una transición que persigue un clip en movimiento no lo deja bloqueado.
Los controles siguen en **Animation > Planeo · modelo artesanal > Handmade
Glide Tremor Degrees / Speed** y conservan los valores de escena. Un clip
Glide/GlideStart pausado puede reanudarse al volver al planeo; el aterrizaje
deslizante sigue congelando deliberadamente la pose mientras roza el suelo.

Abre `res://scenes/player.tscn`, selecciona **Animation** y busca los grupos
**Salto procedural · postura** y **Aterrizaje procedural**. Todos los controles
incluyen ayuda en el Inspector. En ejecución, el mismo nodo en **Remote**
permite afinar la pose en vivo; copia los valores elegidos a **Local** y guarda
la escena para conservarlos. Los tiempos de contracción y recuperación se
capturan al aterrizar; el resto se consulta continuamente.

El salto abre las piernas y las cierra con el tiempo. En una caída prolongada
vuelven a abrirse gradualmente hacia afuera con sus propios controles. Los brazos
parten bajos y suben al perder velocidad ascendente; al caer alcanzan su límite
y vibran gradualmente. Caer desde una cornisa entra directamente en esa caída.
Run y RunFast se pausan durante el aire. Al tocar suelo se reanudan de inmediato;
la contracción de torso y cabeza se aplica encima de la locomoción terrestre.
Las poses mezclan desde los huesos visibles al entrar y hacia la animación que
corresponda al salir. Climb toma prioridad al agarrarse; Glide usa sus clips.

## Controles iniciales

| Control | Inicial | Ajuste habitual |
| --- | --- | --- |
| Air Pose Enabled | Sí | Desactiva la expresión procedural; en el aire queda la pose base, sin carrera. |
| Air Leg Spread Degrees | 40° | Apertura de cada pierna al despegar. |
| Air Leg Close Duration | 1,5 s | Tiempo para cerrar patas; al empezar a caer terminan de cerrarse suavemente. |
| Air Fall Leg Spread Degrees | 25° | Apertura lateral de cada pierna en caída prolongada. 0 desactiva esta apertura. |
| Air Fall Leg Spread Delay | 0,18 s | Tiempo cayendo antes de empezar a abrirlas. |
| Air Fall Leg Spread Duration | 0,6 s | Tiempo de apertura gradual hasta el ángulo máximo. |
| Air Arm Start Degrees | 5° | Elevación de brazos al despegar. |
| Air Arm Apex Degrees | 56° | Elevación en el punto más alto. |
| Air Arm Fall Degrees | 93,5° | Elevación máxima al caer. |
| Air Arm Inset | 0,08 m | Mete cada hombro hacia el centro del torso según se eleva el brazo. 0 desactiva la corrección. |
| Air Arm Inset Full Angle | 90° | Elevación a la que se alcanza todo el desplazamiento; menor valor aplica la corrección antes. |
| Air Full Fall Speed | 5 m/s | Rapidez descendente que alcanza postura y temblor máximos. |
| Air Tremor Degrees | 10,6° | Intensidad del temblor; 0 lo desactiva. |
| Air Tremor Frequency | 7 Hz | Oscilaciones por segundo; 0 lo desactiva. |
| Air Pose Response | 18 s⁻¹ | Mayor valor responde antes; menor suaviza las transiciones. |
| Landing Body Drop | 0,10 m | Descenso del torso sobre las piernas al impacto máximo. |
| Landing Head Retract | 0,035 m | Retracción adicional de la cabeza. |
| Landing Head Pitch Degrees | 6° | Asentimiento durante la contracción. |
| Landing Compress Duration | 0,07 s | Tiempo hasta máxima contracción. |
| Landing Recover Duration | 0,22 s | Tiempo de recuperación. |
| Landing Locomotion Response | 30 s⁻¹ | Rapidez con que brazos y piernas recuperan el clip terrestre al tocar suelo. |

Estos defaults recogen los ajustes guardados por el usuario en `player.tscn`.
Por ejemplo, baja **Air Arm Fall Degrees** a 90° para una caída más contenida;
usa **Air Tremor Degrees = 1°** y **Frequency = 5 Hz** para suavizar el temblor.
Si la cabeza entra demasiado en el cuerpo, reduce **Landing Head Retract**;
si el aterrizaje se ve muy profundo, baja **Landing Body Drop** a 0,06 m.

Para una apertura de piernas más contenida, prueba **Air Leg Spread Degrees
= 15–20°**. Para cerrarlas antes, reduce **Air Leg Close Duration**, por
ejemplo de 1,5 a 0,5 s. Estos valores no cambian la altura del salto.

Para abrir más las piernas al caer, aumenta **Air Fall Leg Spread Degrees**,
por ejemplo a 35°. **Delay = 0,3 s** retrasa la apertura y **Duration = 1 s**
la hace más lenta. Estos controles están en **Salto procedural · postura**,
son independientes de la apertura al despegar y se actualizan en vivo.
En un salto avanzando la apertura lateral entra junto con la recuperación
de la postura de caída, sin añadir un ciclo de movimiento hacia delante y
atrás. Al tocar suelo las patas recuperan el clip terrestre.

Las uniones redondeadas de los brazos pueden dejar un hueco al levantarse.
**Air Arm Inset** desplaza sus huesos hacia el centro del torso con una curva
suave dependiente de la elevación. El ajuste elegido es 0,08 m; redúcelo si
esconde demasiado el brazo.
La corrección usa el ángulo principal, sin seguir el pequeño temblor, y se
mezcla con el resto de la pose. No modifica el GLB ni las poses de Run, Climb
o Glide. Los valores anteriores personalizados de la escena se conservan.

## Salto avanzando

En el mismo nodo **Animation**, grupo **Salto en movimiento · zancada aérea**,
se captura una pose fija al iniciar el salto: un brazo delante y el otro
detrás, con las piernas en sentido contrario al brazo de su lado. Se conserva
esa postura sin alternar durante el mismo salto. Sólo un nuevo salto invierte
los lados. La velocidad horizontal y la intención de movimiento al despegar
determinan su intensidad; un salto quieto conserva la postura lateral anterior.
No reproduce Run ni RunFast en el aire.

| Control | Inicial | Ajuste habitual |
| --- | --- | --- |
| Air Stride Enabled | Sí | Apagado conserva la postura aérea anterior en todos los saltos. |
| Air Stride Arm Forward Degrees | 67,5° | Ángulo independiente del brazo adelantado. |
| Air Stride Arm Backward Degrees | 96° | Ángulo independiente del brazo retrasado. |
| Air Stride Leg Degrees | 70° | Amplitud opuesta de cada pierna. |
| Air Stride Leg Forward Offset | 0,125 m | Desplaza la pierna adelantada hacia el frente, además del giro. 0 desactiva este desplazamiento. |
| Air Stride Leg Backward Offset | 0,13 m | Desplaza la pierna retrasada hacia atrás de forma independiente. 0 desactiva este desplazamiento. |
| Air Stride Torso Lean Degrees | 15,5° | Inclina el torso hacia delante durante la pose de zancada; 0 lo deja erguido. |
| Air Stride Head Forward Offset | 0,025 m | Adelanta la cabeza respecto al torso durante la zancada. 0 elimina el desplazamiento adicional. |
| Air Stride Full Speed | 3 m/s | Velocidad horizontal para toda la zancada al despegar; afecta el siguiente salto. |
| Air Stride Fall Delay | 0,12 s | Tiempo cayendo antes de comenzar a abandonar la pose fija. |
| Air Stride Fall Start Speed | 1 m/s | Velocidad descendente donde empieza a apagar la zancada. |
| Air Stride Fall End Speed | 6 m/s | Velocidad descendente donde el objetivo ya es la postura de caída normal. |
| Air Stride Blend Speed | 10 s⁻¹ | Rapidez de mezcla entre ambas posturas. |

Los ángulos y la transición se ajustan en vivo. Por ejemplo, **Fall Delay =
0,25 s** conserva más tiempo la pose fija; **Fall End Speed = 4 m/s** recupera antes los brazos elevados de
la caída normal. End debe superar Start; el código protege el intervalo si
se invierten. En una caída larga la recuperación es progresiva y no vuelve
a activar la zancada por una reducción momentánea de velocidad vertical.
Al aterrizar o entrar a Glide/Climb se abandona la zancada. El ajuste Inset
también sigue el giro longitudinal para mantener las uniones del hombro.

Los desplazamientos de piernas cambian de lado junto con la pose de cada
salto y se reducen al recuperar la postura de caída. No oscilan durante el
salto ni mueven la cápsula física. Se ajustan en vivo: prueba **Forward
Offset = 0,04 m** y **Backward Offset = 0,02 m** para adelantar más una pierna
sin retrasar tanto la otra. Valores grandes pueden dejar huecos en las
caderas; conserva desplazamientos pequeños para este rig de piezas rígidas.

La inclinación de torso y el avance de cabeza siguen la misma intensidad de
zancada: se conservan durante el salto en movimiento y desaparecen al entrar
en la postura de caída. Por ejemplo, **Torso Lean Degrees = 12°** acentúa la
intención de avance y **Head Forward Offset = 0,04 m** adelanta más la cabeza.
Ambos se ajustan en vivo sin mover la cápsula física.

La contracción al tocar suelo ya no bloquea el clip terrestre. **Landing
Locomotion Response**, en **Aterrizaje procedural**, mezcla brazos y piernas
hacia el clip desde el primer contacto. Sube de 30 a 40 para una respuesta más
rápida, o baja a 20 para suavizar la transición; la duración de la contracción
del torso sigue controlada por Compress/Recover Duration.

La contracción depende de la velocidad de impacto capturada antes de la
colisión. En el nodo raíz, **Landing Threshold** y **Hard Landing Speed**
siguen delimitando impactos leves y fuertes. La contracción procedural
sustituye el squash global antiguo mientras esté activada: no se suman ambas
compresiones. **Landing Duration/Squash** quedan para el comportamiento
anterior al desactivar Air Pose Enabled.

Sólo cambia el modelo visual. La cápsula, la gravedad, el impulso del salto y
el movimiento físico se conservan. El torso baja mediante `spine` y la cabeza
mediante `head`; las piernas siguen desde `root`, conservando su apoyo base.
El rig tiene una pieza por pierna: no puede doblar rodillas reales. Ajustes
extremos de descenso o retracción pueden cruzar las mallas. El coste es una
mezcla por hueso y frame durante la pose y su transición de salida, sin
generación de geometría.

## Controles de planeo

Mando: pulsar y mantener **R1 / RB** estando en el aire activa planeo; soltar
lo termina. Cruz/A sólo salta o conserva agarre al trepar: ya no inicia planeo.
R1 deja de activar sprint. **L1 / LB** conserva carrera y, junto a R1, planeo
rápido. Teclado conserva otra pulsación de **Espacio** en el aire y mantener;
**Shift** acelera. Mantener el botón desde tierra no inicia planeo automáticamente.
