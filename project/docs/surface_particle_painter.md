# Pincel de detalles de superficies

Preparado para **Godot 4.6 / Terrain3D 1.0.2**. Hay un nodo
`Terrain3D/SurfaceDetails` dentro de `res://scenes/grass_terrain.tscn`.
La cobertura que pintes se conserva entre revisiones del renderizador. No se
han creado escenas de demostración ni escenas reutilizables. El sistema anterior
GrassParticles sigue disponible y es independiente de este pincel.

## Empezar a pintar

1. Abrir `grass_terrain.tscn` y seleccionar **Terrain3D → SurfaceDetails**.
2. Abrir el panel inferior **Pincel de detalles**. Si no aparece, activar
   **Pincel de superficies** en Project Settings → Plugins. El plugin ya está
   registrado en el proyecto; un editor que estaba abierto puede necesitar
   recargarlo. Guardar los cambios propios del editor antes de recargar escenas.
3. Elegir **Nieve**, **Hojas**, **Tierra** o **Pasto** y activar
   **Pintar superficies**.
4. Ajustar **Radio**, **Intensidad** y **Dureza** y arrastrar con clic izquierdo.
   La circunferencia indica el alcance. Cada arrastre completo es una operación.
5. **Ctrl + arrastrar**, o **Borrar detalle**, elimina la cobertura de la capa
   seleccionada. La textura del suelo se pinta y reemplaza con los pinceles
   habituales de Terrain3D.
6. **Ctrl+Z / Ctrl+Shift+Z** deshace/rehace la cobertura.
   **Ctrl+S** guarda la escena, los perfiles y la cobertura. **Esc** desactiva
   el pincel; RMB/Alt y MMB
   conservan la navegación del editor.

La herramienta siempre pinta sólo detalle. Para cambiar el suelo, seleccionar
Terrain3D y usar su pincel **Texturas**. Elegir otra capa aquí permite
superponer detalles: la cobertura de cada una es independiente. Borrar la
nieve de SurfaceDetails no borra una textura blanca pintada en Terrain3D.

Los pinceles nativos de Terrain3D siguen funcionando cuando el pincel de detalles
está apagado. La herramienta recibe primero los clics cuando está activa para
evitar pintar/esculpir también con la herramienta nativa por accidente.

## Apariencia y valores iniciales

Seleccionar **SurfaceDetails** y expandir **Perfiles editables → Snow / Leaves /
Dirt / Grass**, o pulsar **Editar apariencia** en el panel. Todos los valores
tienen ayuda al mantener el cursor sobre la propiedad.

| Perfil | Aspecto inicial |
| --- | --- |
| Nieve | Capa continua estilizada y mate, espesor inicial de 8 cm más ondulaciones suaves; relieve de material visible desde la cámara de juego. |
| Hojas | Siluetas lobuladas curvadas, nervio central, tamaños de 14–36 cm, ocres y marrones, movimiento mínimo opcional. |
| Tierra | Piedritas/terrones facetados, de 3.5–15 cm, mate y marrón cálido. |
| Pasto | Hojas cruzadas de 18–42 cm, raíz oscura, punta más clara y viento suave. |

La base opcional de hojarasca para el pincel de texturas de Terrain3D está en
`res://assets/textures/autumn_leaves/autumn_leaves_terrain3d.tres`. Se ha añadido
al final de la lista sin cambiar IDs existentes. Su albedo se generó con ImageGen
integrado; el prompt completo está en `generation_prompt.txt` de esa carpeta.
Los mapas RGBA8 de 1024² se empaquetan con
`tools/build_autumn_leaf_textures.gd`: color/altura y normal OpenGL/rugosidad.
La altura es una aproximación por luminancia, no un escaneo. Sus bordes conservan
detalle pero no coinciden matemáticamente; revisar repetición bajo la luz del
nivel. No se ha repintado ninguna región para añadir esta textura.

La nieve ahora tiene su propia malla y shader. En **Nieve: superficie**:

- **Snow Albedo Gain** (0.75): bajar si el blanco pierde detalle bajo el sol.
- **Snow Depth** (0.08 m), **Snow Relief** (0.06 m) y **Snow Relief Scale**
  (1.2 m): espesor, altura y anchura de acumulaciones suaves. Son sólo visuales.
- **Snow Mesh Spacing** (0.5 m): resolución de la capa; menor cuesta más.
- **Snow Grain Size** (0.025 m) y **Grain Strength**: microdetalle cercano,
  filtrado antes de hacerse subpíxel. Evita puntos grandes repetidos.
- **Snow Scatter** (0.25) y **Snow Sparkle** (0.06): iluminación envolvente
  aproximada y destellos discretos. No es dispersión física volumétrica.

Para nieve estilizada, elegir **Shading → Toon**, reducir Grain Strength y
poner Snow Sparkle en 0. Para nieve lisa, bajar Snow Relief. Los antiguos
Density, Size Min/Max, Thickness y Realism se conservan serializados pero se
ocultan/no se usan para nieve. No se sobrescriben colores ni valores guardados.

