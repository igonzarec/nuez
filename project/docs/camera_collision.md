# Cámara con distancia constante

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
