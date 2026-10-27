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
| Inherit Entry Tilt Enabled | Sí | Comienza desde la inclinación visual real de llegada, sin enderezarse antes del pansazo. Se captura en el siguiente impacto. |
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
**Inherit Entry Tilt Enabled** se captura en el siguiente splat: guarda la
orientación completa al impactar y la mezcla directamente hacia la postura
aplastada durante Compress Duration. Así aprovecha la inclinación que ya
traía al caer o planear, sin regresar primero a cero. Apagar recupera la
entrada anterior. Los valores guardados de altura, escala y recuperación se conservan.
La corrección usa cajas de malla de torso y cabeza: no resuelve cada vértice,
las extremidades ni el relieve completo bajo todo el personaje. Un margen
grande puede hacerlo flotar. El collider siempre conserva su forma normal.

## Pataleo antes de incorporarse

En **player.tscn → Animation → Splat · movimiento antes de levantarse**:

| Control | Inicial | Efecto |
| --- | --- | --- |
| Splat Wiggle Enabled | Sí | Activa movimiento de extremidades, incluidos brazos por pulsaciones. |
| Splat Wiggle Auto Full State Enabled | Sí | Mueve brazos, piernas, cabeza, torso y cola sin pulsar, después de absorber el impacto. |
| Splat Wiggle Auto Speed Multiplier | 1,5 | Ritmo automático un 50 % mayor que la base, respetando Wiggle Max Hz. |
| Splat Wiggle Duration | 0,35 s | Ventana de piernas antes de incorporarse y de brazos desde el inicio de la incorporación. |
| Splat Wiggle Frequency | 7 Hz | Ciclos por segundo; mayor mueve más rápido. |
| Splat Wiggle Max Hz | 20 Hz | Límite global: ni el movimiento automático ni las pulsaciones lo superan. 0 detiene las oscilaciones. |
| Splat Wiggle Arm Degrees | 14° | Intensidad de movimiento de brazos; 0 los deja quietos. |
| Splat Wiggle Leg Degrees | 20° | Intensidad del pataleo; 0 deja las piernas quietas. |
| Splat Wiggle Pose Response | 50 s⁻¹ | Respuesta de huesos durante estas sacudidas; mayor conserva mejor el movimiento rápido. |

**Wiggle Max Hz** se aplica en vivo sin sobrescribir Wiggle Frequency ni Tap
Max Frequency. Por ejemplo, con frecuencia base 0,5 Hz, Tap Max Frequency 14 Hz
y Wiggle Max Hz 3 Hz, las pulsaciones aceleran desde 0,5 hasta 3 Hz como máximo.
Si la base supera el límite, también se recorta. Cabeza y torso siguen usando
sus multiplicadores sobre la frecuencia ya limitada. El default 20 Hz conserva
el rango anterior; no modifica los ajustes guardados de la escena.

Por defecto todos los miembros se mueven automáticamente tras la compresión,
con entrada gradual y salida al incorporarse. **Auto Speed Multiplier** aumenta
un poco ese ritmo: con Wiggle Frequency 1 Hz y máximo 3 Hz, el automático va a
1,5 Hz. X acelera desde esa rapidez hasta el máximo permitido. Si ya se alcanza
Wiggle Max Hz, aumentar el multiplicador no lo supera. Cada miembro conserva
sus amplitudes, interruptores y límites propios.

Con **Auto Full State Enabled** activo, Wiggle Duration determina la entrada
suave al movimiento tras la compresión (mínimo 0,01 s). No reduce el bloqueo.
Si apagas esa opción recuperas las ventanas anteriores, descritas a continuación.

Los cambios responden en vivo. En el modo anterior, las piernas conservan el pataleo previo a
**Recover Duration**, recortado al espacio después de **Compress Duration**.
Sin pulsar, los brazos se mueven sólo desde el inicio de la incorporación,
durante Wiggle Duration o lo que quede del estado, con entrada y salida suaves.
Las pulsaciones descritas abajo permiten adelantarlos mientras sigue aplastado.
No añade tiempo a Splat Duration ni modifica física, audio o rapidez de
incorporación. En caídas altas el movimiento automático espera a la recuperación.

