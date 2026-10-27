# Diario de desarrollo · Lantern Trail

Una bitácora breve de decisiones y aprendizajes del proyecto. La documentación
de referencia explica el detalle; aquí queda el contexto de cómo va creciendo
el juego.

## 2026-10-23 · Terrain3D y montañas de Blender

Decidimos usar Terrain3D para el suelo y las laderas que conviene pintar y
ajustar durante el diseño, y Blender para montañas, acantilados y paredes con
forma definida. Las piezas se integrarán visualmente en Godot y tendrán
colisión propia cuando sean caminables. Aprendizaje: un mapa de alturas facilita
pendientes continuas; una malla de autor permite paredes y salientes sin forzar
el relieve de Terrain3D.

## 2026-10-23 · La nieve deja de ser un detalle disperso

La prueba de nieve generada por `SurfaceDetails` resultó pesada y no alcanzó
el aspecto del `SnowTerrain` de prueba ni de la textura `snow_powder_v2`. Decidimos
separar **aspecto**, **respuesta del personaje** y **clima**: el autor pinta la
textura en Terrain3D y marca aparte zonas de nieve ligera o profunda. Ambas
pueden dejar huellas y la profunda suma hundimiento visual y respuesta de
movimiento. La malla densa de nieve se retiró del render de `SurfaceDetails`;
las zonas tienen colores editables sólo en el editor. `Snowfall` admite zonas
de clima independientes y el pasto pintado usa `GrassParticles` original. Las
hojas mantienen su propia lógica. Aprendizaje: un pincel común no obliga a
representar materiales distintos con la misma geometría. La escena arranca en
Godot 4.6; falta valorar el resultado visual jugando en el editor.

## 2026-10-04 · Copos y huellas ocultos por el blur

Al activar el blur compartido en la escena de nieve, su prioridad 100 hacía
que dibujara una captura sin transparencias encima de copos y huellas.
Se corrigió a -128: primero el fondo desenfocado, después esos efectos.
Los ajustes artísticos se conservaron. Aprendizaje: cambiar un default global
también puede alterar cómo se combinan sistemas que funcionaban por separado.
Las hipótesis previas sobre partículas e índices de colisión no se confirmaron.
La escena arranca en Godot 4.6; falta confirmar visualmente el resultado.
El diagnóstico y la comprobación manual están en `terrain_snow_playground.md`.

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

## Cámara y superficies sólidas

- La cámara compartida ahora consulta una esfera desde la ardilla hasta su
  posición deseada. Las superficies de la capa física **Camera Blocker** hacen
  que la cámara conserve su ángulo, pero se acerque antes de atravesarlas.
- El terreno de nieve, la montaña de prueba y los sólidos principales del
  nivel usan esa capa. El jugador sigue usando su colisión normal; la capa
  adicional sólo sirve para decidir qué bloquea la vista.
- El mínimo de distancia evita que un obstáculo convierta el encuadre en un
  primer plano accidental. Radio, margen, distancia mínima, recuperación y
  suavidad de regreso se ajustan en `CameraRig`, dentro de **Colisión de
  cámara**. La entrada hacia un obstáculo es inmediata; la salida se suaviza.
- Esta medida impide que el recorrido normal muestre el reverso de un terreno
  abierto. Si más adelante se permite una cámara libre bajo el mundo, el
  terreno también necesitará grosor o una falda visual para ocultar su cara
  inferior.

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

## 2026-10-27 · Los STPine ganan paisaje lejano sin perder la copa

Los árboles de `glb 2` ahora preparan tres LOD por asset y dejan a Terrain3D
elegirlos por distancia, sin depender de TreeColors. Se conservaron colores,
IDs y pinceladas; el punto de partida es 80/220/900 m, con sombras sólo en los
dos primeros niveles. La comparación visual descubrió que simplificar toda la
copa borraba ramas altas: ahora se reduce cada pieza de follaje y se conserva
su carta UV. STPine1 pasa de 1500 a 944 y 278 triángulos. La preparación queda
guardada en disco y sirve para futuros meshes. Aprendizaje: contar triángulos
no basta; hay que revisar silueta y alfa. El cambio nativo ocurre por celdas y
aún falta medir el rendimiento del bosque completo.

Creamos una herramienta propia de editor con scripts `@tool`: TreeMeshAsset
extiende el asset nativo de Terrain3D y reúne materiales, colores y distancias
en el Inspector; tree_lod_preparer prepara los tres niveles con el botón
«Preparar / regenerar LOD». El trabajo geométrico se hace una vez en el editor
y se guarda en recursos derivados, conservando el GLB original. Durante el juego,
Terrain3D reutiliza esas mallas para todas las instancias del asset y elige el
nivel por distancia, sin simplificar geometría en tiempo real. Así, futuros
árboles compatibles se configuran sin código nuevo por modelo. Es una herramienta
integrada en el proyecto y dependiente de Terrain3D, todavía no un plugin
independiente. El flujo y sus controles están en
[tree_lod_preparation.md](tree_lod_preparation.md).
