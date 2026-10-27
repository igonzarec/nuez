# Pansazo tras una caída fuerte

Una caída que supera **ambos** umbrales, desnivel y velocidad vertical de
impacto, activa `splat`. La ardilla extiende brazos y piernas, cae de panza,
se comprime moderadamente y se incorpora antes de recuperar control. Durante
el estado no puede caminar, correr, saltar, planear ni iniciar escalada.
Mantener Sprint no evita la reacción. No causa daño ni modifica la cápsula.

El desnivel se mide desde la altura máxima del tramo aéreo hasta el contacto.
El apoyo en suelo, el deslizamiento apoyado y la escalada reinician esa referencia. Planeo no la borra,
pero su frenado reduce la velocidad: llegar despacio evita el splat aunque
hayas bajado muchos metros. `Hard Landing Speed` sigue graduando la reacción
normal y es independiente de los nuevos umbrales.

El pansazo tiene prioridad sobre el aterrizaje de planeo si llegas demasiado
rápido. Emite un único evento `splat`, sin añadir el sonido de aterrizaje normal.
Si pierde el suelo durante el estado, recupera la caída. Respawn lo cancela.

## Ajustes físicos

Abre **res://scenes/player.tscn → SquirrelExplorer → Splat por caída**:

| Control | Inicial | Efecto al aumentarlo |
| --- | --- | --- |
| Splat Enabled | Sí | Activa/desactiva todo el estado; desactivarlo permite recuperar control. |
| Min Fall Height | 6 m | Exige una caída más alta. |
| Min Impact Speed | 18 m/s | Exige un golpe más rápido. |
| Duration | 1,25 s (default del script) | Duración mínima; duración fija si Height Duration Enabled está apagado. Conserva el valor guardado en la escena. |
| Height Duration Enabled | Sí | Hace proporcional la duración al desnivel entre Min Fall Height y Full Duration Height. |
| Max Duration | 4 s | Límite superior de duración; nunca menor que Duration. |
| Full Duration Height | 20 m | Altura que alcanza la duración máxima; mayor hace más gradual el aumento. |
| Speed Retention | 0 | Conserva más velocidad horizontal al impactar. |
| Braking | 20 m/s² | Frena antes ese deslizamiento residual. |

Todos llevan el prefijo **Splat**. La duración calculada y Speed Retention se
capturan al impactar; cambios de duración afectan el siguiente splat. Los umbrales
de activación y Braking se consultan en vivo. Con gravedad 30, una caída libre de
6 m llega aproximadamente a 19 m/s, suficiente con estos valores. Para un
golpe reservado a precipicios grandes, prueba 10 m y 22 m/s. Para recuperarse
más rápido, reduce Duration a 0,8 s y Recover Duration a 0,3 s.

### Duración proporcional a la altura

La duración aumenta linealmente entre **Duration** al alcanzar **Min Fall
Height**, y **Max Duration** al alcanzar **Full Duration Height**. Por encima
de esa altura se mantiene el máximo. Se siguen exigiendo ambos umbrales de
activación, incluida la velocidad de impacto.

Con Min Fall Height 6 m, Duration 2 s, Full Duration Height 20 m y Max Duration
4 s: una caída de 6 m da 2 s, una de 13 m da 3 s y una de 20 m o más da 4 s.
El valor personalizado de Duration de la escena se conserva. Apaga **Height
Duration Enabled** para recuperar el comportamiento de tiempo fijo.

Si Max Duration queda por debajo de Duration, se usa Duration como límite.
Si Full Duration Height no supera Min Fall Height, se usa el mínimo más 0,01 m
para evitar divisiones por cero. Configura alturas separadas para que la
progresión sea visible. La compresión y recuperación mantienen sus tiempos;
el tiempo adicional al caer más alto prolonga principalmente la pausa aplastada.

## Pose

En **player.tscn → Animation → Splat por caída**, todos con prefijo **Splat**:

| Control | Inicial | Uso |
| --- | --- | --- |
| Pose Enabled | Sí | Desactiva sólo la pose, conservando bloqueo y audio. |
| Compress Duration | 0,10 s | Tiempo de entrada al pansazo. |
| Recover Duration | 0,45 s | Tramo final de incorporación. |
| Body Pitch Degrees | 90° | Acuesta el cuerpo de panza. |
| Flat Scale | (1,12; 0,65; 1,12) | X/Z ensanchan, Y reduce el grosor vertical. Escala limitada entre 0,05 y 3 por eje. |
| Visual Height | −0,50 m | Baja el modelo hacia el suelo. |
| Arm Spread Degrees | 90° | Extiende los brazos hacia los lados. |
| Leg Spread Degrees | 32° | Separa las patas. |
| Head Pitch Degrees | 0° | Ajusta el hocico respecto al torso. |
| Pose Response | 30 s⁻¹ | Rapidez de mezcla de huesos, inclinación y escala. |
| Surface Follow Enabled | Sí | Sigue el plano de apoyo en pendientes. |
| Clearance Enabled | Sí | Evita que torso y cabeza crucen el plano de apoyo. |
| Clearance Margin | 0,015 m | Separación mínima del plano. |
| Clearance Max Lift | 0,6 m | Límite de elevación correctora. |

Todos los ajustes visuales responden en vivo. Compresión y recuperación se
limitan a Duration; el tiempo intermedio sostiene el pansazo. Mantén Duration
por encima de la suma de ambas transiciones para conservar una pausa visible.
La corrección usa cajas de malla de torso y cabeza: no resuelve cada vértice,
las extremidades ni el relieve completo bajo todo el personaje. Un margen
grande puede hacerlo flotar. El collider siempre conserva su forma normal.

## Pataleo antes de incorporarse

En **player.tscn → Animation → Splat · movimiento antes de levantarse**:

| Control | Inicial | Efecto |
| --- | --- | --- |
| Splat Wiggle Enabled | Sí | Activa sacudidas alternadas de brazos y piernas mientras sigue aplastado. |
| Splat Wiggle Duration | 0,35 s | Ventana inmediatamente anterior al inicio de la incorporación. |
| Splat Wiggle Frequency | 7 Hz | Ciclos por segundo; mayor mueve más rápido. |
| Splat Wiggle Arm Degrees | 14° | Intensidad de movimiento de brazos; 0 los deja quietos. |
| Splat Wiggle Leg Degrees | 20° | Intensidad del pataleo; 0 deja las piernas quietas. |
| Splat Wiggle Pose Response | 50 s⁻¹ | Respuesta de huesos durante estas sacudidas; mayor conserva mejor el movimiento rápido. |

Los cambios responden en vivo. El cuerpo mantiene la postura de pansazo y las
extremidades se mueven alternadas, con entrada y salida suaves. La ventana
se coloca antes de **Recover Duration**, y se recorta al espacio disponible
después de **Compress Duration**. Si no hay pausa disponible, se omite. No añade
tiempo a Splat Duration ni modifica el movimiento físico, el audio o la rapidez
de incorporación. En caídas más altas se retrasa junto con el inicio de la
recuperación; no ocurre inmediatamente después del impacto.

Para una reacción más exagerada, prueba Frequency 9, Arm Degrees 20 y Leg
Degrees 28. Frecuencias altas con una respuesta baja amortiguan el movimiento.
Clearance sigue protegiendo torso y cabeza; comprueba visualmente que las
extremidades no crucen el suelo al aumentar sus ángulos.

## Audio y comprobación manual

`hurt.wav` suena al entrar al splat y al recoil de pared. Ambos usan el mismo
recurso **SquirrelExplorer → Audio de reacciones → Hurt Sound**. El salto usa
**Jump Sound**, ahora con `jump or react.wav`, copiado como `character/jump.wav`.
Los archivos originales de Downloads se conservaron íntegros. Consulta
[`character_audio.md`](character_audio.md) para mezcla, prioridades y extensión.

Para comprobar en juego: saltar normalmente, caer desde más de 6 m manteniendo
Sprint, repetir frenando con planeo, chocar una pared sin agarre y volver a
saltar tras la recuperación. Ajusta en Remote para explorar; copia después
los valores elegidos a Local y guarda la escena. Remote no persiste al detener.
