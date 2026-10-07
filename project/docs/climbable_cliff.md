# Acantilado escalable: edición y prueba

La referencia actual es `magnific__crea-un-cliff-escalable-con-grficos-tipo-low-polly__56592.png`:
roca oscura con facetas grandes, vetas irregulares, nieve en la coronación y
repisas anchas mezcladas con apoyos pequeños. La versión procedural interpreta
esa forma con geometría real y controles, no proyecta la fotografía sobre la roca.

## Dónde está y cómo jugar

Abre `res://scenes/terrain_snow_playground.tscn` y ejecuta F6. **ClimbableCliff**
se encuentra en `(30, 14, -105)`, sobre el frente de roca orientado hacia +X.
El terreno y su GLB original se conservan: la pieza nueva se superpone al frente.
Las pendientes laterales y el borde de encuentro deben revisarse visualmente al
variar dimensiones; no hay unión booleana automática con la montaña.

**Spawn Marker** en la raíz apunta a **CliffTestStart**, delante de la pared.
Mueve ese marcador para probar otra entrada. Vacía la propiedad para regresar
al **PlayerStart** original. El inicio se proyecta verticalmente sobre el suelo.

Acércate mirando a la roca, mantén **Espacio** y usa **W/S** para subir/bajar,
**A/D** para moverte lateralmente. Soltar Espacio suelta el agarre. Al superar
un borde, el controlador existente intenta subir a él si hay espacio para la
cápsula. No atraviesa una plataforma desde abajo: rodéala por el lateral y
acércate a su frente para alcanzar su techo. Las plataformas son descansos de
una ruta escalable, no una escalera diseñada para saltar cada separación.

Los valores de velocidad, alcance, ángulo de agarre y animación están en
**SquirrelExplorer → Escalada**. Se reutilizan la postura procedural y los
sonidos existentes; una animación artística nueva sigue siendo trabajo posterior.

## Pared y controles visuales

Selecciona **ClimbableCliff**. Cada propiedad nueva incluye ayuda al posar el
cursor en el Inspector. Su frente local es **+Z**, su base **Y=0**.

| Grupo / control | Uso |
| --- | --- |
| Forma / Dimensions | Anchura, altura, profundidad en metros. Ajustar esto antes que escalar el nodo físico. |
| Shape Seed | Otra distribución reproducible del relieve y facetas. |
| Columns / Rows | Resolución de relieve y proxy. Ambas aumentan el coste de reconstrucción. |
| Relief | Nervaduras verticales que sigue la colisión; no es sólo una textura. |
| Facet Depth | Detalle visual pequeño entre nervaduras; no modifica el proxy. |
| Top Width Ratio / Crown Drop | Estrechamiento superior y caída de los extremos para la silueta arqueada. |
| Rim Variation | Irregularidad en altura del borde superior. |
| Silhouette Irregularity / Crown Asymmetry | Desigualdad de flancos y desplazamiento lateral de la cumbre. |
| Vertical Relief / Base Projection | Relieve por altura y volumen saliente en la parte baja. |
| Terrain Path / Conform / Offset | Referencia a SnowTerrain, intensidad de adaptación y separación frontal en metros. |
| Rock Color / Vein Color | Colores de base y de las vetas. |
| Strata Scale | Frecuencia de vetas: mayor valor las hace más pequeñas y juntas. |
| Strata Strength / Warp | Contraste y ondulación de las vetas. Strength=0 las elimina. |
| Facet Variation | Variación tonal entre los triángulos del frente. |
| Roughness | Rugosidad: valores altos reducen el brillo. |
| Snow Enabled / Depth | Activa la capa superior y define su espesor físico. |
| Snow Color / Roughness | Apariencia de esa nieve, independiente del material de SnowTerrain. |

La forma toma muestras de las caras del terreno generado: adapta alturas y
profundidades sin editar el GLB. Tras modificar SnowTerrain, pulsa **Rebuild
Geometry** en ClimbableCliff para volver a muestrearlo. La adaptación es parcial:
**Terrain Conform=0** deja sólo la forma procedural; **1** sigue más la montaña.
El tamaño y la posición de la pieza siguen siendo decisiones manuales.

