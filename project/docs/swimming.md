# Nado y buceo

La ardilla nada en cualquier `WaterRiver` o `WaterLake`. No hay que configurar nada por escena: basta con que el agua
exista y tenga **Swimmable** activo.

Escena de prueba: `scenes/3D_playground_water.tscn` (**F6**). Para probar, salta al lago desde la orilla, nada río arriba
contra la corriente o déjate caer por la cascada hasta la poza.

## Controles

| Acción | Mando | Teclado |
|---|---|---|
| Nadar | Stick izquierdo (relativo a la cámara) | WASD |
| Nadar rápido | L1 | Shift |
| Saltar fuera del agua (desde la superficie) | A | Espacio (pulsación corta) |
| Clavado | En el aire sobre agua, pulsar A otra vez | En el aire sobre agua, pulsación corta de Espacio (mantenerla planea) |
| Bucear | Mantener R1 (Planear) | Mantener Espacio |
| Subir | Soltar R1: flota hacia arriba. Mantener A sube más rápido; cada pulsación de A da una brazada hacia arriba | Soltar Espacio |
| Salir caminando | Nadar hacia una orilla poco empinada: al tocar fondo vuelve a caminar | Igual |
| Trepar desde el agua | Mantener A frente a una pared trepable (salta y se agarra) | Igual |

En teclado, Espacio es a la vez Brincar y Planear. Una pulsación corta salta y mantenerla bucea; el umbral es
**Key Hold Time** (0,2 s). Con mando, A y R1 son botones distintos y no hay espera.

## Dónde están los controles

| Qué | Dónde |
|---|---|
| Física del nado, buceo, aire, salpicaduras, ondas y sonido | `scenes/player.tscn` → nodo **Swimming** (`scripts/swimming.gd`) |
| Pose de nado (perrito) y de buceo (braza) | `scenes/player.tscn` → nodo **Animation** → grupos **Nado · …** y **Buceo · postura** |
| Si un agua se puede nadar, empuje de su corriente, profundidad máxima | Cada `WaterRiver` / `WaterLake` → grupo **Nado** |
| Cuánto se ve al jugador sumergido desde fuera | Recurso `WaterStyle` del agua → grupo **Buceador visible** |
| Niebla bajo el agua (sólo con la cámara submarina activada) | Recurso `WaterStyle` del agua → grupo **Bajo el agua** |
| Cámara al nadar y bucear | `CameraRig` (TrailCamera) → grupo **Agua** |

Todos los valores se aplican en vivo. Los de la escena del jugador se guardan en `player.tscn` y afectan también a los NPC
(que comparten esa escena).

### Swimming (nodo del jugador)

**Clavado** (grupo Clavado): con agua debajo (al menos **Dive Jump Min Height**, 1,2 m, y nada sólido en medio), pulsar
Brincar otra vez en el aire pone a la ardilla de cabeza, con los brazos estirados, hasta entrar al agua. Entra limpia
(salpicadura × **Dive Jump Splash Scale**, 0,45), frena menos (**Dive Jump Entry Drag Scale**, 0,45) y sigue bajando
**Dive Jump Plunge Time** (0,7 s) antes de flotar. **Dive Jump Forward Boost** (1,5 m/s) la impulsa hacia delante al
lanzarse. Durante el tiempo de coyote, Brincar sigue siendo un salto normal.

