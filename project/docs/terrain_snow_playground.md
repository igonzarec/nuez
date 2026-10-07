# Terreno nevado: jugar y editar

Esta escena usa tu terreno de 300 × 300 m y crea nieve con volumen real en Godot.
Las acumulaciones modifican la superficie y su colisión: Nuez camina sobre ellas.
El GLB y el archivo de Blender siguen siendo las fuentes del relieve original.

## Abrir y jugar

En **FileSystem**, abajo a la izquierda de Godot, abre
`res://scenes/terrain_snow_playground.tscn` con doble clic. Pulsa **F6** para
ejecutar esta escena. **F8** la detiene; **F5** abre el juego principal.

WASD mueve, Shift corre, Espacio salta y permite planear con una nueva pulsación
en el aire. Mantén clic derecho para mover la cámara; C recentra; R devuelve al
inicio. También se conservan los controles de mando del jugador existente.
La escalada está activada en el nuevo **ClimbableCliff**: mantén Espacio frente
a la roca y usa WASD para subir o desplazarte lateralmente. El test inicia
frente a esa pared mediante **CliffTestStart**. Para volver al inicio anterior,
vacía **Spawn Marker** en la raíz. Consulta [Acantilado escalable](climbable_cliff.md)
para colocar repisas, cambiar sus materiales y delimitar las zonas escalables.

En el árbol **Scene**, arriba a la izquierda, selecciona un nodo; sus controles
aparecen en **Inspector**, a la derecha. Edita con el juego detenido y guarda
con Ctrl+S. Los valores del panel Remote durante ejecución no son persistentes.

## Forma y cobertura de nieve

Selecciona **SnowTerrain**. La superficie se actualiza en el editor al cambiar
sus propiedades o las zonas, con una comprobación breve mientras editas.

| Control | Qué cambia |
| --- | --- |
| Snow Enabled | Activa nieve, espesor y montículos; apagado muestra el terreno base. |
| Base Coverage | Cobertura general. Pon 0 para colocar nieve solamente mediante zonas. |
| Snow Line | Altura local Y donde comienza la cobertura automática. |
| Height Transition | Metros de transición hasta la cobertura completa. |
| Slope Limit | Inclinación máxima con nieve; un valor mayor cubre paredes más empinadas. |
| Slope Transition | Suavidad de la transición por inclinación, en grados. |
| Blanket Depth | Espesor base, en metros. Inicial: 0,3. |
| Undulation / Undulation Size | Altura y escala de las ondulaciones superficiales. |
| Subdivision Levels | Resolución del volumen: cada nivel multiplica por cuatro las caras. Se conserva tu elección: 0. Subdividir no redondea el relieve. |
| Rounding Iterations | Pasadas de suavizado del relieve base. 0 conserva tu forma; prueba 2–5 para redondear pliegues. |
| Rounding Strength | Fuerza por pasada. Prueba 0,2–0,4; valores altos aplanan detalles. La colisión sigue la misma superficie. |
| Preview Enabled | Oculta la superficie generada en el editor para aligerar la edición; sigue apareciendo al jugar. |
| Reconstruir terreno y nieve | Vuelve a leer el GLB y reconstruye la superficie. Úsalo después de reexportar. |
| Flip Source Faces | Corrige caras invertidas en la copia generada. Está activo porque este GLB tiene las normales hacia abajo. |

Una superficie abierta no tiene un interior cerrado inequívoco: Recalculate
Outside en Blender no garantiza que su cara visible quede arriba. Si corriges
la orientación en Blender y reexportas, desactiva Flip Source Faces y reconstruye.

## Colocar montículos y abrir claros

Despliega **SnowTerrain → SnowZones** en el árbol de la izquierda. Hay dos
montículos de ejemplo y un claro desactivado, `ClearingExample`.

1. Selecciona `SnowdriftWide` o `SnowdriftSmall`.
2. Duplica con **Ctrl+D** sobre el árbol Scene y ponle un nombre descriptivo.
3. En **Inspector → Transform → Position**, cambia X y Z para colocar la zona.
   También puedes arrastrar las flechas de movimiento de la vista 3D.
4. Ajusta **Radius**, **Depth** y **Softness**. El terreno muestra el volumen
   resultante. El círculo azul es una guía que solo existe en el editor.
5. Usa **Transform → Scale** en X/Z para hacer una elipse, y Rotation Y para
   orientarla. Mantén escala positiva, Scale Y=1 y Rotation X/Z=0.

