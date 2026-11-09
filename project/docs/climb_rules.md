# ClimbRules: reglas de escalada compartidas

`ClimbRules` es un recurso (`.tres`) con las reglas que deciden **a qué pendiente
se puede agarrar la ardilla**. Es la única fuente de verdad: lo leen el Player,
las superficies en modo *Heredar* y `ClimbDebugView`. Todo se aplica en vivo.

**Archivo por defecto:** `res://resources/climb/climb_rules_default.tres`
(asignado en `player.tscn`). Haz doble clic en FileSystem para editarlo.

## Controles (Inspector del .tres)

| Grupo | Campo | Defecto del .tres | Efecto |
| --- | --- | --- | --- |
| Agarre inicial | Untagged Enabled | Sí | Terrain3D y superficies sin etiqueta `climbable` se agarran por pendiente. |
| | Grab Min Slope Degrees | 65° | Pendiente mínima para **empezar** a trepar (Terrain3D y mallas en modo Heredar). |
| | Grab Max Slope Degrees | 89° | Pendiente máxima en superficies sin etiqueta. |
| Continuidad | Sustain Enabled / Min Slope Degrees | Sí / 10° | Pendiente mínima para **seguir** agarrado. |
| Orientación | Facing Angle Degrees | 45° | Desviación máxima entre hacia dónde mira la ardilla y la pared. |
| | Facing Horizontal | Sí | Mide esa desviación solo en horizontal; permite agarrarse a pendientes suaves. Apagado = medida 3D anterior. |

Siguen en el Player (son del cuerpo, no de la superficie):
**Walkable Slope Degrees**, **Climb Grab Distance** y el resto de *Escalada*.

## Quién lo usa

| Superficie | Cómo elegir las reglas |
| --- | --- |
| Terrain3D esculpido | Siempre ClimbRules. |
| Malla de `CliffFoldsGenerator` | **Aspecto y colision → Climb Rule Mode**: *Heredar* (recomendado), *Angulo Propio* (Climb Min Slope Degrees) o *Cualquier Pendiente*. |
| Rocas `CliffPiece` | **Escalada y física → Climb Inherit Rules**; apagado usa Climb Surface Tilt. |
| `ClimbDebugView` | Lee el ClimbRules del Player; sin player usa su propio campo **Climb Rules**. |
| Otros `climbable` sin método propio | Límite fijo ≈ 75,5° (sin cambios). |

## Límites útiles

- Por debajo de **Walkable Slope Degrees** la ardilla camina: agarrarse ahí solo
  lleva a salir por la cima.
- El agarre inicial usa un rayo horizontal desde el pecho (0,85 m) de longitud
  **Climb Grab Distance**. En una pendiente de ~30° el rayo apenas llega a 1,5 m;
  más tendida no la toca.
- Para escenas con reglas distintas, asigna otro `.tres` al Player de esa escena
  (no edites el compartido).
- **Climb Last Grab Miss** y **Climb Last Release** (Player, en Remote) dicen qué
  regla rechazó el agarre o soltó la escalada.

## Ejemplo: trepar pliegues tendidos de un cliff

1. Cliff → **Climb Rule Mode = Heredar**.
2. `climb_rules_default.tres` → **Grab Min Slope Degrees = 50**, **Facing Horizontal = Sí**.
3. F3 en juego: lo verde es donde puedes empezar a trepar.
