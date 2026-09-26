# Lantern Trail

Una expedición 3D breve para **Godot 4.6**, con una ardilla sin ropa ni accesorios, una montaña que se puede rodear y una cima accesible. Recoge semillas de luz, restaura tres faroles y regresa con Mara al refugio.

## Ejecutar

1. Abre Godot 4.6 (Standard o Mono).
2. Importa `project.godot` desde esta carpeta.
3. Pulsa **F5**. La escena principal es `main.tscn`; comienza en el título.
4. Elige **Nueva expedición**. Cuando exista progreso, **Continuar** estará disponible.

No requiere plugins, descargas, .NET ni una solución C#. La ardilla utiliza una versión optimizada del GLB proporcionado por el usuario, incluida en el proyecto; el escenario y el audio se construyen con recursos propios. Las capturas de referencia no están incluidas como assets.

## Controles

| Acción | Teclado y ratón | Mando estándar |
| --- | --- | --- |
| Mover | WASD / flechas | Stick izquierdo |
| Cámara | Mantener clic derecho y arrastrar | Stick derecho |
| Saltar | Espacio | Botón sur (A / cruz) |
| Desplegar / recoger planeo | Volver a pulsar Espacio en el aire | Volver a pulsar A / cruz en el aire |
| Interactuar | E | Botón oeste (X / cuadrado) |
| Correr rápido | Mantener Shift | Mantener LB / L1 mientras mueves el stick |
| Pausa | Escape | Menú / Start |
| Menús | Ratón, flechas, Tab, Enter | Cruceta y botón sur; este para volver |

El cursor permanece visible y libre, incluso durante el arrastre. Mover el ratón sin mantener el botón derecho no cambia la cámara; puedes salir de la ventana y usar otras aplicaciones.

La cámara conserva un radio fijo de **14,4 unidades** desde el punto de enfoque del personaje, con seguimiento y órbita amortiguados e interpolación física. No tiene zoom ni brazo retráctil: los objetos nunca pueden acercarla al jugador. Se puede girar horizontalmente y variar la inclinación solo entre **−54° y −42°** (por defecto −48°). La cámara no gira al mover al personaje. El encuadre normal sitúa a la ardilla alrededor del 10 % de la altura de pantalla. Los objetos pueden ocultar temporalmente al personaje; el giro horizontal permite despejar la vista sin alterar la distancia.

## Ardilla y movimiento

Últimos ajustes: cola elástica que baja su extremo al subir en un salto y lo levanta al caer, con flexión y estiramiento/compresión interpolados; dos marcas blancas de la nuca corregidas mediante UV locales de pelaje (textura y archivo original intactos). Las pendientes no caminables permiten resbalar suavemente, dirigir el deslizamiento de lado y saltar. El fondo tiene desenfoque progresivo por profundidad; la ardilla cercana y la interfaz permanecen nítidas. Todos estos valores están documentados en `docs/animation_tuning.md`.

El original de Downloads permanece intacto. `assets/squirrel/squirrel_optimized.glb` reduce la geometría de **989.198 a 27.410 triángulos** (97,2 % menos). Conserva la cabeza y el pelaje original, con reparación local de las UV de la nuca y brazos reconstruidos como tubos simétricos independientes del torso. Incluye 15 huesos y pesos para torso, cabeza, hombros, codos, patas y cola. `squirrel_visual.scn` es la escena nativa precalculada que usa el juego; no procesa la malla al comenzar una partida. Para regenerar ambos desde el original:

```powershell
godot --headless --path . --script tests/prepare_squirrel.gd -- "C:/Users/USER/Downloads/model.glb"
```

El movimiento comienza en el primer tick físico. La aceleración se aplica al vector completo, el frenado es gradual y más fuerte, y la orientación sigue el desplazamiento real. El salto conserva su arco al pausar o abrir diálogo. La adherencia al suelo evita deslizamiento en reposo; la velocidad real determina el ritmo de las patas. La animación mezcla reposo, carrera, despegue, subida, caída y aterrizaje. Recoger/interactuar se superpone sin bloquear el movimiento. Los aterrizajes dependen de la velocidad del impacto. Incluye apoyo de patas mediante rayos al suelo e IK de dos huesos, interpolación de poses, inclinación contenida y cola amortiguada.

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

En el hijo **Animation** encontrarás grupos para ritmo, patas, brazos/codos, cuerpo/cabeza, aterrizaje y cola. La guía **docs/animation_tuning.md** explica todos los controles, valores iniciales y cómo probarlos en Remote y guardarlos en la escena. La carrera incluye alternancia de brazos/piernas, codos flexionados, torsión del torso, cambio de peso, arco de recuperación de patas y compensación de cabeza.

