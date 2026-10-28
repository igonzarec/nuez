# Cliffs automáticos: construcción B y bake

Escena: `scenes/automatic_cliff_playground.tscn`. Nodo **CliffFolds**.
Autoría: `scripts/terrain/cliff_folds_generator.gd`.
Construcción: `scripts/terrain/cliff_contour_builder.gd`.
Resultado guardado: `terrain_data/automatic_cliff/cliffs_baked.scn`.

## Qué se implementó

La pared ahora se construye como una malla independiente de filas y columnas, siguiendo
el enfoque del **B cerrado** de `cliff_playground.tscn`. No subdivide ni conserva los
triángulos de Terrain3D. Para cada pared conectada:

1. Encuentra el contorno a media altura, cerrado o abierto.
2. Lo remuestrea por longitud con `Mesh Step` y suaviza el contorno dentro de un límite.
3. Busca cima y pie a ambos lados y construye perfiles rectos entre ambos, como la pared
   base de B. Distribuye filas según la altura real, también con `Mesh Step`.
4. Aplica el ruido 3D de B sobre la normal, con los mismos controles de profundidad,
   tamaño, nitidez y estiramiento. La máscara se desvanece desde la cima y el pie en
   metros verticales; en paredes abiertas también desde sus extremos.
5. Calcula normales suaves antes de separar chunks, agrega la unión con Terrain3D y
   construye la colisión de blockout.

Las alturas originales no se modifican. La malla reconstruida es una interpretación
regular de la pared: no conserva cada irregularidad de su perfil vertical.

**Mismo método no significa idéntica imagen.** La meseta esculpida mide unos 50 m,
frente a 20 m en el B del laboratorio. El ruido se muestrea en coordenadas de mundo,
por lo que una ubicación diferente cambia la distribución de pliegues. El B recto
original usa ruido 2D; este generador usa el 3D del B cerrado también en paredes abiertas.

Se conservaron los ajustes existentes del automático (Mesh Step 0,5 m, transición 2 m).
El botón **Copiar ajustes del B de referencia** copia los valores guardados en
`cliff_playground.tscn`, incluyendo Mesh Step 1 m y Edge Fade 4 m actualmente, y los
controles de pliegues/mezcla. No copia la forma de la montaña ni cambia sus alturas.
Después hay que regenerar/hornear. No se aplica ese preset silenciosamente.

## Flujo de edición

La escena incluye un bake listo para cargar. No hace falta regenerar para ejecutarla.

1. Para volver a esculpir, pulsa **Restaurar terreno**. Cierra los agujeros propios,
   elimina la cubierta de la vista y desconecta el bake del nodo; no borra el archivo.
2. Esculpe en Terrain3D.
3. Pulsa **Regenerar cliffs** para una vista previa. Para ajustar solo el relieve no
   hace falta restaurar el terreno.
4. Cuando te guste, pulsa **Hornear y guardar B**. Guarda mallas, materiales y colisiones
   en `Bake Path`, y los datos de Terrain3D con los agujeros correspondientes.
5. **Guarda la escena con Ctrl+S**, para conservar la referencia al bake y los ajustes.

`Live Preview` agrupa cambios de parámetros mediante `Preview Delay`; no detecta las
pinceladas de Terrain3D y no guarda el resultado en disco automáticamente.

En runtime **solo se instancia el PackedScene horneado**. No se calcula ruido, no se
reconstruye geometría y el generador no procesa frames. Si falta un bake, muestra un
error; no introduce una generación inesperada durante la carga.

Un bake puede estar desactualizado después de esculpir o cambiar parámetros. El Inspector
avisa si falta o si detecta una vista previa/ajustes distintos; las pinceladas no se
vigilan automáticamente. Hornear de nuevo sobrescribe el recurso indicado por Bake Path.
Cada generador con una escultura distinta debe tener su propia ruta de bake.

## Controles: Inspector → CliffFolds

Todas las propiedades de autoría incluyen ayuda `##` con efecto y coste. Los cambios
requieren **Regenerar** para previsualizar y **Hornear + Ctrl+S** para conservarlos en juego.

