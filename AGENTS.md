# Instrucciones del proyecto

## Versión de Godot

El proyecto usa **Godot 4.6**. Al escribir código, configurar importaciones o
dar instrucciones del editor, usar las APIs y la interfaz compatibles con esa
versión.

## Diario del proyecto

El diario técnico vive en `project/docs/project_journal.md`. Al completar una
feature o un aprendizaje relevante, preguntar al usuario si quiere añadir una
entrada. Las entradas deben ser breves, amenas y técnicas: registrar qué cambió,
la decisión tomada y cualquier aprendizaje o límite útil, sin repetir manuales
ni describir cada cambio menor.

El diario debe poder leerse como una bitácora del proyecto y, a la vez, enseñar
la decisión técnica: explicar el cambio, su motivo y un límite o aprendizaje
útil con lenguaje claro. No sustituye la documentación de uso de cada sistema.

## Controles y documentación en el Inspector

Los sistemas y componentes nuevos o modificados deben ofrecer controles de
autoría completos y manipulables en el Inspector de Godot: exponer los valores
que el usuario necesita ajustar para diseño, apariencia y comportamiento, con
nombres claros, grupos y rangos apropiados. Incluir activación/desactivación
cuando corresponda. Evitar constantes ocultas que obliguen a editar código
para ajustes habituales de diseño.

Documentar cada propiedad exportada con comentarios `##` visibles como ayuda:
qué cambia, unidades, efecto de aumentar o reducir el valor, dependencias y
coste de rendimiento cuando sea relevante. Indicar si se actualiza en vivo o
requiere regeneración, y ofrecer Live Preview para geometría procedural cuando
sea práctico, agrupando cambios costosos. Documentar también la ubicación de
los controles y ejemplos de uso en `project/docs/`.

Conservar los valores personalizados y las colocaciones manuales del usuario
al modificar código o regenerar contenido. Los cambios de defaults deben ser
explícitos y no sobrescribir ajustes existentes sin autorización.

## Colisión de terreno

Durante el blockout, la malla visual puede servir como colisión para probar
escala, rutas y movimiento. Antes de tratar un terreno como producción, preguntar
al usuario si desea crear un proxy de colisión más simple o conservar la colisión
visual actual. No crear ese proxy sin esa decisión explícita.

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
