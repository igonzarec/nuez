# Lantern Trail

Una expedición 3D breve para **Godot 4.6**, con una ardilla sin ropa ni accesorios, una montaña que se puede rodear y una cima accesible. Recoge semillas de luz, restaura tres faroles y regresa con Mara al refugio.

## Ejecutar

1. Abre Godot 4.6 (Standard o Mono).
2. Importa `project.godot` desde esta carpeta.
3. Pulsa **F5**. La escena principal es `main.tscn`; comienza en el título.
4. Elige **Nueva expedición**. Cuando exista progreso, **Continuar** estará disponible.

Incluye **Dialogue Manager 3.10.4** (MIT, Nathan Hoad) para conversaciones editables, elecciones y condiciones narrativas. No requiere .NET ni una solución C#. La ardilla utiliza el modelo artesanal `playertest2.glb`, incluido en el proyecto; el escenario y el audio se construyen con recursos propios. Las capturas de referencia no están incluidas como assets.

## Controles

| Acción | Teclado y ratón | Mando estándar |
| --- | --- | --- |
| Mover | WASD / flechas | Stick izquierdo |
| Cámara | Mantener clic derecho y arrastrar | Stick derecho |
| Saltar | Espacio | Botón sur (A / cruz) |
| Planear | Pulsar Espacio ya en el aire y mantenerlo | Pulsar A / cruz ya en el aire y mantenerlo |
| Interactuar | E | Botón oeste (X / cuadrado) |
| Correr rápido | Mantener Shift | Mantener L1 o R1 mientras mueves el stick |
| Pausa | Escape | Menú / Start, si el reinicio rápido está desactivado |
| Menús | Ratón, flechas, Tab, Enter | Cruceta y botón sur; este para volver |

El cursor permanece visible y libre, incluso durante el arrastre. Mover el ratón sin mantener el botón derecho no cambia la cámara; puedes salir de la ventana y usar otras aplicaciones.

La cámara conserva un radio fijo de **14,4 unidades** desde el punto de enfoque del personaje, con seguimiento y órbita amortiguados e interpolación física. No tiene zoom ni brazo retráctil: los objetos nunca pueden acercarla al jugador. La vista normal está limitada entre **−54° y −42°**; durante planeo se mezcla hacia un ángulo configurable en el Inspector de `CameraRig`. La cámara no gira al mover al personaje. Los objetos pueden ocultar temporalmente al personaje; el giro horizontal permite despejar la vista sin alterar la distancia.

## Ardilla y movimiento

El personaje jugable es el modelo artesanal `assets/playertest2/playertest2.glb`. Su archivo fuente es `playertest2.blend`. El GLB contiene el armature `NuezRig`, el clip de caminata `Run`, el clip de sprint `RunFast`, la transición `GlideStart`, el clip de planeo `Glide` y las dos membranas.

Cada membrana tiene la Shape Key `membrana_abierta`: `0` es plegada y `1` es abierta. Godot controla ese valor directamente durante el planeo, además de ocultar las dos membranas fuera de Glide: una Shape Key plegada no vuelve invisible su malla. Edita el rig, pesos o Shape Keys en `playertest2.blend`; después vuelve a exportar el GLB a `assets/playertest2/playertest2.glb`.

**Regla de visibilidad por estado:** cuando un objeto de Blender deba desaparecer durante un estado de juego, controla su propiedad `visible` desde Godot según el estado, siguiendo el ejemplo de las membranas. Una Shape Key sirve para deformar la malla, no para ocultarla; no dependas solo de un valor `0` ni de ocultar el objeto desde el Outliner de Blender.

Las pendientes no caminables permiten resbalar suavemente y dirigir el deslizamiento de lado. La cámara conserva una distancia fija y puede elevar su vista durante el planeo. La interfaz permanece nítida sobre el acabado pixelado del mundo.

