# Menú de pausa único

El proyecto tiene **un solo menú de pausa**: el autoload `PauseMenu`
(`scripts/core/pause_menu.gd`, registrado en **Proyecto → Configuración del
proyecto → Globales / Autoload**). Funciona igual en la partida principal
(`main.tscn`) y en cualquier escena de trabajo con un `ExplorerPlayer`; no hace
falta añadir nada a cada escena.

## Contenido

| Botón | Qué hace |
| --- | --- |
| Seguir explorando | Cierra la pausa. |
| Ponerse / Quitarse el … | Uno por accesorio obtenido (vestuario). Sólo aparece cuando ya lo tienes. **green hat** abre un selector Equipar / Quitar / Cancelar; los demás accesorios conservan el cambio directo. |
| Reinicio rápido | Partida: vuelve a la cima junto al farol del mirador, sin cambiar el refugio de recuperación. Escena de trabajo: vuelve al punto de inicio de la ardilla. |
| Ajustes | Volumen, pantalla, apariencia, cámara y acabado pixelado. **Guardar y volver** los escribe en disco. |
| Volver al título | Partida: guarda y muestra el título. Escena de trabajo: abre `main.tscn`. |

**Esc / Start** abren la pausa; con mando, **círculo / B** también. Dentro del
menú, Esc / Start / círculo / B vuelven atrás un nivel. Start ya no hace el
reinicio rápido: ahora es un botón del menú, y se quitó su casilla de Ajustes.

## Cómo se integra una escena

- **Sin anfitrión (escenas de trabajo):** `PauseMenu` descubre al jugador
  humano, la `TrailCamera` y el `TrailAudio`, pausa el árbol y aplica los ajustes.
  No abre la pausa durante un diálogo (grupo `active_dialogue`).
- **Con anfitrión (partida principal):** `game.gd` llama a
  `PauseMenu.attach_host(self)` y responde a `pause_allowed()`,
  `pause_opened()`, `pause_closed()`, `pause_to_title()` y `pause_fast_reset()`.
  Así decide cuándo se puede pausar (sólo explorando) y guarda el progreso al pausar.
  Tras reconstruir la sesión llama a `PauseMenu.refresh()`.
- Los ajustes viven en `PauseMenu.settings`, que es la única fuente; `game.gd`
  usa ese mismo diccionario. Ajustes desde el título usa `PauseMenu.open_settings()`.
- `PauseMenu.play_cue(cue)` reproduce un `TrailSoundCue` con el `TrailAudio` de
  la escena, respetando los volúmenes de Ajustes.

## Selector de green hat

El pickup abre `PauseMenu.open_hat_choice()` y pausa el árbol. La interfaz
`ui/accessories/hat_choice.tscn` sigue funcionando durante la pausa; el menú
normal no puede abrirse encima. Equipar o Quitar guarda y cierra; Cancelar y
Esc no cambian el vestuario. Si se abrió desde el menú, vuelve a ese menú y
mantiene la pausa; si se abrió desde el objeto, vuelve a jugar. La pulsación
se consume al abrir y cerrar para no producir un salto con el mando.

La presentación escucha el cambio incluso en pausa. El sonido usa TrailAudio
si existe, o una voz SFX propia que respeta Master/SFX en escenas ligeras.
Un error de escritura mantiene el estado anterior y muestra un aviso.
Durante diálogos NPC no se abre ni este selector ni la pausa normal.