| Control de zona | Uso |
| --- | --- |
| Enabled | Activa o desactiva la contribución sin borrar la zona. |
| Operation: Acumular | Añade cobertura y espesor local. |
| Operation: Quitar | Retira cobertura y volumen para formar un claro. |
| Radius | Radio en metros antes de aplicar escala. |
| Depth | Espesor adicional en el centro; no interviene al quitar. |
| Coverage | Intensidad de cobertura o de borrado, de 0 a 1. |
| Softness | Fracción del radio usada para el borde gradual. 1 crea un montículo redondeado; valores bajos hacen una meseta. |

La zona se proyecta sobre X/Z: su posición Y no define la altura del montículo.
Muévela verticalmente si deseas situar la guía cerca del suelo; usa **Depth**
para cambiar la acumulación. Los montículos superpuestos suman espesor; los
claros se aplican después. Slope Limit sigue actuando también en las zonas.

Para nieve exclusivamente manual: Base Coverage=0, añade zonas con Operation
Acumular y Coverage=1. Para nieve casi continua como la referencia, conserva
Base Coverage=1 y añade montículos o claros donde quieras.

Esta primera herramienta está pensada para terrenos abiertos. No distingue dos
pisos superpuestos, techos o cuevas en la misma coordenada X/Z. Evita montículos
muy estrechos respecto al tamaño de los triángulos: sube resolución solo si la
silueta necesita más detalle. La superficie es continua, sin cajas de nieve
visibles durante el juego.

## Aspecto: blanco, grano y suavidad

En **SnowTerrain → Material Style** puedes comparar **Original**, **Grano
visible** y **Nieve en polvo**. Se conserva tu selección actual; no se cambia
automáticamente al actualizar herramientas.
**Flat Detail Strength** controla el contraste adicional del grano mediano,
mediante color además de relieve de iluminación, en las tres variantes.
Prueba 0,1 para algo discreto y 0,4 para hacerlo más evidente.

**Snow Brightness** modifica el brillo de toda la nieve; **Flat Brightness**
modifica sólo las partes casi horizontales, con transición hacia las pendientes.
1 conserva el brillo; prueba Flat Brightness=0,85 para reducir el blanco de los
planos. Estos controles cambian el material, mientras que **Sunlight → Light →
Energy** y **WorldEnvironment → Environment → Ambient Light → Energy** cambian
la luz de toda la escena.

Para reducir picos de los montículos, usa **SnowTerrain → Volumen → Snow
Rounding Iterations** (empieza con 2–4) y **Snow Rounding Strength** (0,25).
Se aplica después de acumular nieve y la colisión sigue el resultado. Los
controles Rounding anteriores suavizan el relieve base antes de añadir nieve.
Ninguno añade polígonos: una silueta con muy pocos vértices seguirá teniendo
segmentos; puedes combinar suavizado con Subdivision Levels=1 si lo necesitas.

Las variantes aparecen también como **SnowTerrain → Grain Material** y
**Powder Material**. Haz clic en el recurso de la variante que esté seleccionada
en Material Style y despliega **Shader Parameters** en el Inspector para cambiar
Grain Scale, Grain Strength, Broad Scale/Strength, Roughness y Micro Relief.
Los cambios de material se ven inmediatamente en el editor; el detalle muy fino desaparece a distancia
para evitar parpadeos; Grain Scale más bajo hace el grano visible desde más lejos.

### Referencia de Shader Parameters

| Valor | Qué controla | Punto de partida |
| --- | --- | --- |
| Snow Color / Rock Color | Colores de nieve y suelo expuesto. | Ajusta primero Snow Color; Rock Color sólo aparece donde no hay cobertura. |
| Roughness | Dispersión de la luz: 0 se ve más pulido o húmedo; 1 más mate y seco. No cambia la forma ni el grano. | 0,8–1 para nieve seca; 0,45–0,7 para nieve húmeda o compactada. |
| Grain Enabled | Check para apagar por completo el grano fino, sin apagar el detalle medio ni las variaciones amplias. | Activado para nieve granular; desactivado para nieve lisa. |
| Grain Scale | Tamaño del grano fino; mayor = más pequeño. | 2–8 para lectura cercana. |
| Grain Strength | Contraste del grano fino. | 0,05–0,15 discreto; 0,2 o más visible. |
| Grain Distance Fade | Desvanece grano fino a distancia para evitar parpadeo. | 1 seguro; 0 lo conserva a toda distancia. |
| Broad Scale / Strength | Tamaño y contraste de variaciones amplias. Sólo en Grano visible y Nieve en polvo. | Scale 0,3–1, Strength 0,05–0,2. |
| Flat Detail Scale / Strength | Tamaño y contraste del detalle medio, útil en planos y vistas lejanas. | Scale 1–4, Strength 0,05–0,2. |
| Micro Relief | Pequeña variación de iluminación, sin añadir polígonos. | 0,02–0,1. |
| Shading Softness | 0 muestra facetas low-poly; 1 suaviza la iluminación entre caras. | 0,7–1 para nieve redonda. |
| Snow Brightness / Flat Brightness | Brillo global y brillo adicional de partes horizontales. | 0,85–1,05 para evitar blanco quemado. |