Para una reacción más exagerada, prueba Frequency 9, Arm Degrees 20 y Leg
Degrees 28. Frecuencias altas con una respuesta baja amortiguan el movimiento.
Clearance sigue protegiendo torso y cabeza; comprueba visualmente que las
extremidades no crucen el suelo al aumentar sus ángulos.

## Cabeza diciendo «no» y balanceo del torso

En **Animation → Splat · cabeza y torso** puedes ajustar dos gestos que
acompañan al pataleo: la cabeza gira a cada lado del cuello como diciendo «no,
no», mientras el torso se inclina suavemente a izquierda y derecha respecto
a las caderas. No gira el personaje entero ni mueve la cámara.

| Control | Inicial | Efecto |
| --- | --- | --- |
| Splat Head Shake Enabled | Sí | Activa el gesto de cabeza. |
| Splat Head Shake Degrees | 12° | Amplitud a cada lado; mayor hace más marcado el «no». |
| Splat Head Shake Frequency Multiplier | 0,35 | Fracción de la frecuencia de extremidades para la cabeza. |
| Splat Head Shake Max Hz | 20 Hz | Límite independiente de rapidez del «no», incluso pulsando repetidamente; 0 detiene ese giro adicional. |
| Splat Torso Sway Enabled | Sí | Activa inclinación lateral del pecho. |
| Splat Torso Sway Degrees | 4° | Amplitud del torso; menor deja un balanceo más sutil. |
| Splat Torso Sway Frequency Multiplier | 0,25 | Fracción de la frecuencia de extremidades para el torso. |

Todos responden en vivo. Con el pataleo base de 7 Hz, la cabeza se mueve a
2,45 ciclos/s y el torso a 1,75 ciclos/s: más tranquilos que brazos y piernas.
Pulsar repetidamente acelera también estos gestos, respetando sus multiplicadores.
No aumenta su amplitud ni reduce el tiempo de splat.

**Head Shake Max Hz** se aplica después del multiplicador y del límite global
de wiggle. Por ejemplo, Wiggle a 10 Hz × Head Multiplier 0,35 pide 3,5 Hz;
con Head Shake Max Hz en 2, el «no» queda limitado a 2 ciclos/s. El torso y
las extremidades mantienen sus frecuencias propias. El control responde en
vivo y no modifica los valores guardados del multiplicador. El default de
20 Hz conserva el rango previo; bájalo para imponer el límite deseado. Con
0 la cabeza vuelve a su pose sin giro adicional, aunque sigue acompañando al
torso por la jerarquía y conserva el ajuste de Head Pitch.

Se activan en las ventanas de pataleo automático y desde la primera pulsación
manual, con las mismas entradas y salidas suaves. Si no hay movimiento activo,
recuperan la postura normal. Cada gesto tiene un reloj continuo para no saltar
al cambiar la rapidez y se reinicia en cada splat/respawn. Requieren **Splat
Wiggle Enabled** y **Splat Pose Enabled**. Pueden desactivarse por separado.

La cabeza conserva además su ajuste **Splat Head Pitch** y acompaña el torso
por la jerarquía de huesos. La protección existente de torso/cabeza sigue activa;
ángulos extremos aún pueden causar cruces entre piezas. Para algo más sutil,
prueba Head Shake 8° y Torso Sway 2°; para un «no» más lento baja el multiplicador
de cabeza a 0,2. Comprueba el gesto tanto aplastado como durante la incorporación.

## Agitar brazos y piernas pulsando salto

### Qué controla el tiempo y qué controla X

- **SquirrelExplorer → Splat por caída → Splat Duration / Splat Max Duration**:
  tiempo total del estado según altura. En la escena se conservan 2 s de base
  y el máximo inicial es 4 s. Para un estado más corto, reduce ambos; el máximo
  efectivo nunca queda por debajo de Duration.
