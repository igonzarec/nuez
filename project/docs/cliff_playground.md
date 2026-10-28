# Laboratorio de cliffs

Abrir `res://scenes/cliff_playground.tscn` y ejecutar con F6. La escena conserva
los recursos originales y genera datos temporales propios al abrir o ejecutar.
No escribe regiones en disco ni modifica `grass_terrain.tscn`.

## Comparacion

- Izquierda: referencia sin relieve, centro X=24.
- Centro: A, Terrain3D real, centro X=64. El patron modifica exclusivamente Y
  en el heightmap, con muestras cada 0.25 m. No produce voladizos; los valores
  se limitan entre suelo y cima. La pared muy vertical ofrece pocas muestras.
- Derecha: B, malla continua, centro X=104. El mismo patron se aplica a lo largo
  de la normal original, con mas filas sobre la pared. Incluye suelo, lados,
  cima y rampa trasera; reemplaza un rectangulo del terreno mediante agujeros.
  Un faldon plano ligeramente elevado cubre el borde del agujero.

Las muestras usan normales suaves y ningun normal map. Por defecto se texturizan
por inclinacion con los assets del Terrain3D: soft-grass ID 0 y soft-cliff ID 1.
No se extraen cliffs arbitrarios de un mapa existente: la base es parametrica.

### Pintado automatico por inclinacion

En **Aspecto y colision**, **Slope Textures Enabled** activa el acabado; apagado
recupera el color uniforme para comparar volumen. **Rock Start Angle** (45 grados)
inicia la roca y **Rock Blend Angle** (10 grados) determina la transicion hasta
roca completa. Los dos responden a Live Preview o Regenerar comparacion y sus
tooltips explican costes. Los angulos se miden desde horizontal sobre la forma
final, no sobre el normal map ni la inclinacion minima que activa los pliegues.

En Terrain3D se calcula la pendiente desde las alturas generadas y se escribe
la mezcla 0/1 en el mapa de control temporal, conservando los agujeros. Se usa
la proyeccion existente para paredes. En B, un shader mezcla las mismas texturas
segun las normales de la malla, con proyeccion triplanar. Los bordes no seran
identicos: Terrain3D interpola pintura por vertices con su mezcla de alturas;
B calcula la mezcla por pixel. Ninguno modifica la geometria o colision.

B toma albedo, tinte y UV Scale de los dos assets al regenerar. Despues de editar
los assets, pulsar Regenerar comparacion para sincronizar B. No implementa los
controles de detiling de Terrain3D. No usa el canal normal ni desplazamiento por
textura. Los datos son generados: cualquier pintura manual sobre este laboratorio
se reemplaza en la siguiente regeneracion, sin afectar otros mapas.

Coste: la pintura agrega un recorrido de la cuadricula durante la generacion;
B realiza seis lecturas de albedo por pixel para las dos proyecciones triplanares.
Cambiar incluso un angulo reconstruye actualmente todo el laboratorio.

### Segunda fila: contorno cerrado irregular

En Z=84 hay tres mesetas de 360 grados, no semicirculos. Comparten el mismo
contorno con lobulos amplios: referencia a la izquierda, A al centro, B a la
derecha. **Referencia redondeada > Rounded Enabled** permite ocultar esta fila;
**Rounded Radius** controla el radio medio y **Outline Irregularity** su variacion
(0 produce un circulo). La semilla tambien cambia el contorno. El radio local
se limita a 15.5 m para conservar separacion; este limite puede aplanar lobulos
con radio/irregularidad muy altos.

A aplica el patron a las alturas. B usa anillos con mas muestras sobre la pared
y desplaza sus vertices segun la normal de la forma original. Usa ruido 3D
continuo alrededor de la formacion, compartido con A de esta fila. Los vertices
de la costura angular se comparten. Incluye cima y faldon sobre un agujero circular
en Terrain3D; usa colision de su propia malla. La referencia y A tienen colisiones
trianguladas desde las mismas alturas, como en la primera fila.

Los controles de pliegues y Live Preview afectan ambas filas; activarlas aumenta
el coste de regeneracion. La vista general puede mostrar simplificacion por LOD
de Terrain3D: acercarse con el personaje para comparar el detalle fino.

## Controles

Seleccionar el nodo raiz **CliffPlayground** en el Inspector. **Generacion > Live
Preview** esta activado por defecto: los cambios reconstruyen alturas, malla y
colisiones despues de **Preview Delay** segundos sin nuevos ajustes (0.4 s por
defecto). Arrastrar un slider agrupa los cambios. La reconstruccion es sincrona
y puede causar una pausa; apagar el check cancela las actualizaciones pendientes
y permite usar **Regenerar comparacion** manualmente. Volver a activarlo aplica
los cambios pendientes. No acumula deformaciones.