| Grupo | Controles | Notas |
|---|---|---|
| Nado | Swim Enabled, Enter Depth, Exit Depth, Float Depth, Float Response, Bob Height / Speed | Empieza a nadar con más de `Enter Depth` (0,85 m) de agua sobre los pies. Vuelve a caminar al tocar fondo con menos de `Exit Depth` (0,55 m). `Exit Depth` debe ser menor que `Float Depth`. |
| Nado · movimiento | Swim Speed, Swim Sprint Speed, Swim Acceleration, Swim Drag, Swim Turn Speed, Stroke Rate, Tread Stroke Rate, Sprint Stroke Multiplier | Las velocidades son relativas al agua; la corriente se suma aparte. |
| Nado · corriente | Current Push, Face Current | `Current Push` 1 = flota con el agua. Flotando quieta, el cuerpo gira poco a poco río abajo. |
| Nado · entrada y salida | Entry Drag, Jump Velocity, Reentry Delay | `Entry Drag` decide cuánto se hunde al caer al agua. Dentro del agua nunca hay pansazo. |
| Buceo | Dive Enabled, Dive Speed, Dive Swim Speed, Rise Speed, Swim Up Speed, Up Stroke Impulse, Vertical Response, Key Hold Time | |
| Buceo · aire | Air Enabled, Air Seconds, Air Refill Time | Al quedarse sin aire sube sola a respirar, sin daño. Aún no hay indicador en pantalla (`air_ratio` está listo para una interfaz). |
| Salpicaduras y ondas | Effects Enabled, Splash Min / Full Speed, Splash Scale, Splash Droplets, Splash Color, Ripple Interval / Radius / Lifetime / Opacity, Bubbles Enabled | Salpicadura al caer o saltar. Ondas en la superficie al nadar, más seguidas cuanto más rápido. Burbujas al bucear. |
| Empapado | Drip Enabled, Drip Duration, Drip Rate, Drip Size, Drip Spread, Drip Height, Drip Color | Al salir del agua (saltando o caminando) gotea **Drip Duration** (2,5 s), cada vez menos, de forma irregular. Se corta al volver al agua. |
| Audio del agua | Splash Sound, Splash Volume Db, Stroke Sounds, Stroke Order, Stroke Max Repeats, Stroke Sound Each Arm, Stroke Volume Db, Stroke Pitch Variation, Stroke Voices | Ver "Sonidos" abajo. Bus SFX. |
| Audio del buceo | Dive Stroke Sounds Enabled, Dive Start Sound / Volume Db, Dive Start From Surface Only, Dive Start Cooldown, Dive Stroke Sounds, Dive Stroke Order, Dive Stroke Max Repeats, Dive Stroke Volume Db, Dive Stroke Pitch Variation, Dive Stroke Speed Variation, Dive Stroke Rhythm Variation | Ver "Sonidos" abajo. Bus SFX. |
| Audio del buceo · efecto | Underwater Effect Enabled, Dive Stroke Effect Amount, Dive Start Effect Enabled / Amount, Underwater Cutoff Hz, Underwater Resonance, Underwater Pitch, Underwater Reverb, Underwater Reverb Size | Filtro, tono y eco que hacen sonar bajo el agua las brazadas de buceo. Ver "Sonidos". |
| Ambiente submarino | Underwater Ambience Enabled, Underwater Ambience, Volume Db, Fade In / Fade Out, Random Start | Bucle de ambiente mientras el jugador está bajo el agua. Ver "Sonidos". |

### Sonidos (Swimming › Audio del agua)

Los archivos están en `audio/water/`: `diving_splash.wav` (chapuzón) y `swim_1.wav` … `swim_5.wav` (brazadas).

- **Splash Sound:** suena al caer al agua, más bajo y agudo si la caída es suave. Al saltar fuera suena más suave.
- **Stroke Sounds:** una brazada por ciclo, sólo en superficie. Puedes añadir, quitar o reordenar sonidos en la lista.
- **Stroke Order:**
  - **Secuencial:** 1 → 5 y vuelve a empezar.
  - **Aleatorio:** al azar, sin repetir el anterior.
  - **Aleatorio (puede repetir):** al azar entre todos, con un máximo de **Stroke Max Repeats** (2) iguales seguidos.
- **Stroke Sound Each Arm:** un sonido por cada brazo, el doble de seguido. Los sonidos de brazada duran ~0,7 s, así que
  se solapan.
