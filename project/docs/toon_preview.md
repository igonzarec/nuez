# Vista toon experimental

En **Ajustes**, desde el título o la pausa, activar **Sombreado toon ·
experimental**. Se aplica durante la ejecución, incluso en pausa. Desactivarlo
restaura el sombreado anterior. **Guardar y volver** guarda la elección junto
con las demás preferencias; una partida nueva y las escenas de trabajo con
TrailCamera utilizan esa misma preferencia. Está apagado por defecto.

**Suavidad del sombreado toon** va de 0 a 1: 0 ofrece un corte duro y 0.08 es
el punto de partida; subirlo suaviza la transición entre luz y sombra. El
deslizador se habilita al activar toon. Para comparar el sombreado con claridad,
se puede reducir Acabado pixelado a 1 y apagar Desenfoque de distancia en la
cámara. Estos dos efectos conservan sus controles independientes.

Controles de autoría en **CameraRig / OrbitCamera → Vista toon experimental**:
**Toon Enabled** y **Toon Softness**, con ayuda en el Inspector. Se actualizan
en vivo al ejecutarse, también desde Remote. No hay previsualización dentro
del editor sin ejecutar. Al arrancar, los ajustes guardados tienen prioridad
sobre estos valores. El componente no cambia el archivo de la escena.

Se utiliza el modelo `diffuse_toon` nativo de Godot 4.6 y se desactiva el
especular directo durante la vista previa. La suavidad utiliza la rugosidad
del modelo toon. Terrain3D mantiene su shader generado de relieve, mezcla de
texturas y sombras, adaptando sólo los modos de iluminación y la rugosidad.
También se adaptan los materiales estándar del personaje, objetos y árboles,
y los shaders espaciales iluminados sin un `light()` propio. Se conservan
texturas, colores, transparencia, animación y posición de las mallas.

Los materiales `unshaded`, cielo, nubes, interfaz y efectos de pantalla
conservan su apariencia. Los shaders con iluminación propia y los materiales
estándar con iluminación por vértices no se adaptan automáticamente. No se
añaden contornos: Separación de siluetas sigue siendo una opción independiente
de la cámara. Es una exploración de iluminación, no una reproducción completa
de la dirección artística de Wind Waker. El ambiente y la niebla pueden hacer
que los cortes se vean menos marcados; las sombras proyectadas mantienen la
configuración del sol y sus posibles artefactos.

Las modificaciones sólo viven en memoria y se registran para restaurarlas al
desactivar el efecto o salir de la escena. En Terrain3D 1.0.2 se evita cambiar
los overrides de los assets, porque sus setters intentan regenerar miniaturas
del editor durante el juego; los materiales estándar de esos overrides se
ajustan directamente y luego se restauran. Los cambios se aplican también a
mallas añadidas durante la ejecución. Activar o cambiar suavidad puede causar
una pausa breve por preparación de materiales y compilación de shaders; no se
añade un pase de pantalla completa para toon.

Verificación puntual: Godot 4.6 con OpenGL Compatibility, capturas con el modo
apagado/encendido en 3D_playground, shader override toon activo en Terrain3D y
restauración de su material original durante la pausa. Se revisó el menú con
scroll y la sintaxis de los scripts modificados, sin añadir ni ejecutar suites
de tests. El entorno restringido emitió avisos de caché de shaders y de recursos
de Terrain3D al salir; no hubo errores de compilación de los shaders toon.
