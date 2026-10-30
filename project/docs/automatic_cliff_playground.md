# Cliffs automáticos: construcción B y bake

Escena: `scenes/automatic_cliff_playground.tscn`. Nodo **CliffFolds**.
Autoría: `scripts/terrain/cliff_folds_generator.gd`.
Construcción: `scripts/terrain/cliff_contour_builder.gd`.
Material: `shaders/cliff_slope_surface.gdshader` (opaco), `shaders/cliff_slope_fade.gdshader`
(banda de fundido) y su código común `shaders/cliff_slope_surface.gdshaderinc`.
Resultado guardado: `terrain_data/automatic_cliff/cliffs_baked.scn`.

## Cómo funciona

La malla **sigue la escultura**: hombros redondeados, cimas de altura variable y terrazas.
Los pliegues solo aparecen en la zona de cliff (pendiente ≥ `Minimum Slope`), que con
`Terrain Auto Slope` = 1 coincide con la roca completa del Auto Shader de Terrain3D.

1. **Una franja por pared.** Para cada punto de la pared calcula dónde están su pie y su cima
   siguiendo la pendiente, y siembra la franja en la mitad de *esa* pared, sea cual sea su
   altura. Así cada escalón de una terraza recibe una franja continua alrededor de toda la pared.
   Las pasadas siguientes (`Wall Search Passes`) cubren lo que quede: uniones y restos.
2. **Columnas por línea de máxima pendiente.** Desde cada semilla la columna sube y baja por la
   escultura hasta que la pendiente baja de `Minimum Slope`: **cada columna encuentra su propia
   cima y pie**. Las filas se reparten a lo largo de la superficie con `Mesh Step`.
3. **Cinco tramos por columna:** fundido, collar, cliff, collar, fundido. Solo el tramo de cliff
   recibe pliegues; collares y fundidos copian la altura esculpida.
4. **Agujeros solo bajo los pliegues**, con al menos `Seam Overlap` de malla opaca alrededor
   (medido sobre la superficie y, en los extremos libres, también en planta). Ese margen tapa
   los triángulos grandes que Terrain3D retira alrededor de cada agujero en sus LOD lejanos.
5. **Unión invisible:** el collar coincide con el terreno, se adelanta un poco en profundidad
   (`Seam Depth Offset`) y la banda final se funde con un tramado (`Seam Fade Width`). El tramado
   se dibuja en el pase opaco: el desenfoque lejano de la cámara del jugador, que solo lee geometría
   opaca, la trata igual que al terreno (con transparencia aparecía un anillo nítido en runtime). Con
   `Match Terrain Shading`, la malla usa el mismo cálculo que el Auto Shader de Terrain3D
   (texturas, escala UV, proyección vertical en pendientes, mezcla por altura, iluminación) con
   la normal esculpida, por lo que el hombro y la unión no se distinguen del terreno.

Las alturas de Terrain3D nunca se modifican. La cantidad de pliegue y su dirección dependen solo
de la posición (distancia al pie y a la cima de la pared en ese punto, y normal esculpida
suavizada): dos franjas que se solapan pliegan exactamente igual y el empalme no se ve.

**Uniones de terrazas.** Donde una terraza desaparece contra otra pared, una franja de 20–60 m
queda al lado de una pared continua de 0–60 m. Cada franja se prolonga unos metros sobre la
pared vecina, recortando esas columnas a su propio rango de alturas, y se solapa con ella. Así
la unión tiene pliegues continuos en lugar de una banda lisa de Terrain3D. Solo los extremos
libres de verdad (una pared que se disuelve en la ladera) llevan collar y fundido laterales.
El Inspector avisa si más del 3 % de la pared detectada queda sin pliegues.

## Roca por ángulo (Terrain3D y malla)

El Auto Shader de Terrain3D mezcla roca con una fórmula lineal que ya pone roca en colinas de
20–30°. Con **Rock By Angle** (activo por defecto) la regla pasa a ser: hierba pura por debajo de
`Rock Angle Start`, roca completa desde `Rock Angle Full` y transición suave entre ambos (más la
irregularidad de la mezcla por altura de las texturas). Por defecto 58° → 66°, alineado con la
escalada del jugador (65° en superficies sin etiqueta): la roca anuncia lo trepable.