El movimiento comienza en el primer tick físico. La aceleración se aplica al vector completo, el frenado es gradual y la orientación sigue el desplazamiento real. El salto conserva su arco al pausar o abrir diálogo. La adherencia al suelo evita deslizamiento en reposo. Los clips de Blender animan los huesos del modelo, mientras que Godot mezcla inclinación, rebote, apertura de membranas y temblor de miembros.

Valores ajustables en el Inspector de `scenes/player.tscn`:

| Parámetro del jugador | Valor inicial |
| --- | --- |
| Walk Speed / Sprint Speed | 5,6 / 8 unidades/s |
| Acceleration / Deceleration | 32 / 44 unidades/s² |
| Turn Speed | 16 |
| Jump Velocity / Gravity | 8,52 / 22 |
| Air Control | 0,52 |
| Coyote Time / Jump Buffer | 0,10 / 0,12 s |
| Landing Threshold / Hard Landing Speed | 2,5 / 18 unidades/s |
| Snap Distance / Walkable Slope Degrees | 0,35 / 48° |

En el hijo **Animation** encontrarás los grupos **Ritmo y transiciones**, **Cuerpo**, **Salto y aterrizaje**, **Postura de planeo** y **Planeo · modelo artesanal**. `Idle` se activa al no haber desplazamiento: detiene el clip de movimiento y restablece la pose de reposo real del rig (piernas y brazos rectos), sin aplicar movimiento adicional. Durante Glide, `Glide Lean Degrees` conserva la postura base; una entrada de movimiento y R1/Shift pueden sumar inclinación adicional. Ahí también se ajustan inclinación, apertura/cierre de membranas, velocidad de `GlideStart`, velocidad de `Glide` y temblor de brazos/piernas.

El audio ya no incluye el acorde grave continuo. La música usa notas suaves separadas por silencios; los pasos emplean ruido filtrado breve sin tono grave sostenido. Los bucles arrancan una sola vez, después de aplicar los volúmenes guardados.

Al subir pendientes, el controlador conserva la velocidad sobre la superficie y entra en cada triángulo siguiendo su inclinación. El contacto explícito con el suelo evita pequeños saltos entre caras. Esto corrige las paradas breves que provocaba reiniciar la velocidad vertical a cero.

## Expedición

Detrás de las rocas del norte hay un paso hacia el **Paredón de la Cruz** (frente en Z = −48). Sustituye las montañas decorativas de conos por roca escalable de 52 metros, repisas laterales y una cima nevada con cruz.

Mantén **Brincar / A / cruz** cerca de la roca y mirándola de frente para agarrarte. También se agarra al llegar manteniendo el botón desde el salto; eso sigue sin activar el planeo automáticamente. Mientras estás agarrado, arriba/abajo del stick o W/S suben/bajan, y izquierda/derecha o A/D desplazan por la pared. Soltar Brincar te desprende; una nueva pulsación en el aire permite planear. La salida por el borde comprueba espacio y sube el cuerpo a la plataforma. No hay resistencia limitada.

En `SquirrelExplorer → Escalada` están velocidad, alcance y ángulo de agarre, distancia a la pared, separación al soltar, amplitud/ritmo de miembros y distancia entre sonidos. El volumen está en **Ajustes → Raspado de escalada**. La postura es procedural y las membranas se ocultan desde código. Las superficies escalables se identifican por el grupo físico `climbable`, no solo por su color.

Lee el letrero y habla con Mara. El sendero asciende en espiral por todas las caras de la montaña. Los faroles del claro, del pinar y de la cima cuestan **3 semillas cada uno**. Hay 15 semillas en total: nueve necesarias y seis adicionales. Puedes explorar y encender los faroles en cualquier orden si tienes semillas suficientes.

Cada farol encendido queda como punto de recuperación. Tras encender los tres, vuelve con Mara: su conversación inicia la llegada de los vecinos al refugio, seguida de la pantalla final con tiempo y semillas recogidas. Puedes volver al título o jugar otra vez.

