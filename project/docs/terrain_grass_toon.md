# Iluminación toon del terreno de hierba

En `grass_terrain.tscn`, seleccionar **Terrain3D → Material**. El shader
`res://shaders/terrain_grass_toon.gdshader` está asignado como **Shader Override**
y **Shader Override Enabled** está activado. Se ve en el editor y durante F6.
Para volver al material generado por Terrain3D, desactivar **Shader Override
Enabled**; se conservan la pintura, las alturas y los ajustes originales.

Los controles están en los parámetros del material, grupo **Toon**. Todos se
actualizan en vivo y no requieren regenerar terreno:

- **Toon Enabled**: activa las bandas. Apagado utiliza iluminación Lambert
  continua sin especular; para recuperar el modelo original completo, desactivar
  el override.
- **Toon Bands**: de 2 a 6 niveles. Menos niveles producen áreas de color más
  amplias. El punto de partida es 3.
- **Toon Softness**: ancho de transición entre niveles, sin unidades. Un valor
  de 0 produce cortes prácticamente duros; subirlo suaviza las bandas. Inicio: 0.06.
- **Toon Normal Strength**: de 0 a 1, fuerza de las normales de las texturas.
  Inicio: 0 para evitar detalle de iluminación que compita con las bandas;
  1 recupera su fuerza pintada. No altera la geometría ni su colisión.

El shader conserva el desplazamiento y las normales geométricas de Terrain3D,
sus texturas pintadas, mezcla de materiales, fondo y sombras. La iluminación
ambiental y la niebla pueden reducir el contraste entre bandas. Flat Terrain
Normals sigue disponible para probar caras planas, sin cambiar su valor previo.
No reduce polígonos ni elimina ondulaciones de la geometría. El coste añadido
es un cálculo pequeño por luz y píxel, sin otro pase de pantalla completa.

Es una copia del shader generado con la configuración actual de Terrain3D
1.0.2. Al actualizar el plugin o activar funciones que necesiten otro shader,
conviene regenerar la base y reaplicar la sección Toon. La vista toon global
del menú respeta shaders con `light()` propio: este terreno se ajusta desde
su propio material.

Verificación: ejecución de `3D_playground` en Godot 4.6 con OpenGL
Compatibility y revisión de una captura, sin errores de compilación del shader.
El entorno emitió avisos de caché de shaders y recursos al salir. No se añadieron
ni ejecutaron suites de tests.