- **Animation → Splat · extremidades por pulsaciones → Splat Tap Duration**:
  cuánto sigue el pataleo después de cada toque, no cuánto dura el estado.
- **Splat Tap Speed Gain / Speed Decay**: cuántas pulsaciones seguidas necesitas
  para acumular rapidez y cuánto se pierde entre ellas. Mayor Gain o menor
  Decay permite alcanzar la rapidez máxima con menos pulsaciones.
- **Animation → Splat por caída → Splat Recover Duration**: tiempo de la
  incorporación dentro del total. Las pulsaciones no adelantan esta fase.

Durante splat, pulsa **Cruz/X en PlayStation**, **A en Xbox** o **Espacio en
teclado**, la misma acción `jump`. Una pulsación inicia el movimiento de brazos y piernas
inmediatamente; varias seguidas acumulan rapidez hasta el máximo. Cada toque
renueva una ventana breve de movimiento. Mantener el botón no acumula pulsaciones.

En **Animation → Splat · extremidades por pulsaciones**:

| Control | Inicial | Efecto |
| --- | --- | --- |
| Splat Tap Enabled | Sí | Permite agitar brazos y piernas manualmente, con lados alternados. |
| Duration | 0,35 s | Tiempo de movimiento tras el último toque, con salida suave. |
| Max Frequency | 14 Hz | Rapidez objetivo de pulsaciones; parte de Wiggle Frequency y siempre respeta Wiggle Max Hz. |
| Speed Gain | 0,3 | Energía añadida por toque; mayor necesita menos pulsaciones. |
| Speed Decay | 0,6/s | Pérdida gradual de esa energía; mayor exige pulsar más seguido. |
| Transition Response | 12 s⁻¹ | Suaviza el cambio de rapidez al pulsar y al dejar de pulsar. Mayor responde antes. |

### Continuidad al pulsar X

El automático y las pulsaciones usan un mismo reloj continuo para brazos y
piernas. X renueva el impulso y aumenta la rapidez, sin reiniciar el ciclo ni
cambiar su amplitud automática. Al dejar de pulsar vuelve gradualmente al
ritmo base desde el punto donde se quedó. Cabeza, torso y cola conservan
también sus propios relojes; ninguno vuelve al principio por pulsar X.

**Splat Tap Transition Response**, en el mismo grupo del Inspector, controla
la rapidez de esa transición. Prueba 6 para una aceleración más gradual o 20
para mayor respuesta. Se consulta en vivo y no afecta el tiempo total del splat,
los límites de Hz ni los ángulos personalizados. Los relojes sólo se reinician
al entrar a un nuevo splat o al reaparecer. Con Auto Full State apagado, el
movimiento manual entra y sale suavemente conservando también la fase.

Todos llevan el prefijo **Splat Tap** y responden en vivo. Las amplitudes siguen
en **Splat Wiggle Arm Degrees** y **Splat Wiggle Leg Degrees**, y la respuesta en **Splat Wiggle Pose Response**.
El movimiento manual tiene prioridad sobre el automático y se suma a la postura
de apoyo; puede agitar las manos mientras empuja. Se desvanece al dejar de
pulsar y al terminar la recuperación. No acelera el levantamiento ni reduce
el tiempo en el piso, ni activa saltos ni emite el audio de salto.
Las piernas siguen la misma frecuencia acelerada que los brazos; el movimiento
manual sustituye temporalmente su pataleo automático y conserva su amplitud propia.

Requiere **Splat Pose Enabled** y **Splat Wiggle Enabled**. La energía se limpia
al entrar en un nuevo splat y al reaparecer. Sin pulsar se mantiene el movimiento
automático; sólo con Auto Full State apagado los brazos esperan al inicio
de la incorporación. Para comprobarlo, pulsa una vez al caer,
después varias veces seguidas, deja de pulsar y compara con una caída sin tocar
el botón. Ajusta amplitud si las manos cruzan el suelo.