## Interacciones y diálogos

Al acercarte a un letrero, vecino u objeto interactuable que no esté bloqueado por una pared aparece una **pequeña burbuja flotante**, crema, con punta inferior y un botón oscuro. Muestra `E` en teclado, `X` en Xbox o `×` en PlayStation detectado. X de Xbox/cuadrado de PlayStation siempre interactúa; A/cruz también interactúa si estás en tierra y hay un objetivo válido. Esa pulsación se consume hasta soltar para evitar que saltes a la vez. Fuera de ese contexto, A/cruz conserva salto, planeo y escalada.

Las conversaciones narrativas usan archivos `.dialogue` de Dialogue Manager. El primer ejemplo está en `dialogue/paso_de_bruma.dialogue`, asignado al letrero **Paso de Bruma** junto al sendero. El fondo se compone de pinceladas crema con bordes difuminados y sombra opcional; el nombre tiene su propia pincelada morada arriba a la izquierda. El texto permanece nítido. La flecha amarilla centrada debajo flota suavemente incluso con el juego pausado. Las páginas antiguas de Mara y los otros letreros comparten este diseño. `Esc/B/círculo` cierra; `E/X/A/cruz` revela el texto y después avanza o elige la respuesta enfocada. La cruceta cambia la respuesta.

### Ajustar el diseño con vista previa en el editor

En **Balloon → DialogueBox → Presentation**, cambia **Presentation Mode** entre
**Fijo en pantalla** (predeterminado) y **Sobre personaje**. El segundo sigue al
NPC o letrero con el que abriste la conversación; si no hay anclaje válido vuelve
a pantalla fija. No cambia automáticamente de personaje por el nombre de una
línea: para conversaciones de varios actores se puede llamar a
`set_follow_target(nodo_3d)` en el balloon.

Controles de presentación:

- **Fixed Scale = 1 / Overhead Scale = 0.65:** tamaño relativo por modalidad.
- **Overhead World Offset = (0,2.5,0):** altura sobre el origen del interlocutor,
  en metros. **Overhead Screen Offset = (0,-25)** lo eleva 25 píxeles adicionales.
- **Follow Speed = 12:** suavizado del seguimiento; 0 es instantáneo.
- **Keep On Screen / Screen Margin = 20:** evita salir de pantalla con tamaños
  que caben en ella. **Hide Behind Camera:** oculta el globo detrás de la cámara.
- **Preview Anchor = (0.5,0.65):** punto simulado para el modo sobre personaje
  dentro del editor 2D, donde no hay interlocutor 3D.

En **Appearance Animation**, ambos modos comparten entrada configurable:
`Appearance Duration = 0.25`, `Appearance Start Scale = 0.88`,
`Appearance Slide = (0,18)` y `Appearance Fade = true`.
`Appearance Easing` ofrece **Suave** o **Rebote leve**.
`Animate Each Page` repite la entrada al avanzar (desactivado por defecto).
`Appearance Enabled = false` o duración 0 la desactiva.
Marca **Preview Appearance** para verla una vez en el editor.
La flecha mantiene su flotación independiente. Las respuestas conservan su
tamaño legible y se recolocan cerca del globo sin escalarse con él.

En **Ambient Loop**, el diálogo respira mientras está visible:

- **Ambient Enabled:** interruptor general del loop.
- **Breathing Enabled / Percent / Period:** respiración solo del fondo crema
  (y su sombra), sin deformar el texto. Valores iniciales: **0.75% / 3.5 s**.
- **Floating Enabled / Amplitude / Period:** flotación vertical del conjunto.
  Valores iniciales: **1.5 píxeles / 4 s**.
- **Fixed Loop Intensity = 1 / Overhead Loop Intensity = 0.5:** intensidad
  independiente para cada modalidad.

