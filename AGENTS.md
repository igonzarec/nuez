# Instrucciones del proyecto

## No agregar tests por defecto

No crear tests, archivos de pruebas ni ampliar suites existentes salvo que el
usuario lo solicite explícitamente. El proyecto está en iteración rápida:
priorizar la implementación y evitar consumir tokens en código de pruebas.
Para verificar cambios, preferir revisiones puntuales del código y comprobaciones
manuales o visuales proporcionales al cambio, sin añadir infraestructura de tests.
No ejecutar suites de tests salvo petición explícita del usuario.
No eliminar los tests existentes sin autorización.

## Visibilidad de objetos por estado

Cuando un objeto importado desde Blender deba desaparecer o aparecer según un
estado del juego, controla su propiedad `visible` desde código de Godot. Sigue
el patrón de las membranas de planeo en `project/scripts/squirrel_rig.gd`.

No uses una Shape Key con valor `0` como sustituto de visibilidad: una Shape
Key deforma la malla, pero no la oculta. Tampoco dependas de ocultar el objeto
desde el Outliner de Blender para resolver una condición de juego.