- Terrain3D: al regenerar u hornear, el generador toma el shader que Terrain3D genera, sustituye
  solo la línea del Auto Shader y lo guarda como **shader override** del material de esta escena
  (Ctrl+S para conservarlo). Afecta a todo el terreno de la escena; lo pintado a mano en Terrain3D
  conserva prioridad. Si ya hubiera un override propio, se modifica una copia de él.
- Malla de cliffs: usa la misma regla con la pendiente esculpida, así la unión sigue sin verse.
- `Rock Height Reduction` (0 por defecto) sustituye a `auto_height_reduction` de Terrain3D, que
  quita hierba con la altura y, por la mezcla por altura de las texturas, deja manchas de roca en
  cumbres suaves. Con 0 la roca depende solo del ángulo.
- Los ángulos se actualizan en vivo en el editor (Terrain3D y malla); hornea para llevarlos al juego.
- Comprobación: tras hornear y guardar, `automatic_cliff_playground.tscn` debe contener
  `shader_override` en el `Terrain3DMaterial`. Si CliffFolds aparece con valores `null`, el script
  no estaba cargado al guardar: recarga la escena, revisa los controles y vuelve a hornear.
- Apagar Rock By Angle y regenerar vuelve a `Terrain Auto Slope`; el override solo se quita si
  Far Spike Fix también está apagado.
- Tras actualizar el plugin Terrain3D, regenera para rehacer el override desde su shader nuevo.
- El override parte del código limpio que Terrain3D rellena al activar un override vacío, no del
  shader compilado: en el editor éste ya lleva el pincel y las vistas de depuración, y Terrain3D los
  inyecta otra vez en el override (error `Redefinition of '_editor_brush_texture'`, terreno sin
  texturas). Si cambias Auto Shader o Dual Scaling en Terrain3D, regenera para rehacer el override.
- En el juego, si la escena se guardó sin el override, CliffFolds lo instala al arrancar.

## Flujo de edición

1. Para volver a esculpir, pulsa **Restaurar terreno**: cierra los agujeros propios, elimina la
   cubierta de la vista y desconecta el bake del nodo; no borra el archivo.
2. Esculpe en Terrain3D.
3. Pulsa **Regenerar cliffs** para una vista previa.
4. Si aparece *"la cubierta cruza N agujeros no registrados"*: si son restos de pruebas, pulsa
   **Adoptar agujeros bajo la cubierta** (regenera registrándolos como propios); si los pintaste
   tú, separa esa zona.
5. **Hornear y guardar B** guarda mallas, materiales, colisiones y los datos de Terrain3D.
6. **Guarda la escena con Ctrl+S** para conservar la referencia al bake, los ajustes y la lista
   de agujeros propios.

Hornear, regenerar y restaurar marcan la escena como modificada (asterisco). Si aun así el juego
se ejecuta con una escena guardada sin la referencia al bake, el nodo carga el archivo de
`Bake Path` siempre que el terreno guardado tenga sus agujeros, y avisa en la salida.

Al cargar un bake, la lista de agujeros propios de la escena y la guardada en el bake se
**unen**: un agujero abierto por una regeneración posterior al último bake sigue siendo propio
y Restaurar lo cierra.

`Live Preview` agrupa cambios de parámetros mediante `Preview Delay`; no detecta pinceladas
de Terrain3D ni guarda en disco. En runtime **solo se instancia el PackedScene horneado**.

### Bake desactualizado

Si esculpes o regeneras **después** de hornear y guardas con Ctrl+S sin volver a hornear, el
terreno guardado y la malla horneada describen esculturas distintas. En el juego aparecen huecos
al vacío (agujeros nuevos sin malla encima) y malla "levantada" (la cubierta vieja sobre un
terreno que ya bajó). El nodo lo detecta al cargar:

- Agujeros propios abiertos que el bake no cubre.
- Alturas del terreno bajo la cubierta distintas de las guardadas en el bake (más de 2 cm;
  sólo en bakes hechos con esta versión).

En el editor muestra un aviso en el nodo y en la salida. En el juego, con **Rebuild Stale Bake**
(activo por defecto) reconstruye los cliffs al iniciar (unos segundos de pausa) y avisa; apagado,
sólo da un error. La solución definitiva es siempre **Hornear y guardar B** + **Ctrl+S** después
de la última pincelada.

## Controles: Inspector → CliffFolds

Todas las propiedades tienen ayuda `##`. Los cambios requieren **Regenerar** para la vista
previa y **Hornear + Ctrl+S** para conservarlos en juego.

| Grupo | Control | Efecto y coste |
|---|---|---|
| Generacion | Rebuild On Ready, Live Preview / Preview Delay | Vista previa en editor; no genera al iniciar el juego (salvo bake desactualizado, ver Rebuild Stale Bake). |
| | Rebuild Stale Bake | Si el terreno guardado no coincide con el bake, reconstruye al iniciar el juego en lugar de mostrar huecos. Coste: una regeneración al cargar. |
| | Regenerar / Hornear / Restaurar | Vista previa, guardado final y regreso a esculpir. |
| | Adoptar agujeros bajo la cubierta | Regenera registrando como propios los agujeros sin registrar bajo la malla. No lo uses sobre agujeros pintados que quieras conservar. |
| | Copiar ajustes del B de referencia | Copia pliegues, resolución y mezcla de `cliff_playground.tscn` solo al pulsarlo. |
| | Baked Scene / Bake Path | Recurso de runtime y destino de escritura. |
| Deteccion | Minimum Slope | Inicio de la zona de cliff; cada columna termina donde la escultura baja de este ángulo. |
| | Slope Transition | Entrada de los pliegues; un collar se corta si la escultura vuelve a superar Minimum Slope + este valor (otra pared). |
| | Normal Radius | Radio de medición de pendiente; mayor ignora irregularidades pequeñas. |
| Pliegues | Pattern Seed, Fold Size, Indentation, Protrusion, Fold Sharpness, Vertical Stretch | Forma del ruido de B; no agregan vértices. |
| Malla | Profile Search Distance | Distancia horizontal máxima de semilla a cima/pie. Si se alcanza, la zona de cliff termina ahí y se avisa. |
| | Wall Search Passes | Pasadas de semillas a distintas alturas (terrazas). CPU solo al regenerar. |
| | Strip Break Distance | Diferencia máxima entre cimas/pies de columnas vecinas antes de partir la franja. |
| | Surface Smoothing / Smoothing Limit | Suavizan contorno semilla y límites cima/pie; los puntos se mueven sobre la escultura. |
| | Edge Fade Meters | Metros verticales desde los bordes de la zona de cliff para desvanecer pliegues. |
| | Seam Overlap | Collar opaco sobre la escultura y margen de los agujeros. Recomendado ≥ 1 m. |
| | Seam Fade Width | Banda transparente final. 0 = borde duro (usa Skirt Depth). |
| | Seam Fade Far Distance | Desde esta distancia (opaca del todo al doble) la banda deja de tramarse y tapa las rayas oscuras de Terrain3D lejano. 0 = siempre tramada. En vivo. |
| | Seam Lift | Elevación anti-parpadeo; se suma a Seam Depth Offset. |
| | Mesh Step | Separación de columnas y filas. La mitad ≈ 4× geometría y colisión. |
| | Chunk Size / Skirt Depth | Bloques de malla/colisión; faldón solo con Seam Fade Width = 0. |
| Aspecto y colision | Grass/Cliff Texture Id | Texturas de Terrain3D usadas por la malla. |
| | Match Terrain Shading | Copia el Auto Shader de Terrain3D. Apagado: mezcla antigua por Rock Start/Blend Angle. |
| | Fold Triplanar | 0–1: roca triplanar en los pliegues (evita estiramientos) frente a la proyección exacta del terreno. |
| | Clean Rock Edge | 0–1: pliegues siempre de roca y, con Match Terrain Shading, transición hierba/roca estrecha dentro de la malla. Quita los dientes verdes del pie. La banda de fundido conserva la regla del terreno. En vivo. |
| | Seam Depth Offset | Adelanto en profundidad (fracción de la distancia) para ganar a Terrain3D donde coinciden. |
| | Rock Start / Blend Angle | Solo con Match Terrain Shading apagado. |
| | Terrain Auto Shader / Terrain Auto Slope | Material de Terrain3D; Auto Slope solo con Rock By Angle apagado. |
| | Rock By Angle / Rock Angle Start / Rock Angle Full / Rock Height Reduction | Roca por ángulo en Terrain3D (shader override) y en la malla, sin roca por altura por defecto. En vivo. |
| | Collision Enabled | Trimesh de la parte opaca, capas 1 y 3, grupo climbable. Blockout, no proxy simplificado. |
| Distancia (LOD) | Far Spike Fix / Far Spike Push / Far Spike Reach | Quita los picos de terreno sobre los cliffs lejanos (shader override de Terrain3D). Activar: regenerar; empuje y radio en vivo. |
| | Mesh LOD / Mesh LOD Merge Angle | Versiones simplificadas de cada chunk para la distancia. Regenerar/hornear. |
| | Mesh LOD Bias | Detalle a distancia por chunk: >1 más detalle, <1 simplifica antes. En vivo. |