La escena se muestra en el editor **2D**, con nombre y texto de ejemplo y
el tamaño de lienzo configurado en el proyecto (1280×720).
**Animate Editor Preview** permite ver el loop y la flecha animados;
al desactivarlo, el fondo queda estático sin ocultarse.

Abre `ui/dialogue/squirrel_dialogue_balloon.tscn` en la vista **2D**, selecciona **Balloon → DialogueBox** y edita sus propiedades en el Inspector. El script `@tool` actualiza la nube en el editor sin ejecutar el juego. Guarda la escena para aplicar los valores a todas las conversaciones.

| Propiedad | Ejemplo | Efecto |
| --- | --- | --- |
| Cloud Width / Height | 960 / 240 | Tamaño del área en píxeles |
| Bottom Margin | 75 | Distancia al borde inferior |
| Brush Style | Suave | Suave (referencia), Gis / Tiza, Acuarela o Pincel seco |
| Stroke Count / Thickness / Spacing | 5 / 65 / 40 | Cantidad, grosor y separación de centros |
| Length Variation / Horizontal Variation | 0,12 / 35 | Longitudes y posiciones irregulares |
| Edge Softness / Texture Strength | 12 / 0,45 | Difuminado y textura; para tiza prueba 2 / 0,7 |
| Brush Seed | 7 | Distribución estable; cambia el número para otra variante |
| Text Margins | (80, 30, 80, 35) | Izquierda, arriba, derecha, abajo |
| Text Font / Line Spacing | fuente opcional / 4 | Fuente e interlineado |
| Text Font Weight | 400 | Peso del contenido: 400 normal, 600 seminegrita, 700 negrita |
| Text Size | 28 | Tamaño del texto |
| Name Auto Size | activado | Ajusta la pincelada al texto del personaje |
| Name Min/Max Width | 140 / 350 | Límites de ancho para nombres cortos o largos |
| Name Min/Max Height | 48 / 100 | Límites de alto si el nombre ocupa varias líneas |
| Name Text Margins | (24, 8, 20, 8) | Espacio alrededor del nombre dentro de lo morado |
| Subtitle Text Color | amarillo suave | Color de la segunda línea, por ejemplo un rol |
| Name Text Size / Name Font | 26 / opcional | Tamaño y fuente del título |
| Subtitle Text Size / Subtitle Font | 20 / opcional | Tamaño y fuente independientes del subtítulo |
| Name Font Weight / Subtitle Font Weight | 400 / 400 | Pesos independientes para título y subtítulo |
| Name Line Spacing | 2 | Separación entre los renglones de la etiqueta |
| Name Brush Auto Strokes | activado | Un trazo morado por renglón, hasta ocho |
| Name Brush Strokes / Variation | 2 / 0,08 | Cantidad manual (desactiva Auto Strokes) e irregularidad |
| Title Content Gap | 10 | Separación del contenido respecto a la etiqueta inclinada |
| Name Offset / Tilt | (-25, -40) / 0 | Posición y ángulo de la etiqueta |
| Name Text Size / Color | 26 / blanco | Texto del nombre |
| Shadow Enabled / Softness | activado / 12 | Activa y difumina la sombra |
| Shadow Offset / Color | (5, 7) / café translúcido | Desplazamiento, color y opacidad de la sombra |
| Arrow Enabled / Size | activado / (36, 24) | Visibilidad y tamaño de la flecha inferior |
| Arrow Float Amplitude | 4 | Amplitud vertical en píxeles; 0 la deja fija |
| Arrow Float Speed | 0,8 | Ciclos de flotación por segundo |
| Animate Editor Preview | activado | Anima la flecha también en la vista previa |
| Cloud / Name / Text / Arrow Color | crema / morado / café / amarillo | Colores independientes |
| Preview Name / Text | Mara / mensaje de muestra | Solo vista previa; no cambia el guion |