En **SnowTerrain → Snow Material**, haz clic en el recurso y despliega **Shader
Parameters**. También puedes abrir `res://materials/terrain_snow.tres` desde
FileSystem. El material es compartido; hazlo único antes de reutilizarlo con
un estilo diferente en otra escena.

| Parámetro | Uso |
| --- | --- |
| Snow Color / Rock Color | Colores de nieve y suelo expuesto. |
| Roughness | Rugosidad: cerca de 1 es mate; valores menores dan reflejos. |
| Grain Scale | Frecuencia del grano: mayor valor produce detalle más fino. |
| Grain Strength | Contraste del grano. Inicialmente sutil. |
| Micro Relief | Pequeña variación visual de normales, sin afectar colisión. |
| Shading Softness | 1 interpola la iluminación suavemente; 0 marca cada triángulo. No redondea la geometría. |

La suavidad geométrica de un montículo se controla con Softness y su resolución.
Las grandes formas siguen siendo las que modelaste en Blender. El material no
borra automáticamente aristas o pliegues del relieve original.

La iluminación también cambia mucho el blanco: **Sunlight → Light** ajusta luz
y color; **WorldEnvironment → Environment → Ambient Light** ajusta relleno y
tono azulado de sombras. Los valores iniciales buscan la referencia de nieve
suave, conservando el personaje low-poly.

## Nevada y reacciones a los pasos

Selecciona **Snowfall**: Enabled, Flakes, Radius, Ceiling, Flake Size, Fall Speed
y Wind controlan los copos. Height Start/End delimitan el tramo de altura y
Low/High Intensity determinan la densidad en sus extremos. Puedes invertir las
intensidades para nevar más abajo. El emisor sigue al personaje: no llena los
300 metros del mapa de partículas. Los parámetros se aplican al iniciar F6;
también se previsualizan en el editor si **Snowfall → Editor Preview** está
activado. Los copos son discos redondos orientados hacia
la cámara, de dos triángulos cada uno, sin sombras. Flakes admite hasta 20.000
en el deslizador, Fall Speed hasta 50 m/s, Flake Size hasta 1 m y Radius hasta
200 m; también puedes escribir valores mayores. Los controles se pueden
probar en Remote durante ejecución, pero debes copiarlos a Local para guardarlos.

Selecciona la raíz **TerrainSnowPlayground**:

- **Huellas:** interruptor, tamaño, color, máximo simultáneo y duración. Son
  marcas visuales temporales, alternadas por paso; no agujeros físicos. La
  colocación usa el ritmo de pasos del controlador, no contactos de huesos.
- **Nieve profunda:** activa una reducción gradual de velocidad según el
  espesor real de la superficie. Deep Speed Multiplier=1 conserva la velocidad;
  Deep Snow Depth indica el espesor donde se alcanza la reducción máxima.

Las huellas se reutilizan hasta el límite configurado, se desvanecen y no se
guardan al cerrar. La superficie no se deforma persistentemente al empujarla;
esa interacción requerirá una máscara dinámica y otra iteración del sistema.
Los sonidos actuales del personaje y el recentrado de cámara se conservan con
TrailAudio. En nieve, SnowStepAudio sustituye el paso habitual por seis
pasos de nieve ya separados.

## Sonido de pasos

**Walk Min Interval** y **Run Min Interval** limitan cuán seguido pueden sonar
los pasos al caminar y correr, sin alterar el archivo, volumen ni velocidad del
clip. Valores iniciales: 0,30 y 0,20 segundos. Valores mayores espacian el audio.
Step Frequency sigue controlando contactos por distancia; el intervalo sólo
limita las reproducciones, por lo que las huellas conservan sus contactos.