## Movimiento lateral de cola

En **Animation → Splat · movimiento de cola**, la cola barre a izquierda y
derecha junto al movimiento automático. X/A/Espacio acelera el gesto durante
Tap Duration; al dejar de pulsar regresa al ritmo automático. Con Auto Full
State apagado, sólo se mueve por pulsaciones y se desvanece al dejarlas.

| Control | Inicial | Efecto |
| --- | --- | --- |
| Splat Tail Sway Enabled | Sí | Activa sólo este balanceo de cola. |
| Splat Tail Sway Degrees | 18° | Amplitud lateral a cada lado; mayor amplía el barrido. |
| Splat Tail Sway Frequency Multiplier | 0,5 | Frecuencia relativa al pataleo efectivo; menor mueve la cola más despacio. |
| Splat Tail Sway Max Hz | 3 Hz | Máxima rapidez propia; 0 detiene la oscilación de cola. |

Los ajustes responden en vivo y requieren Wiggle Enabled y Pose Enabled.
Tap Enabled sólo es necesario para el control manual. Las pulsaciones aceleran la cola respetando su multiplicador, su
máximo y el límite global de wiggle. Sólo gira el hueso `tail_base`; conserva
los ajustes de las otras animaciones y no acorta el splat. Comprueba el barrido
al aumentar Degrees, porque la protección de suelo cubre torso y cabeza,
no la cola. El reloj se reinicia en cada splat/respawn.

## Apoyo de manos al levantarse

En **player.tscn → Animation → Splat · apoyo para levantarse** se controla una
incorporación en tres pasos: recoge los brazos y prepara el apoyo con la panza
baja, empuja para levantar el pecho y finalmente suelta las manos para quedar
erguido. El pataleo automático de piernas termina antes de esta preparación;
los brazos pueden agitarse al incorporarse o desde las pulsaciones anteriores.

| Control | Inicial | Efecto |
| --- | --- | --- |
| Splat Support Enabled | Sí | Activa la incorporación con apoyo; apagar recupera la transición previa. |
| Plant Fraction | 0,25 | Primer 25 % de Recover Duration para preparar manos sin levantar aún el pecho. |
| Push End Fraction | 0,72 | Termina de empujar al 72 % y después se incorpora soltando las manos. |
| Body Pitch Degrees | 35° | Inclinación del pecho al acabar el empuje; 0 erguido, 90 tumbado. |
| Arm Spread Degrees | 22° | Separación de brazos al apoyarse, más cerca del pecho que durante el pansazo. |
| Arm Pitch Offset Degrees | 0° | Corrección hacia delante/atrás del giro que mantiene los brazos orientados al suelo. |
| Pose Response | 55 s⁻¹ | Rapidez mínima de mezcla de huesos durante el apoyo. |

Todos llevan el prefijo **Splat Support**, responden en vivo y caben dentro
de **Splat Recover Duration**: no añaden tiempo al estado. Plant Fraction y
Push End Fraction se expresan de 0 a 1; el final del empuje se limita a por lo
menos Plant Fraction + 0,05. Body Pitch se limita al ángulo de pansazo existente.
La escala y altura visual empiezan a recuperarse después de preparar las manos.
Se conservan los ajustes guardados de recuperación, altura y escala.

Con Recover Duration 0,2 s, el apoyo es muy rápido: 0,05 s de preparación,
0,094 s de empuje y 0,056 s de incorporación final. Para apreciar el gesto con
más claridad, prueba 0,5–0,7 s de Recover Duration. La duración del pansazo total
sigue controlada por el nodo raíz y su progresión con altura.

Es una pose procedural de los brazos rígidos actuales, sin codos articulados
ni IK que ancle las palmas a puntos físicos. Las manos acompañan el empuje,
pero pueden deslizar o separarse del suelo según la proporción, pendiente y
Visual Height. Ajusta Arm Spread y Arm Pitch Offset mirando la escena; la
protección de intersecciones sigue cubriendo torso y cabeza, no las manos.

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