- **Stroke Pitch Variation:** pequeña variación de tono para que el bucle no suene mecánico. 0 = sin variación.
- **Stroke Voices:** brazadas que pueden sonar a la vez; las brazadas no cortan nunca el chapuzón.
- Si se vacía un campo de sonido, se usa el sonido generado por código.

**Buceo** (Swimming › Audio del buceo), con `dive_start_underwater.wav`, `dive_stroke_1.wav` y `dive_stroke_2.wav`:

- **Dive Start Sound:** suena al empezar a bucear. Por defecto `dive_start_underwater.wav` (chapuzón y burbujas, cortado de una grabación submarina); `dive_start.wav` sigue disponible. Con **Dive Start From Surface Only** (encendido) sólo al hundirse
  desde la superficie; apagado, también al volver a pulsar Planear ya bajo el agua. **Dive Start Cooldown** (0,8 s) evita
  que se repita al pulsar seguido.
- **Dive Stroke Sounds:** por defecto las brazadas de superficie `swim_1`, `swim_2`, `swim_3` y `swim_5`, que con el
  efecto submarino suenan bajo el agua. `dive_stroke_1/2.wav` siguen en `audio/water/`, y en `audio/water/underwater_strokes/` hay 7 brazadas submarinas reales (`dive_stroke_uw_1` … `_7`, cortadas de la misma grabación) para arrastrar a la lista. Al ser ya submarinas, conviene bajar el efecto (Cutoff alto o Underwater Effect Enabled apagado).
- **Efecto submarino** (Audio del buceo · efecto), en un bus propio por voz (`SwimDiveVoice0…`, creados al jugar):
  - **Underwater Cutoff Hz** (700): cuánto se apaga el sonido. 300-600 = muy sordo; 1500+ = casi claro.
  - **Underwater Resonance** (0,5): tono hueco y burbujeante junto al corte.
  - **Underwater Pitch** (0,85): más grave y algo más lento.
  - **Underwater Reverb / Reverb Size** (0,25 / 0,45): eco de agua cerrada y su duración.
  - **Underwater Effect Enabled:** apagado, las brazadas suenan sin efecto.
  - **Dive Stroke Effect Amount** (1): intensidad del efecto en las brazadas. 0,2-0,4 = sólo un toque, útil con las
    brazadas `underwater_strokes/`, que ya suenan submarinas.
  - **Dive Start Effect Enabled / Amount** (apagado / 0,4): pasa también el inicio del buceo por el efecto, con su propia
    intensidad.
  - La intensidad mezcla los tres efectos a la vez: el corte baja desde 16 kHz hasta Cutoff, el tono va de 1 a
    Underwater Pitch y el eco de 0 a Underwater Reverb.
- **Dive Stroke Sounds Enabled:** apágalo para que bajo el agua no suenen brazadas (sólo el inicio y el ambiente).
- **Cuándo suenan:** una brazada de braza por ciclo mientras está sumergida, aunque no mueva el stick si mantiene
  Planear. Sustituyen a las brazadas de superficie, que no suenan mientras bucea.
- **Dive Stroke Order:**
  - **Secuencial:** 1, 2, 1, 2…
  - **Aleatorio:** al azar sin repetir el anterior. Con sólo dos sonidos queda igual que el secuencial.
  - **Aleatorio (puede repetir):** al azar, con un máximo de **Dive Stroke Max Repeats** (2) iguales seguidos; por
    ejemplo 1, 1, 2, 1, 2, 2… Con 1 se comporta como Aleatorio.
- **Variación de cada brazada de buceo**, para que no suenen repetitivas:
  - **Dive Stroke Speed Variation** (0,2): acelera el sonido sin cambiar el tono, entre velocidad normal y un 20 % más
    rápido (más corto). Nunca lo hace más lento. Usa un efecto de cambio de tono en un bus propio por voz (`SwimDiveVoice0…`, creados al jugar y enviados a
    SFX).
  - **Dive Stroke Pitch Variation:** tono más agudo o más grave (también cambia un poco la velocidad, como un disco).
  - **Dive Stroke Rhythm Variation** (0 = apagado): cada brazada llega algo antes o después; cambia también el ritmo de la
    animación.