El salto conserva el sonido habitual del juego. **Landing Sample** usa
Snowstep 06 Mid al tocar suelo y **Landing Double Step** reproduce una segunda
vez el mismo clip, para representar ambos pies. **Landing Second Delay** separa
ambos contactos; 0,04–0,08 s suele sonar natural. Landing Gain Db ajusta ambos
sobre Volume Db. Landing Step Delay evita sumar otra pisada inmediatamente.

## Rendimiento y actualización en el editor

Los controles de materiales (color, brillo, grano, Micro Relief, Roughness) son
ligeros: cambian el shader de la GPU y se ven de inmediato en la vista 3D.
**Flakes** es el coste continuo más claro: 1.000 es razonable para esta escena;
varios miles aumentan el trabajo de partículas. **Radius** y **Ceiling** amplían
el volumen que se simula, pero no multiplican el número de copos por sí solos.

**Subdivision Levels** multiplica por cuatro las caras por nivel y hace más
lenta la reconstrucción, la vista y la colisión. **Rounding Iterations** y
**Snow Rounding Iterations** recorren todos los vértices por cada pasada: no
añaden triángulos, pero pueden tardar al editar una malla grande, sobre todo con
Subdivision Levels alto. Rounding Strength solamente cambia cuánto se mueve cada
vértice; no es costoso por sí mismo. Empieza con nivel 0 y 1–4 pasadas.

Los parámetros que cambian geometría o colisión se actualizan en el editor tras
una pausa muy breve al arrastrar un deslizador. El jugador, sus pendientes, los
audios y la nieve profunda requieren **F6** porque dependen del juego en marcha.
Si estás editando un material y no ves cambio, comprueba **SnowTerrain → Material
Style**: debes abrir el recurso que corresponde a esa variante (Snow Material,
Grain Material o Powder Material), no uno de los otros dos.

Los controles de detalle están separados:

- **Grain Scale** cambia el tamaño/frecuencia: mayor valor = grano más pequeño.
- **Grain Strength** cambia solamente el contraste del grano.
- **Grain Distance Fade** controla cuánto se oculta el grano fino a distancia:
  1 conserva el antialias para evitar parpadeo; 0 lo mantiene visible en toda
  la nieve, con posible ruido visual a distancia.
- **Flat Detail Scale** cambia el tamaño del detalle mediano; **Flat Detail
  Strength** cambia su contraste. Esta capa sirve para conservar lectura sobre
  nieve plana o vista desde lejos.

Un cambio corto de Grain Scale, por ejemplo de 3 a 2,5, puede ser sutil con
Grain Strength=0,07. Para comprobarlo, compara 1 contra 12 y aumenta
temporalmente Grain Strength a 0,2; después recupera los valores que prefieras.

Con el juego detenido, selecciona **SnowStepAudio** en el árbol **Scene**,
arriba a la izquierda. Sus propiedades aparecen en **Inspector**, a la derecha.
Guarda con Ctrl+S y ejecuta con F6 para escuchar los cambios.

| Control | Qué cambia |
| --- | --- |
| Enabled | Activa los clips de nieve; apagado recupera el sonido habitual. |
| Variantes activas | Seis interruptores individuales: activa o desactiva Noisy 1/2, Soft 3/4 y Mid 5/6. |
| Samples | Los seis clips individuales; puedes sustituirlos o reordenarlos. |
| Mezcla → Volume Db | Volumen de las pisadas, además de los controles SFX y Master. Inicial: −12 dB. |
| Playback Speed | Velocidad del clip: 2 dura la mitad, 0,5 dura el doble. |
| Pitch | Tono final: 1 original, menos de 1 grave, más de 1 agudo. |
| Frecuencia de pasos → Step Frequency | Pisadas por distancia: 2 duplica la cadencia, 0,5 la reduce a la mitad. |
| Selection Mode | Aleatorio sin repetición inmediata o los cinco clips en orden. |
| Frecuencias del sonido → Low Pass Enabled | Activa el filtro que atenúa agudos. |
| Cutoff Hz | Frecuencia de corte: valores bajos apagan el crujido; altos conservan más brillo. |

Playback Speed y Pitch son independientes mediante compensación de tono.
La compensación puede introducir un pequeño retardo y alterar el timbre en
ajustes extremos. Con ambos en 1 se evita ese procesamiento. El filtro está
apagado inicialmente para conservar el sonido original.

