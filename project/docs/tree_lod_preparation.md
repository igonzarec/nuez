# LOD nativos por asset de árbol

Los STPine de `grass_terrain.tscn` usan tres niveles explícitos gestionados por
Terrain3D 1.0.2 en Godot 4.6 Compatibility. No requieren TreeColors para cambiar
de nivel, aplicar materiales o permanecer visibles a distancia. Los cinco
PineTree anteriores conservan su sistema propio, sin modificar sus ajustes.

## Usar los árboles actuales

Seleccionar el mesh en el dock de Terrain3D. El Inspector de TreeMeshAsset reúne
los colores existentes, **LOD - Preparación en editor** y **LOD - Distancias y
sombras**. Los assets están guardados individualmente en
`res://resources/trees/assets/`; guardar sus cambios conserva los ajustes.

| Representación | Rango inicial | Sombras |
| --- | --- | --- |
| LOD0, detalle cercano | 0–80 m | Sí |
| LOD1, intermedio | 80–220 m | Sí |
| LOD2, paisaje | 220–900 m | No |

Son valores iniciales editables, no distancias óptimas universales. Terrain3D
aplica los rangos a celdas de 32 m y puede añadir pequeños márgenes internos.
La cámara, frustum/oclusión y las sombras de la luz también limitan el resultado.
No se amplió el plano lejano de la cámara ni la distancia de sombras del nivel.
Los cambios de nivel son los nativos por celda, sin prometer fundido suave:
el fade nativo de esta versión tiene limitaciones y no se usa aquí.

**Tree Lod Enabled** apaga la simplificación y conserva LOD0 hasta la distancia
final: sirve para comparar aspecto, pero dibuja más triángulos. **Lod Near / Mid /
Far Distance** cambian los rangos en vivo, sin regenerar. Si se cruzan los
valores, el rango efectivo se ordena manteniendo al menos 1 m entre niveles;
no se reescriben los valores del diseñador. **Lod Last Shadow Level** permite
-1 (sin sombras), 0, 1 o 2. Se conserva Cast Shadows del asset como límite global.
Los rangos nativos inferiores aparecen de sólo lectura cuando controla la
escena preparada: se editan desde el grupo superior para tener una única fuente.

## Preparar un árbol nuevo

1. Crear un recurso **TreeMeshAsset**, o añadir el GLB al dock y asignar
   `res://scripts/tree_mesh_asset.gd` al campo Script de su asset.
2. Asignar el original en **Scene File** o **Lod Source Model**. Mantener la malla
   estática, con UV, origen y escala correctos. Tronco y hojas deben ser
   superficies de una misma malla; no dos objetos que Terrain3D confunda con LOD.
3. Configurar los materiales y sus nombres desde Tree Materials. Las palabras
   e índices de Foliage identifican también qué superficies deben proteger sus
   piezas al simplificar. No se necesita un prefijo STPine ni editar código.
4. Ajustar ratios, protección de hojas y, si se dispone de ellos, las mallas
   manuales intermedia/lejana. Pulsar **Preparar / regenerar LOD**.
5. Revisar **Lod Preparation Report** y la silueta a varias distancias. Ajustar
   rangos/sombras y guardar el asset; si pertenece a una escena como subrecurso,
   guardar también esa escena. Se conservan ID, densidad, altura y pinceladas.

La herramienta guarda `.res` comprimidos y una escena con hermanos terminados
en `LOD0`, `LOD1`, `LOD2` dentro de **Lod Output Directory**. Asigna esa escena al
asset y conserva el original en **Lod Source Model**. Los nombres incluyen el ID,
por lo que los dos STPine5 mantienen preparaciones independientes.

No se simplifica durante el juego ni se añaden copias lejanas paralelas desde un
nodo. El botón rechaza la preparación fuera del editor: la reconstrucción activa
miniaturas del addon que necesitan su contexto de edición. Cada material del
árbol se aplica a los tres niveles por el mismo asset.
Este flujo también admite materiales nativos en el modelo de origen cuando se
migre la configuración de color; no depende del shader de colores lisos antiguo.

## Controles de preparación

