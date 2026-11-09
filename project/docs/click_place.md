# Colocar con clic

Plugin del editor (`addons/click_place/`). Mueve los nodos 3D seleccionados al punto del terreno o de la malla donde hagas
clic. Se activa una vez en **Project → Project Settings → Plugins → Colocar con clic → Enable**.

## Cómo se usa

1. Selecciona uno o varios nodos 3D en el panel **Scene**.
2. En la barra superior de la vista 3D, pulsa **Colocar con clic**.
3. Haz clic izquierdo donde quieras el nodo. Puedes seguir haciendo clic; **Esc** o el mismo botón salen del modo.

Clic derecho, central y Alt siguen navegando. **Ctrl+Z** deshace cada colocación. Si seleccionas varios nodos, el primero
va al punto y los demás conservan su separación.

## Controles (barra de la vista 3D, con el modo activo)

| Control | Efecto |
|---|---|
| **Conservar altura** | Sólo cambia X y Z. Para un `WaterLake`, cuya Y es el nivel del agua. |
| **Mallas** | Encendido: también coloca sobre mallas visibles (acantilados, rocas, agua). Apagado: sólo sobre Terrain3D. |
| Campo en metros | Altura que se suma al punto de clic. Positivo = por encima. Sin efecto con Conservar altura. |

Los valores se recuerdan por proyecto.

## Límites

- Terrain3D no necesita colisión en el editor: se usa su propio trazado de rayos.
- No detecta instancias de `MultiMesh` (partículas, hierba) ni colisiones sin malla.
- Un nodo nunca se coloca sobre sí mismo ni sobre sus hijos.
- Con **Mallas** encendido, en una malla muy densa cada clic puede tardar un instante.