Step Frequency modifica los eventos de contacto, incluidas huellas y partículas;
no cambia la velocidad del personaje ni la animación de sus patas. Conviene
mantenerlo cerca de 1 para que el sonido acompañe la animación.

Los clips se eligen al caminar sobre cobertura de nieve de al menos 0,5. En
suelo expuesto se conserva el paso habitual. Ocho voces permiten solapar las
colas del crujido; los archivos no se reproducen en bucle. Saltos, cámara y los
demás efectos conservan su conexión con TrailAudio.

Los clips se conservan en `res://audio/snow_steps/`; no se modificaron ni se
recortaron durante la importación.

## Inicio, cámara y reexportación

Mueve **PlayerStart → Transform → Position X/Z** dentro del mapa para cambiar
el inicio. Al ejecutar se busca suelo hacia abajo y se coloca al jugador sobre
la nieve. Y es el origen de esa búsqueda, no la altura final del personaje.
R y las caídas fuera del mapa recuperan ese punto.

**CameraRig** permite ajustar distancia, inclinación y suavizado. El desenfoque
de distancia está apagado en esta escena para inspeccionar el material.
**SquirrelExplorer** conserva los parámetros del controlador real.

La vertical en Godot es **Y**. En CameraRig, **Full Vertical Orbit** permite
inclinar libremente la cámara; Minimum/Maximum Pitch delimitan el ángulo entre
−89° y 89°. C recentra a Pitch Degrees. Si apagas Full Vertical Orbit vuelve el
margen limitado por Vertical Range Degrees. Al planear, Glide Pitch Degrees
mantiene su vista especial hasta que inclines manualmente la cámara; C restaura
el comportamiento automático.

## Copos: forma, color y vuelo

Selecciona **Snowfall** en Scene, arriba a la izquierda. En el Inspector:

- **Flake Style:** Original angular recupera la geometría inicial; Copo irregular
  tiene bordes desiguales; Polvo suave usa motas difusas. Irregularity controla el
  borde de la segunda variante.
- **Flake Color / Opacity:** color y transparencia. Receive Lighting permite que
  las luces tiñan los copos. Apagado muestra su color propio.
- **Flake Size / Size Variation:** tamaño y diversidad. Se conserva tu tamaño
  guardado de 0,005 m; puede ser apenas visible a cierta distancia.
- **Nevada durante vuelo → Flight Intensity:** 0 desactiva copos al planear,
  1 mantiene la cantidad base, 2 la duplica. Flight Size Multiplier cambia sólo
  su tamaño durante el planeo.
- **Follow Player Motion:** mantiene los copos alrededor de la vista al moverse
  rápido. El emisor llena un volumen, no una región fija del mapa. Desactivado
  deja las partículas en el mundo y un vuelo rápido puede adelantarse a ellas.

## Cámara, pendientes y bordes

Se restauró **CameraRig → Full Vertical Orbit = Off**. La escena compartida usa
Pitch Degrees=−40 y Vertical Range Degrees=6, es decir, de −46° a −34°.
Aumenta Vertical Range Degrees para ampliar ese margen. Con Full Vertical Orbit
activado se usan Minimum/Maximum Pitch. La altura espacial es Y; estos límites
son ángulos de inclinación, no límites de posición en Y.

Para caminar pendientes, selecciona **SquirrelExplorer → Ground Contact →
Walkable Slope Degrees**. El valor actual es 48°. Por ejemplo, 55 permite subir
más inclinación; 40 provoca deslizamiento antes. El rango ahora llega a 85° y
también responde a cambios en Remote. **SnowTerrain → Slope Limit** controla
dónde se acumula nieve, no qué puede caminar el personaje.

