# Materiales por mesh y colores de árboles

Los STPine ahora tienen también LOD nativos preparados por asset y alcance
editable. Ver [preparación de LOD](tree_lod_preparation.md) para generar futuros
árboles y configurar sus distancias/sombras sin TreeColors.

## Árboles nuevos: configuración en cada mesh

En `grass_terrain.tscn`:

1. Seleccionar **STPine1**, STPine2, etc. en el dock inferior de Terrain3D.
2. En el Inspector del asset abrir **Colores del árbol**.
3. Cambiar **Foliage Color** (hojas) y **Bark Color** (tronco) directamente.
4. Guardar el recurso de materiales (y la escena si se cambió su asignación).

**TreeColors no es necesario para aplicar estos materiales.** TreeMeshAsset
escucha los cambios de su propio recurso, las importaciones y los ajustes del
asset. Actualiza sus superficies una sola vez en el siguiente ciclo del editor
o juego, agrupando las ediciones y sin un proceso periódico auxiliar.

Cada mesh recibe un recurso de materiales independiente. Cambiar STPine1 no
cambia STPine2. Sus instancias pintadas comparten el material de ese asset:
se actualizan juntas sin crear un material por árbol ni regenerar geometría.
La configuración se guarda dentro del asset Terrain3D, cuyo script es
`res://scripts/tree_mesh_asset.gd` (clase TreeMeshAsset).

Los colores directos editan el mismo recurso de materiales; sólo éste se guarda,
para evitar valores duplicados que se sobrescriban al cargar. Para texturas,
recorte alfa y selección de superficies, abrir **Materiales del árbol → Tree
Materials**. Allí también se pueden editar los mismos colores.

El preset anterior `stpine.tres` sirve sólo como punto de partida para migrar
STPine existentes y nuevos. Al configurarse un asset se duplica el preset;
editar el preset después ya no cambia las copias. La lista antigua del nodo se
conserva como dato de migración oculto para no perder ajustes guardados.

### Controles del mesh

Los valores tienen ayuda al posar el cursor en el Inspector. Todos se aplican
en el siguiente ciclo del editor/juego; no necesitan reconstruir ni reexportar el GLB.

| Grupo | Controles | Efecto |
| --- | --- | --- |
| Activación | Enabled | Activa el setup del mesh. Apagar restaura sus materiales importados. |
| Tronco | Bark Enabled / Color | Activa el cambio de tronco y elige su color/tinte. Blanco mantiene el color de la textura marrón. |
| Tronco | Bark Material Keywords / Surface Indices | Identifica superficies por fragmentos de nombre o índices desde 0. |
| Tronco | Bark Texture Mode / Texture | Conservar usa la importada; Reemplazar usa la elegida; Sin textura produce color liso. |
| Hojas | Foliage Enabled / Color | Activa el cambio de follaje y elige el tinte. La textura blanca se multiplica por él. |
| Hojas | Foliage Material Keywords / Surface Indices | Identifica superficies de follaje por nombre o índice. Si coincide con tronco, gana follaje. |
| Hojas | Foliage Texture Mode / Texture | Conserva, reemplaza o elimina la textura de hojas. Eliminar una máscara puede revelar los planos rectangulares. |
| Hojas | Foliage Transparency | Conserva el modo original, fuerza opaco o usa Alpha Scissor. STPine usa Alpha Scissor con una máscara válida. |
| Hojas | Alpha Scissor Threshold | De 0 a 1: subir recorta más borde; bajar conserva más. Requiere alfa en la textura. |
| Hojas | Foliage Double Sided | Dibuja ambos lados de los planos; apagar descarta las caras traseras. |
| Acabado | Override Finish / Roughness / Specular | Conserva el acabado importado o ajusta rugosidad (1 mate, 0 brillante) y reflejos. |

### Futuros árboles