El contenido se pagina automáticamente dentro de **Layout → Text Margins**
(izquierda, arriba, derecha, abajo), reservando además espacio para la etiqueta
morada inclinada. **X/E/A/cruz** primero completa la escritura de la página;
la siguiente pulsación muestra la página siguiente. Solo al terminar todas las
páginas se avanza a otra línea o aparecen las respuestas. También funciona con
las páginas manuales de Mara y al hacer clic. Se conservan el formato y las
acciones de Dialogue Manager en sus posiciones originales.

**Editor Preview → Preview Content Page** permite revisar cada página en el
editor, desde 1. Cambiar fuente, peso, tamaño o padding recalcula los saltos.
Si los márgenes dejan menos de un renglón de espacio, la altura del cuadro crece
lo necesario para alojarlo.

Los tres controles **Font Weight** aceptan 100–900. En fuentes variables se usa
su eje de peso; en las estáticas se simula el grosor. Para mejores resultados
con pesos muy finos o muy gruesos, asigna una fuente que incluya esos pesos.

Abre `ui/interaction/interaction_prompt.tscn` en **3D** y selecciona **InteractionPrompt**. También es `@tool`: el icono se ve y se actualiza en el editor. `Icon Width = 0,95` regula el ancho en metros (0,65 es más discreto); `Bob Amount = 0,06` y `Bob Speed = 2,6` controlan su flotación en juego (amplitud 0 la desactiva). `Fill Color`, `Outline Color` y `Button Color` regulan los colores. `Key Text = X` y `Height = 2,5` sirven para la vista previa; en juego el símbolo se adapta al dispositivo y cada objeto fija su altura. El icono se dibuja después del desenfoque de cámara para permanecer visible.

Para crear una conversación nueva:

1. Crea un archivo dentro de `dialogue/`, por ejemplo `dialogue/mi_vecino.dialogue`.
2. Define un bloque inicial `~ start`, líneas como `Vecino: Hola`, respuestas con `- Opción` y finales con `=> END`.
3. En el objeto `TrailInteractable`, asigna el recurso en **Dialogue Resource** y deja **Dialogue Title** en `start` u otro bloque que hayas definido.

El plugin solo procesa el contenido y las ramas. La proximidad, la línea de visión, el pin 3D y el bloqueo de controles continúan siendo código propio de Lantern Trail. El diseño está en `ui/dialogue/squirrel_dialogue_balloon.tscn`; no modifiques `addons/dialogue_manager/` para cambiar colores o disposición.

## Guardado y ajustes

La mezcla tiene +6 dB respecto a la versión anterior: música −13 dB, efectos −5 dB y pasos −14 dB. El viento permanece en −23 dB y se respetan los controles guardados. Un limitador único en Master, con techo de −0,5 dB, protege frente a picos de efectos simultáneos. `tests/audio_review.gd` verifica ganancias, picos individuales, mute y ausencia de limitadores duplicados.

Los datos se almacenan en `%APPDATA%/LanternTrail/` en Windows:

- `expedition_v3.json`: IDs de semillas recogidas y faroles encendidos, punto seguro, tiempo y final.
- `settings.json`: volumen general, música, efectos, sensibilidad, pantalla completa, acabado pixelado y reinicio rápido.

Cada sesión, incluso al elegir **Continuar**, comienza junto al farol de la cima. Los faroles que se restauren durante esa sesión siguen siendo los puntos de recuperación al caer. En **Ajustes**, `Reinicio rápido · Start` está activado por defecto: al pulsar Start/Menú con mando mientras exploras, vuelves a la cima sin alterar el progreso ni tu último farol de recuperación. Al desactivarlo, Start vuelve a abrir el menú de pausa.

Se guarda al recoger, encender, pausar, salir al título, cerrar la ventana y cada 15 segundos durante la exploración. La escritura usa un archivo temporal antes de sustituir el guardado. **Nueva expedición** pide confirmar antes de reemplazar una partida existente. Los archivos de versiones anteriores permanecen intactos y no se cargan porque pertenecen al mapa anterior.