El audio ya no incluye el acorde grave continuo. La música usa notas suaves separadas por silencios; los pasos emplean ruido filtrado breve sin tono grave sostenido. Los bucles arrancan una sola vez, después de aplicar los volúmenes guardados.

Al subir pendientes, el controlador conserva la velocidad sobre la superficie y entra en cada triángulo siguiendo su inclinación. El contacto explícito con el suelo evita pequeños saltos entre caras. Esto corrige las paradas breves que provocaba reiniciar la velocidad vertical a cero.

## Expedición

Lee el letrero y habla con Mara. El sendero asciende en espiral por todas las caras de la montaña. Los faroles del claro, del pinar y de la cima cuestan **3 semillas cada uno**. Hay 15 semillas en total: nueve necesarias y seis adicionales. Puedes explorar y encender los faroles en cualquier orden si tienes semillas suficientes.

Cada farol encendido queda como punto de recuperación. Tras encender los tres, vuelve con Mara: su conversación inicia la llegada de los vecinos al refugio, seguida de la pantalla final con tiempo y semillas recogidas. Puedes volver al título o jugar otra vez.

## Guardado y ajustes

La mezcla tiene +6 dB respecto a la versión anterior: música −13 dB, efectos −5 dB y pasos −14 dB. El viento permanece en −23 dB y se respetan los controles guardados. Un limitador único en Master, con techo de −0,5 dB, protege frente a picos de efectos simultáneos. `tests/audio_review.gd` verifica ganancias, picos individuales, mute y ausencia de limitadores duplicados.

Los datos se almacenan en `%APPDATA%/LanternTrail/` en Windows:

- `expedition_v3.json`: IDs de semillas recogidas y faroles encendidos, punto seguro, tiempo y final.
- `settings.json`: volumen general, música, efectos, sensibilidad, pantalla completa y acabado pixelado.

Se guarda al recoger, encender, pausar, salir al título, cerrar la ventana y cada 15 segundos durante la exploración. La escritura usa un archivo temporal antes de sustituir el guardado. **Nueva expedición** pide confirmar antes de reemplazar una partida existente. Los archivos de versiones anteriores permanecen intactos y no se cargan porque pertenecen al mapa anterior.

Para reiniciar la partida, usa **Nueva expedición** en el título. Para restaurar todos los ajustes manualmente, cierra el juego y renombra `settings.json`. Las pruebas usan exclusivamente `qa_expedition.json` y `qa_settings.json`.

## Estructura y configuración

- `scripts/game.gd`: estados de título, juego, diálogo, pausa, ajustes, final y coordinación.
- `scenes/player.tscn` + `scripts/player.gd`: aceleración, frenado, salto configurable, tolerancia de borde y buffer de salto, control aéreo y recuperación.
- `scripts/squirrel_animator.gd` + `scripts/squirrel_rig.gd`: estados, transiciones, movimiento secundario y poses esqueléticas interpoladas. El ciclo avanza por desplazamiento real; recoger/interactuar se superponen a locomoción.
- `scenes/camera_rig.tscn`: distancia, inclinación, campo de visión y suavizado editables en el Inspector.
- `scenes/mountain.tscn` + `scripts/level.gd`: montaña fija, circuito en espiral, posiciones de objetos, decoración, luz y nieve. Los modelos se ensamblan al ejecutar; el editor muestra los nodos raíz de estos componentes.
- `scripts/interactable.gd` + `scripts/interaction.gd`: rango, orientación, línea de visión y prompts reutilizables.
- `scripts/lamp.gd` / `scripts/collectible.gd`: faroles y semillas con señales, IDs estables y protección frente a recogida repetida.
- `scripts/resident.gd`: vecinos con respiración, parpadeo, mirada y ciclo de caminar.
- `scripts/ui.gd`: menús, foco visible, HUD, diálogos y controles de ajustes.
- `scripts/core/`: configuración de entradas y persistencia.
- `scripts/audio.gd`: música ambiental y viento sintetizados, voces de efectos reutilizadas y buses independientes.
- `shaders/`: acabado pixelado del mundo (la interfaz permanece nítida), senderos, estratos de roca y agua.

La topología y los puntos del recorrido están definidos en `TrailLevel.ROUTE`, `SEEDS`, `LAMP_POINTS` y `height_at()`. La máscara del sendero se calcula una vez y se reutiliza para reducir el coste del shader. No hay mapas aleatorios, combate ni escalada.

## Planeo y referencias de rigging

La primera pulsación salta. Una nueva pulsación en el aire despliega brazos, patas y membranas de ardilla voladora; mantener el botón desde el suelo no las abre. Otra pulsación las recoge. Se controlan con WASD/stick izquierdo y se recogen automáticamente al aterrizar. No hay impulso extra hacia arriba: el descenso se estabiliza en 2,6 unidades/s, con frenado gradual si se despliega durante una caída rápida. Pausa y diálogo congelan el estado sin perderlo.

