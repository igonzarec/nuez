# Vista de depuración de escalada

Colorea la pantalla según la pendiente de cada superficie visible, usando los
mismos umbrales que decide el agarre del player. Sirve para esculpir rutas en
Terrain3D y ver de un vistazo dónde se puede empezar a trepar.

**Tecla:** `F3` durante el juego (alterna encendido/apagado).

## Dónde se ajusta la inclinación necesaria para trepar

| Superficie | Control | Ubicación |
| --- | --- | --- |
| Sin etiqueta (Terrain3D) y mallas en modo Heredar | Grab Min / Max Slope Degrees (65° / 89°) | Recurso **ClimbRules** del Player ([climb_rules.md](climb_rules.md)) |
| Agarre ya iniciado | Sustain Enabled / Min Slope Degrees (10°) | Recurso **ClimbRules** del Player |
| Suelo caminable | Walkable Slope Degrees (48°) | `SquirrelExplorer` (grupo superior) |
| Rocas `CliffPiece` (grupo `climbable`) | Climb Surface Tilt (35° desde vertical ⇒ ≥ 55° desde horizontal) | Nodo de la roca > **Escalada y física** |
| Malla de `CliffFoldsGenerator` | Climb Rule Mode (Heredar / Angulo Propio / Cualquier Pendiente) | Nodo del generador > **Aspecto y colision** |
| Otros `climbable` sin método propio | Constante 0,25 en `climbing.gd` (≈ ≥ 75,5°) | Código; no expuesto |

Sin player (editor), la vista usa su campo **Umbrales > Climb Rules**: asigna el
mismo `.tres` que el Player para ver lo mismo que en el juego.

Bajar **Grab Min** permite agarrarse a laderas menos verticales; subirlo
exige paredes más rectas. Todos se leen en vivo: con la vista activa, cambiar
el valor en **Remote** recolorea la pantalla al instante.

## Colores

| Color | Banda | Significado |
| --- | --- | --- |
| Azul (alfa 0 por defecto) | 0° – Walkable | Se camina. |
| Naranja | Walkable – Sustain Min | Desliza y no se puede trepar. Con los defaults no aparece, porque Sustain (40°) es menor que Walkable (48°). |
| Amarillo | max(Sustain, Walkable) – Grab Min | Sólo conserva un agarre ya iniciado (transición a la cima); no permite empezar a trepar. |
| Verde | Grab Min – Grab Max | Se puede iniciar la escalada. |
| Rojo | > Grab Max, techos | No se agarra. |

La leyenda de la esquina superior izquierda muestra los rangos efectivos e
indica `· manual` si no está leyendo los valores del player.

## Controles

El nodo `ClimbDebugView` está dentro de `scenes/camera_rig.tscn`, así que existe
en cualquier partida. Inspector:

- **Activación**: Enabled (encendida al iniciar), Toggle Key Enabled / Toggle
  Key, Editor Preview (dibujarla en el viewport del editor) y Show Legend.
- **Umbrales**: Read From Player lee el player automáticamente (target de la
  cámara). Los valores Manual se usan si está apagado o no hay player, por
  ejemplo en el editor. Player Path permite elegir uno concreto.
- **Colores**: color y alfa de cada banda, Opacity global, y Threshold Line
  Width Degrees para dibujar isolíneas en cada umbral (prueba 1,5°).
- **Alcance**: Max Distance (60 m) y Fade Distance (15 m); Ignore Player Radius
  evita teñir la ardilla (prueba 0,45 m; valores mayores ocultan la pared
  agarrada). Render Priority 102 queda encima del contorno y del agua.

Para previsualizar mientras esculpes: añade un nodo `Node3D` con el script
`scripts/debug/climb_debug_view.gd` a la escena del terreno, activa **Editor
Preview** y ajusta los umbrales Manual (o asigna Player Path).

## Cómo funciona y límites

Un quad de pantalla completa reconstruye la posición desde el depth buffer y
la normal a partir de los píxeles vecinos (eligiendo el de profundidad más
parecida para no inventar normales en las siluetas). Funciona en Compatibility.
Coste: un pase de pantalla con 5 lecturas de profundidad por píxel sólo
mientras está activa.

- Es una lectura **por pendiente** con la regla sin etiqueta. Las rocas del
  grupo `climbable` usan su propio límite y sus zonas (Selected Zones /
  Disabled), que esta vista no distingue.
- Muestra la **malla visual**, no la colisión. En Terrain3D coinciden; con
  proxies de colisión distintos pueden diferir.
- No evalúa alcance, orientación del jugador ni NPC bloqueados.
- Superficies transparentes (agua) no escriben profundidad: se colorea lo que
  hay debajo. A gran distancia la precisión de profundidad añade ruido.