Funciona en el editor y durante el juego mediante el Inspector **Remote**. En
`3D_playground`, seleccionar Remote > 3D_playground > TerrainInstance para cambiar
la instancia ejecutada. Los cambios Remote no se guardan: para conservarlos,
editar la raiz de `cliff_playground.tscn` en Local y guardar la escena. Modificar
Local durante una partida no actualiza automaticamente la instancia Remote.

- **Forma base:** altura, ancho y carrera horizontal de la pendiente.
- **Pliegues compartidos:** tamano, profundidad negativa, saliente positivo,
  exponente de crestas, estiramiento vertical, angulo minimo, transicion angular
  y desvanecimiento en los bordes. La pendiente se mide antes de deformar.
- **Malla B:** paso de vertices. Reducirlo aumenta detalle, memoria y coste de
  generar la malla y su colision.
- **Aspecto y colision:** color y activacion de colision de blockout.
- **Generacion:** semilla reproducible, activacion del relieve y restauracion.
  Restaurar desactiva el relieve, pero conserva los valores. Para recuperarlo,
  activar Relief Enabled y regenerar. No acumula desplazamientos.

Ejemplo: Fold Size=4, Indentation=0.5 y Protrusion=1 crea pliegues amplios,
con mayor volumen exterior. Vertical Stretch=3 alarga los surcos. La dureza es
un exponente del patron; no es un control de bisel ni de sombreado plano.

En F6: **1/2/3** llevan al personaje a cada muestra recta; **4/5/6** a las muestras
cerradas (referencia/A/B); **V** alterna vista general
y camara de personaje; **R** reinicia en la muestra elegida. Se reutilizan player,
camera_rig y TrailAudio del proyecto. Los controles habituales de locomocion y
escalada permanecen activos. La vista general bloquea controles del personaje.
Cuando se instancia dentro de `3D_playground`, se usa su jugador y camara, sin
crear otro conjunto. Los mismos atajos funcionan tambien en `3D_playground`.

## Limites del blockout

### Costes en el Inspector

Cada propiedad y boton tiene ayuda `##` que distingue el coste de cambiarla
del coste de mantener la escena generada. Son tendencias de la implementacion,
no tiempos medidos ni garantias de FPS para una GPU concreta.

- Cualquier parametro observado, incluido el color, reconstruye actualmente
  todo el laboratorio. Live Preview agrupa cambios, pero la reconstruccion sigue
  siendo sincrona. Preview Delay reduce la frecuencia, no el coste individual.
- Mesh Step es el control principal de densidad B: reducirlo a la mitad implica
  aproximadamente cuatro veces mas triangulos, con mas memoria, renderizado y
  coste de colision. No cambia la resolucion de Terrain3D A.
- Altura agrega filas B. Activar la segunda fila agrega geometria y colisiones.
- Semilla, amplitudes y mascaras cambian la forma, no simplifican la topologia.
  Desactivar el relieve tampoco elimina vertices.
- Desactivar Collision Enabled ahorra fisica, pero deja al personaje sin las
  superficies fisicas del laboratorio. No reduce los triangulos visuales.

B usa su malla visual como colision triangular, marcada `climbable`; A y la
referencia usan triangulos construidos desde las mismas muestras del heightmap,
sin simplificacion. La colision nativa se desactiva en este laboratorio porque
las consultas detectaron paredes pero perdian la cima A en la region con agujeros.
Las consultas posteriores detectan paredes y cimas de las tres muestras.
No se ha creado un proxy simplificado. `3D_playground.tscn` tiene asignado este
laboratorio, Spawn XZ=(64,47) frente a A y Preserve Terrain Collision activado.
Este control esta en su raiz, grupo Colision de Terrain3D; conserva la colision
propia del laboratorio. Para otros terrenos se puede desactivar y volver a la
colision dinamica nativa. Requiere reiniciar. Se usa la camara del jugador para
actualizar el detalle de Terrain3D.
Con amplitudes grandes y pliegues pequenos pueden aparecer autointersecciones
o repisas dificiles de escalar: no hay un solucionador de plegado fisico.
La cubierta se desvanece en sus bordes; no modela roturas abiertas.

No esculpir ni colocar contenido manual dentro de GeneratedComparison o los
datos transitorios de Terrain3D: se reconstruyen. Los nodos propios fuera de
ese contenedor se conservan. Guardar la escena conserva los parametros, no una
copia definitiva de la malla. No mover/escalar la raiz: el laboratorio utiliza
coordenadas de mundo para coincidir con Terrain3D.

Verificacion: carga y captura con Godot 4.6/OpenGL Compatibility, revision
visual de las tres muestras y consultas puntuales de colision. No se crearon
ni ejecutaron suites de tests. Falta valorar manualmente tacto de escalada y
preferencia artistica. El motor muestra avisos de interpolacion deprecada y de
assets de Terrain3D sin archivo externo; no impiden generar la comparacion.
