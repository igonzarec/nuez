# Vida sutil: parpadeo, orejas y balanceo de cuerpo

Componente `SquirrelFaceLife` (`scripts/squirrel_face_life.gd`), nodo **FaceLife** en
`scenes/player.tscn`. Los NPC lo heredan porque `squirrel_npc.tscn` instancia
`player.tscn` como `Body`: para ajustar un NPC concreto, activa *Editable Children*
en su `Body` y edita `Body → FaceLife`.

## Dónde están los controles

Inspector → FaceLife →
- **Parpadeo**: `Blink Enabled`, intervalo mínimo/máximo (2,5–6 s), tiempos de
  cierre/mantenido/apertura, `Blink Closed Scale` (escala vertical del ojo cerrado)
  y `Double Blink Chance`.
- **Orejas**: `Ears Enabled`, `Ears Intensity` y gestos rápidos ocasionales de una
  oreja (`Ear Flick Interval Min/Max`, `Ear Flick Degrees`, `Ear Flick Duration`).
- **Balanceo general**: `Body Sway Intensity` (multiplica cabeza, brazos, panza, cola y
  piernas), `Body Sway While Moving` (cuánto queda al desplazarse; 0 = sólo en reposo),
  `Body Sway Moving Speed` y `State Fade Speed`.
- **Cabeza**: cabeceo, inclinación lateral, giro y velocidad.
- **Brazos**: vaivén adelante/atrás, apertura y velocidad.
- **Panza** (hueso `spine`): inclinación tipo respiración, vaivén lateral y velocidad.
- **Piernas**: vaivén, apertura y velocidad.
- **Cola** (`tail_base` y `tail_tip`): vaivén lateral, subida/bajada, velocidad,
  `Tail Tip Amount` (amplitud de la punta) y `Tail Tip Lag` (retraso de la punta,
  crea la onda a lo largo de la cola).

Cada parte tiene su propio interruptor; un ángulo en 0 anula ese eje.

Todo se actualiza en vivo durante el juego (no hay preview en editor).

## Cómo funciona

- El parpadeo escala en Y las mallas `nuez_ojo_izquierdo` / `nuez_ojo_derecho` del GLB.
  Cada ardilla arranca con un desfase aleatorio, así los NPC no parpadean a la vez.
- Orejas y balanceos se aplican con un `SkeletonModifier3D` (huesos `ear_*`, `head`,
  `spine`, `arm_*`, `leg_*`, `tail_*`): se suman a la pose final (clip + SquirrelRig) sin
  acumularse entre frames. Los ángulos van en ejes del cuerpo y el lado derecho se refleja.
- Las ondas combinan dos senos con fases aleatorias por ardilla: no se ven sincronizadas
  ni se nota la repetición.
- En patinaje, nado, buceo, planeo y escalada SquirrelRig ya anima esas partes, así que
  los balanceos se desvanecen y vuelven al salir de esos estados.
- Sigue activo durante el diálogo.

## Ejemplos

- Ardilla nerviosa: `Ear Flick Interval` 1,5–4 s, `Blink Interval` 1,5–3,5 s.
- Ardilla tranquila/somnolienta: `Blink Open Time` 0,2, `Belly Sway Speed` 0,2, `Head Nod Degrees` 3.
- Sólo vida en reposo: `Body Sway While Moving` 0.