| Grupo | Control | Efecto y coste |
|---|---|---|
| Generacion | Rebuild On Ready | Solo genera en editor cuando no hay bake. Con bake, carga el recurso. Nunca genera al iniciar el juego. |
| | Live Preview / Preview Delay | Regeneración diferida al cambiar controles; coste de CPU de autoría. No cambia FPS del bake. |
| | Regenerar / Hornear / Restaurar | Vista previa, guardado final y regreso a esculpir. |
| | Copiar ajustes del B de referencia | Sobrescribe controles de pliegues, resolución y mezcla al pulsarlo; no se ejecuta automáticamente. |
| | Baked Scene / Bake Path | Recurso de runtime y destino de escritura. Guarda la escena tras hornear. |
| Deteccion | Minimum Slope / Slope Transition | Umbral angular y transición del relieve. Bajar el umbral puede agregar paredes/coste. |
| | Normal Radius | Radio en celdas para detectar pendientes. No controla la densidad de la malla B. |
| Pliegues | Pattern Seed | Distribución reproducible del ruido; mismo coste. |
| | Fold Size | Escala de las formas en metros; mayor produce pliegues más amplios. |
| | Indentation / Protrusion | Metros hacia dentro/fuera. No agregan geometría; amplitudes grandes pueden autointersectarla. |
| | Fold Sharpness / Vertical Stretch | Concentración y estiramiento vertical. No agregan vértices. |
| Malla | Profile Search Distance | Alcance desde el contorno medio para encontrar cima y pie. Aumentarlo agrega trabajo de búsqueda, no coste runtime. |
| | Surface Smoothing | Pasadas sobre contorno y líneas de cima/pie. Más pasadas redondean dientes del muestreo; coste CPU de autoría. |
| | Smoothing Limit | Desviación máxima horizontal del suavizado, en metros. 0 conserva el contorno muestreado. |
| | Edge Fade Meters | Metros desde cima/pie y extremos abiertos en los que desaparecen los pliegues. Igual criterio de máscara que B. |
| | Mesh Step | Separación objetivo alrededor Y a lo alto. Reducir a la mitad produce aproximadamente cuatro veces más geometría, memoria y colisión. |
| | Seam Overlap / Seam Lift | Banda de unión y elevación contra superficies coincidentes. Más ancho agrega geometría; demasiada elevación crea escalón. |
| | Chunk Size | Tamaño de bloques. Menor aumenta nodos/draw calls. Actualmente se regenera todo al editar; no hay actualización incremental. |
| | Skirt Depth | Faldón exterior visual, sin colisión. No garantiza unión ante cualquier LOD lejano. |
| Aspecto y colision | Grass/Cliff Texture Id | Texturas, tintes y escalas de Terrain3D; sin normal maps en la cubierta. |
| | Rock Start Angle / Rock Blend Angle | Ángulo y suavidad de hierba/roca en la malla. |
| | Terrain Auto Shader / Terrain Auto Slope | Material nativo; Auto Slope no es un ángulo y puede diferir de la mezcla en la cubierta. |
| | Collision Enabled | Guarda trimesh con las caras visuales, capas 1 y 3 y grupo climbable persistente. Es blockout, no proxy simplificado. |

`Reconstruct Surface`, `Max Subdivisions`, `Edge Fade Cells` y `Visibility Range`
solo se conservan internamente para migrar escenas; ya no controlan el algoritmo.
Los chunks no desaparecen por distancia, pues dejarían expuestos los agujeros.

## Formas admitidas y límites

Admite contornos cerrados de mesetas y paredes abiertas, con cima/pie aproximadamente
al mismo nivel a lo largo de cada pared conectada y un perfil que pueda aproximarse
por una franja continua. No está pensado para reconstruir cualquier montaña.

Detecta y rechaza contornos ambiguos, bifurcados, múltiples contornos desconectados
en una misma pared, búsquedas sin cima/pie, bandas que salen del terreno, contornos
que se cruzan y cubiertas que no cubren todos los agujeros detectados. Conserva la
cubierta anterior y no abre nuevos agujeros si esa validación falla.

Terrazas unidas, cimas de altura muy variable, crestas estrechas, cuevas y voladizos
requieren separar la zona o una malla de autoría. Grandes desplazamientos de pliegue
todavía pueden autointersectar la geometría; la validación del contorno no garantiza
que cualquier amplitud sea válida. Los collarines necesitan espacio libre suficiente.

Los agujeros manuales bajo la cubierta provocan un aviso y cancelan la generación;
no se rellenan silenciosamente. Restaurar solo cierra agujeros registrados como propios.
Pintar un agujero manual encima de uno ya propio no es distinguible: restaura primero.
La pintura manual de texturas no se transfiere a la cubierta; conserva prioridad en
el Terrain3D visible. La cubierta usa soft-grass/soft-cliff por pendiente.

## Comprobación local

Godot 4.6 Compatibility, meseta esculpida de ~50 m, ajustes conservados (paso 0,5 m):
unos **24 500 vértices / 9 chunks**, aproximadamente **0,5–0,7 s** de generación y
**1 MB** de bake comprimido. La versión anterior tenía unos 113 000 vértices y tardaba
4,4 s. No es una medición de FPS ni garantiza igual coste en otro equipo/terreno.

Una ejecución nueva cargó el bake con 9 cuerpos climbable, sin ejecutar el generador
ni procesarlo por frame. Los rayos detectaron cima, pared y suelo. Se comprobó una
pared abierta de 20 m (3 200 vértices a paso 0,5 m), y las alturas antes/después del
bake coincidieron. Queda la valoración artística y el recorrido/escalada con el jugador.

Para usarlo desde `3D_playground.tscn`, conserva esta Terrain Scene y **Preserve Terrain
Collision** activado. La colisión Terrain3D de esta escena sigue en Full / Game.