- Si se vacía un campo de buceo, ese sonido no suena.

**Ambiente submarino** (Swimming › Ambiente submarino): `underwater_ambience_loop.wav` suena en bucle mientras el
jugador está sumergido. Aparece en **Fade In** (0,6 s) y se apaga en **Fade Out** (0,9 s) al salir a la superficie. Sólo
suena para el jugador, no para los NPC.

- **Underwater Ambience Volume Db** (0): el archivo es suave (~-28 dBFS); súbelo si queda tapado por las brazadas.
- **Random Start:** cada inmersión empieza en un punto distinto del bucle.
- El archivo viene de una grabación de 60 s: se recortó a 58 s fundiendo los últimos 2 s con el principio, para que el
  empalme no se note, y se importó con **Loop Mode = Forward**. Otro bucle que pongas aquí también necesita ese ajuste en
  la pestaña Import.

### Animation › Clavado · postura

- **Dive Jump Start / Max Pitch Degrees** (105 / 172): el cuerpo empieza casi horizontal y sigue la dirección de la caída
  hasta quedar de cabeza.
- **Dive Jump Response** (9): rapidez del giro.
- **Brazos / piernas / cabeza / cola / orejas:** ángulos de la pose (brazos por encima de la cabeza, piernas rectas y
  juntas, cabeza metida, cola estirada).
- **Dive Jump Visual Height** (0,45 m): sube el cuerpo girado respecto a la cápsula.

### Animation › Nado / Buceo

- **Nado · postura:** inclinación del cuerpo, altura visual (cabeza fuera del agua), cabeza nivelada, balanceos y orejas.
  - Si la cabeza queda muy hundida, sube **Swim Visual Height**.
  - Para una ardilla más erguida, baja **Swim Body Pitch Degrees**.
- **Nado · brazos (perrito):** ángulo central, recorrido, apertura y círculo de cada brazada. Los lados se alternan.
- **Nado · piernas y cola:** pataleo y cola como timón, que gira hacia la curva y ondula con cada brazada.
- **Buceo · postura:** cuerpo tumbado que se inclina hacia donde va (abajo o arriba), braza con ambos brazos y patada de
  rana. Al cruzar la superficie la pose se mezcla suave entre perrito y braza.

Ejemplos:
- **Nado tranquilo:** Stroke Rate 1, Swim Arm Reach 25, Swim Roll 3.
- **Nado nervioso:** Stroke Rate 2,5, Swim Kick 40, Swim Tail Wave 20.

### Agua (WaterRiver / WaterLake › Nado)

- **Swimmable:** apágalo en charcos decorativos.
- **Current Strength:** multiplica el empuje sobre el nadador. La velocidad base es `Flow Speed` del estilo, la misma que
  mueve las ondas, y en los rápidos es mayor.
- **Swim Depth Limit:** profundidad máxima del agua a efectos de nado.

### Estilo (WaterStyle › Buceador visible)

Mientras bucea, sólo la ardilla se ve a través del agua: el fondo, las piedras y el resto del agua no cambian. Si algo
opaco (una roca, la orilla) queda delante, la sigue tapando.

- **Swimmer Clarity** (8 m): metros de agua a través de los que aún se la ve clara. Mayor = nítida aunque bucee hondo.
- **Swimmer Tint** (0,4): cuánto toma el color del agua; aumenta un poco con la profundidad. 0 = colores originales.

### Estilo (WaterStyle › Bajo el agua)

Sólo se usa si la cámara entra en el agua (**Dive Camera Underwater** activado).

- **Underwater Color / Light Color:** color de la niebla hacia el fondo y hacia la superficie.
- **Underwater Fog Distance:** metros a los que la niebla lo tapa casi todo. Lo cercano, como la propia ardilla, queda casi
  limpio. Mayor da agua cristalina; menor, turbia.