Para reiniciar la partida, usa **Nueva expedición** en el título. Para restaurar todos los ajustes manualmente, cierra el juego y renombra `settings.json`. Las pruebas usan exclusivamente `qa_expedition.json` y `qa_settings.json`.

## Estructura y configuración

- `scripts/game.gd`: estados de título, juego, diálogo, pausa, ajustes, final y coordinación.
- `scenes/player.tscn` + `scripts/player.gd`: aceleración, frenado, salto configurable, tolerancia de borde y buffer de salto, control aéreo y recuperación.
- `scripts/squirrel_animator.gd` + `scripts/squirrel_rig.gd`: transición visual de carrera/planeo, inclinación, temblor de miembros, reproducción de acciones de Blender y control directo de las Shape Keys de las membranas.
- `scenes/camera_rig.tscn`: distancia, inclinación, campo de visión y suavizado editables en el Inspector.
- `scenes/mountain.tscn` + `scripts/level.gd`: montaña fija, circuito en espiral, posiciones de objetos, decoración, luz y nieve. Los modelos se ensamblan al ejecutar; el editor muestra los nodos raíz de estos componentes.
- `scripts/interactable.gd` + `scripts/interaction.gd`: rango, orientación, línea de visión y prompts reutilizables.
- `addons/dialogue_manager/`: dependencia MIT de Dialogue Manager 3.10.4; procesa recursos `.dialogue`.
- `ui/dialogue/squirrel_dialogue_balloon.tscn`: globo inferior personalizado; `dialogue/`: conversaciones editables.
- `scripts/lamp.gd` / `scripts/collectible.gd`: faroles y semillas con señales, IDs estables y protección frente a recogida repetida.
- `scripts/resident.gd`: vecinos con respiración, parpadeo, mirada y ciclo de caminar.
- `scripts/ui.gd`: menús, foco visible, HUD, diálogos y controles de ajustes.
- `scripts/core/`: configuración de entradas y persistencia.
- `scripts/audio.gd`: música ambiental y viento sintetizados, voces de efectos reutilizadas y buses independientes.
- `shaders/`: acabado pixelado del mundo (la interfaz permanece nítida), senderos, estratos de roca y agua.

La topología y los puntos del recorrido están definidos en `TrailLevel.ROUTE`, `SEEDS`, `LAMP_POINTS` y `height_at()`. La máscara del sendero se calcula una vez y se reutiliza para reducir el coste del shader. No hay mapas aleatorios, combate ni escalada.

## Planeo y rigging

### Cámara y referencia de controles

En **Ajustes → Cámara al frente durante planeo**, activa el seguimiento del
frente visual del personaje. El ajuste se guarda. **R2 / RT**, o **C** en teclado,
recentra una vez por pulsación, también fuera del planeo y aunque el ajuste esté
desactivado. En `OrbitCamera → Seguimiento frontal suave`, `Forward Response Time`
(0.65 s), `Forward Max Speed` (55°/s) y `Forward Acceleration` (90°/s²) suavizan el
seguimiento automático. Para una cámara más tranquila prueba 1.2 s y 30°/s.
`Forward Start Angle` (12°) y `Forward Stop Angle` (3°) forman una histéresis:
no persigue pequeños movimientos. R2 ignora el umbral inicial y usa su propio grupo
**Recentrar cámara · R2 / RT**: `Recenter Response Time` (0.18 s), `Recenter Max Speed`
(150°/s) y `Recenter Acceleration` (540°/s²). Es más inmediato que el seguimiento
automático, sin hacer un salto brusco. Mover la cámara manualmente suspende el seguimiento durante
`Forward Manual Pause` (1.2 s). `Orbit Smoothing` conserva su uso para el giro
manual y la inclinación de cámara. No se cambia la física del personaje.
Cada pulsación de R2/RT o C reproduce el clic de interfaz ya existente como confirmación.
**Ajustes → Controles** muestra las acciones de teclado y mando, incluidas las
condiciones de salto, planeo, escalada y reinicio rápido. La referencia tiene scroll
y se puede recorrer con cruceta/flechas.