Crear un recurso **TreeMeshAsset** y asignarle el GLB en **Scene File**. También
se puede añadir un GLB al dock y asignar `res://scripts/tree_mesh_asset.gd` en el
campo **Script** de su asset Terrain3D. El setup nace en el propio recurso:
no necesita nodos en la escena. El botón **Reaplicar materiales**, dentro del
mesh, permite forzar una actualización tras recargar scripts.

Configurar las texturas desde **Materiales del árbol → Tree Materials**. Un
setup nuevo conserva las texturas importadas por defecto. Los STPine actuales
ya tienen recursos independientes en `res://resources/trees/materials/`, con
máscara foliar y corteza válidas de `res://assets/textures/trees/stpine/`.
Hay dos assets llamados STPine5: cada ID conserva su archivo propio.

Las superficies se reconocen por fragmentos `trunk/bark/wood` y
`leaves/leaf/foliage/green`, sin distinguir mayúsculas. Para nombres diferentes,
ajustar Keywords o Surface Indices desde 0, comprobando todos los LOD.
Una única superficie con tronco y hojas necesita separarse en el modelo o una
máscara/shader para poder usar dos colores. No se sustituyen scripts ajenos.

TreeColors conserva una migración opcional para assets antiguos que aún no
sean TreeMeshAsset. Una vez guardada la asignación del script y los materiales,
la aplicación funciona sin esa migración ni el nodo.

Para compartir expresamente materiales entre dos assets, asignar el mismo
recurso Tree Materials. Para independizarlos de nuevo, usar **Make Unique**.
Las texturas se pueden compartir; los ajustes de color son propios de cada
recurso de materiales.

### Editor, compatibilidad y límites

Enabled dentro de los materiales del mesh activa sus cambios y restaura las
superficies importadas al apagar. Bark/Foliage Enabled permiten restaurar sólo
una parte. Cambiar la textura, transparencia, recorte o acabado emite la señal
Changed del recurso y actualiza el mesh sin tocar el nodo.

El recurso TreeMeshAsset se reconecta al cargar y al cambiar Scene File, y aplica
los materiales de todos sus LOD nativos. **Reaplicar materiales** devuelve un
Callable mediante getter, evitando el Nil de inicializadores durante recargas.
Los controles directos son accesos al mismo recurso: sólo éste se serializa,
sin guardar colores duplicados que se puedan sobrescribir al cargar.

El campo **Material Override** del asset debe quedar vacío para ver materiales
por superficie. Se respeta un override existente, sin eliminarlo. Las paletas
no sustituyen ShaderMaterial personalizados. Los nuevos meshes usan todos sus
LOD nativos; no se les añade el sistema lejano de los pinos anteriores.

Los cinco PineTree anteriores conservan su sistema de LOD y colores compartidos
en **TreeColors → Corteza - pinos anteriores / Follaje - pinos anteriores**.
Esos controles no cambian los STPine: éstos se editan en su propio asset. Se
conservan los valores personalizados, IDs, escalas, densidades y pinceladas.

Se modifican copias de materiales en memoria y las superficies de las mallas
generadas por Terrain3D, sin guardar cambios en los GLB. Todas las instancias que
compartan la misma malla reciben esos materiales: usar un controlador por
biblioteca de assets y evitar configuraciones distintas sobre una malla
compartida deliberadamente. Cambiar colores conserva las otras propiedades del
material; no hornea shaders ni repara UV incompatibles.

Comprobación puntual en Godot 4.6: se retiró TreeColors de una copia temporal de
la escena antes de añadirla al árbol. Los materiales cargaron automáticamente;
editar hojas actualizó sus 19 lotes pintados sin modificar otro asset ni tronco.
También se comprobó edición avanzada de corte alfa y rugosidad, restauración al
apagar, reutilización de materiales sin cambios y guardado/recarga del asset
sin nodo auxiliar. Las inspecciones no guardaron pinceladas ni añadieron suites
de pruebas. Falta valorar el aspecto con la iluminación del nivel.

