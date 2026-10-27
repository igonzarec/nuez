# Colores y LOD continuo de los pinos

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