| Propiedad | Uso |
| --- | --- |
| Lod Source Model | Original para regenerar; puede ser una escena que contenga una malla estática. Nunca seleccionar la escena derivada como origen. |
| Lod Output Directory | Carpeta de salida dentro de res://. Sólo cambiarla no genera ni mueve archivos. |
| Lod Mid / Far Ratio | Objetivos de triángulos, inicialmente 0.5 / 0.18. Se elige geometría disponible: el resultado puede conservar más para proteger detalle. |
| Lod Min Surface Triangles | Mínimo por superficie al elegir LOD globales, 32 por defecto; las superficies pequeñas conservan el original. |
| Lod Preserve Leaf Parts | Conserva todas las piezas conectadas del follaje, evitando que desaparezcan ramas completas. Más trabajo sólo al preparar. |
| Lod Leaf UV Tolerance | Tolerancia UV para quitar vértices casi colineales del borde de cartas. Mayor simplifica más, pero puede perder curvatura; requiere regenerar. |
| Lod Mid / Far Override | Mallas manuales opcionales, con mismo origen, escala y nombres de material. Se copian respetando todos sus atributos, sin volver a simplificarlas. |
| Preparar / regenerar LOD | Ejecuta el trabajo costoso explícitamente. No cambia colores ni archivos originales. |
| Lod Preparation Report | Recuento real por nivel y advertencias; es de sólo lectura. |

Los controles geométricos requieren regenerar; distancias, sombras y colores
se actualizan en vivo. Regenerar reemplaza los archivos derivados del asset:
no editarlos manualmente. Los GLB, materiales de autor y datos del terreno no se
reescriben. Una reimportación del GLB no regenera estas copias automáticamente;
pulsar el botón después de cambiar geometría/UV/materiales del original.

## Por qué se protegen las piezas de follaje

En la revisión visual, usar directamente los índices LOD globales de Godot
eliminaba las ramas altas de STPine1–4. Mantener UV era necesario, pero no
suficiente para mantener la silueta.

La preparación identifica piezas conectadas por posición y simplifica cada una
por separado con ImporterMesh. Para cartas con una región UV completa y convexa
se puede usar su contorno triangulado, sin borrar la carta entera. Se comprueban
área UV y orientación; regiones solapadas, con huecos o incompatibles conservan
una reducción más conservadora. Esto aproxima la curvatura en el nivel lejano,
por lo que siempre debe revisarse el resultado. No es un generador de impostores.

Se conservan todos los atributos de vértice: UV, normales, tangentes y colores.
Los buffers retienen vértices no usados para evitar pérdidas de atributos;
la reducción está en los índices/triángulos dibujados, no es una promesa de
reducción proporcional de VRAM. Las mallas generadas no incluyen otra tabla de
LOD automático, evitando una segunda simplificación que vuelva a borrar hojas.

Una malla sin LOD importados puede no reducir sus superficies no foliares:
el informe lo indica. Asignar entonces mallas manuales. Rigs, blend shapes,
primitivas no triangulares y materiales cuyo shader necesita atributos especiales
requieren una preparación específica. No se hornean rigs ni shaders aquí.

## Resultado y comprobación

| Modelo | LOD0 | LOD1 | LOD2 |
| --- | ---: | ---: | ---: |
| STPine1 | 1500 | 944 | 278 |
| STPine2 | 1468 | 944 | 252 |
| STPine3 | 1580 | 1028 | 276 |
| STPine4 | 1384 | 870 | 246 |
| STPine5, cada asset | 476 | 238 | 102 |
| STPine6 | 460 | 190 | 94 |
| STPine7 | 208 | 104 | 48 |

Se cargó la escena real en Godot 4.6: tres niveles y lotes nativos por STPine,
rangos 80/220/900, sombras desactivadas sólo en el lejano y edición de distancias
en vivo. Se conservaron los perfiles de color, IDs, densidades y el sistema de
lotes lejanos antiguos. Se renderizaron comparativas de los STPine con follaje usando
Compatibility/OpenGL y se corrigió la pérdida de copa detectada en la primera
preparación. No se añadieron ni ejecutaron suites de pruebas.

Falta medir tiempo de GPU/CPU del bosque completo. El mayor alcance dibuja más
celdas; hojas superpuestas, materiales y sombras pueden dominar el coste aunque
baje el número de triángulos. Para horizontes más lejanos, valorar impostores
o agrupaciones HLOD en una iteración posterior.

Referencias: [LOD de Terrain3D 1.0.2](https://terrain3d.readthedocs.io/en/stable/docs/instancer.html#lod-support),
[ImporterMesh de Godot 4.6](https://docs.godotengine.org/en/4.6/classes/class_importermesh.html).