**Nieve: estilo** añade Snow Stylized (activo): acabado mate, sin destellos,
con ondulaciones de 32 cm visibles a distancia de juego. Snow Surface Strength
(0.13) ajusta las normales, Snow Surface Contrast (0.10) hace legible el relieve
incluso con toon o sol cenital. Snow Surface Scale controla el tamaño en metros.
Estos controles no cambian la colisión. Se puede usar iluminación Normal suave
con Snow Stylized activo; el modo Toon no es obligatorio para este estilo.
Los nuevos valores iniciales de espesor/relieve sólo se aplican a propiedades
ausentes: se conservan los valores numéricos guardados. Los null producidos por
recargas del editor se recuperan con el valor inicial al cargar/guardar.

Las hojas tienen geometría y shader propios. **Hojas: apoyo → Leaf Clearance**
(0.012 m) controla el margen mínimo, muestreado alrededor de la hoja. El viento
levanta los bordes; no desplaza toda la hoja a través del terreno. Las dos
mitades comparten orientación superior y las hojas subpíxel se desvanecen.

Cada perfil expone:

- **Enabled** y tipo geométrico. Los IDs de textura de perfiles antiguos se
  conservan en el archivo para compatibilidad, pero el pincel no los usa.
- **Density** en elementos/m², tamaño mínimo/máximo en metros, **Thickness**,
  **Maximum Slope**, **Ground Offset**, alineación y **Random Seed**.
- Dos colores, variación de claridad, rugosidad y especular.
- **Shading**: Seguir ajustes del juego / Normal / Toon. **Toon Softness**
  controla el corte sin cambiar el acabado mate. Seguir ajustes usa normal
  en el editor; elegir Toon local para verlo antes de ejecutar.
- Viento opcional, fuerza en metros, velocidad y dirección para hojas/pasto.

Los cambios se actualizan en vivo; geometría y distribución se agrupan cada
0.18 s y las celdas se preparan de una en una. Color, brillo, micrograno y toon
sólo actualizan el material, sin reconstruir instancias. Semilla o densidad
redistribuyen el detalle disperso sin borrar las zonas pintadas.

## Controles del componente

En **Terreno y pintura** se asignan Terrain Path, Paint Data, Enabled y
Editor Preview. El primero apunta al Terrain3D padre; las coordenadas de la
cobertura son mundiales X/Z. No mover/escalar este nodo para mover la pintura.

**Pincel de detalles** ofrece los mismos controles de capa, radio, intensidad y
dureza del panel inferior. La intensidad controla cuánta
cobertura añade cada pasada: más pasadas hacen la nieve más opaca o añaden
instancias dispersas, hasta la densidad del perfil. No guarda tamaños o colores diferentes por
pincelada: éstos son ajustes de cada perfil para todas sus zonas.

**Alcance y rendimiento** controla Draw Distance (40 m), Distance Fade (25 %
exterior), Max Particles (60 000 instancias dispersas) y Cast Shadows (apagado).
**Active Particles** conserva su nombre por compatibilidad: cuenta instancias
de hojas/tierra/pasto, no vértices de nieve. **Active Snow Tiles** cuenta bloques
de nieve cargados. El presupuesto se reserva para el
máximo de celdas cercanas y capas dispersas activas, de forma conservadora.
Mover cámara no cambia esa cuota ni reconstruye las celdas que siguen visibles.
Aumentar Draw Distance puede reducir densidad efectiva; desactivar perfiles
dispersos que no uses libera cuota. La nieve cuesta según Snow Mesh Spacing y
superficie cercana, no consume Max Particles.

Al pintar desde una vista general lejana, **Editor Preview** centra el alcance
visual en el círculo del pincel mientras está activo. Así puede verse la
superficie mientras se trabaja desde una vista general. En el juego, Draw
Distance sigue medido desde la cámara. El círculo sólo indica dónde caerá la
pincelada; para comprobar una zona recién pintada, dejar el ratón sobre ella
un instante mientras se generan sus bloques.

## Guardado y límites

La cobertura se guarda en
`res://resources/surface_details/grass_paint.res`, como tiles binarios comprimidos
de 16 × 16 m con texeles de 0.5 m y cuatro canales. Sólo se crean tiles al
pintar. El render se genera cerca de cámara: nieve con MeshInstance3D y detalle
disperso con MultiMeshInstance3D. El movimiento se calcula en el shader de GPU.
No hay ciclos de emisión, vida o reinicio de partículas. Los nodos generados
no tienen owner y no se guardan; la máscara anterior funciona sin repintar.

Los perfiles externos están en `res://resources/surface_details/`. Para otro
mapa independiente, hacer únicos **Paint Data** y los perfiles que se quieran
independientes, y guardarlos con rutas propias. Compartirlos comparte pintura
o apariencia. No sustituir el archivo de cobertura existente para empezar otro
mapa. Guardar ambos datos —cobertura y regiones Terrain3D— en control de versiones.

El pincel de detalles no cambia los mapas de textura, altura ni colisión de
Terrain3D. La cobertura tiene su propia resolución y filtrado; su borde visual
puede no coincidir exactamente con una transición de texturas pintada aparte.

