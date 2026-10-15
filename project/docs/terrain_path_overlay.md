# Sendero por curva sobre Terrain3D

`res://scenes/terrain_path_experiment.tscn` es un experimento aislado para
probar un sendero importante sin pintar ni modificar los datos de
`grass_terrain`. Instancia el terreno existente sólo para leer su altura y
añade una cinta visual generada por `Path3D`.

## Uso

1. Abrir la escena y seleccionar **ImportantPath**.
   La primera apertura crea una curva inicial de cuatro puntos para que el
   prototipo sea visible; guardar la escena conserva cualquier ajuste posterior.
2. En el viewport, editar los puntos de su `Curve3D` hasta definir el recorrido.
3. Seleccionar **PathSurface** y ajustar sus controles en el Inspector. La
   vista se regenera al cambiar la curva o una propiedad; **Regenerar sendero**
   permite forzar la actualización.
4. Si el camino se integra después en un nivel, conservar `Terrain3D` como la
   superficie física y dejar `PathSurface` sin colisión. Así la ardilla pisa la
   misma geometría que ve, sin duplicar cuerpos físicos.

## Controles principales

| Control | Uso y coste |
| --- | --- |
| `Path Width` | Anchura sólida en metros. Para la cápsula actual de la ardilla (radio 0,42 m), 2,4–3,4 m deja lectura y margen cómodos. |
| `Edge Feather` | Franja de color entre el sendero y el césped. Da una transición orgánica sin depender de la resolución del control map. |
| `Sample Spacing` | Longitud de cada segmento. 0,4–0,7 m es suficiente para el prototipo; reducirlo aumenta linealmente los triángulos. |
| `Edge Irregularity` | Pequeña ondulación reproducible de ambos bordes. Usar 0,1–0,3 m; valores altos convierten el sendero en una silueta ruidosa. |
| `Terrain Offset` | Separación sobre Terrain3D para evitar parpadeo de profundidad. Mantener cerca de 0,02–0,04 m. |
| `Cast Path Shadows` | Apagado por defecto: la cinta es plana y no necesita sombras. Activarlo sólo si más adelante adquiere relieve real. |

## Rendimiento y límites

La ruta se consulta y genera al editarla, no cada frame. En juego queda como
una sola malla con un material; una ruta de 100 m a 0,5 m de `Sample Spacing`
tiene aproximadamente 1.200 triángulos (tres franjas, dos triángulos por
sección). Esto suele costar mucho menos que aumentar la resolución de todo el
Terrain3D o dispersar muchos decals individuales.

La malla no añade colisión. Antes de producción, si se decide que el sendero
tendrá puentes, bordes elevados o desniveles propios, habrá que decidir si
conserva la colisión visual temporal o se crea un proxy simple específico. No
se crea ese proxy automáticamente.