Los archivos `model-rigged-fly.glb` (40 huesos) y `model-rigged-open-arms.glb` (29 huesos), fuera de la carpeta del proyecto, se inspeccionaron como referencias. No se intercambian esos modelos completos al saltar: la postura y las membranas se integran en el personaje actual para conservar su cara, tamaño y continuidad. Los archivos originales no se modifican. Las membranas son una malla visual separada de 10 triángulos; el torso no se estira para crearlas.

En `player.tscn`, el nodo raíz tiene el grupo **Planeo**; **Animation → Postura de planeo** controla apertura de brazos/piernas, inclinación y rapidez de despliegue. Todos incluyen descripción y ejemplos en el Inspector. Los controles normales de brazos siguen siendo independientes.

`tests/glide_review.gd` verifica 13 casos, incluyendo segunda pulsación, mando, cancelación, descenso sin ascenso extra, pausa, diálogo, aterrizaje y respawn. Añade `--visual` después de `-- --qa` para capturar la postura en un visor de revisión. `tests/arm_geometry_review.gd` verifica pesos independientes, simetría a 150° y ausencia de deformación del torso al mover los brazos. `tests/animation_review.gd -- --stress-arms` prueba la elevación extrema sin cambiar los valores guardados.

## Verificación

Aviso pendiente de diagnóstico: al cerrar `blur_review.gd`, Godot Compatibility informa de dos texturas GL sin liberar (349.524 bytes cada una). La comparación visual pasa y no se observó un fallo durante el juego; no se ha demostrado todavía la causa del aviso. La prueba normal `visual_review.gd` terminó sin ese aviso.

Desde una terminal en esta carpeta, usando la ruta de tu ejecutable como `godot`:

```powershell
godot --headless --editor --path . --quit
godot --headless --path . --script tests/qa_runner.gd --fixed-fps 60 -- --qa
godot --headless --path . --script tests/movement_review.gd --fixed-fps 60 -- --qa
godot --headless --path . --script tests/polish_review.gd --fixed-fps 60 -- --qa
godot --headless --path . --script tests/diagnose_slopes.gd --fixed-fps 60 -- --qa
godot --path . --script tests/visual_review.gd -- --qa
godot --path . --script tests/blur_review.gd -- --qa
```

La prueba de juego hace el recorrido con movimiento y colisiones reales, comprueba gasto de semillas, guardado/continuación, final, reinicio, diálogos, pausa, eventos de mando, duplicados y radio fijo de cámara ante obstáculos. La prueba de movimiento verifica aceleración, frenado, reversas, sprint LB/L1, salto, pausas en el aire, impactos, pendientes, giros y límites de cámara. La revisión visual captura título, escenario, cima, ardilla, diálogo, ajustes y encuadre en `tests/captures/`; todas las capturas de juego mantienen la distancia de producción.

Validación realizada en Godot 4.6 Mono / Compatibility: 90 comprobaciones de expedición y **46 de movimiento/cámara**, sin fallos en sus últimas ejecuciones. Estas últimas incluyen cursor libre, arrastre con clic derecho, liberación y pausa. También se revisaron poses con renderizado real en la RTX 4060. Una muestra de 120 frames con el modelo optimizado dio aproximadamente 6,3 ms de mediana; no es una garantía para otros equipos ni una prueba de rendimiento extensa.

La revisión adicional de pendientes recorre 24 ascensos: 21 líneas de terreno quedan libres de atascos y pérdida de contacto; tres atraviesan árboles o rocas reales y conservan sus colisiones. También comprueba silencios y ausencia de saturación en el ambiente musical. `tests/animation_review.gd` captura seis fases de carrera en un visor de revisión independiente de la cámara de juego y verifica los controles de brazos.

El mando se verifica mediante eventos inyectados, no con una sesión manual en un dispositivo físico. El esqueleto y sus pesos se preparan por código para este modelo concreto; las poses son procedurales, sin clips de animación externos ni animación facial. El audio es síntesis original sencilla.

La nueva prueba `polish_review.gd` añade **30 comprobaciones** de deslizamiento a 55°, límite de velocidad, dirección lateral, salto, retorno a suelo llano, deformación de cola en subida/caída y restauración tras aterrizar, y activación del desenfoque al cambiar de cámara/pausa. `blur_review.gd` captura el mismo encuadre con y sin desenfoque y comprueba que no cambia apreciablemente el color del primer plano. `inspect_head.gd` verifica que no quedan caras blancas en la región posterior de la cabeza. El GLB tiene 27.410 triángulos tras reconstruir los brazos independientes; algunas esquinas se duplican para reparar las UV.