Los detalles no acumulan nieve física ni bloquean al jugador. La nevada que cae sigue siendo el sistema independiente
existente. Fuera del alcance desaparece el volumen; el suelo pintado conserva
su aspecto. Los cambios de relieve con el pincel nativo actualizan la colocación;
cambios externos que no emitan maps_edited pueden requerir apagar/encender
Enabled para reconstruir. Pintar en laderas lee la altura del terreno, pero un
elemento grande puede intersectar relieves abruptos: reducir Size o ajustar Offset.
La nieve se retira suavemente antes del geomorph lejano de Terrain3D para evitar
que una malla fija cruce un LOD móvil. En crestas muy abruptas aún puede necesitar
más Snow Depth o menor Snow Mesh Spacing. Su espesor no cambia la colisión.
Las transparencias superpuestas tienen las limitaciones de ordenación de Godot;
se usa prepasada de profundidad en las zonas opacas de nieve y hojas.

## Organización del renderizado

SurfaceDetails conserva pincel, máscaras, guardado y deshacer. `snow_surface.gd`
y `snow.gdshader` construyen la capa continua; `leaf_geometry.gd` y
`leaves.gdshader` controlan las hojas. `scatter_renderer.gd` coloca instancias
persistentes de hojas/tierra/pasto. El pasto original sigue en GrassParticles;
su forma y todos sus controles aún no se han trasladado a este perfil.

Verificación puntual previa realizada con Godot 4.6 OpenGL Compatibility:
render de las cuatro capas y cobertura guardada y recargada. No se pintó el
mapa real para estas comprobaciones ni se añadieron suites de tests. La prueba
headless de editor emitió avisos al generar miniaturas sin renderizador; la
prueba con GPU emitió avisos de acceso a caché del entorno restringido.

Revisión de nieve/estabilidad: se capturaron las cuatro superficies en un terreno
temporal con relieve y nieve normal/toon. Se verificó
que el mismo nodo de hojas permanece al mover la cámara entre celdas. Los shaders
compilaron en Godot 4.6 Compatibility. No se guardaron estas pinceladas en el mapa
del usuario ni se ejecutaron suites de tests. Queda por valorar el resultado con
la iluminación y las pendientes concretas del nivel; no se midió el presupuesto
de tiempo de GPU del mapa completo.

La simplificación posterior retiró la edición de texturas de este plugin.
Se comprobaron con Godot 4.6 los scripts del perfil, componente y editor;
queda por probar el pincel visualmente en la escena abierta. El deshacer
conserva la firma antigua para acciones previas de la misma sesión del editor.

## Huellas y hundimiento del personaje

En **SurfaceDetails → Snow → Nieve: huellas**, Snow Footprints Enabled activa
las marcas. Snow Footprint Min Depth (0.04 m) exige ese espesor local: Snow Depth
más ondulación, modulado por cobertura. Ground Offset no cuenta como espesor.
El player envía cada paso normal y alterna izquierda/derecha. No se generan
marcas al saltar, trepar o deslizarse, ni sólo por tener una textura blanca.
Snow Contact Tolerance evita detectar el terreno cuando el personaje está
sobre un objeto elevado; objetos más bajos que esa tolerancia pueden coincidir.

Snow Footprint Width/Length/Separation controlan la pisada (0.22/0.34/0.12 m).
Snow Footprint Depth es su límite de profundidad visual. Snow Footprint Lifetime
(120 s) la desvanece durante el último tercio. Son máscaras temporales de 512²
por bloque de 16 m, actualizadas al pisar; Snow Footprint Tiles limita memoria
(8 por defecto, aproximadamente 32 MB en CPU y 32 MB en GPU). Se elimina el
bloque más antiguo al superar el límite. No se guardan con la partida.

En **Nieve: hundimiento**, Snow Compaction va de polvo (0) a dura (1).
La compresión es `min(Snow Sink Max, espesor × Snow Sink Ratio × (1-compacción))`.
La altura visible del modelo sobre el suelo es el espesor restante más Ground
Offset. Snow Sink Response suaviza entrada/salida; Snow Sink Enabled apagado
sostiene el modelo sobre la capa sin hundirlo. La compactación también limita
la profundidad de cada huella nueva. Ejemplo: capa de 10 cm, ratio 0.65 y
compactación 0.35 hunden el modelo unos 4.2 cm; con compactación 0.9, sólo 0.65 cm.

La colisión del actor permanece sobre Terrain3D. El ajuste se suma al contenedor
visual del personaje y se retira al saltar/trepar; no cambia velocidad, salto,
cámara ni la altura física del terreno. Las huellas simulan depresión mediante
normales y sombreado: no excavan la geometría ni alteran la silueta o colisión.
Las capas muy profundas requerirían otro sistema físico y no son el objetivo
de este componente. Los árboles, tejados y huellas de la referencia no se
generan automáticamente sobre props: el pincel trabaja sobre Terrain3D.

Verificación visual de esta revisión: player real caminando en un terreno
temporal plano, huellas a ambos lados del paso y elevación visual del modelo;
shaders normal/toon compilados en Godot 4.6 Compatibility. Se conservó intacta
la pintura del mapa real. La iluminación del nivel puede cambiar el tono final.
