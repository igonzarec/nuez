# Escalada con brazos manuales (L2/R2)

Es la misma lógica que los pies del patinaje sobre hielo, aplicada a la
escalada. Está activa por defecto y se puede apagar.

## Cómo se juega

- Mantén **Climb** (F / A) para agarrarte, como siempre.
- **L2 / Z** tira con el brazo izquierdo y **R2 / C** con el derecho. Hay que
  alternarlos. Cada tirón avanza un tramo (`Climb Pull Distance`) en la
  dirección del stick: arriba, abajo o lateral. Con el stick neutro sube.
  Sin tirones se queda agarrada, sin moverse.
- Tirar con más ritmo hace trepar más rápido.
- **Mantener un gatillo** deja ese brazo estirado arriba, sin avanzar, hasta
  soltarlo.
- **Fallos**: repetir el mismo brazo, o mantener ambos gatillos más tiempo del
  que permite la dificultad, la deja **colgada de un brazo**. Durante
  `Climb Hang Duration` no puede moverse: patalea, agita el brazo libre y se
  balancea. Después se recupera sin soltarse.
- Al llegar a la cima, un tirón hacia arriba activa la transición de cima
  habitual.
- Recentrar la cámara se hace con R3 (clic del stick derecho) o V.

## Controles en el Inspector

En `SquirrelExplorer` (`scenes/player.tscn`):

- **Escalada · brazos (L2/R2)**
  - `Climb Manual Arms`: apagado, vuelve el movimiento continuo con el stick.
  - `Climb Pull Distance` y `Climb Pull Duration`: tramo y duración de cada
    tirón.
  - **`Climb Arms Difficulty`** (0–1): ventana de solape tolerada entre
    gatillos, de 0,35 s a 0,04 s. Es independiente de la del patinaje.
  - `Climb Same Arm Memory`: tras este tiempo sin tirar, se puede repetir el
    mismo brazo sin fallo.
  - `Climb Hold Arm Enabled` y `Climb Hold Arm Reach Degrees`: brazo estirado al
    mantener el gatillo.
- **Escalada · colgada de un brazo**
  - `Climb Hang Enabled`, `Climb Hang Duration` y `Climb Hang Scream Enabled`
    (grito del splat al quedar colgada).
  - Elevación del brazo que sostiene y del brazo libre.
  - Pataleo, su frecuencia y el balanceo del cuerpo.

Todo se actualiza en vivo. Los NPC nunca usan brazos manuales.

## Cómo funciona

- `ExplorerPlayer.climb_arms_input()` sustituye el stick en `Climbing.tick()`.
  Sólo devuelve movimiento durante un tirón, con una curva `sin(π·t)` que
  recorre exactamente `Climb Pull Distance`. Por eso la cima, la continuidad y
  el resto de la escalada siguen funcionando igual.
- Cada tirón fija `climb_manual_phase`, que `SquirrelRig` usa como fase del
  ciclo procedural en lugar de avanzarla por distancia. El tirón centra el pico
  de elevación del brazo correspondiente, respetando `Arm Phase`,
  `Opposite Side Phase` y `Reverse Cycle`.
- Los huesos `*_left` del rig son el lado **derecho** del personaje visto desde
  atrás, porque el modelo está girado 180°. Por eso L2 mueve `arm_right` y
  `leg_right`. Lo mismo vale para los pies del patinaje.
