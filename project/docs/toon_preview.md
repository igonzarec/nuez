# Laboratorio de apariencia: toon y acabado mate

En **CameraRig / OrbitCamera → Laboratorio de apariencia** están los perfiles
de autoría. También se pueden comparar durante el juego desde **Ajustes →
Laboratorio de apariencia**, en el título o en pausa. Los controles muestran
su valor numérico. Guardar y volver conserva las preferencias, compartidas con F6.

## Prioridad y controles

- **Toon Enabled / Usar toon general** es el check de override general.
  Activado usa **Toon General** para mundo, Terrain3D, ardillas y detalles de
  superficie, incluso si sus controles locales estaban apagados.
- Apagado recupera **Toon World**, **Toon Terrain** y **Toon Character**,
  cada uno con su check **Enabled / Activar toon particular**. Los valores
  locales se conservan mientras el general está activo.
- Un perfil local apagado conserva el material original. En terreno esto
  incluye el shader toon propio de `grass_terrain.tscn`: apagar el perfil de
  cámara no apaga el toon que ya pertenece a ese material.
- Los detalles de superficie recuperan su selección Normal / Toon / Seguir
  ajustes al apagar el general. Seguir ajustes utiliza entonces Toon World.

Cada perfil es un recurso **TrailToonLook**, reutilizable entre escenas:

| Control | Efecto |
| --- | --- |
| Bands | De 2 a 6 niveles de luz directa. Menos niveles, masas mayores. |
| Softness | De 0 a 1: corte duro a transición suave, relativo al espacio entre bandas. |
| Light Offset | De -1 a 1. Positivo amplía las zonas claras; negativo las oscuras. |
| Contrast | De 0.1 a 3. 1 neutro; más valor separa los niveles de iluminación. |
| Normal Strength | De 0 a 1. Reduce el relieve de las texturas; conserva geometría y colisión. |

El Enabled dentro de Toon General se ignora: el check de la cámara controla
ese override. Los perfiles de cada cámara son independientes al ejecutar.
Se conservó la suavidad 1.0 que tenía la escena de cámara, migrada al recurso
general. Las preferencias anteriores de toon siguen siendo compatibles.
Los nuevos ajustes guardados tienen prioridad sobre el Inspector; si nunca
se guardaron, se utiliza la autoría del recurso. No se escriben escenas ni
materiales originales desde los controles del juego.

## Acabado mate del personaje

En **Personaje · acabado mate**, activar **Character Matte Enabled / Probar
acabado mate**. Afecta a las ardillas del jugador y NPC que usan SquirrelRig.
Funciona independientemente del check toon: con toon apagado mantiene el
material PBR original y sustituye rugosidad, especular y metalicidad.

- **Roughness**: 1 mate, 0 pulido. El modo mate ignora el mapa de rugosidad.
- **Specular**: 0 sin reflejo especular, valores mayores añaden brillo.
- **Metallic**: 0 dieléctrico, 1 metálico; el modo mate ignora el mapa metálico.

Desactivarlo recupera los valores y mapas originales. Con toon activo se
elimina el especular directo, así que ese control no añade brillos al toon.
No cambia colores, visibilidad, animaciones, cámara ni orientación del actor.

Ejemplo: desactivar el general, activar Toon Character con Bands 2 y Softness
0.08; activar Toon Terrain con Bands 3 y Normal Strength 0.15. Para comparar
un acabado mate continuo, apagar Toon Character y activar acabado mate con
Roughness 1, Specular 0 y Metallic 0. Para unificar la prueba, encender el
general con Bands 3, Softness 0.08 y Contrast 1.2, y luego apagarlo para
recuperar la combinación anterior.

## Actualización, coste y límites

Los perfiles y el acabado mate se actualizan en ejecución, incluso en pausa
y desde Remote. No hay preview de cámara en el editor sin ejecutar. El shader
propio de grass_terrain sí se previsualiza en el editor desde su material.
Cambiar valores numéricos reutiliza materiales y shaders; activar modos o
incorporar materiales nuevos puede preparar variantes y compilar shaders.
Las mallas nuevas se adaptan al entrar sin recorrer de nuevo toda la escena.

La rampa añade operaciones por luz y píxel, sin un pase de pantalla completo.
No hay todavía una comparación de FPS o tiempos GPU. Los cambios viven en
memoria; apagar los modos o salir restaura los materiales y overrides.
El cielo, interfaz y materiales unshaded no cambian. Ambiente, niebla y
filtrado de sombras siguen siendo independientes y pueden suavizar el look.
La rampa cuantiza luz directa, no la suma final de todas las luces.

El adaptador multibanda conserva los canales comunes del material estándar:
albedo, UV1, normales, AO, emisión, colores de vértices y transparencia.
Los materiales con funciones especiales (ORM, triplanar, billboard, parallax,
detalle, transmisión, rim, clearcoat, deformación o desvanecimiento) conservan
el toon nativo de dos niveles para mantener esas funciones: siguen la suavidad,
pero no Bands, Light Offset, Contrast ni Normal Strength. Lo mismo aplica a
los overrides de material de assets pintados de Terrain3D 1.0.2, cuyos setters
intentan generar miniaturas durante el juego. Los shaders ajenos con light()
propio se respetan; los del terreno de hierba y detalles del proyecto sí están
integrados. Materiales con iluminación por vértices tampoco se adaptan.

Verificación puntual en Godot 4.6, OpenGL Compatibility: capturas de personaje
original/mate/toon local/general, prioridad y recuperación en pausa, reutilización
de materiales al variar bandas y restauración completa de overrides. También
se comprobó el terreno real y el menú. Sin añadir ni ejecutar suites de tests.
El entorno restringido emitió avisos de caché/certificados y de Terrain3D al salir;
no se observaron errores de compilación de los shaders en las comprobaciones finales.