Referencia: [materiales y recorte alfa en Godot 4.6](https://docs.godotengine.org/en/4.6/tutorials/3d/standard_material_3d.html).

## Pinos anteriores: colores y LOD

En `grass_terrain.tscn`, seleccionar **Terrain3D → TreeColors**.
Funciona en el editor y en el juego con Godot 4.6 Compatibility. El script
conserva la ruta `res://scripts/tree_surface_textures.gd` por compatibilidad.

Ahora el árbol original se convierte en una representación simplificada:
**no se disuelve para dejar el bosque vacío**. Los colores personalizados,
las posiciones, escalas, rotaciones y datos pintados existentes se conservan.

## Controles

| Grupo | Propiedad | Uso |
| --- | --- | --- |
| Activación | Enabled | Activa colores y LOD. Apagar restaura materiales y retira las copias lejanas. |
| Activación | Editor Preview | Previsualización sólo en el editor. |
| Activación | Terrain Path | Terreno de origen; cambiar requiere recargar escena. |
| Activación | Asset Prefix | Filtro de nombres, inicialmente PineTree_. |
| Corteza | Bark Enabled / Color | Color del tronco; apagar usa el color original. |
| Follaje | Foliage Enabled / Color | Color del follaje; apagar usa el color original. |
| Acabado | Roughness / Specular | Rugosidad y brillo de las partes con color personalizado. |
| LOD lejano | LOD Enabled | Activa la versión simplificada persistente. Apagar vuelve al original con sus cortes nativos, sin fade. |
| LOD lejano | Far Mesh Overrides | Malla lejana por nombre del asset; origen y escala deben coincidir con el original. |
| LOD lejano | Far Detail Ratio | Sólo sin override: elige una reducción entre los LODs importados; valores pequeños pueden deformar la silueta. |
| LOD lejano | Far Shadows | Sombras lejanas; apagarlas ahorra trabajo pero elimina esas sombras. |
| LOD lejano | Far Render Layers | Capas visibles para las cámaras, inicialmente capa 1. |
| Transición | Fade Enabled | Mezcla con tramado; apagar cambia directamente entre las dos versiones. |
| Transición | Fade Start / End | Distancia 3D al origen del árbol donde empieza y termina el cambio. Defaults 60 / 90 m. |
| Transición | Minimum Transition Width | Ancho mínimo de mezcla, inicialmente 20 m. Evita saltos si Start y End coinciden. |
| Transición | Cull Safety Margin | Reserva antes del corte del original por bloques, inicialmente 32 m. |

Los cambios se agrupan cada 0.3 s; la cámara se actualiza cada frame. Cambiar
apariencia o malla reconstruye materiales/lotes, sin escribir las regiones.
Ejemplos: cambiar Foliage Color a naranja; apagar Fade Enabled para comparar
el salto de LOD; apagar Far Shadows para comparar su coste. El LOD lejano
permanece visible hasta el recorte de cámara y oclusión/frustum normales.

## Rangos guardados y efectivos

Se conservan los Start/End personalizados de la escena. El final efectivo se
limita al corte del original menos Fade Margin del asset y Cull Safety Margin.
El inicio se adelanta para conservar el ancho solicitado, con un mínimo de
Minimum Transition Width. No se reescriben estos ajustes ni los rangos nativos.
Por ejemplo, con Start=End=200 m y corte nativo de 128 m, margen nativo 0 y
reserva de 32 m, la mezcla efectiva es 76–96 m. En un asset sin corte (0),
sería 180–200 m. Para mover la transición más lejos, ampliar primero el rango
original en el panel Meshes de Terrain3D. La representación lejana continúa
más allá de estos cortes. Aumentar Safety Margin si árboles grandes o bloques
extensos aún muestran cortes prematuros del original.

## Mallas simplificadas

Los cinco overrides están en `res://resources/trees/lods/`. Son copias generadas
fuera del juego con Blender: soldar posiciones coincidentes, separar partes
conectadas y simplificar cada una a aproximadamente 35 %, conservando al menos
40 triángulos por parte pequeña. Se mantienen las capas y puntas del follaje,
materiales Wood/Green y sombreado facetado. No se modifican los GLB originales.
Se eliminaron los LODs automáticos de estas copias para evitar nuevas
reducciones que eliminen puntas o abran huecos.

| Pino | Triángulos originales | Lejanos |
| --- | ---: | ---: |
| 1 | 1920 | 688 |
| 2 | 1692 | 604 |
| 3 | 2392 | 842 |
| 4 | 1704 | 604 |
| 5 | 1576 | 568 |

Reproducción desde la raíz del repositorio:

1. Ejecutar Blender en background con `--factory-startup --python tools/build_tree_lods.py`.
   Opciones después de `--`: `--ratio 0.35 --minimum-triangles 40`.
   Los GLB intermedios se escriben en `tmp/tree_lods/`.
2. Ejecutar Godot 4.6 con `--headless --path project --script ../tools/pack_tree_lods.gd`
   y un `--log-file` escribible si el entorno restringe la carpeta de usuario.
   Esto empaqueta las cinco mallas `.res` comprimidas, sin LODs internos.

Para un objeto nuevo, añadir su malla lejana en Far Mesh Overrides y adaptar
el filtro y la identificación de materiales según su estructura. El fallback
`tree_lod_mesh.gd` reutiliza los índices LOD de Godot, compactando vértices.
La selección automática puede perder detalles pequeños: revisar visualmente.

## Render y límites

Terrain3D sigue dibujando el original con sus rangos de siempre. Este componente
lee sus transformaciones por región/celda y genera lotes MultiMesh lejanos
transitorios, sin owner ni guardado. Comprueba cambios de pintura/undo cada
0.3 s y sólo reemplaza lotes cuyos datos cambien. No modifica colisión ni IDs.
Assets desactivados no generan copias. Los assets con varios LODs propios o
material override se omiten para evitar mezclarlos con esta ruta.

`tree_lod_transition.gdshader` calcula la distancia al origen de cada instancia
en vertex, incluyendo MultiMesh. Original y copia usan el mismo tramado con
máscaras complementarias: uno pierde cobertura mientras el otro la gana.
El árbol permanece presente; sólo las diferencias de silueta pueden descubrir
algo del fondo durante el cambio. El patrón es visible al ampliar la imagen.
Se usan colores lisos, sin UV, texturas, transparencia alfa ni nuevas colisiones.
La posición de la cámara principal también se usa al dibujar las sombras;
el alcance de sombras de la luz sigue aplicándose. Varios viewports con cámaras
independientes requieren una integración específica; se usa la cámara de Terrain3D.

Hay coste adicional: materiales shader, copias de transformaciones, otro juego
de lotes y revisión periódica de instancias en CPU. Ambos modelos se dibujan en
la franja de mezcla; el original sigue enviando geometría hasta su corte nativo.
Los lotes lejanos se recortan por frustum/oclusión y se ocultan antes del inicio
menos el margen de seguridad. Menos triángulos en el LOD lejano no garantiza
por sí solo más FPS. No se midió el tiempo de GPU del bosque completo.

Usar un componente por conjunto de assets, porque compartir assets comparte
las mallas generadas. Apagar Enabled restaura los materiales anteriores,
respetando reemplazos externos posteriores, y elimina los lotes lejanos.

Verificación puntual: Godot 4.6 Compatibility, capturas a 45/75/110/200 m con
una franja temporal 60–90 m, revisión de siluetas y persistencia lejana; carga
real del mapa con 64 regiones y 64 lotes lejanos; recuentos de geometría y
restauración Wood/Green al apagar. No se guardaron pinceladas ni se añadieron
o ejecutaron suites de tests. Falta valorar un recorrido completo con la luz
del nivel y medir rendimiento del bosque.