### Tamaño, escritura y voz del globo

La voz predeterminada ahora usa las letras grabadas de ambos alfabetos.
Perfiles, controles y prueba en editor: [guía de Animalese](audio/animalese/README.md).
Abre `ui/dialogue/animalese_preview.tscn` y usa los botones del Inspector.

En `ui/dialogue/squirrel_dialogue_balloon.tscn`:

- `Balloon/DialogueBox → Layout → Cloud Width / Cloud Height`: ancho y alto;
  `Text Margins`: padding. Los cambios se ven en el editor y el contenido se pagina.
- `Balloon/DialogueBox/Content/TextViewport/DialogueLabel → Typewriter`:
  `Typewriter Enabled` activa escritura; desactivado revela cada página completa.
  `Reveal Mode`: letras o palabras; ejemplos: `Letters Per Second = 35`,
  `Words Per Second = 5`, `Punctuation Pause = 0.2` segundos.
- En ese mismo nodo, `Typing Voice`: sonido on/off, volumen (-19 dB), intervalo
  mínimo (0.06 s), duración (0.075 s), variación de tono (0.7 semitonos) y muestra
  de audio opcional en `Synthetic Fallback`. Estos controles anteriores se usan
  si desactivas `Recorded Voice Enabled`; las grabaciones se ajustan en su perfil.
  Respeta el volumen Sonidos del juego.
- En el nodo raíz, `Character Voice Pitches`: diccionario por nombre exacto.
  Ejemplos: Mara = 1.15, otro personaje = 0.8 (grave) o 1.3 (agudo).
  `Default Voice Pitch` se usa para nombres sin entrada.

Una pulsación de avance completa la página que se está escribiendo; la siguiente
pasa a la siguiente página. No reproduce una ráfaga de voz al completar texto.
La vista previa del editor mantiene el texto visible y no reproduce sonidos.

La primera pulsación inicia el salto. Para planear, vuelve a pulsar Brincar cuando
la ardilla esté en el aire y mantenlo; soltarlo termina el planeo. Mantener la
pulsación inicial del salto no inicia planeo, pero sí permite anclarse a una roca
escalable cercana si se mira hacia ella. No existe impulso vertical adicional:
el planeo reduce la caída.

Mientras planeas, mantén R1/L1 o Shift para el sprint de planeo. Aumenta la velocidad horizontal, suma inclinación hacia delante y permite una caída ligeramente más rápida.

Valores físicos en el Inspector de `SquirrelExplorer`:

- **Planeo**: `Glide Fall Speed`, `Glide Gravity Scale`, `Glide Braking` y `Glide Air Control`.
- **Planeo con sprint · R1**: multiplicador de velocidad, límite extra de caída y gravedad adicional.

Valores visuales en `SquirrelExplorer → Animation`:

- **Postura de planeo**: inclinación normal, inclinación extra con R1 y rapidez de apertura/cierre.
- **Banking de planeo**: roll visual hacia el interior de la curva. Usa el ángulo firmado entre rumbo y dirección pedida, y el giro de yaw real mientras la curva termina; incluye límite de grados, ángulo necesario para alcanzar ese límite, suavizado e inversión visual. El roll se aplica alrededor del eje longitudinal local después del pitch: al girar a la izquierda bajan los miembros izquierdos y suben los derechos (o viceversa, según `Glide Bank Invert`). No modifica la física.
- **Curvatura del planeo**: reducción de control, giro máximo por segundo, reducción de ese giro a alta velocidad, conservación de velocidad en curvas, velocidad de giro visual exclusiva de Glide y relación entre orientación visual y trayectoria física; impide invertir el rumbo de inmediato sin hacer que el modelo se sienta desconectado.
- **Planeo · modelo artesanal**: velocidad de `Glide`, velocidad de `GlideStart`, grados y frecuencia del temblor de miembros.