- **Underwater Tint / Max Fog:** tinte mínimo junto a la cámara y opacidad máxima a lo lejos.
- **Underwater Surface Color / Window:** la superficie vista desde abajo. Mirando hacia arriba se abre una ventana al
  cielo.

### Cámara (TrailCamera › Agua)

- **Water Line Enabled / Margin:** la cámara nunca baja de la superficie del agua.
- **Dive Camera Underwater** (apagado): al bucear la cámara no cambia; conserva la altura que tenía con la ardilla
  flotando y la ve a través del agua. Encendido, baja con ella bajo el agua (vista submarina con niebla).
- **Dive Look Follow** (0,4): cuánto inclina la mirada hacia la ardilla cuando bucea, sin mover la cámara. 0 = mira a la
  superficie; 1 = a la ardilla.
- **Reveal Swimmer:** deja ver a la ardilla a través del agua (ver Buceador visible). Sólo mientras bucea (cabeza bajo el
  agua), con un fundido de **Reveal Swimmer Fade** (0,4 s) al entrar y al salir.
- **Underwater View Enabled:** niebla submarina, sólo con Dive Camera Underwater.

## Cómo funciona (resumen técnico)

- **Consulta de agua:** `WaterBody.find_water(tree, punto)` recorre el grupo `water_bodies`.
  - Devuelve la superficie, la corriente y el cuerpo de agua.
  - Los ríos guardan sus muestras en coordenadas de mundo al rehacer la malla.
  - Los tramos empinados (cascadas) no cuentan como agua: quien entra cae por la cortina hasta la poza.
  - Donde un río entra en un lago gana la superficie más baja que cubre el punto.
- **Estado del jugador:**
  - `PlayerSwimming.tick()` se ejecuta tras la escalada en `ExplorerPlayer._physics_process`.
  - Cuando nada, controla el movimiento entero: el nado es relativo al agua y la corriente se suma aparte.
  - La flotación es un muelle hacia `Float Depth` y la entrada al agua frena con `Entry Drag`.
- **Pose:**
  - `SquirrelAnimator._tick_swim` inclina y sube el cuerpo.
  - `SquirrelRig._apply_procedural_swim` mueve los huesos: perrito en superficie, braza al bucear.
  - Usa el mismo sistema de miembros por dirección que el patinaje y suaviza la entrada y la salida.
- **Buceador visible:** mientras bucea, la cámara pone `shaders/water/swimmer_reveal.gdshader` como `material_overlay`
  en las mallas del modelo. Se dibuja tras el agua (prioridad 2; ondas 3) y repinta sólo los píxeles del jugador con la
  imagen de antes del agua (screen texture), teñida según la profundidad. Compara con la profundidad de la escena para
  que lo que tenga delante lo siga tapando.
- **Vista submarina (opcional):**
  - Un quad a pantalla completa en la cámara (`shaders/water/underwater_view.gdshader`) aplica niebla según la profundidad
    de la escena.
  - El agua vista desde abajo se decide por la altura de la cámara, no por `FRONT_FACING`: la orientación de las
    caras del lago no es fiable.
- **Efectos:**
  - Las ondas son un grupo fijo de 14 discos con `water_ripple.gdshader`, que no crea nodos mientras nadas.
  - Las salpicaduras son `CPUParticles3D` de un solo disparo que se borran solas.

## Límites conocidos

- **Buceador lejano:** a la distancia normal de la cámara la ardilla sumergida se ve pequeña y teñida; si cuesta
  seguirla, sube Swimmer Clarity o baja Swimmer Tint.
- **Línea del agua en pantalla:** no hay efecto de cámara a medio sumergir; la cámara evita esa posición.
- **Cascadas:** no se pueden nadar hacia arriba. Para subir, trepa por el cliff de al lado.
- **Aire:** sin indicador visual todavía.
- **Reflejo:** la ardilla no se refleja en el agua (fase 5).