**CameraRig → Separación de siluetas → Depth Outline Enabled** activa una línea
en cambios bruscos de profundidad. Opacity, Width, Threshold y Color controlan
su aspecto. Está apagada por defecto. Reconoce superficies opacas delante de
otras aunque compartan color; no dibuja la unión entre caras coplanares ni
contornos de partículas transparentes. Puede marcar también personaje y árboles.
La técnica utiliza la [textura de profundidad de Godot](https://docs.godotengine.org/en/4.4/tutorials/shaders/advanced_postprocessing.html).

## Menú de pausa

**Esc** o **Start** abre el menú; Seguir explorando vuelve a jugar. Ajustes y
Controles reutilizan la interfaz del juego y comparten el archivo de ajustes.
El autoload ScenePause descubre automáticamente las escenas de trabajo con
ExplorerPlayer; no hace falta añadir un menú a cada escena. El juego principal
conserva su coordinador de estados y usa la misma TrailUI sin duplicar menús.
En una escena de trabajo, el acabado pixelado se aplica cuando lo cambias en
Ajustes; al abrir la escena se mantiene la vista de autoría sin ese filtro.

## Árbol provisional reutilizable

En **FileSystem**, abajo a la izquierda, abre `res://scenes/props/` y arrastra
**snow_pine.tscn** a la vista 3D. Selecciona la instancia en Scene y ajusta
**Inspector → Transform → Position**, especialmente Y para apoyar el tronco
sobre la nieve. Usa escala uniforme para variar tamaño y Ctrl+D para duplicar.
El árbol mide unos 4,7 m de alto y está basado en el pino de la escena original.

Al abrir snow_pine.tscn puedes editar sus mallas y materiales normales de Godot.
SnowCaps agrupa las tres capas de nieve; desactiva su Visible para un pino sin
nieve. El tronco tiene colisión, las ramas son visuales. Haz únicos los recursos
si quieres cambiar los colores de una instancia sin afectar a las otras.

**ClearingExample**, dentro de SnowTerrain/SnowZones, es un ejemplo desactivado
de Operation=Quitar: retira nieve en una zona circular o elíptica. Activa Enabled
y muévelo para abrir un claro. Puedes duplicarlo como cualquier montículo.

Exporta nuevamente desde Blender al mismo GLB, espera a que Godot reimporte y
usa **Reconstruir terreno y nieve**. Las zonas y el material se conservan en la
escena. Si cambias mucho la forma, revisa sus posiciones y PlayerStart.

## Alcance técnico de esta versión

### Incidencia: copos y huellas invisibles con blur activo (2026-10-04)

Al unificar los defaults se eliminó `distant_blur_enabled = false` de esta
escena. El blur compartido tenía `render_priority = 100`: dibujaba encima de
copos y huellas una captura que sólo contiene objetos opacos. Ambos efectos
usan transparencia, por lo que quedaban tapados aunque estuvieran activos.

Se cambió la prioridad del blur a **-128**, antes de las transparencias
habituales (prioridad 0). El blur permanece activo sobre el mundo opaco;
copos y huellas se componen después y no reciben este desenfoque.
No se cambiaron los valores artísticos guardados en la escena.

Las explicaciones anteriores sobre conversión CPU/GPU y ausencia de índices
de colisión no se demostraron. Se conserva la configuración GPU explícita,
pero se restauró la lectura de cobertura interpolada para las huellas, igual
que para el audio, para respetar la superficie de nieve generada.

Verificación: Godot 4.6 ejecutó la escena sin errores de scripts, generó
1.922 triángulos y colocó al personaje en el terreno. Fue una ejecución sin
imagen; queda pendiente la confirmación visual en Compatibility. Al revisar
el resultado, ejecutar esta escena, caminar y comparar con Distant Blur
Enabled encendido/apagado: ambos efectos deben seguir visibles.

Referencia: [captura 3D y transparencias en Godot](https://docs.godotengine.org/en/4.6/tutorials/shaders/screen-reading_shaders.html).

La malla derivada combina el suelo expuesto y la nieve para evitar superficies
superpuestas. El volumen se desplaza hacia arriba y conserva el trazado base;
no crea voladizos. La colisión se genera una vez al arrancar a partir de esta
misma superficie (1.922 triángulos con el GLB actual y nivel 0). Sigue siendo
una colisión de blockout: aún falta revisar un proxy simplificado para el nivel
final. Las zonas no reconstruyen física cada frame durante el juego.

Se comprobó el arranque en Godot 4.6 y el render en Compatibility, con colocación
del personaje sobre la nieve. Queda la revisión manual del recorrido completo,
el tacto del movimiento y el acabado artístico. No se ejecutaron suites ni se
añadieron archivos de tests.

Referencias de implementación: [SurfaceTool en Godot 4.6](https://docs.godotengine.org/en/4.6/classes/class_surfacetool.html)
y [GPUParticles3D en Godot 4.6](https://docs.godotengine.org/en/4.6/classes/class_gpuparticles3d.html).