El modelo no cambia de posición por sus clips: el `CharacterBody3D` mueve al jugador por el mundo y las acciones de Blender mueven huesos y Shape Keys de manera local.

## Verificación

Aviso pendiente de diagnóstico: al cerrar `blur_review.gd`, Godot Compatibility informa de dos texturas GL sin liberar (349.524 bytes cada una). La comparación visual pasa y no se observó un fallo durante el juego; no se ha demostrado todavía la causa del aviso. La prueba normal `visual_review.gd` terminó sin ese aviso.

Desde una terminal en esta carpeta, usando la ruta de tu ejecutable como `godot`:

```powershell
godot --headless --editor --path . --quit
godot --headless --path . --script tests/qa_runner.gd --fixed-fps 60 -- --qa
godot --headless --path . --script tests/movement_review.gd --fixed-fps 60 -- --qa
godot --headless --path . --script tests/polish_review.gd --fixed-fps 60 -- --qa
godot --headless --path . --script tests/diagnose_slopes.gd --fixed-fps 60 -- --qa
godot --headless --path . --script tests/dialogue_review.gd -- --qa
godot --path . --script tests/visual_review.gd -- --qa
godot --path . --script tests/blur_review.gd -- --qa
```

La prueba de juego hace el recorrido con movimiento y colisiones reales, comprueba gasto de semillas, guardado/continuación, final, reinicio, diálogos, pausa, eventos de mando, duplicados y radio fijo de cámara ante obstáculos. La prueba de movimiento verifica aceleración, frenado, reversas, sprint L1/R1, salto, pausas en el aire, impactos, pendientes, giros y límites de cámara. La revisión visual captura título, escenario, cima, ardilla, diálogo, ajustes y encuadre en `tests/captures/`.

Validación realizada en Godot 4.6 Mono / Compatibility: 90 comprobaciones de expedición y **46 de movimiento/cámara**, sin fallos en sus últimas ejecuciones. Estas últimas incluyen cursor libre, arrastre con clic derecho, liberación y pausa. También se revisaron poses con renderizado real en la RTX 4060. Una muestra de 120 frames con el modelo optimizado dio aproximadamente 6,3 ms de mediana; no es una garantía para otros equipos ni una prueba de rendimiento extensa.

La revisión adicional de pendientes recorre 24 ascensos: 21 líneas de terreno quedan libres de atascos y pérdida de contacto; tres atraviesan árboles o rocas reales y conservan sus colisiones. También comprueba silencios y ausencia de saturación en el ambiente musical. `tests/animation_review.gd` captura seis fases de carrera en un visor de revisión independiente de la cámara de juego y verifica los controles de brazos.

El mando se verifica mediante eventos inyectados, no con una sesión manual en un dispositivo físico. Los pesos, Shape Keys y clips principales se preparan en Blender para este modelo concreto; Godot reproduce las acciones y aplica ajustes visuales adicionales durante el juego. El audio es síntesis original sencilla.

La nueva prueba `polish_review.gd` añade **30 comprobaciones** de deslizamiento a 55°, límite de velocidad, dirección lateral, salto, retorno a suelo llano, deformación de cola en subida/caída y restauración tras aterrizar, y activación del desenfoque al cambiar de cámara/pausa. `blur_review.gd` captura el mismo encuadre con y sin desenfoque y comprueba que no cambia apreciablemente el color del primer plano. `inspect_head.gd` verifica que no quedan caras blancas en la región posterior de la cabeza. El GLB tiene 27.410 triángulos tras reconstruir los brazos independientes; algunas esquinas se duplican para reparar las UV.