La nieve usa ahora el mismo shader **terrain_snow.gdshader**, con valores propios
por pieza. Conserva Snow Color y ofrece **Snow Grain Enabled / Scale / Strength**,
**Micro Relief**, **Shading Softness**, **Flat Detail Strength / Scale**, **Brightness**
y **Flat Brightness**. Estos controles cambian el material en vivo y no modifican
los valores del material de tu terreno. El grano está inicialmente desactivado.

**Snow Undulation** es la altura de ondulaciones físicas; **Undulation Size**,
su amplitud horizontal. **Snow Rounding** abomba suavemente el centro de los
apoyos. **Snow Segments** define cuántas divisiones representan esas curvas.
La colisión superior se genera de la misma superficie de nieve.
Al pisarla se conserva la integración de audio de nieve y huellas. Desactivar
la nieve quita esa identificación de superficie. No se cambian los clips ni los
valores de audio que ya configuraste.

## Repisas manipulables

Despliega **ClimbableCliff → Platforms** en la escena de prueba. Los hijos de la
instancia están habilitados para edición. También puedes abrir directamente
`res://scenes/cliff/climbable_cliff.tscn` para editar la pieza reutilizable.

Selecciona una repisa y usa mover/rotar, duplica con Ctrl+D o elimina la que no
quieras. Para otra nueva instancia `res://scenes/cliff/rock_platform.tscn` dentro
de **Platforms**. Sus Dimensions determinan ancho, grosor y profundidad; la
posición Y marca la **base**, no el techo. La superficie de apoyo está en
aproximadamente en Y + Dimensions.y + Snow Depth, más pendiente y ondulación.

**RestLower**, **RestRight** y **RestUpper** son bloques grandes: el inferior
sobresale 8 m de su pared local, el intermedio 5 m y el superior 2,5 m. Sus cuerpos
se prolongan hacia abajo. Puedes cambiar esos valores individualmente con
**Protrusion** y la altura con **Dimensions.y**; no hay recolocación automática en X/Y.

Los **Foothold** son apoyos menores, de 1,4–1,7 m de ancho y salida 0,55–0,7 m.
**Protrusion** controla la salida y **Dimensions.z** su profundidad total, incluida
la parte enterrada. Si quieres apoyar todo el cuerpo con holgura, aumenta la salida.

**Bevel** estrecha la base; **Corner Variation** varía el contorno octogonal;
**Side Relief** mueve facetas laterales. **Top Slope Degrees** inclina el techo en
dos direcciones (máximo ±25°), y **Top Irregularity** rompe su regularidad en metros.
Para descansos cómodos usa 0–5° y poca irregularidad. Cada pieza tiene material
y semilla propios. Las propiedades
Columns, Rows, Relief, Facet Depth, Crown Drop y Rim Variation corresponden a
Wall; no cambian las repisas. Facet Variation afecta las facetas del frente Wall.

**Attach To Wall** conserva tu posición X/Y, pero ajusta la geometría en profundidad
cuando cambia la pared o mueves el apoyo: evita dejarlo flotando o enterrado.
Está activado en los apoyos de esta escena. Para colocar libremente también Z,
desactívalo y usa la transformación del nodo; Protrusion pasa a ser un desplazamiento
local. No se eliminan ni recrean tus nodos manuales al regenerar la pared.
La adaptación requiere Live Preview o reconstrucción manual de cada pieza.
No escales ni inclines mucho un cuerpo físico;
prefiere Dimensions y mantén Scale=(1,1,1).

## Toda la pared, sólo zonas o ninguna

**Climb Mode** en la pared ofrece:

- **Whole Wall** (inicial): toda la pared permite agarre, sujeto a los límites
  de inclinación y orientación del controlador del personaje.
- **Selected Zones**: sólo los puntos dentro de un volumen de **ClimbZones**.
  Hay un **ExampleRoute** con contorno verde visible únicamente en el editor.
  Muévelo, ajusta **Size**, duplícalo o desactívalo con **Enabled**.
- **Disabled**: conserva la roca sólida, pero impide agarrarse a ella.

