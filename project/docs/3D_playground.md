# Recorrido del prototipo Terrain3D

Abrir `res://scenes/3D_playground.tscn` y pulsar F6. Esta
escena instancia `snow_terrain.tscn`, por lo que usa las regiones,
las dos montanas y los materiales que se editaron sin modificar esa escena.

Incluye la ardilla, su camara orbital, iluminacion, ambiente, musica/efectos,
pasos de nieve, huellas visuales, nevada local y el mismo StylizedSky con nubes
de terrain_snow_playground. WASD mueve, Shift corre, Espacio salta y permite
planear; clic derecho rota la camara; C la recentra y R devuelve al inicio.

StylizedSky toma el control de WorldEnvironment y Sunlight durante F6. Sus
controles estan en `StylizedSky` dentro de la escena: perfiles, luz, niebla y
nubes. Cloud Count, Altitude Range y Size Range requieren Regenerate Clouds;
color, proporciones, suavidad y viento se actualizan en vivo.

CameraRig conserva disponible Depth Outline, un postproceso que dibuja un borde
azul gris cuando una superficie cercana tapa otra lejana. Esta apagado en este
playground porque tambien contornea nubes y otros objetos opacos. En CameraRig,
Opacity regula lo marcado del borde, Width su grosor en pixeles y Threshold el
salto de profundidad minimo; los tres se actualizan en vivo.

Footprints crea marcas temporales sobre la colision del terreno: no deforma la
geometria ni cambia la fisica. En `Footprints`, Enabled, Footprint Limit,
Footprint Seconds, Footprint Size y Footprint Color quedan disponibles en el
Inspector; Limit es el coste maximo de nodos visuales activos.

En la raiz `3D_playground`, el grupo **Terreno** tiene
**Terrain Scene**: la escena de terreno que se prueba (por defecto
`snow_terrain.tscn`, la montana de nieve). Para probar otro mapa,
arrastra su escena ahi, por ejemplo `grass_terrain.tscn`. Debe
contener un nodo Terrain3D. Se instancia al ejecutar (F6), por lo que no se ve
en el editor de esta escena: edita el terreno abriendo su propia escena. Cambiar
la escena requiere volver a ejecutar. Ajusta Spawn XZ si el nuevo terreno tiene
otra forma o ubicacion de regiones.

El grupo Inicio del jugador contiene
Spawn XZ, Auto Spawn Fallback y Spawn Ray Height. **Auto Spawn Fallback** evita
que el jugador quede sin control cuando Spawn XZ cae fuera de las regiones del
terreno cargado: usa el centro de la primera region y avisa en consola con la
coordenada que deberias fijar en Spawn XZ. Cada mapa coloca sus regiones donde
quiere, asi que al cambiar Terrain Scene es normal que Spawn XZ ya no sirva.
Desactivalo si prefieres un error en vez de la correccion automatica. Si el
terreno no tiene ninguna region guardada, ninguna correccion es posible: abre su
escena, crea una region con Add Region y guarda. Cambia Spawn XZ para elegir una zona plana dentro
de las regiones. Colision Radius controla el radio de colision dinamica de
Terrain3D: 96 m es apropiado para esta prueba; aumentarlo permite recorrer mas
sin reconstruir colision, con mayor uso de memoria.

La prueba usa Terrain3D Dynamic / Game en la capa 1 para el jugador y 4 para
los obstaculos de la camara. Se genera colision alrededor de la camara activa;
no es aun un proxy de produccion. Antes de tratar esta montana como nivel final,
decidir si se conserva esa colision visual o se crea un proxy simplificado.
