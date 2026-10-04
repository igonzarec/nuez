# Diario de desarrollo · Lantern Trail

Una bitácora breve de decisiones y aprendizajes del proyecto. La documentación
de referencia explica el detalle; aquí queda el contexto de cómo va creciendo
el juego.

## Base del proyecto

- **Lantern Trail** es una expedición 3D corta en Godot 4.6 protagonizada por
  una ardilla exploradora. La meta es recorrer una montaña, reunir semillas de
  luz, restaurar faroles y volver al refugio.
- La estructura separa el comportamiento del juego, la presentación, el audio
  y la interfaz. Blender es la fuente de los modelos; Godot compone el nivel y
  decide colisiones, interacción y reglas de gameplay.
- Se trabaja a escala métrica: una unidad de Godot y Blender equivale
  aproximadamente a un metro.

## Personaje y movimiento

- Se construyó e importó una ardilla low-poly con rig propio (`NuezRig`) y
  animaciones de carrera, sprint, inicio de planeo y planeo.
- El controlador permite caminar, correr, saltar, planear, deslizarse en
  pendientes demasiado inclinadas y escalar superficies marcadas como
  `climbable`.
- La cámara sigue al personaje con una distancia fija de 14,4 m y se controla
  con arrastre de clic derecho. Su sonido de recentrado forma parte del sistema
  de audio compartido.
- El modelo visual de la ardilla mide aproximadamente **1,84 m** de alto,
  **1,01 m** de ancho y **1,16 m** de profundidad. La cápsula física mide
  1,42 m de alto, con radio de 0,42 m.

## Mundo, juego y presentación

- El recorrido principal incluye pendientes, una cima, semillas de luz,
  faroles, un refugio, personajes con los que hablar y un cierre de expedición.
- Hay interacción contextual, diálogos con Dialogue Manager, guardado de
  progreso y ajustes de audio y pantalla.
- La interfaz y los diálogos tienen un tratamiento visual propio; el mundo usa
  una dirección low-poly y un acabado de imagen compatible con ese estilo.
- Se añadieron sonidos para movimiento, planeo, interacción y cámara. El nodo
  `TrailAudio` centraliza las conexiones de jugador y cámara para que una
  escena de vista previa reciba el mismo audio que la escena principal.

## Primera montaña de aprendizaje

- Se creó `mountain_v01_blockout.blend` como ejercicio de Blender: una base de
  200 × 200 m subdividida y elevada con edición proporcional hasta formar una
  montaña asimétrica.
- La ardilla se añadió como referencia visual mediante una colección separada
  (`REF_squirrel`), sin formar parte del modelo de la montaña.
- La montaña se exportó como GLB a
  `project/assets/mountain/mountain_v01_blockout.glb` y se abrió en Godot.
- Se creó una escena de vista previa y otra para caminar sobre la montaña. La
  segunda genera por ahora una colisión triangular desde la malla visual: es
  adecuada para blockout, pero una versión final usará una colisión simple e
  independiente.
- La vista previa añadió iluminación, cámara, audio compartido y una nevada
  temporal para comprobar rápidamente la escala y el movimiento.

## Decisiones que guían el siguiente terreno

- Una montaña no debe ser una única malla gigantesca que contenga cada árbol,
  roca y detalle del nivel. El terreno visual puede ser continuo, mientras los
  elementos repetibles y las colisiones se mantienen separados.
- Cada terreno tendrá tres capas conceptuales: **render mesh** para la forma
  visible, **colisión caminable** para la física y **zona escalable** para las
  paredes que el diseñador autorice explícitamente.
- La inclinación por sí sola no vuelve escalable una superficie: la zona debe
  pertenecer al grupo `climbable`.
- Para nieve, la dirección inicial es aumentar la nieve acumulada conforme se
  gana altura. La intensidad de la nevada será una decisión artística
  configurable, no una regla física rígida.

## Herramientas y hábitos

- Existe la skill global `walkable-terrain`, creada para guiar el flujo de
  terrenos caminables: malla visual de Blender, importación, colisión, escala,
  validación del personaje y capas opcionales. Se ampliará sólo con prácticas
  que hayan sido probadas en el proyecto.
- Al dar pasos de Blender o Godot, se indicará dónde encontrar cada opción en
  la interfaz y una referencia visual para localizarla.
- El usuario dispone de teclado numérico; se pueden usar atajos como `Numpad
  1`, `Numpad 3` y `Numpad 0` al guiar la vista en Blender.