Las repisas tienen **Inherit Climb Mode** activo: obedecen la pared antecesora.
Desactívalo para un comportamiento independiente. Las zonas se comprueban en
el punto de contacto, sin crear nuevos cuerpos que bloqueen al personaje.
**Climb Surface Tilt** permite ajustar qué inclinación de faceta admite el agarre,
medida desde una pared vertical (inicial: 35°). No cambia el ángulo caminable del jugador.

## Aclarar la roca y manipular la luz

Los colores de roca y nieve se conservan. La oscuridad depende de la orientación
del sol y las sombras; ahora **ClimbableCliff → CliffFill** aporta relleno suave.
Es una OmniLight3D sin sombras que sólo ilumina la capa visual 20, usada por estas
piezas: no aumenta la iluminación del resto del terreno.

- **Light → Energy**: intensidad del relleno (inicial 1,8). Prueba 0,8–2,5.
- **Light → Color**: tinte del relleno; blanco mantiene una iluminación más neutra.
- **Omni → Range / Attenuation**: alcance y rapidez con que decae. Range inicial: 90 m.
- **Transform → Position**: mueve la luz delante o a un lado para cambiar el modelado.
- **Visible**: desactiva temporalmente el relleno para comparar.

Para el sol de toda la escena selecciona **StylizedSky → Primary Profile**:
**Sun Azimuth** gira la dirección horizontal, **Sun Elevation** eleva el sol,
**Sun Energy** cambia luz directa y **Ambient Energy** aclara las zonas en sombra.
**Shadow Opacity** reduce la oscuridad de las sombras proyectadas. Con Profile
Blend mayor que cero, Secondary Profile también contribuye. No edites sólo
Sunlight: StylizedSky puede volver a aplicar el perfil. Si quieres ajustes
exclusivos de esta escena, haz **Make Unique** en el perfil antes de editarlo.
Se conserva el perfil actual; sólo se añadió el relleno local.

## Colisión, edición en vivo y coste

La pared usa un proxy de triángulos estático, con menos detalle que sus facetas
visuales; cada bloque usa un proxy convexo y una superficie de nieve con su propia
colisión. La
capa 1 es suelo del jugador y **Camera Blocker** añade la capa 3 para la cámara.
**Solid Enabled** apaga ambas colisiones para usar una pieza como decoración.

**Live Preview** regenera la geometría al terminar de editar, después de
**Preview Delay** (0,35 s). **Rebuild Geometry** fuerza la actualización aunque
la casilla esté apagada. Colores, vetas y rugosidad cambian directamente;
reglas de escalada no requieren reconstrucción. Mover una pieza con Attach To
Wall sí recalcula su profundidad, sin alterar la transformación que guardaste.

El coste crece con Columns × Rows y el número de repisas. Snow Segments tiene
coste cuadrático: duplicarlo cuadruplica aproximadamente el detalle de cada parche.
Terrain Conform muestrea las caras del terreno sólo al reconstruir. Los cambios de geometría
reconstruyen mallas y cuerpos: para muchas piezas, apaga Live Preview mientras
ajustas varios valores y reconstruye al final. Cambiar el color o la intensidad
de vetas tiene un coste muy inferior. La pieza no usa texturas externas ni
efectos volumétricos, y conserva Compatibility.

## Archivos y verificación

- `scenes/cliff/climbable_cliff.tscn`: composición de pared, repisas y zonas.
- `scenes/cliff/rock_platform.tscn`: repisa reutilizable.
- `scripts/cliff/cliff_piece.gd`: forma, proxy, materiales y autoría en vivo.
- `scripts/cliff/climb_zone.gd`: regiones de agarre editables.
- `shaders/cliff_rock.gdshader`: color y vetas de roca.
- `scripts/climbing.gd`: consulta permisos de la pieza antes de agarrarse.
- `scripts/snow/terrain_snow_playground.gd`: inicio opcional y reconocimiento
  de nieve de las plataformas para audio y huellas.

La revisión actual cargó en Godot 4.6, confirmó la lectura de 1922 triángulos del
terreno, el proxy irregular de 272 triángulos y el ascenso sobre la pared deformada.
Se comprobaron contactos nevados en bloques y apoyos (en los pequeños, cerca del
frente expuesto; su parte posterior queda incrustada). La apariencia, iluminación,
cámara y recorrido artístico completo se revisan jugando; no se han validado visualmente.