## Distancia: picos lejanos y LOD

**Picos verdes sobre los cliffs lejanos.** Terrain3D dibuja el terreno en anillos cada vez más
gruesos (con `vertex_spacing` 0,25 y `mesh_size` 64: 0,25 m hasta ~16 m, luego 0,5, 1, 2, 4 m…).
Un vértice solo se oculta si cae justo sobre un agujero, así que de lejos sobreviven triángulos
que unen el pie con la meseta atravesando la pared; cerca del pie quedan delante de la malla y,
como debajo hay suelo plano, se pintan de hierba. **Far Spike Fix** añade al shader override de
Terrain3D un empuje en profundidad para los vértices lejanos que tienen cerca (`Far Spike Reach` ×
paso del anillo) un agujero o un desnivel de más de 60°: se alejan a lo largo del rayo de visión
(`Far Spike Push` × paso), sin moverse en pantalla, y la malla del cliff les gana. El LOD cercano
no se toca y las sombras direccionales tampoco (solo cámaras en perspectiva).

- Solo se mueve la profundidad rasterizada (`POSITION`); `VERTEX`, con el que se calculan luz y
  sombras, sigue en la superficie real. Una primera versión movía `VERTEX` y el terreno empujado
  quedaba "bajo tierra" para las sombras: puntos oscuros en colinas junto a los cliffs.
- `Far Spike Reach` debe alcanzar todos los vértices de los triángulos que cruzan la pared: con
  1,5 quedaban muñones verdes al pie de un pilar estrecho visto a ~150 m; con 2,5 (por defecto)
  desaparecen. `Far Spike Push` 3 (por defecto) limpia también el pie a ~250 m; 2 dejaba un pico.
- También cubre la transición del anillo más fino: con `mesh_size` 64 y `vertex_spacing` 0,25,
  entre ~25 y ~32 m los vértices se desplazan hacia la rejilla de 0,5 m y dejaban rombos verdes al
  pie de la pared vistos de cerca. El paso usado es `escala × (1 + morph)`.
- Una escena guardada con un override anterior recibe el Far Spike Fix al arrancar el juego; para
  verlo en el editor, regenera u hornea.

**Rayas oscuras al pie y la cima, de lejos.** Los triángulos gruesos de Terrain3D que bordean los
agujeros se sombrean con la normal de la pared (casi horizontal) y quedan oscuros. De cerca los
tapa el collar opaco; de lejos sobresalen bajo la banda de fundido y se veían a través de su
tramado como rayas punteadas. **Seam Fade Far Distance** (24 m) vuelve la banda opaca de forma
gradual hasta el doble de esa distancia.

