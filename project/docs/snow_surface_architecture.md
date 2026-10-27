# Dirección de superficies y nieve

**Estado: primera implementación en Terrain3D.** El aspecto se pinta en
Terrain3D; `SurfaceDetails` guarda detalle y comportamiento.

## Capas de responsabilidad

- **Aspecto del suelo:** el autor pinta texturas de Terrain3D. Para nieve puede
  usar `snow_powder_v2`; el sistema de comportamiento no pinta ni sustituye esa
  textura automáticamente. También se pueden probar las texturas clay de pasto
  y acantilado documentadas en `clay_terrain_textures.md`.
- **Comportamiento de nieve:** el pincel marca nieve ligera o profunda en datos
  separados. Ambas activan huellas ligeras; la segunda aumenta el hundimiento
  visual y puede reducir la velocidad del personaje. No genera malla de nieve.
- **Vista de autoría:** el editor muestra las zonas con colores y opacidad
  configurables, por ejemplo azul claro y azul intenso. Se muestran todas las
  zonas pintadas sin depender de la distancia a la cámara ni del cursor. Esta
  superposición se desactiva al ejecutar el juego.
- **Clima:** el autor puede colocar `SnowClimateZone` bajo `SnowClimateZones`.
  `Snowfall` responde con transición gradual si se activa `Climate Zones Enabled`.
  Pintar nieve en el suelo no activa copos por sí solo.
- **Otros detalles:** el pasto pintado usa `GrassParticles` original mediante
  una máscara cercana del canal Pasto. Hojas y Tierra conservan su dispersión.

## Límites y migración

`SnowTerrain` del playground genera su superficie sobre una malla importada;
no se insertó como capa de Terrain3D. Se adaptó su enfoque de huellas planas y
ligeras. La pintura anterior de nieve sigue en su canal; nieve profunda tiene
un recurso aparte. Una máscara dinámica para un surco continuo queda como
opción posterior si la prueba visual y de rendimiento lo justifica.

Para rendimiento, el comportamiento se consultará cerca del personaje y al
producirse pasos. El color de autoría no se dibujará en runtime. La colisión de
Terrain3D seguirá siendo la superficie física mientras el hundimiento sea
sólo visual; un surco con colisión real requeriría otra solución y evaluación.

En `grass_terrain.tscn`, selecciona `Terrain3D > SurfaceDetails`, abre `Pincel
de detalles` y activa `Pintar superficies`. `Borrar detalle` o Ctrl restan
cobertura de la capa elegida. `Editar apariencia` abre el perfil. Los colores
de nieve se ajustan en `SurfaceDetails > Vista de autoría` y sólo se ven en el
editor. Para pasto, el nodo hermano `GrassParticles` tiene `Painted Only` y
sus ajustes de hojas, color, viento y presupuesto.

La textura del suelo se pinta aparte en Terrain3D. Antes de probar huellas o
hundimiento, pinta una textura de nieve debajo. Para nevada localizada, coloca
un `Node3D` con `snow_climate_zone.gd` bajo `SnowClimateZones`, ajusta tamaño e
intensidad, activa `Snowfall Enabled` en el playground y `Climate Zones Enabled`
en `Snowfall`.
