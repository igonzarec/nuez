# Cámara con distancia constante

Recentrar con C/R2 sólo alinea el giro horizontal con el personaje. Conserva
la inclinación vertical elegida y su override manual durante Glide; no vuelve
a Pitch Degrees. En términos de Godot se ajusta yaw (rotation.y), sin resetear
pitch. El modo instantáneo o por tiempo sigue usando sus controles actuales.

La colisión conserva `Distance` y `Field Of View`: nunca acerca la cámara al
personaje para resolver un obstáculo. Sustituye el comportamiento anterior
que permitía reducir la distancia hasta 5,5 m y producía un zoom indeseado.

Si la dirección solicitada queda bloqueada, busca una elevación libre en ese
mismo rumbo. Sube gradualmente y continúa el giro cuando cabe. La inclinación
elegida por el jugador se conserva por separado para poder regresar a ella.
La búsqueda ya no salta hacia los lados ni detrás del personaje.

Para bajar exige más espacio libre y un tiempo continuo de despeje: esa
histéresis evita oscilar en el borde. Además conserva brevemente la elevación
ganada al salir de un obstáculo. Se comprueba el arco a distancia constante
en segmentos de hasta 2 grados y se barre una esfera entre muestras.
Si no hay recorrido libre, el giro espera. Una recuperación inmediata sólo
se permite si no había vista previa (inicio/respawn) o ésta quedó invalidada
por el movimiento del personaje. Puede desactivarse con Camera Collision Recovery.

En la escena, selecciona `CameraRig` en el árbol izquierdo. En Inspector,
`Colisión de cámara` contiene máscara, radio, margen, recuperación, paso angular
y elevación máxima de búsqueda. Los defaults compartidos se editan abriendo
`project/scenes/camera_rig.tscn` y seleccionando su nodo raíz.

Controles de elevación (todos con ayuda al dejar el cursor sobre la propiedad):

| Propiedad | Default | Función |
| --- | --- | --- |
| Camera Obstacle Lift | 25° | Elevación adicional máxima sobre la vista solicitada. |
| Camera Lift Speed | 35°/s | Velocidad de subida. |
| Camera Return Speed | 12°/s | Rapidez del regreso; un valor mayor vuelve antes a la inclinación elegida. |
| Camera Return Clearance | 0,4 m | Espacio extra necesario para bajar. |
| Camera Return Delay | 0,2 s | Tiempo despejado antes de bajar. |
| Camera Lift Hold Time | 0,3 s | Tiempo mínimo que conserva la elevación tras escapar. Súbelo en terreno muy irregular. |
| Camera Collision Angle Step | 3° | Resolución de búsqueda; menor valor cuesta más consultas. |
| Camera Collision Max Elevation | 85° | Techo de elevación automática, sin rebajar una vista manual ya más alta. |

Verificación de esta revisión: la escena de nieve arranca en Godot 4.6 sin
errores de scripts. La revisión visual corresponde al usuario: girar ante una
ladera, superar su borde, invertir el giro y comprobar que el regreso no oscile.

Camera Blocker es la capa física 3 (valor de máscara 4). La esfera protege la
posición y el arco de la cámara; un rayo entre el personaje y la cámara evita
falsas correcciones por terreno cercano a los pies. Sólo actúa contra cuerpos de
las capas elegidas.

Límite: si ningún ángulo comprobado permite colocar la cámara a la distancia
completa, conserva el último encuadre, incluso si queda obstruido. En un espacio
cerrado menor que el radio no se pueden garantizar simultáneamente distancia
constante y ausencia de obstáculos; ese lugar requerirá diseño de cámara o
visibilidad específico. No se aplica zoom como alternativa.

## Cámara libre durante planeo

En el nodo de cámara, **Vista durante planeo > Glide Free Camera Enabled**
está activado por defecto. Mantiene yaw/pitch manuales al planear, sin alinearse
con el personaje. Ignora el seguimiento frontal
de planeo aunque estuviera activado en Ajustes. El stick derecho o ratón permite
órbita vertical entre Minimum Pitch y Maximum Pitch; se conserva la protección
contra obstáculos. R2/C sigue recentrando sólo horizontalmente por petición.
El control se consulta en vivo; desactivarlo recupera la vista automática anterior.

**Glide Initial Pitch Enabled** es independiente de Free Camera y está activo
por defecto: al empezar cada planeo adopta **Glide Pitch Degrees** suavemente
con **Glide Camera Speed**, sólo una vez. Después no regresa a ese ángulo.
Mover verticalmente el stick/ratón cancela la transición y entrega control
inmediato; mover sólo horizontalmente no la cancela. Desactivarlo conserva la
perspectiva previa al iniciar el siguiente planeo. Los límites activos recortan
el ángulo inicial si está fuera del rango. Guardar CameraRig conserva el check.

### Límites manuales durante planeo

En el nodo **CameraRig**, Inspector > **Vista durante planeo**, los siguientes
controles se guardan con la escena y se consultan en vivo:

- **Glide Orbit Limits Enabled**: Sí inicialmente. Limita la órbita, sin
  volver a orientar automáticamente la cámara hacia la ardilla.
- **Glide Horizontal Range Degrees**: 120° a cada lado del ángulo al empezar
  el planeo. 180° permite vuelta completa; 0 bloquea el giro horizontal.
  El centro no sigue al personaje; R2/C lo redefine al recentrar manualmente.
- **Glide Minimum Pitch Degrees / Glide Maximum Pitch Degrees**: −80° / −15°.
  Ajustan cuánto puedes mirar desde arriba o hacia el horizonte. No cambian
  la cámara fuera del planeo. Valores negativos mantienen vista desde arriba.

Requieren **Glide Free Camera Enabled**. Desactivar Limits recupera la órbita
libre anterior. La corrección por obstáculos conserva prioridad y puede elevar
la vista más allá de los límites manuales para evitar atravesar terreno.