**Dientes verdes al pie, de cerca.** Son textura de la malla, no terreno. Con Match Terrain Shading
apagado, la mezcla antigua pinta hierba en las caras de los pliegues más tendidas que Rock Start
Angle. Con Match Terrain Shading encendido, la escultura cruza los ángulos de roca a lo largo de
casi un metro y la mezcla por altura dibuja dientes. **Clean Rock Edge** fuerza roca en cuanto hay
pliegues y estrecha la transición dentro de la malla; la banda de fundido conserva la regla
exacta, así la unión con el terreno no cambia.

- Límite: junto a un cliff lejano, el terreno empujado puede dejar ver algo que esté justo detrás
  o enterrado en él. Los personajes y objetos no se mueven.
- Comparte override con Rock By Angle; si ambos se apagan, el override se quita al regenerar.

**LOD de malla.** Con **Mesh LOD**, cada chunk guarda versiones simplificadas (ImporterMesh,
`generate_lods`) y Godot elige una según su tamaño en pantalla; funciona en Compatibility. La
colisión sigue usando la malla completa. **Mesh LOD Bias** ajusta cada chunk y el umbral global
está en *Project Settings → Rendering → Mesh LOD → LOD Change → Threshold Pixels* (por defecto 1).

- Prueba local (vista a ~140 m): 425 000 → 301 000 primitivas dibujadas en total (terreno
  incluido) sin diferencia visible; regenerar tarda ~5 % más.
- Forzando el LOD más bajo cerca de la pared las caras se ven planas y asoma algo de hierba en la
  franja de la cima (la malla simplificada baja del terreno). No apareció ninguna grieta entre chunks.
  Si bajas mucho el sesgo y ves hierba sobre la roca, súbelo.
- Los mipmaps son el equivalente para texturas; la malla ya los usa.

`Reconstruct Surface`, `Max Subdivisions`, `Edge Fade Cells` y `Visibility Range` solo se
conservan para migrar escenas.

## Límites

- La copia del Auto Shader asume texturas automáticas: lo pintado a mano en Terrain3D, el
  color map, la variación macro, el detiling y los normal maps no se transfieren a la malla.
- Sí se copian, **en vivo en el editor y al cargar el juego** (sin rehornear): de los Texture
  Assets de Terrain3D usados (Grass/Cliff Texture Id) los archivos albedo, **Albedo Color** y
  **UV Scale**; del material, Blend Sharpness, Projection y Auto Height Reduction. El editor los
  revisa cuatro veces por segundo.
- En una unión, la amplitud de los pliegues puede cambiar bruscamente en la franja de 2 m
  (`Edge Fade Meters`) junto a la altura de la terraza que desaparece.
- En LOD muy lejanos (triángulos de Terrain3D mayores que `Seam Overlap`) aún pueden verse
  rendijas pequeñas; súbelo si aparecen. Con Far Spike Fix, a más de ~200 m puede asomar una
  astilla de terreno en el contorno de un pilar contra el cielo: ahí no hay malla detrás que gane
  en profundidad.
- Pliegues muy grandes pueden autointersectar la malla. Cuevas y voladizos no se admiten.
- Los agujeros pintados a mano bajo la cubierta cancelan la generación salvo que los adoptes.

## Comprobación local

Godot 4.6 Compatibility, meseta original + acantilado de tres niveles (0–60 m), ajustes
existentes (paso 0,5 m): **9 franjas, ~126 000 vértices, 67 chunks, ~3,8 s** de generación;
las uniones de terrazas quedan cubiertas (menos del 3 % de la pared sin pliegues). Capturas antes/después:
el borde de la meseta pasa de sierra con motas de roca a un borde continuo, y los hombros
del acantilado nuevo siguen la escultura. Restaurar cerró todos los agujeros, incluidos 416
restos de pruebas adoptados. No es una medición de FPS; falta hornear, revisar en editor y
el recorrido/escalada con el jugador.

Para usarlo desde `3D_playground.tscn`, conserva esta Terrain Scene y **Preserve Terrain
Collision** activado. La colisión Terrain3D de esta escena sigue en Full / Game.
