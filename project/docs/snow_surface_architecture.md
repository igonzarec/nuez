# Dirección de superficies y nieve

**Estado: decisión de diseño; implementación pendiente.** Este documento
describe la meta para el terreno Terrain3D sin cambiar todavía las escenas ni
el sistema de nieve existente.

## Capas de responsabilidad

- **Aspecto del suelo:** el autor pinta texturas de Terrain3D. Para nieve puede
  usar `snow_powder_v2`; el sistema de comportamiento no pinta ni sustituye esa
  textura automáticamente. También se pueden probar las texturas clay de pasto
  y acantilado documentadas en `clay_terrain_textures.md`.
- **Comportamiento de nieve:** un pincel marca nieve ligera o profunda en datos
  independientes del material visual. La primera activa huellas. La segunda
  añade parámetros editables de profundidad, hundimiento visual y, si la prueba
  de rendimiento lo permite, un camino comprimido cerca del personaje.
- **Vista de autoría:** el editor muestra las zonas con colores y opacidad
  configurables, por ejemplo azul claro y azul intenso. Esta superposición se
  desactiva al ejecutar el juego; no requiere una segunda superficie visible.
- **Clima:** el autor coloca zonas de nevada. `Snowfall` responde a esas zonas
  con transición gradual; una zona de nieve en el suelo no activa por sí sola
  copos de nieve.
- **Otros detalles:** el pincel puede seleccionar pasto y hojas, pero el pasto
  debe reutilizar la apariencia del `GrassParticles` original y las hojas su
  lógica existente. Compartir herramienta no implica compartir renderizador.

## Límites y migración

`SnowTerrain` del playground genera su superficie sobre una malla importada;
no puede insertarse sin cambios como capa de Terrain3D. Se aprovecharán su
dirección visual y la lógica ligera de huellas, sin copiar su geometría. La
malla nueva de nieve en `SurfaceDetails` se retirará después de conservar o
migrar los datos de pintura existentes. En el primer paso se priorizan textura
de Terrain3D, huellas reutilizables y hundimiento visual del modelo; una máscara
dinámica de deformación quedará como opción posterior si el aspecto lo exige.

Para rendimiento, el comportamiento se consultará cerca del personaje y al
producirse pasos. El color de autoría no se dibujará en runtime. La colisión de
Terrain3D seguirá siendo la superficie física mientras el hundimiento sea
sólo visual; un surco con colisión real requeriría otra solución y evaluación.

Controles previstos en el Inspector: activación por tipo de zona, color y
opacidad de vista previa, umbrales de cobertura, profundidad, hundimiento
máximo, respuesta de movimiento, apariencia y vida de huellas, alcance y
presupuesto del camino local, e intensidad y transición de `Snowfall` por zona.
Cada propiedad nueva deberá llevar ayuda `##` y conservar los valores de las
escenas ya editadas.
