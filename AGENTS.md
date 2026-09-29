# Instrucciones del proyecto

## Visibilidad de objetos por estado

Cuando un objeto importado desde Blender deba desaparecer o aparecer según un
estado del juego, controla su propiedad `visible` desde código de Godot. Sigue
el patrón de las membranas de planeo en `project/scripts/squirrel_rig.gd`.

No uses una Shape Key con valor `0` como sustituto de visibilidad: una Shape
Key deforma la malla, pero no la oculta. Tampoco dependas de ocultar el objeto
desde el Outliner de Blender para resolver una condición de juego.
